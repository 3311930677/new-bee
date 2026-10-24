"""Lossless standard tar.zst backup of all nine APK builds, with payload verification."""
from pathlib import Path
import sys,json,tarfile,hashlib,io,time
R=Path(r"D:\new-bee");O=R/"reports/github_sync_20261024";ST=O/"upload_staging"
sys.path.insert(0,str(R/"tools/github-upload-deps"))
import zstandard as z
M=json.loads((O/"release_assets.json").read_text(encoding="utf-8"))
ARCHIVE=ST/"Yuanzheng-apk-archive-20261024.tar.zst"
def build():
    rows=sorted(M["assets"],key=lambda x:(not ("mobile" in x["asset"] and "audit" not in x["asset"]),x["path"]))
    params=z.ZstdCompressionParameters.from_level(3,window_log=30,enable_ldm=True,threads=2)
    compressor=z.ZstdCompressor(compression_params=params)
    started=time.time()
    with ARCHIVE.open("wb") as raw:
        with compressor.stream_writer(raw,closefd=False) as dest:
            with tarfile.open(fileobj=dest,mode="w|") as tar:
                portable={"format":"all APKs at original relative paths","assets":[{k:row[k] for k in ["path","bytes","sha256"]} for row in M["assets"]]}
                content=json.dumps(portable,ensure_ascii=False,indent=2).encode("utf-8")
                info=tarfile.TarInfo("release_assets.json");info.size=len(content);info.mtime=int(started)
                tar.addfile(info,io.BytesIO(content))
                for row in rows:
                    print("ARCHIVE_ADD",row["path"],flush=True)
                    p=R/row["path"];tar.add(p,arcname=row["path"],recursive=False)
                    idsig=Path(str(p)+".idsig")
                    if idsig.exists():tar.add(idsig,arcname=row["path"]+".idsig",recursive=False)
                    print("COMPRESSED_BYTES",raw.tell(),"elapsed",round(time.time()-started,1),flush=True)
    print("ARCHIVE_DONE",ARCHIVE.stat().st_size,"seconds",round(time.time()-started,1),flush=True)
def verify():
    expected={r["path"]:r for r in M["assets"]};found=[]
    dec=z.ZstdDecompressor(max_window_size=2**30)
    with ARCHIVE.open("rb") as raw,dec.stream_reader(raw) as src:
        with tarfile.open(fileobj=src,mode="r|") as tar:
            for entry in tar:
                assert entry.isfile()
                if entry.name not in expected:continue
                h=hashlib.sha256();size=0
                f=tar.extractfile(entry)
                while True:
                    chunk=f.read(4*1024*1024)
                    if not chunk:break
                    h.update(chunk);size+=len(chunk)
                e=expected[entry.name]
                assert size==e["bytes"] and h.hexdigest()==e["sha256"],entry.name
                found.append(entry.name);print("ARCHIVE_VERIFIED",entry.name,flush=True)
    assert set(found)==set(expected)
    out={"archive":ARCHIVE.name,"bytes":ARCHIVE.stat().st_size,"sha256":hashlib.file_digest(ARCHIVE.open("rb"),"sha256").hexdigest(),"format":"standard tar with Zstandard compression, 1 GiB window","verified_apk_payloads":found,"all_nine_payload_sha256_match":True}
    (O/"apk_archive_verification.json").write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding="utf-8")
    print("ALL_ARCHIVE_PAYLOADS_VERIFIED",len(found),"archive_bytes",out["bytes"],flush=True)
if __name__=="__main__":globals()[sys.argv[1]]()

