"""Inspect, fault and wait on a verifier's known child; never select by name."""
import ctypes
import ctypes.wintypes as w
from pathlib import Path


class ProcessEntry(ctypes.Structure):
    _fields_ = [('size', w.DWORD), ('usage', w.DWORD), ('pid', w.DWORD), ('heap', ctypes.c_size_t),
                ('module', w.DWORD), ('threads', w.DWORD), ('parent', w.DWORD), ('priority', w.LONG),
                ('flags', w.DWORD), ('image', w.WCHAR * 260)]


class ThreadEntry(ctypes.Structure):
    _fields_ = [('size', w.DWORD), ('usage', w.DWORD), ('tid', w.DWORD), ('owner', w.DWORD),
                ('priority', w.LONG), ('delta', w.LONG), ('flags', w.DWORD)]


class OwnedProcess:
    def __init__(self, pid, parent, executable):
        self.api = api = ctypes.WinDLL('kernel32', use_last_error=True)
        api.CreateToolhelp32Snapshot.argtypes = [w.DWORD, w.DWORD]
        api.CreateToolhelp32Snapshot.restype = w.HANDLE
        api.Process32FirstW.argtypes = [w.HANDLE, ctypes.POINTER(ProcessEntry)]
        api.Process32NextW.argtypes = [w.HANDLE, ctypes.POINTER(ProcessEntry)]
        api.Thread32First.argtypes = [w.HANDLE, ctypes.POINTER(ThreadEntry)]
        api.Thread32Next.argtypes = [w.HANDLE, ctypes.POINTER(ThreadEntry)]
        api.OpenProcess.argtypes = [w.DWORD, w.BOOL, w.DWORD]
        api.OpenProcess.restype = w.HANDLE
        api.QueryFullProcessImageNameW.argtypes = [w.HANDLE, w.DWORD, w.LPWSTR, ctypes.POINTER(w.DWORD)]
        api.GetExitCodeProcess.argtypes = [w.HANDLE, ctypes.POINTER(w.DWORD)]
        api.WaitForSingleObject.argtypes = [w.HANDLE, w.DWORD]
        api.TerminateProcess.argtypes = [w.HANDLE, w.UINT]
        api.OpenThread.argtypes = [w.DWORD, w.BOOL, w.DWORD]
        api.OpenThread.restype = w.HANDLE
        api.SuspendThread.argtypes = [w.HANDLE]
        api.SuspendThread.restype = w.DWORD
        api.CloseHandle.argtypes = [w.HANDLE]
        snapshot = api.CreateToolhelp32Snapshot(2, 0)
        if snapshot == w.HANDLE(-1).value:
            raise RuntimeError('Could not inspect verifier-owned process')
        found = False
        try:
            entry = ProcessEntry()
            entry.size = ctypes.sizeof(entry)
            more = api.Process32FirstW(snapshot, ctypes.byref(entry))
            while more:
                if entry.pid == pid:
                    found = entry.parent == parent
                    break
                more = api.Process32NextW(snapshot, ctypes.byref(entry))
        finally:
            api.CloseHandle(snapshot)
        if not found:
            raise RuntimeError('Refused process fault: parent is not this verifier host')
        self.handle = api.OpenProcess(0x1000 | 0x100000 | 0x0001, False, pid)
        if not self.handle:
            raise RuntimeError('Could not open verifier-owned process')
        self.pid = pid
        try:
            buffer = ctypes.create_unicode_buffer(32768)
            length = w.DWORD(len(buffer))
            code = w.DWORD()
            if (not api.QueryFullProcessImageNameW(self.handle, 0, buffer, ctypes.byref(length))
                    or Path(buffer.value).resolve() != Path(executable).resolve()
                    or not api.GetExitCodeProcess(self.handle, ctypes.byref(code)) or code.value != 259):
                raise RuntimeError('Refused process fault: executable or live handle mismatch')
        except Exception:
            self.close()
            raise

    def terminate(self):
        if not self.api.TerminateProcess(self.handle, 67):
            raise RuntimeError('Owned process termination failed')

    def suspend(self):
        snapshot = self.api.CreateToolhelp32Snapshot(4, 0)
        if snapshot == w.HANDLE(-1).value:
            raise RuntimeError('Owned process thread inventory failed')
        count = 0
        try:
            entry = ThreadEntry()
            entry.size = ctypes.sizeof(entry)
            more = self.api.Thread32First(snapshot, ctypes.byref(entry))
            while more:
                if entry.owner == self.pid:
                    handle = self.api.OpenThread(2, False, entry.tid)
                    if not handle:
                        raise RuntimeError('Owned thread could not be opened')
                    try:
                        if self.api.SuspendThread(handle) == 0xffffffff:
                            raise RuntimeError('Owned thread suspension failed')
                        count += 1
                    finally:
                        self.api.CloseHandle(handle)
                more = self.api.Thread32Next(snapshot, ctypes.byref(entry))
        finally:
            self.api.CloseHandle(snapshot)
        if not count:
            raise RuntimeError('No owned process threads were suspended')
        return count

    def wait(self, seconds):
        return self.api.WaitForSingleObject(self.handle, int(seconds * 1000)) == 0

    def close(self):
        if self.handle:
            self.api.CloseHandle(self.handle)
            self.handle = None

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()
