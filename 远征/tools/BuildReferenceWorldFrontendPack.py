"""Package user's reference, current map captures and frontend pages for Claude design."""
from pathlib import Path
from PIL import Image
import shutil,json,zipfile,hashlib,html
root=Path(__file__).resolve().parents[1];workspace=root.parent
pack=workspace/'ui_review_input/reference_world_frontend_20261010'
for name in ['reference','current/maps','current/frontend','optional','context','outputs']:(pack/name).mkdir(parents=True,exist_ok=True)
reference=Path('C:/Users/tsz/AppData/Local/Temp/codex-clipboard-78b727fa-1f33-4504-a42a-0d9078827c6b.jpg')
files=[('reference/01_target_forest.jpg',reference,'用户目标参考，画风与场景组织'),
 ('current/maps/02_town_plaza.png',root/'shots/map_rebuild_20261010/after/lorin_plaza_hud.png','当前城镇广场'),
 ('current/maps/03_field_spawn.png',root/'shots/map_rebuild_20261010/after/maple_spawn_hud.png','当前野外进入视口'),
 ('current/maps/04_field_junction.png',root/'shots/map_rebuild_20261010/after/maple_junction_hud.png','当前野外岔口/桥'),
 ('current/frontend/05_loading.png',workspace/'ui_review_input/next_review_20261010/current/13_loading.png','加载'),
 ('current/frontend/06_login.png',workspace/'ui_review_input/next_review_20261010/current/11_login.png','旅人登记/登录'),
 ('current/frontend/07_title.png',workspace/'ui_review_input/next_review_20261010/current/01_title.png','标题/开始'),
 ('optional/08_introduction.png',workspace/'ui_review_input/next_review_20261010/current/16_introduction.png','手记/介绍，范围备用'),
 ('optional/09_town_overview_nohud.png',root/'shots/map_rebuild_20261010/after/lorin_overview_nohud.png','城镇全景调试，隐藏HUD'),
 ('optional/10_field_overview_nohud.png',root/'shots/map_rebuild_20261010/after/maple_overview_nohud.png','野外全景调试，隐藏HUD')]
manifest=[]
for target,source,title in files:
    assert source.exists(),source
    shutil.copy2(source,pack/target)
    manifest.append(dict(file=target,title=title,source=str(source),size=list(Image.open(source).size),sha256=hashlib.sha256(source.read_bytes()).hexdigest(),source_mtime=source.stat().st_mtime,optional=target.startswith('optional/')))
cfg=json.loads((root/'data/main_world_maps.json').read_text(encoding='utf8'));maps=cfg['maps'];maps={m['id']:m for m in maps} if isinstance(maps,list) else maps
facts={}
for id in ['lorin_wilds','maple_road']:
    row=maps[id];facts[id]={k:row[k] for k in ['name','layout_version','map_cols','map_rows','camera_zoom','player_scale','spawn','spawn_points','exits','flat_routes','city_building_positions','city_npc_positions','entities','clear_rects','monster_positions','river'] if k in row}
(pack/'context/CURRENT_MAP_FACTS.json').write_text(json.dumps(facts,ensure_ascii=False,indent=2),encoding='utf8')
city=json.loads((root/'data/city.json').read_text(encoding='utf8'))
lines=['# 功能合同：功能与进度保留，位置/画风/路线可重做','','坐标只描述当前版本；新规划可以改变道路、地形、地图尺寸、相机、碰撞、摆放和出生点。由Codex适配地图版本、旧档位置与寻路。保留以下ID、功能、开放条件和任务依赖。','','## 城镇建筑','','| ID | 名称 | 入口/用途 |','|---|---|---|']
for b in city['buildings']:lines.append(f"| {b['id']} | {b['name']} | {b.get('action','')} |")
lines+=['','保留已落成/待建状态，可以重做未落成视觉，不直接解锁全部设施。','','## 常驻NPC','','| ID | 名称/身份 | 关联建筑 |','|---|---|---|']
for n in city['npcs']:lines.append(f"| {n['id']} | {n['name']} · {n.get('title','')} | {n.get('need','')} |")
lines+=['','保留来访旅人的访问和交谈功能。NPC可迁移，任务角色和用途保留。','','## 地区连接','','| 当前地图 | 出口ID | 目标 | 开放条件 |','|---|---|---|---|']
for id,row in facts.items():
    for e in row['exits']:
        conditions='；'.join(str(e[k]) for k in ['requires_story','requires_flag','requires_item','requires_cleared'] if k in e) or '沿用现有条件'
        lines.append(f"| {id} | {e['id']} | {e['to']} | {conditions} |")
lines+=['','## 地图任务和交互点','','配置中的实体可能随任务进度显示；新方案必须给出迁移位置与可达性。','','| 地图 | ID | 名称 | 类型 | 任务 |','|---|---|---|---|']
for id,row in facts.items():
    for key,e in row.get('entities',{}).items():lines.append(f"| {id} | {key} | {e.get('name','')} | {e.get('kind','')} | {e.get('quest','')} |")
