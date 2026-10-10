from pathlib import Path
import json, shutil, zipfile, html
root=Path(__file__).resolve().parents[1]
shots=root/'shots/travel_chest_b2_20261009'
pack=root.parent/'ui_review_input/travel_chest_b2_review_20261009'
for d in ['screenshots/core','screenshots/states','screenshots/before','specs','outputs']:(pack/d).mkdir(parents=True,exist_ok=True)
core=['growth_800','equipment_800','gems_800','refine_800','bag_800','town_800','talent_800','pet_800','mount_800','titles_800']
allshots=sorted(p for p in shots.glob('*.png') if p.stem!='equip_800')
for p in allshots:shutil.copy2(p,pack/('screenshots/core' if p.stem in core else 'screenshots/states')/p.name)
old=root/'shots/cloud_full_redesign_20261009'
for name in ['growth','equip','bag']:shutil.copy2(old/(name+'.png'),pack/'screenshots/before'/(name+'.png'))
specs=root.parent/'ui_review_input/cloud_full_redesign_20261009/outputs'
for name in ['UI_REDIRECTION_MASTER.md','MAIN_UI_REBUILD_BLUEPRINT.md','ASSET_PRODUCTION_BRIEF.md']:shutil.copy2(specs/name,pack/'specs'/name)
shutil.copy2(root/'docs/plans/2026-10-09-travel-chest-b2-delivery.md',pack/'IMPLEMENTATION_NOTES.md')
entries=[{'file':('screenshots/core/' if p.stem in core else 'screenshots/states/')+p.name,'group':'core' if p.stem in core else 'state'} for p in allshots]
(pack/'capture_manifest.json').write_text(json.dumps({'engine':'Godot 4.7.2','actual_native_render':True,'isolated_demo_save':True,'files':entries},ensure_ascii=False,indent=2),encoding='utf-8')
readme='''# 灯下行箧 · 第 2 批视觉审查包

先读 `PROMPT_REVIEW_B2.md`、`IMPLEMENTATION_NOTES.md`，按需查看三份已确定的规范。先看 `screenshots/core/` 的 10 张主要画面，只有验证具体问题时再打开 `states/`。

当前图为 Godot 原生运行输出。`before/` 是本轮全面重构前的养成、装备、背包。状态包含真实操作得到的成功／失败、锁定、缺材料、骑乘等；尺寸包含 800、1067 和模拟安全区。来源详见实施说明及清单。

天赋、宠物、坐骑、称号属于没有原始设计截图的模板扩展页。审查它们时以功能保留、材料语言、信息顺序和视觉比例判断。技能书的专门重建，以及战斗等流程统一属于第 3 批。

请直接输出 `outputs/UI_REVIEW_FIXES_B2.md`。不需要扫描项目、调用 Godot MCP、修改代码、生成图片或启动子代理。
'''
(pack/'00_README.md').write_text(readme,encoding='utf-8')
prompt='''你是成熟商业竖屏 RPG 的 UI 美术总监，现在验收 Godot《远征》的“灯下行箧”第 2 批实际实现。

本轮目标是根据真实游戏画面决定下一轮最值得投入的视觉改造。请大胆、严格、具体：统一风格成立并不意味着比例、构图、物品展示或组件质量已经合格。必要时可以要求整块区域或整个子页重新布局，达到成熟游戏的水平。保留深漆、结构铜边、有限灯金和朱漆主行动的既定美术方向，保留现有玩法与数据。

输入位于本包：
- IMPLEMENTATION_NOTES.md：本批范围、功能保留、演示状态来源及未处理范围。
- specs/UI_REDIRECTION_MASTER.md：已确定的方向与组件规则。
- specs/MAIN_UI_REBUILD_BLUEPRINT.md：第 2 批布局与扩展规则。
- specs/ASSET_PRODUCTION_BRIEF.md：素材规格。
- screenshots/core/：10 张核心画面，先检查这些。
- screenshots/before/：3 张重构前画面，只作对照。
- screenshots/states/：长屏、安全区与操作状态，按问题查阅，不必每张重复分析。

请先判断当前实现是否具有一致的游戏美术语言、清晰的对象展示和可操作的信息顺序，再找出最影响商业游戏质感的 5 个问题。尤其检查：
1. 装备原有图标和新物品格叠加后是否过厚、重复边框、过暗或展示不足。
2. 养成与四个扩展子页是否因为共用骨架变得机械，舞台、列表、详情之间是否有过量空白或阅读断层。
3. 背包五列密度、名称／数量／锁定／品质层级、比较数值与底部操作的主次。
4. 强化／宝石／精炼的成本与风险是否能在短时间读懂；确认按钮与反馈是否配合。
5. HUD 图标重量、任务签与折叠入口、名称重叠避让、骑乘与疾行状态、小地图导航。
6. 480×1067 与安全区的构图是否完整，有没有不应存在的拉伸、接缝或裁切。

允许给出幅度较大的重做要求，但每一项必须以本包截图中的具体事实为依据。不要笼统地写“增加质感”“丰富层次”“优化留白”。不要重新发明货币、成长条件、战斗、解锁等级、排序或奖励；若建议涉及玩法，只列在可选提案中，不放入默认实施任务。既有地图建筑透明层与第 3 批页面仅标注跨范围依赖，不能挤掉本批的核心修复项。

每个问题必须包含：
- 优先级与受影响页面／文件名。
- 截图中的位置，必要时给逻辑像素框或相对比例。
- 当前具体视觉缺陷及其影响。
- 修正后的可检查效果；可要求区域重排。
- Godot 工程师可执行的结构、尺寸、间距、字体、状态和层级要求。
- 是否需要新美术素材；若需要，给用途、源尺寸、显示尺寸、透明／九宫格边距和风格要求。
- 需要补拍的真实运行状态与验收标准。

只保存 outputs/UI_REVIEW_FIXES_B2.md，包含最多 5 个最关键问题，按影响排序；末尾给出下一轮建议修复顺序。若不足 5 个真实问题，写实际数量，不要凑数。已合格部分不展开重复夸奖。

工作边界：只读本包设计文档和截图；不读取游戏工程、不扫描整个磁盘、不调用 Godot MCP、不运行游戏或测试、不改场景与代码、不启动子代理、不生成图片。不要宣称截图无法证明的交互已经验收。完成文件后停止。
'''
(pack/'PROMPT_REVIEW_B2.md').write_text(prompt,encoding='utf-8')
css='''body{margin:0;background:#17141a;color:#f3e8d0;font:16px/1.6 system-ui,sans-serif}main{max-width:1100px;margin:auto;padding:24px}h1{font-size:26px}p,figcaption{color:#bfb096}nav{display:flex;gap:8px;flex-wrap:wrap;margin:16px 0}button,a{color:#f3e8d0;background:#221e26;border:1px solid #6e5434;padding:8px 14px;cursor:pointer;text-decoration:none;font:inherit}button[aria-selected=true]{color:#f0b95a;border-color:#f0b95a}.pair{display:flex;gap:20px;overflow:auto}figure{margin:0;flex:0 0 480px}img{width:480px;max-width:90vw;display:block}section[hidden]{display:none}.links{display:flex;flex-wrap:wrap;gap:10px}'''
nav=['养成','装备','背包','子页','地图','长屏','状态']
def figure(title,url):return '<figure><figcaption>'+title+'</figcaption><img loading="lazy" src="'+url+'"></figure>'
sections=[]
for tab,oldname,newname in [('养成','growth','growth_800'),('装备','equip','equipment_800'),('背包','bag','bag_800')]:
    sections.append('<section id="'+tab+'"'+(' hidden' if tab!='养成' else '')+'><div class="pair">'+figure('改造前','../cloud_full_redesign_20261009/'+oldname+'.png')+figure('本批实际运行',newname+'.png')+'</div></section>')
