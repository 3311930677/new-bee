"""Build a portable audit index from captured evidence; no game files changed."""
from pathlib import Path
import json,re,html,hashlib
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parent
md=(R/"README.md").read_text(encoding="utf-8")
issues=[]
for line in md.splitlines():
    if re.match(r"\| (M\d\d|A\d\d) \|",line):
        c=[x.strip() for x in line.strip("|").split("|")]
        links=[{"label":a,"path":b} for a,b in re.findall(r"\[([^\]]+)\]\(([^)]+)\)",c[3])]
        issues.append({"id":c[0],"title":c[1],"status":c[2],"detail":re.sub(r"\[([^\]]+)\]\(([^)]+)\)",r"\1",c[3]),"evidence":links})
new=[]
for ident,priority,related,title in [
("N01","P2",["M03","M10"],"誓约说明越过卡片边界"),
("N02","P1",["A03"],"胜利音在警报并发时丢失"),
("N03","P2",[],"背包四列布局仍按五列移动焦点"),
("N04","P2",["M10"],"多处小按钮触控范围偏小"),
("N05","P1",["M04"],"主城底部被系统三键导航覆盖"),
("N06","P1",["M04"],"运行中切换导航模式后退出 原因待定位")]:
    new.append({"id":ident,"priority":priority,"related":related,"title":title})
out={"date":"2026-10-24","conclusion":"未全部解决","scope":"Android 17 API37 AOSP x86_64 emulator; current workspace export; not original ARM64 final APK","original_issues":issues,"new_or_refined_issues":new}
assert len(issues)==17
(R/"issue_results.json").write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding="utf-8")
suites=[]
for p in sorted(R.glob("*/result.json")):
    d=json.loads(p.read_text(encoding="utf-8"))
    checks=d.get("checks",[])
    suites.append({"id":p.parent.name,"suite":d.get("suite"),"checks":len(checks),"failed":[c for c in checks if not c.get("ok",False)],"photos":len(d.get("photos",[])),"result":p.relative_to(R).as_posix()})
media=[]
for p in sorted(R.rglob("*")):
    if p.suffix.lower() in [".png",".jpg",".wav",".mp4"] and p.is_file() and p.name!="preview.jpg":
        media.append({"path":p.relative_to(R).as_posix(),"kind":p.suffix[1:],"bytes":p.stat().st_size,"group":p.relative_to(R).parts[0] if p.parent!=R else "重点证据"})
(R/"evidence_index.json").write_text(json.dumps({"suites":suites,"media":media},ensure_ascii=False,indent=2),encoding="utf-8")
broken=[]
for label,target in re.findall(r"\[([^\]]+)\]\(([^)]+)\)",md):
    if not target.startswith(("http:","https:","#")) and not (R/target).exists() and target not in ["index.html","evidence_index.json"]:
        broken.append((label,target))
if broken:raise RuntimeError(broken)
def e(s):return html.escape(str(s),quote=True)
def links(seq):return " ".join('<a href="'+e(x["path"])+'">'+e(x["label"])+'</a>' for x in seq)
rows="".join('<tr><td>'+e(x["id"])+'</td><td>'+e(x["title"])+'</td><td>'+e(x["status"])+'</td><td>'+e(x["detail"])+'<p>'+links(x["evidence"])+'</p></td></tr>' for x in issues)
nrows="".join('<li><b>'+e(x["id"])+' '+e(x["priority"])+'</b> '+e(x["title"])+'</li>' for x in new)
groups=sorted({x["group"] for x in media})
cards=[]
for m in media:
    if m["kind"] not in ("png","jpg","wav","mp4"):continue
    src=e(m["path"])
    if m["kind"] in ("png","jpg"):
        body='<a href="'+src+'" target="_blank"><img src="'+src+'" loading="lazy" alt="'+src+'"></a>'
    elif m["kind"]=="wav":body='<audio controls preload="none" src="'+src+'"></audio>'
    else:body='<video controls preload="none" src="'+src+'"></video>'
    cards.append('<article data-group="'+e(m["group"])+'" data-search="'+src.lower()+'">'+body+'<a href="'+src+'">'+src+'</a></article>')