lines+=['','修桥/旧路石匣/风铃等事件可以重做视觉与布局，保留进度逻辑、奖励和可交互性。敌人摆位可重排，保留种类、奖励与刷新语义。','','## 前端功能','','- 加载：真实资源/脚本预热、进度与原自动进入流程。不得用装饰进度代替实际加载。','- 标题：开始游戏、游戏介绍、设置、退出；保留现有平台退出行为。','- 登记/登录：本地旅人登记，账号/密码输入、密码查看切换、头像选择/导入、登录提交、游客入口与错误反馈。没有远程认证服务，不增加新登录服务。','- 创建角色的后续流程保留，本轮不新增昵称/职业/付费限制。','- 手记/介绍（可选范围）：世界、旅人、启程三类内容与翻页。','','地图与前端设计不得改变成长、货币、战斗、奖励、任务条件及付费规则。']
(pack/'FUNCTION_CONTRACT.md').write_text('\n'.join(lines)+'\n',encoding='utf8')
readme='''# 用户参考驱动 · 地图重做与进入页面设计包

使用 `PROMPT_CLAUDE_REFERENCE_REBUILD.md`。用户提供的森林参考为最高优先级，旧路线和旧美术方案均可放弃。先看参考和3张当前地图，读取短功能合同；前端只看相关页面。全景和手记按需查看，不读整个工程或旧18页UI包。

地图当前图采用最新 `map_rebuild_20261010/after` 的重建版本，城镇layout4、野外layout3；没有用旧样板代替现状。前端图沿用已有 `next_review_20261010/current` 的实际运行输出。原图来源、尺寸、文件时间和校验值记录在input_manifest.json；本轮没有运行游戏、改代码或生成新图片。

页面范围暂待用户确认：“记载/进入”可能指加载、登记或标题。暂按加载＋登记/登录＋标题/开始这组前端流程提供设计输入，手记/介绍放在optional备用。若用户随后明确范围，以最新答复为准，仅展开确认的页面。

参考是1411×1114横向例图，目标游戏为480×800/1067竖屏。角色、植被、路缘、落影与构图需按竖屏重新组织；主角保持现有辨识度。

optional中的全景明确为隐藏HUD的调试图，用来判断完整空间，不代表正常HUD被删除。截图不证明全部交互已通过验证；本轮Claude仅做设计，不运行测试。

context/CURRENT_MAP_FACTS.json为当前功能/位置现状，可重做几何与摆放；功能合同中的用途、地区目标、门槛、任务依赖仍需保留。

请只输出outputs/MAP_REFERENCE_REBUILD_PLAN.md、FRONTEND_REDESIGN_PLAN.md、REFERENCE_ASSET_PRODUCTION_BRIEF.md。先做城镇/野外各一个参考级样板及确认的前端页面，再推广，不先量产全部地域与NPC。
'''
(pack/'00_README.md').write_text(readme,encoding='utf8')
(pack/'input_manifest.json').write_text(json.dumps(dict(date='2026-10-10',reference_supplied_by_user=True,new_images_generated=False,new_game_run=False,files=manifest),ensure_ascii=False,indent=2),encoding='utf8')
css='body{background:#17141a;color:#f3e8d0;font:16px/1.6 system-ui;margin:24px}main{max-width:1120px;margin:auto}a,button{color:#f0b95a;background:#221e26;border:1px solid #6e5434;padding:8px 12px;text-decoration:none;font:inherit;cursor:pointer}figure{margin:20px 0}img{display:block;max-width:100%;height:auto}figcaption,p{color:#bfb096}.grid{display:flex;gap:20px;flex-wrap:wrap}.grid figure{width:480px;max-width:100%}nav{display:flex;gap:8px;flex-wrap:wrap}section[hidden]{display:none}'
parts=[]
for id,title,filter in [('reference','用户目标参考','reference/'),('maps','当前地图','current/maps/'),('frontend','前端页面','current/frontend/'),('optional','可选视角与手记','optional/')]:
    images=''.join(f'<figure><figcaption>{html.escape(x["title"])}</figcaption><img loading="lazy" src="{x["file"]}"></figure>' for x in manifest if x['file'].startswith(filter))
    parts.append(f'<section id="{id}"'+(' hidden' if id!='reference' else '')+f'><h2>{title}</h2><div'+(' class="grid"' if id!='reference' else '')+'>'+images+'</div></section>')
nav=''.join(f'<button data-page="{id}">{title}</button>' for id,title in [('reference','目标参考'),('maps','当前地图'),('frontend','进入页面'),('optional','可选资料')])
script='document.querySelectorAll("button[data-page]").forEach(b=>b.onclick=()=>document.querySelectorAll("section").forEach(s=>s.hidden=s.id!==b.dataset.page));'
(pack/'index.html').write_text('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>远征 · 用户参考重做包</title><style>'+css+'</style><main><h1>远征 · 按用户参考重做</h1><p>允许放弃粗糙路线，重新规划地图与相关进入页面；先看目标参考，再看现状。</p><p><a href="PROMPT_CLAUDE_REFERENCE_REBUILD.md">Claude详细提示词</a>　<a href="00_README.md">使用说明</a></p><nav>'+nav+'</nav>'+''.join(parts)+'</main><script>'+script+'</script></html>',encoding='utf8')
archive=pack.with_suffix('.zip')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    z.writestr(pack.name+'/outputs/','')
    for file in pack.rglob('*'):
        if file.is_file():z.write(file,file.relative_to(pack.parent))
with zipfile.ZipFile(archive) as z:assert z.testzip() is None
print(json.dumps(dict(zip=str(archive),MB=round(archive.stat().st_size/1024**2,2),reference_images=1,current_images=6,optional_images=3),ensure_ascii=False))