sections.append('<section id="子页" hidden><div class="pair">'+''.join(figure(t,n+'_800.png') for t,n in [('天赋','talent'),('灵宠','pet'),('坐骑','mount'),('称号','titles')])+'</div></section>')
sections.append('<section id="地图" hidden><div class="pair">'+''.join(figure(t,n+'.png') for t,n in [('城镇 HUD','town_800'),('骑乘','riding_on_800'),('暗场野外与路牌','field_dark_1067')])+'</div></section>')
sections.append('<section id="长屏" hidden><div class="pair">'+''.join(figure(t,n+'.png') for t,n in [('养成长屏','growth_1067'),('装备长屏','equipment_1067'),('背包长屏','bag_1067'),('安全区','bag_safe_800')])+'</div></section>')
sections.append('<section id="状态" hidden><div class="links">'+''.join('<a href="'+p.name+'">'+html.escape(p.stem)+'</a>' for p in allshots if p.stem not in core)+'</div></section>')
gallery='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>灯下行箧 · 第2批</title><style>'+css+'</style><main><h1>灯下行箧 · 第 2 批</h1><p>主要页面前后对照与真实操作状态。Godot 原生截图，保持原分辨率，横向滑动查看。</p><nav>'+''.join('<button data-page="'+t+'" aria-selected="'+('true' if t=='养成' else 'false')+'">'+t+'</button>' for t in nav)+'</nav>'+''.join(sections)+'</main><script>document.querySelectorAll("button[data-page]").forEach(b=>b.onclick=()=>{document.querySelectorAll("button[data-page]").forEach(x=>x.setAttribute("aria-selected",String(x===b)));document.querySelectorAll("section").forEach(s=>s.hidden=s.id!==b.dataset.page)});</script></html>'
(shots/'index.html').write_text(gallery,encoding='utf-8')
print(json.dumps({'native_screenshots':len(allshots),'core':len(core),'review_dir':str(pack)},ensure_ascii=False))
archive=pack.with_suffix('.zip')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for p in pack.rglob('*'):
        if p.is_file():z.write(p,p.relative_to(pack.parent))
print(str(archive))
