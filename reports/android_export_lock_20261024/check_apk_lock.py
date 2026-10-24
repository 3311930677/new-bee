import ctypes as c,json
from ctypes import wintypes as w
from pathlib import Path
p=str(Path(r"D:\new-bee\远征\Yuanzheng.apk"))
rm=c.WinDLL("rstrtmgr")
class UNIQUE(c.Structure):_fields_=[("pid",w.DWORD),("started",w.FILETIME)]
class INFO(c.Structure):_fields_=[("process",UNIQUE),("app",w.WCHAR*256),("service",w.WCHAR*64),("type",c.c_int),("status",w.ULONG),("session",w.DWORD),("restartable",w.BOOL)]
session=w.DWORD();key=c.create_unicode_buffer(33)
err=rm.RmStartSession(c.byref(session),0,key)
if err:raise OSError(err,"RmStartSession")
try:
    names=(w.LPCWSTR*1)(p)
    err=rm.RmRegisterResources(session,1,names,0,None,0,None)
    if err:raise OSError(err,"RmRegisterResources")
    needed=w.UINT();count=w.UINT();reason=w.DWORD()
    err=rm.RmGetList(session,c.byref(needed),c.byref(count),None,c.byref(reason))
    rows=[]
    if err==234:
        buf=(INFO*needed.value)();count.value=needed.value
        err=rm.RmGetList(session,c.byref(needed),c.byref(count),buf,c.byref(reason))
        if err:raise OSError(err,"RmGetList")
        for row in buf[:count.value]:rows.append({"pid":row.process.pid,"app":row.app,"type":row.type})
    elif err:raise OSError(err,"RmGetList")
    out={"path":p,"locking_apps":rows}
finally:rm.RmEndSession(session)
k=c.WinDLL("kernel32",use_last_error=True)
k.CreateFileW.argtypes=[w.LPCWSTR,w.DWORD,w.DWORD,c.c_void_p,w.DWORD,w.DWORD,w.HANDLE]
k.CreateFileW.restype=w.HANDLE
h=k.CreateFileW(p,0xC0000000,0,None,3,0,None)
if h==c.c_void_p(-1).value:out["exclusive_open_error"]=c.get_last_error()
else:k.CloseHandle(w.HANDLE(h));out["exclusive_open_error"]=0
r=Path(r"D:\new-bee\reports\android_export_lock_20261024");r.mkdir(exist_ok=True)
(r/"lock_check.json").write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding="utf-8")
print(json.dumps(out,ensure_ascii=False))

