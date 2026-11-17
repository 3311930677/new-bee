package servicehost

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"sync"
)

const childLogLimit = 2 * 1024 * 1024
const retainedChildLogs = 8

var childLogName = regexp.MustCompile(`^child-[0-9a-f]{32}-[0-9]{6}\.log$`)

type boundedLog struct {
	mu      sync.Mutex
	file    *os.File
	written int
	limited bool
}

func newBoundedLog(directory, runID string, generation int) (*boundedLog, error) {
	entries, err := os.ReadDir(directory)
	if err != nil {
		return nil, err
	}
	type entry struct {
		path     string
		modified int64
	}
	var logs []entry
	for _, item := range entries {
		if !childLogName.MatchString(item.Name()) || !item.Type().IsRegular() {
			continue
		}
		info, err := item.Info()
		if err != nil {
			return nil, err
		}
		logs = append(logs, entry{filepath.Join(directory, item.Name()), info.ModTime().UnixNano()})
	}
	sort.Slice(logs, func(i, j int) bool { return logs[i].modified < logs[j].modified })
	for len(logs) >= retainedChildLogs {
		if err := os.Remove(logs[0].path); err != nil {
			return nil, err
		}
		logs = logs[1:]
	}
	file, err := os.OpenFile(filepath.Join(directory, fmt.Sprintf("child-%s-%06d.log", runID, generation)), os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return nil, err
	}
	return &boundedLog{file: file}, nil
}

func (l *boundedLog) Write(data []byte) (int, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.limited {
		return len(data), nil
	}
	if l.written+len(data) > childLogLimit {
		l.limited = true
		_, err := l.file.WriteString("\nSERVICE_CHILD_LOG_LIMIT_REACHED\n")
		return len(data), err
	}
	n, err := l.file.Write(data)
	l.written += n
	return n, err
}

func (l *boundedLog) Close() { l.mu.Lock(); defer l.mu.Unlock(); _ = l.file.Close() }
