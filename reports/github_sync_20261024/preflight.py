from pathlib import Path
import subprocess,json,re,hashlib,collections
R=Path(r"D:\new-bee");O=R/"reports/github_sync_20261024";O.mkdir(exist_ok=True)
def git(*a):return subprocess.run(["git",*a],cwd=R,stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True).stdout
paths=set(x.decode("utf-8") for x in git("ls-files","-m","-o","--exclude-standard","-z").split(b"\0") if x)
large=[];files=[];signals=[]
patterns={"github_token":rb"\bgh[pousr]_[A-Za-z0-9]{30,}\b","github_fine_token":rb"github_pat_[A-Za-z0-9_]{40,}","aws_access_key":rb"\bAKIA[0-9A-Z]{16}\b","private_key":rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----","openai_token":rb"\bsk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{40,}"}
binary={".png",".jpg",".jpeg",".wav",".mp4",".zip",".apk",".exe",".dll",".idsig",".docx",".pck",".webp",".ogg",".ttf",".woff"}
for name in sorted(paths):
    p=R/name
    if not p.is_file():continue
    size=p.stat().st_size;files.append({"path":name,"bytes":size})
    if size>100*1024*1024:large.append({"path":name,"bytes":size})
    if p.suffix.lower() not in binary and size<20*1024*1024:
        data=p.read_bytes()
        for k,pattern in patterns.items():
            for m in re.finditer(pattern,data):
                signals.append({"path":name,"line":data[:m.start()].count(b"\n")+1,"pattern":k,"fingerprint":hashlib.sha256(m.group()).hexdigest()[:12]})
apk_paths=[R/x["path"] for x in large if x["path"].endswith(".apk")]
latest=R/"远征/exports/android/Yuanzheng-0.2.1-mobile2.apk"
assert latest.is_file()
apk_paths.append(latest)
assets=[]
for p in apk_paths:
    assets.append({"path":p.relative_to(R).as_posix(),"bytes":p.stat().st_size,"sha256":hashlib.file_digest(p.open("rb"),"sha256").hexdigest(),"asset":("Yuanzheng-0.2.1-mobile2-arm64.apk" if p==latest else p.name)})
assert len({x["asset"] for x in assets})==len(assets)
out={"repository":"3311930677/new-bee","branch":"main","base":git("rev-parse","HEAD").decode().strip(),"pending_files":len(files),"pending_bytes":sum(x["bytes"] for x in files),"large_files":large,"secret_signals":signals,"release_assets":assets}
(O/"preflight.json").write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding="utf-8")
(O/"pending_paths.txt").write_text("\n".join(sorted(paths))+"\n",encoding="utf-8")
print(json.dumps({k:v for k,v in out.items() if k not in ["release_assets"]},ensure_ascii=False))
print("APK assets",len(assets),"bytes",sum(x["bytes"] for x in assets))

