from pathlib import Path
import json,re,html.parser,hashlib
R=Path(__file__).parent
doc=(R/"README.md").read_text(encoding="utf-8")
class Index(html.parser.HTMLParser):
    def __init__(self):super().__init__();self.refs=[];self.scripts=[];self.inscript=False
    def handle_starttag(self,tag,attrs):
        d=dict(attrs)
        for k in ["href","src"]:
            if k in d:self.refs.append(d[k])
        if tag=="script":self.inscript=True
    def handle_endtag(self,tag):
        if tag=="script":self.inscript=False
    def handle_data(self,data):
        if self.inscript:self.scripts.append(data)
p=Index();p.feed((R/"index.html").read_text(encoding="utf-8"))
missing=[v for v in p.refs if not v.startswith(("https:","http:","#")) and not (R/v).exists()]
assert not missing,missing
(R/"gallery_filter.js").write_text("\n".join(p.scripts),encoding="utf-8")
saves={}
for n in ["saved_mute_on","saved_after_restart"]:
    d=json.loads((R/"normal_flow"/(n+".json")).read_text(encoding="utf-8"))
    saves[n]=d["audio"]
assert all(x["mute"] for x in saves.values())
eq=json.loads((R/"test_builds_equivalence.json").read_text(encoding="utf-8"))
installed=json.loads((R/"normal_flow/installed_package.json").read_text(encoding="utf-8"))
assert installed["device_sha256"].split()[0]==eq["builds"]["Yuanzheng-full-flow.apk"]["sha256"]
assert all(not d["mismatches"] for d in eq["builds"].values())
normal_log=(R/"normal_flow/normal_final_logcat.txt").read_text(encoding="utf-8")
errors=[l for l in normal_log.splitlines() if any(s in l for s in ["SCRIPT ERROR","FATAL EXCEPTION","Fatal signal"])]
assert not errors,errors[:10]
audio=json.loads((R/"audio_android/result.json").read_text(encoding="utf-8"))
failed=[c for c in audio["checks"] if not c["ok"]]
assert len(failed)==1 and "victory can start" in failed[0]["label"]
out=json.loads((R/"report_validation.json").read_text(encoding="utf-8"))
out.update({"html_links_checked":len(p.refs),"html_missing_links":missing,"mute_restart_settings":saves,"normal_flow_fatal_errors":errors,"installed_hash_matches":True,"audio_expected_failures":len(failed),"gallery_visual_browser_review":"not completed; in-app browser local connection refused/time out"})
(R/"report_validation.json").write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding="utf-8")
print(json.dumps(out,ensure_ascii=False))

