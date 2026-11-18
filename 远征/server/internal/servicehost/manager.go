package servicehost

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

var ErrRestartBudget = errors.New("service restart budget exhausted")
var ErrState = errors.New("private service state unavailable")

type Health struct {
	Live, Ready bool
	Code        string
}
type Probe func(context.Context) Health

type Spec struct {
	Kind, Directory, StateDirectory string
	Command, Environment            []string
	Policy                          Policy
	Probe                           Probe
	DevelopmentACL                  bool
}

type Status struct {
	Version        int    `json:"version"`
	Kind           string `json:"kind"`
	RunID          string `json:"run_id"`
	SupervisorPID  int    `json:"supervisor_pid"`
	ChildPID       int    `json:"child_pid"`
	Generation     int    `json:"generation"`
	ChildStarts    int    `json:"child_starts"`
	Phase          string `json:"phase"`
	Reason         string `json:"reason"`
	Live           bool   `json:"live"`
	Ready          bool   `json:"ready"`
	DevelopmentACL bool   `json:"development_acl_acknowledged"`
	UpdatedUTC     string `json:"updated_utc"`
	LastProbeMS    int64  `json:"last_probe_ms"`
	LastProbeCode  string `json:"last_probe_code"`
	UnhealthyForMS int64  `json:"unhealthy_for_ms"`
}

func saveStatus(directory string, status Status) error {
	data, err := json.MarshalIndent(status, "", "  ")
	if err != nil {
		return ErrState
	}
	temporary := filepath.Join(directory, ".status-"+status.RunID+".tmp")
	if err = os.WriteFile(temporary, data, 0600); err != nil {
		return ErrState
	}
	defer os.Remove(temporary)
	return replaceStateFile(temporary, filepath.Join(directory, "status.json"))
}

func replaceStateFile(source, target string) error {
	for attempt := 0; attempt < 15; attempt++ {
		if os.Rename(source, target) == nil {
			return nil
		}
		if attempt < 14 {
			time.Sleep(20 * time.Millisecond)
		}
	}
	return ErrState
}

func readStatus(directory string) (Status, error) {
	path := filepath.Join(directory, "status.json")
	for attempt := 0; attempt < 10; attempt++ {
		data, err := os.ReadFile(path)
		if err == nil && len(data) <= 8192 {
			var status Status
			if json.Unmarshal(data, &status) == nil && len(status.RunID) == 32 {
				if _, decodeErr := hex.DecodeString(status.RunID); decodeErr == nil {
					return status, nil
				}
			}
		}
		if attempt < 9 {
			time.Sleep(20 * time.Millisecond)
		}
	}
	return Status{}, ErrState
}

func stopRequested(directory, runID string) bool {
	path := filepath.Join(directory, "stop.request")
	info, err := os.Lstat(path)
	if err != nil || !info.Mode().IsRegular() || info.Size() > 128 {
		return false
	}
	data, err := os.ReadFile(path)
	return err == nil && strings.TrimSpace(string(data)) == runID
}

// RequestStop is a private filesystem control for the foreground Windows
// development host. Production service managers send SIGTERM to their own unit.
// A stale request cannot stop a new host incarnation.
func RequestStop(directory string) error {
	if !filepath.IsAbs(directory) {
		return ErrState
	}
	status, err := readStatus(directory)
	if err != nil {
		return err
	}
	path := filepath.Join(directory, ".stop-"+status.RunID+".tmp")
	file, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return ErrState
	}
	defer os.Remove(path)
	_, writeErr := file.WriteString(status.RunID)
	closeErr := file.Close()
	if writeErr != nil || closeErr != nil {
		return ErrState
	}
	// The receiver can briefly hold the previous request open on Windows.
	// Publish by replacement so neither readers nor hard links see a partial write.
	return replaceStateFile(path, filepath.Join(directory, "stop.request"))
}

type child struct {
	command *exec.Cmd
	guard   processContainment
	log     *boundedLog
	done    chan struct{}
	err     error
}

