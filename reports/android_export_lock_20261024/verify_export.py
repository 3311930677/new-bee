from pathlib import Path
import subprocess,json,hashlib,zipfile,shutil
r=Path(r"D:\new-bee\reports\android_export_lock_20261024")
apk=Path(r"D:\new-bee\远征\exports\android\Yuanzheng-0.2.1-mobile2.apk")
java=r"C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot\bin\java.exe"
jar=r"C:\Users\tsz\AppData\Local\Android\Sdk\build-tools\36.1.0\lib\apksigner.jar"
sig=subprocess.run([java,"-jar",jar,"verify","--verbose","--print-certs",str(apk)],capture_output=True)
(r/"signature_verify.txt").write_bytes(sig.stdout+sig.stderr)
if sig.returncode:raise RuntimeError("apksigner verify failed")
aapt=r"C:\Users\tsz\AppData\Local\Android\Sdk\build-tools\36.1.0\aapt.exe"
alias=r/"package_verify.apk"
assert not alias.exists()
shutil.copyfile(apk,alias)
try:
    badging=subprocess.run([aapt,"dump","badging",str(alias)],capture_output=True)
    (r/"badging.txt").write_bytes(badging.stdout+badging.stderr)
    if badging.returncode:raise RuntimeError("aapt badging failed; see badging.txt")
finally:
    alias.unlink()
with zipfile.ZipFile(apk) as z:
    qa=[n for n in z.namelist() if "/src/qa/" in n]
    lib=[n for n in z.namelist() if n.startswith("lib/") and n.endswith(".so")]
    scripts={n:hashlib.sha256(z.read(n)).hexdigest() for n in z.namelist() if n.endswith((".gdc",".json")) and "/src/qa/" not in n}
with zipfile.ZipFile(r"D:\new-bee\reports\android_full_audit_20261024\Yuanzheng-full-flow.apk") as z:
    baseline={n:hashlib.sha256(z.read(n)).hexdigest() for n in z.namelist() if n.endswith((".gdc",".json")) and "/src/qa/" not in n}
diff=sorted(n for n in set(scripts)|set(baseline) if scripts.get(n)!=baseline.get(n))
assert not qa and lib and all("/arm64-v8a/" in n for n in lib)
assert not diff,diff
out={"output":str(apk),"sha256":hashlib.file_digest(apk.open("rb"),"sha256").hexdigest(),"bytes":apk.stat().st_size,"signature_verifies":True,"architectures":lib,"diagnostic_files":qa,"production_script_json_count":len(scripts),"mismatches_from_audited_source":diff,"signing":"debug signature; not release-store signing","scope":"export lock workaround only; no gameplay fixes"}
(r/"verification.json").write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding="utf-8")
print(json.dumps(out,ensure_ascii=False))
print("\n".join(sig.stdout.decode(errors="replace").splitlines()[:7]))

