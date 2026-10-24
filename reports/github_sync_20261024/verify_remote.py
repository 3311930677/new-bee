from pathlib import Path
import json,subprocess,hashlib,sys,datetime
R=Path(r"D:\new-bee");O=R/"reports/github_sync_20261024";GH=r"C:\Program Files\GitHub CLI\gh.exe"
def api(path):return json.loads(subprocess.check_output([GH,"api",path]))
d=json.loads((O/"delivery_assets.json").read_text(encoding="utf-8"))
remote=api("repos/"+d["repository"]+"/releases/"+str(d["release_id"]))
expected={r["asset"]:{"sha256":r["sha256"],"bytes":r["bytes"]} for r in d["assets"]}
for name in ["release_assets.json","SHA256SUMS.txt","ARCHIVE_SHA256SUMS.txt","apk_archive_verification.json"]:
    p=O/name;expected[name]={"sha256":hashlib.file_digest(p.open("rb"),"sha256").hexdigest(),"bytes":p.stat().st_size}
got={r["name"]:r for r in remote["assets"]}
rows=[]
for name,e in expected.items():
    assert name in got,name
    a=got[name]
    assert a["state"]=="uploaded" and a["size"]==e["bytes"],name
    assert a["digest"]=="sha256:"+e["sha256"],name
    rows.append({"name":name,"bytes":a["size"],"sha256":e["sha256"],"remote_sha256_matches":True,"asset_id":a["id"]})
assert remote["tag_name"]==d["tag"] and remote["prerelease"]
out={"repository":d["repository"],"release_tag":d["tag"],"release_id":d["release_id"],"all_six_assets_size_and_sha256_match":True,"archive_apk_payloads":9,"assets":rows,"verified_at_utc":datetime.datetime.now(datetime.timezone.utc).isoformat()}
if "--published" in sys.argv:
    assert not remote["draft"]
    head=subprocess.check_output(["git","rev-parse","HEAD"],cwd=R).decode().strip()
    branch=api("repos/"+d["repository"]+"/git/ref/heads/main")["object"]["sha"]
    tag=api("repos/"+d["repository"]+"/git/ref/tags/"+d["tag"])["object"]["sha"]
    assert head==branch==tag,(head,branch,tag)
    assert not subprocess.check_output(["git","status","--porcelain"],cwd=R).strip()
    out.update({"published":True,"main_and_release_tag_commit":head,"working_tree_clean":True,"url":remote["html_url"]})
    target=O/"upload_staging/final_remote_verification.json"
else:
    target=O/"asset_verification.json"
target.write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding="utf-8")
print(json.dumps({k:v for k,v in out.items() if k!="assets"},ensure_ascii=False))