func startChild(spec Spec, runID string, generation int) (*child, error) {
	output, err := newBoundedLog(spec.StateDirectory, runID, generation)
	if err != nil {
		return nil, ErrState
	}
	command := exec.Command(spec.Command[0], spec.Command[1:]...)
	command.Env, command.Dir = spec.Environment, spec.Directory
	command.Stdout, command.Stderr = output, output
	command.WaitDelay = 2 * time.Second
	guard, err := containProcess(command)
	if err != nil {
		output.Close()
		return nil, err
	}
	if err = command.Start(); err != nil {
		guard.close()
		output.Close()
		return nil, err
	}
	if err = guard.attach(command.Process.Pid); err != nil {
		_ = command.Process.Kill()
		_ = command.Wait()
		guard.close()
		output.Close()
		return nil, err
	}
	process := &child{command: command, guard: guard, log: output, done: make(chan struct{})}
	go func() { process.err = command.Wait(); close(process.done) }()
	return process, nil
}

func (c *child) stop(grace time.Duration) {
	select {
	case <-c.done:
	default:
		c.guard.terminate(c.command.Process.Pid)
	}
	timer := time.NewTimer(grace)
	defer timer.Stop()
	select {
	case <-c.done:
	case <-timer.C:
		c.guard.kill(c.command.Process.Pid)
		_ = c.command.Process.Kill()
		<-c.done
	}
	c.guard.close()
	c.log.Close()
}