css="""*{box-sizing:border-box}body{font:16px/1.65 system-ui,"Microsoft YaHei",sans-serif;margin:0;color:#182533;background:#f1f4f7}main{max-width:1280px;margin:auto;padding:32px}h1{font-size:30px}h2{margin-top:36px}a{color:#155b9a}p{margin:10px 0}table{border-collapse:collapse;width:100%;background:white}th,td{padding:12px;border:1px solid #ccd4dd;text-align:left;vertical-align:top}th{background:#203e57;color:white}td:first-child{white-space:nowrap}td:nth-child(2){min-width:130px}td:nth-child(3){min-width:130px}tr:nth-child(even){background:#f7f9fc}.tools{position:sticky;top:0;padding:16px;background:#e3ebf3;z-index:1;display:flex;gap:12px;flex-wrap:wrap}input,select,button{font:inherit;padding:8px;border:1px solid #b9c7d3;border-radius:4px}input{min-width:250px}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(225px,1fr));gap:16px;margin-top:20px}article{background:white;padding:10px;border:1px solid #d6dee7;border-radius:6px;overflow:hidden}article img{width:100%;height:300px;object-fit:contain;background:#19212a}article video{width:100%;max-height:300px}article audio{width:100%}article>a:last-child{display:block;font-size:12px;overflow-wrap:anywhere}[hidden]{display:none!important}.table-wrap{overflow:auto}.intro{max-width:1000px}small{color:#546674}@media(max-width:600px){main{padding:18px}.grid{grid-template-columns:repeat(2,minmax(0,1fr))}article img{height:235px}.tools{position:static}h1{font-size:24px}}"""
doc='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>远征 Android 模拟器复验证据</title><style>'''+css+'''</style><main><h1>远征 Android 模拟器全量复验</h1><div class="intro"><p><b>结论：尚未全部解决。</b>三键导航遮挡、誓约文字越界和胜利音漏播已复现，另有焦点与触控尺寸问题。</p><p>Android 17 API37 AOSP x86_64 实际安装运行。普通入口与诊断入口共用283份相同游戏脚本及JSON；并非直接运行原ARM64 final包。内部混音记录不等于物理扬声器或蓝牙试听。</p><p><a href="README.md">完整问题文档与修改方案</a> · <a href="issue_results.json">机器可读问题清单</a> · <a href="evidence_index.json">完整证据索引</a></p></div><h2>已确认问题</h2><ul>'''+nrows+'''</ul><h2>原清单逐项结论</h2><div class="table-wrap"><table><thead><tr><th>编号</th><th>问题</th><th>结论</th><th>证据和范围</th></tr></thead><tbody>'''+rows+'''</tbody></table></div><h2>实际截图与影音</h2><p>点击图片查看原图；输入文件名或选择目录筛选。地图静态巡检有冻结过程，不能据此判断碰撞或全部任务分支。音频为Android内部Master混音。</p><div class="tools"><input id="search" placeholder="筛选 如 normal_flow 或 bag_gem"><select id="group"><option value="">全部目录</option>'''+''.join('<option>'+e(g)+'</option>' for g in groups)+'''</select><select id="kind"><option value="">所有媒体</option><option value="image">图片</option><option value="wav">音频</option><option value="mp4">视频</option></select><span id="count"></span></div><div class="grid">'''+''.join(cards)+'''</div><script>const cards=[...document.querySelectorAll("article")];const search=document.getElementById("search"),group=document.getElementById("group"),kind=document.getElementById("kind");function update(){let n=0;for(const c of cards){const k=kind.value, s=c.dataset.search;const yes=(!search.value||s.includes(search.value.toLowerCase()))&&(!group.value||c.dataset.group===group.value)&&(!k||(k==="image"?(s.endsWith(".png")||s.endsWith(".jpg")):s.endsWith("."+k)));c.hidden=!yes;if(yes)n++;}document.getElementById("count").textContent=n+" 个文件";}for(const el of [search,group,kind])el.addEventListener("input",update);update();</script></main></html>'''
(R/"index.html").write_text(doc,encoding="utf-8")
font=ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc",26)
smallfont=ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc",21)
canvas=Image.new("RGB",(1440,1100),"#f3f6fa"); draw=ImageDraw.Draw(canvas)
draw.text((32,20),"Android 17 模拟器实际复验  尚未全部解决",fill="#192d43",font=font)
for i,(name,label,box) in enumerate([
("normal_flow/home_threebutton_native.png","普通入口 三键导航遮住主城按钮",(0,1600,1080,2400)),
("oath_overlap.png","誓约页 奖励文字超出卡片",(20,330,700,1010)),
("normal_flow/keyboard_password.png","普通入口 键盘弹出后登录按钮可见",(0,0,1080,2400))]):
    im=Image.open(R/name).convert("RGB").crop(box)
    im.thumbnail((440,940))
    x=32+i*472
    draw.text((x,76),label,fill="#263a50",font=smallfont)
    canvas.paste(im,(x+(440-im.width)//2,125))
canvas.save(R/"preview.jpg",quality=92)
stats={"original_issues":len(issues),"suite_count":len(suites),"media_files":len(media),"broken_readme_links":broken}
(R/"report_validation.json").write_text(json.dumps(stats,ensure_ascii=False,indent=2),encoding="utf-8")
print(json.dumps(stats,ensure_ascii=False))

