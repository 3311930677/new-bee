package servicehost

import (
	"os"
	"os/exec"
	"syscall"
)

type processContainment struct{}

func containProcess(cmd *exec.Cmd) (processContainment, error) {
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true, Pdeathsig: syscall.SIGKILL}
	return processContainment{}, nil
}
func (g processContainment) attach(_ int) error { return nil }
func (g processContainment) terminate(pid int)  { _ = syscall.Kill(-pid, syscall.SIGTERM) }
func (g processContainment) kill(pid int)       { _ = syscall.Kill(-pid, syscall.SIGKILL) }
func (g processContainment) close()             {}
func lockState(path string) (*os.File, error) {
	file, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return nil, err
	}
	if err = syscall.Flock(int(file.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		file.Close()
		return nil, err
	}
	return file, nil
}
