package servicehost

import (
	"os"
	"os/exec"
	"syscall"
	"unsafe"
)

var kernel = syscall.NewLazyDLL("kernel32.dll")
var createJob = kernel.NewProc("CreateJobObjectW")
var setJob = kernel.NewProc("SetInformationJobObject")
var assignJob = kernel.NewProc("AssignProcessToJobObject")
var terminateJob = kernel.NewProc("TerminateJobObject")

type jobBasic struct {
	ProcessTime, JobTime int64
	Flags                uint32
	Minimum, Maximum     uintptr
	Active               uint32
	Affinity             uintptr
	Priority, Scheduling uint32
}
type jobIO struct{ ReadOps, WriteOps, OtherOps, ReadBytes, WriteBytes, OtherBytes uint64 }
type jobExtended struct {
	Basic                                          jobBasic
	IO                                             jobIO
	ProcessMemory, JobMemory, PeakProcess, PeakJob uintptr
}

type processContainment struct{ job syscall.Handle }

func containProcess(cmd *exec.Cmd) (processContainment, error) {
	handle, _, err := createJob.Call(0, 0)
	if handle == 0 {
		return processContainment{}, err
	}
	guard := processContainment{syscall.Handle(handle)}
	info := jobExtended{}
	info.Basic.Flags = 0x00002000 // JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
	ok, _, err := setJob.Call(handle, 9, uintptr(unsafe.Pointer(&info)), unsafe.Sizeof(info))
	if ok == 0 {
		guard.close()
		return processContainment{}, err
	}
	cmd.SysProcAttr = &syscall.SysProcAttr{CreationFlags: 0x08000000} // CREATE_NO_WINDOW
	return guard, nil
}

func (g processContainment) attach(pid int) error {
	handle, err := syscall.OpenProcess(0x0100|0x0001, false, uint32(pid)) // SET_QUOTA | TERMINATE
	if err != nil {
		return err
	}
	defer syscall.CloseHandle(handle)
	ok, _, err := assignJob.Call(uintptr(g.job), uintptr(handle))
	if ok == 0 {
		return err
	}
	return nil
}
func (g processContainment) terminate(_ int) { _, _, _ = terminateJob.Call(uintptr(g.job), 1) }
func (g processContainment) kill(pid int)    { g.terminate(pid) }
func (g processContainment) close() {
	if g.job != 0 {
		_ = syscall.CloseHandle(g.job)
	}
}

func lockState(path string) (*os.File, error) {
	name, err := syscall.UTF16PtrFromString(path)
	if err != nil {
		return nil, err
	}
	handle, err := syscall.CreateFile(name, syscall.GENERIC_READ|syscall.GENERIC_WRITE, syscall.FILE_SHARE_READ, nil, syscall.OPEN_ALWAYS, syscall.FILE_ATTRIBUTE_NORMAL, 0)
	if err != nil {
		return nil, err
	}
	return os.NewFile(uintptr(handle), path), nil
}
