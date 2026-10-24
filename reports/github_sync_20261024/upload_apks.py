"""Upload the manifest's APKs to our new draft release, preserving existing assets."""
from pathlib import Path
import concurrent.futures as cf
import subprocess,json,time,threading
R=Path(r"D:\new-bee");O=R/"reports/github_sync_20261024"
manifest=json.loads((O/"release_assets.json").read_text(encoding="utf-8"))
REPO=manifest["repository"];TAG=manifest["tag"];GH=r"C:\Program Files\GitHub CLI\gh.exe"
state_path=O/"upload_staging/upload_state.json";lock=threading.Lock();states={}
def gh(*args,timeout=3600):
    return subprocess.run([GH,*args],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=timeout)
def release():
    p=gh("api","repos/"+REPO+"/releases/tags/"+TAG,timeout=90)
    if p.returncode:raise RuntimeError(p.stderr.decode(errors="replace")[-1000:])
    return json.loads(p.stdout)
def record(name,**values):
    with lock:
        states.setdefault(name,{}).update(values)
        state_path.write_text(json.dumps(states,ensure_ascii=False,indent=2),encoding="utf-8")
def upload(row):
    name=row["asset"];src=O/"upload_staging"/name if name=="Yuanzheng-0.2.1-mobile2-arm64.apk" else R/row["path"]
    started=time.time();record(name,state="uploading",bytes=row["bytes"],started=started)
    print("START",name,row["bytes"],flush=True)
    for attempt in range(1,4):
        current=release()
        assert current["tag_name"]==TAG
        existing=next((a for a in current["assets"] if a["name"]==name),None)
        if existing and existing["state"]=="uploaded" and existing["size"]==row["bytes"]:
            digest=existing.get("digest")
            if digest and digest!="sha256:"+row["sha256"]:raise RuntimeError("Remote checksum mismatch: "+name)
            record(name,state="verified",asset_id=existing["id"],digest=digest,size=existing["size"],seconds=round(time.time()-started,1))
            print("VERIFIED",name,"seconds",round(time.time()-started,1),flush=True)
            return
        if existing:
            raise RuntimeError("Unexpected existing incomplete or different asset; inspect before retry: "+name)
        p=gh("release","upload",TAG,str(src),"--repo",REPO)
        if p.returncode==0:continue
        error=p.stderr.decode(errors="replace")[-1800:]
        record(name,state="retry",attempt=attempt,error=error)
        print("RETRY",name,attempt,error[-400:],flush=True)
        time.sleep(3*attempt)
    # Upload may have succeeded on the final attempt. Verify once more.
    current=release();existing=next((a for a in current["assets"] if a["name"]==name),None)
    if existing and existing["state"]=="uploaded" and existing["size"]==row["bytes"] and existing.get("digest") in (None,"sha256:"+row["sha256"]):
        record(name,state="verified",asset_id=existing["id"],digest=existing.get("digest"),size=existing["size"],seconds=round(time.time()-started,1))
        print("VERIFIED",name,flush=True);return
    record(name,state="failed")
    raise RuntimeError("Upload failed: "+name)
def main():
    with cf.ThreadPoolExecutor(max_workers=3) as pool:
        futures={pool.submit(upload,row):row["asset"] for row in manifest["assets"]}
        errors=[]
        for f in cf.as_completed(futures):
            try:f.result()
            except Exception as ex:
                errors.append({"asset":futures[f],"error":str(ex)})
                print("ERROR",futures[f],str(ex),flush=True)
    if errors:
        (O/"upload_staging/upload_errors.json").write_text(json.dumps(errors,ensure_ascii=False,indent=2),encoding="utf-8")
        raise RuntimeError(str(errors))
    print("ALL_APK_UPLOADS_VERIFIED",len(states),flush=True)
if __name__=="__main__":main()

