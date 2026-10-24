from pathlib import Path
import zipfile,json,hashlib
r=Path(__file__).parent
names=["Yuanzheng-deep-audit.apk","Yuanzheng-deep-audit-extended.apk","Yuanzheng-deep-audit-final.apk","Yuanzheng-full-flow.apk"]
out={"scope":"Exported production scripts and JSON, excludes diagnostic src/qa","builds":{}}
baseline=None
for name in names:
    p=r/name
    with zipfile.ZipFile(p) as z:
        rows={n:hashlib.sha256(z.read(n)).hexdigest() for n in z.namelist() if (n.endswith(".gdc") or n.endswith(".json")) and "/src/qa/" not in n}
        if baseline is None:baseline=rows
        mismatches=sorted(n for n in set(baseline)|set(rows) if baseline.get(n)!=rows.get(n))
        qa=[n for n in z.namelist() if "/src/qa/" in n]
        libs=[n for n in z.namelist() if n.startswith("lib/") and n.endswith(".so")]
    sha=hashlib.file_digest(p.open("rb"),"sha256").hexdigest()
    out["builds"][name]={"sha256":sha,"production_script_json_count":len(rows),"mismatches":mismatches,"diagnostic_file_count":len(qa),"native_libs":libs}
    print(name,len(rows),"mismatches",len(mismatches),"QA files",len(qa),flush=True)
(r/"test_builds_equivalence.json").write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding="utf-8")

