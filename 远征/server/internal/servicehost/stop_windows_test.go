package servicehost

import (
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"
)

func TestRequestStopToleratesBriefReaderOfPreviousRequest(t *testing.T) {
	directory := t.TempDir()
	id := strings.Repeat("b", 32)
	if err := saveStatus(directory, Status{RunID: id}); err != nil {
		t.Fatal(err)
	}
	stop := filepath.Join(directory, "stop.request")
	if err := os.WriteFile(stop, []byte(strings.Repeat("a", 32)), 0600); err != nil {
		t.Fatal(err)
	}
	path, err := syscall.UTF16PtrFromString(stop)
	if err != nil {
		t.Fatal(err)
	}
	handle, err := syscall.CreateFile(path, syscall.GENERIC_READ, syscall.FILE_SHARE_READ|syscall.FILE_SHARE_WRITE, nil,
		syscall.OPEN_EXISTING, syscall.FILE_ATTRIBUTE_NORMAL, 0)
	if err != nil {
		t.Fatal(err)
	}
	released := make(chan error, 1)
	go func() {
		time.Sleep(35 * time.Millisecond)
		released <- syscall.CloseHandle(handle)
	}()
	err = RequestStop(directory)
	if closeErr := <-released; closeErr != nil {
		t.Fatal(closeErr)
	}
	if err != nil || !stopRequested(directory, id) {
		t.Fatal("an open reader prevented the new nonce-bound stop request")
	}
}