// Run owns one child at a time. Readiness never drives a restart: only an
// unexpected exit, an initial liveness deadline or consecutive liveness misses.
func Run(ctx context.Context, spec Spec, logger *slog.Logger) error {
	if len(spec.Command) == 0 || spec.Probe == nil || !filepath.IsAbs(spec.StateDirectory) || !spec.Policy.valid() {
		return ErrConfiguration
	}
	if err := os.MkdirAll(spec.StateDirectory, 0700); err != nil {
		return ErrState
	}
	info, err := os.Lstat(spec.StateDirectory)
	if err != nil || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 || (runtime.GOOS != "windows" && info.Mode().Perm()&0077 != 0) {
		return ErrState
	}
	lock, err := lockState(filepath.Join(spec.StateDirectory, "service.lock"))
	if err != nil {
		return ErrState
	}
	defer lock.Close()
	var random [16]byte
	if _, err = rand.Read(random[:]); err != nil {
		return ErrState
	}
	status := Status{Version: 1, Kind: spec.Kind, RunID: hex.EncodeToString(random[:]), SupervisorPID: os.Getpid(), DevelopmentACL: spec.DevelopmentACL}
	lastPhase, lastReason, lastGeneration := "", "", -1
	publish := func(phase, reason string, live, ready bool) error {
		status.Phase, status.Reason, status.Live, status.Ready = phase, reason, live, ready
		status.UpdatedUTC = time.Now().UTC().Format(time.RFC3339Nano)
		if err := saveStatus(spec.StateDirectory, status); err != nil {
			return err
		}
		if phase != lastPhase || reason != lastReason || status.Generation != lastGeneration {
			logger.Info("service state", "kind", spec.Kind, "phase", phase, "reason", reason, "generation", status.Generation, "child_pid", status.ChildPID, "ready", ready, "probe_ms", status.LastProbeMS, "probe_code", status.LastProbeCode, "unhealthy_ms", status.UnhealthyForMS)
			lastPhase, lastReason, lastGeneration = phase, reason, status.Generation
		}
		return nil
	}
	stopped := func() error { status.ChildPID = 0; return publish("stopped", "requested", false, false) }
	policy := spec.Policy
	interval := time.Duration(policy.ProbeIntervalMS) * time.Millisecond
	window := time.Duration(policy.RestartWindowSec) * time.Second
	attempts := []time.Time{}
	backoff := time.Duration(policy.BackoffInitialMS) * time.Millisecond
	for {
		if ctx.Err() != nil || stopRequested(spec.StateDirectory, status.RunID) {
			return stopped()
		}
		now := time.Now()
		retained := attempts[:0]
		for _, attempt := range attempts {
			if now.Sub(attempt) < window {
				retained = append(retained, attempt)
			}
		}
		attempts = retained
		if len(attempts) >= policy.RestartBurst {
			if err := publish("failed", "restart_budget", false, false); err != nil {
				return err
			}
			return ErrRestartBudget
		}
		attempts = append(attempts, now)
		status.Generation++
		status.ChildPID = 0
		if err := publish("starting", "launch", false, false); err != nil {
			return err
		}
		process, startErr := startChild(spec, status.RunID, status.Generation)
		reason := "child_start_failed"
		if startErr == nil {
			status.ChildPID = process.command.Process.Pid
			status.ChildStarts++
			if err := publish("starting", "liveness_pending", false, false); err != nil {
				process.stop(0)
				return err
			}
			ticker := time.NewTicker(interval)
			liveBefore, failures := false, 0
			var unhealthySince time.Time
			reason = "child_exit"
		monitor:
			for {
				select {
				case <-ctx.Done():
					process.stop(time.Duration(policy.StopTimeoutSec) * time.Second)
					ticker.Stop()
					return stopped()
				case <-process.done:
					break monitor
				case <-ticker.C:
					if stopRequested(spec.StateDirectory, status.RunID) {
						process.stop(time.Duration(policy.StopTimeoutSec) * time.Second)
						ticker.Stop()
						return stopped()
					}
					probeCtx, cancel := context.WithTimeout(ctx, time.Duration(policy.ProbeTimeoutMS)*time.Millisecond)
					probeStarted := time.Now()
					health := spec.Probe(probeCtx)
					status.LastProbeMS, status.LastProbeCode = time.Since(probeStarted).Milliseconds(), health.Code
					cancel()
					if health.Live {
						liveBefore, failures = true, 0
						unhealthySince = time.Time{}
						status.UnhealthyForMS = 0
					} else {
						failures++
						if unhealthySince.IsZero() {
							unhealthySince = time.Now()
						}
						status.UnhealthyForMS = time.Since(unhealthySince).Milliseconds()
					}
					if !health.Live && ((!liveBefore && time.Since(now) >= time.Duration(policy.StartupTimeoutSec)*time.Second) || (liveBefore && failures >= policy.FailureThreshold && status.UnhealthyForMS >= int64(policy.LivenessGraceMS))) {
						reason = "liveness_timeout"
						break monitor
					}
					phase, why := "starting", "liveness_pending"
					if health.Code != "" {
						why = health.Code
					}
					if health.Live {
						phase, why = "degraded", "dependency_not_ready"
						if health.Ready {
							phase, why = "running", "healthy"
						}
					}
					if err := publish(phase, why, health.Live, health.Ready); err != nil {
						process.stop(0)
						ticker.Stop()
						return err
					}
				}
			}
			ticker.Stop()
			process.stop(time.Duration(policy.StopTimeoutSec) * time.Second)
		}
		status.ChildPID = 0
		if ctx.Err() != nil || stopRequested(spec.StateDirectory, status.RunID) {
			return stopped()
		}
		if err := publish("backoff", reason, false, false); err != nil {
			return err
		}
		if time.Since(now) >= window {
			backoff = time.Duration(policy.BackoffInitialMS) * time.Millisecond
		}
		waitUntil := time.Now().Add(backoff)
		for time.Now().Before(waitUntil) {
			if ctx.Err() != nil || stopRequested(spec.StateDirectory, status.RunID) {
				return stopped()
			}
			remaining := time.Until(waitUntil)
			if remaining > interval {
				remaining = interval
			}
			timer := time.NewTimer(remaining)
			select {
			case <-ctx.Done():
				timer.Stop()
				return stopped()
			case <-timer.C:
			}
		}
		backoff *= 2
		maximum := time.Duration(policy.BackoffMaximumMS) * time.Millisecond
		if backoff > maximum {
			backoff = maximum
		}
	}
}
