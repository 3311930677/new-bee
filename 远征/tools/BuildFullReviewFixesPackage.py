"""Package native captures for a second, bounded Cloud visual review."""
from pathlib import Path
from PIL import Image
import json, shutil, zipfile, hashlib, html, re

root=Path(__file__).resolve().parents[1]
workspace=root.parent
shots=root/'shots/full_review_fixes_20261009'
pack=workspace/'ui_review_input/full_review_fixes_20261009'
baseline=workspace/'ui_review_input/travel_chest_full_review_20261009'
for directory in ['current','before','states','specs','outputs','assets_reference']:
    (pack/directory).mkdir(parents=True,exist_ok=True)
pages=[
 ('01_title','标题',shots/'title_800.png'),
 ('02_home','营帐',shots/'b1/home_800.png'),
 ('03_town_hud','城镇 HUD',shots/'hud_lorin_wilds_partner_800.png'),
 ('04_field_hud','野外 HUD',shots/'hud_maple_road_partner_800.png'),
 ('05_growth','人物养成',shots/'growth_800.png'),
 ('06_equipment','装备整备',shots/'equipment_800.png'),
 ('07_inventory','行旅背包',shots/'bag_800.png'),
 ('08_battle','连续战斗',shots/'battle_focus_800.png'),
 ('09_region_map','地区行路图',shots/'regions_800.png'),
 ('10_departure','出征筹备',shots/'departure_800.png'),
 ('11_login','旅人登记',shots/'login_800.png'),
 ('12_create_role','建立旅人',shots/'b3/create_role_800.png'),
 ('13_loading','加载',shots/'loading_800.png'),
 ('14_codex','灵宠图鉴',shots/'codex_owned_800.png'),
 ('15_settings','设置',shots/'b3/settings_800.png'),
 ('16_introduction','远征手记',shots/'introduction_800.png'),
 ('17_battle_skills','战斗技能',shots/'battle_energy30_800.png'),
 ('18_skill_book','技能研习',shots/'skill_study_800.png')]
manifest=[]
for key,title,source in pages:
    assert source.exists(),source
    current=pack/'current'/f'{key}.png'
    shutil.copy2(source,current)
    previous=baseline/'current'/f'{key}.png'
    assert previous.exists(),previous
    shutil.copy2(previous,pack/'before'/f'{key}.png')
    manifest.append(dict(id=key,title=title,source=str(source.relative_to(workspace)),
                         current='current/'+key+'.png',before='before/'+key+'.png',
                         size=list(Image.open(current).size),sha256=hashlib.sha256(current.read_bytes()).hexdigest()))
states=[
 'battle_cooldown_800','battle_safe_low_800','battle_focus_1067',
 'battle_energy30_1067','regions_deep_800','regions_safe_1067',
 'regions_1067','equipment_result_800','equipment_shortage_800',
 'equipment_gems_800','equipment_safe_800','equipment_1067',
 'bag_locked_800','bag_safe_800','bag_material_800','bag_1067',
 'growth_no_action_800','growth_safe_800','growth_1067',
 'codex_unknown_800','codex_evolved_800','codex_owned_1067',
 'skill_study_safe_800','skill_study_1067','departure_safe_1067',
 'login_keyboard_800','introduction_last_800','introduction_1067',
 'loading_1067','hud_lorin_wilds_partner_1067','hud_maple_road_partner_1067',
 'hud_lorin_wilds_swap_feedback_800']
for name in states:
    source=shots/(name+'.png');assert source.exists(),source
    shutil.copy2(source,pack/'states'/source.name)
for name in ['UI_REDIRECTION_MASTER.md','MAIN_UI_REBUILD_BLUEPRINT.md','ASSET_PRODUCTION_BRIEF.md']:
    shutil.copy2(baseline/'specs'/name,pack/'specs'/name)
shutil.copy2(baseline/'outputs/UI_REVIEW_FIXES_FULL.md',pack/'BASELINE_REVIEW.md')
assets=root/'assets/ui/full_review_fixes_20261009'
for name in ['generation_manifest.json','regions.json','map_layout.json','map.png','map_guide.png']:
    shutil.copy2(assets/name,pack/'assets_reference'/name)
report=root/'docs/plans/2026-10-09-full-review-fixes-delivery.md'
if report.exists():shutil.copy2(report,pack/'IMPLEMENTATION_NOTES.md')
if (shots/'verification_manifest.json').exists():shutil.copy2(shots/'verification_manifest.json',pack/'verification_manifest.json')

readme='''# 灯下行箧 · 第二轮整改验收包

`current/` 是本轮重新运行 Godot 拍摄的 18 个主要页面。`before/` 是上一轮 Cloud 据以提出 8 项问题的画面。打开 `index.html` 查看对照；给 Cloud 的完整提示词在 `PROMPT_NEXT_ACCEPTANCE.md`。

截图使用隔离演示存档，全部为真实引擎渲染。它们不是玩家正式存档的游玩录像。背包当前图使用多种现有装备模板的演示库存，旧图主要为重复狼牙剑：不能把两图数量或品种差异当成产品功能变化。同一模板的多个实例仍使用同一张图标，稀有度、强化和锁定状态各自显示。

HUD 前后地点、时刻与屏幕高度未全部相同，应检查入口、布局、名牌和明暗背景下的可读性。战斗暂停逻辑步进，固定目标、血量、能量与冷却供审图；战斗规则未改。安全区和软键盘是桌面模拟，未据此宣称 Android 设备验收。

先读本文件和 `IMPLEMENTATION_NOTES.md`，再看优先页面。`states/` 有32张长屏及关键状态，按需打开；不要机械重复读取。原规范在 `specs/`，原审查在 `BASELINE_REVIEW.md`。地区节点和路线来自导出的实际表 `assets_reference/map_layout.json`，这只是视觉坐标，不改变地图出口或门槛。

新素材已经在界面中实际显示。生成式素材仍应接受像素风格、清晰度、轮廓与一致性的艺术验收，不能因为替换了素材就判定成熟商业品质。旧城镇侧边半透明建筑、野外世界占位图仍是独立地图美术依赖。

最终请只写 `outputs/UI_REVIEW_FIXES_NEXT.md`。包内不含工程，不需要读取外部项目、运行游戏或工具。
'''
(pack/'00_README.md').write_text(readme,encoding='utf8')
prompt='''你是成熟商业竖屏 RPG 的 UI 美术验收总监。请严格评审 Godot《远征》“灯下行箧”本轮整改后的18个主要页面。

目标是让它接近成熟商业游戏的完整画面质量，而不是仅仅配色一致或修完清单。请大胆、具体、有证据。保持世界观、像素角色、美术语言与现有功能，必要时可以要求整块舞台、列表、信息区、操作区重排，或替换不合格素材；不要因为工程师已经投入工作而迁就当前画面。

已经确定的风格边界：夜墨深漆为基础；旧铜只用于结构边和角；纸仅用于笔记或登记；灯金标记真正可行动的重点；朱漆承载主要行动。正文和数值由引擎渲染。禁止网页白板、装饰性进度条、重复套框、按钮和开关混用、用发光掩饰素材模糊。角色与世界的像素密度必须协调。

阅读顺序与范围：
1. 先读00_README.md和IMPLEMENTATION_NOTES.md，理解实际实现和截图不能证明的部分。BASELINE_REVIEW.md仅用于核对原8项问题。
2. 先看current/08_battle.png、17_battle_skills.png、09_region_map.png、06_equipment.png、07_inventory.png、05_growth.png、14_codex.png、18_skill_book.png。
3. 接着检查03/04 HUD、10出征、11登记、16手记、13加载，最后检查01标题、02营帐、12建角、15设置的统一性。
4. 仅在判断问题需要证据时读取对应before/或states/。仅在核对具体规范时读取specs/相应章节；不要机械读完整个包。

评判重点：
- 战斗：敌人个体、当前集火、下个目标、我方生命/能量与技能成本是否一眼读懂；敌人重叠时目标条能否承担识别；准备就绪、能量不足、冷却是否明确；图标与主攻击入口是否达到真实游戏质感。
- 地图：实际18地点、17连接与画面空间关系；道路是否融入地形；当前、可达、未解锁、条件受限能否用形状与文字区分；拖动、边缘方向标签、定位和详情是否清楚。需要时可读导出的map_layout.json，不能臆造连接。
- 装备/背包：真实物品轮廓是否区分模板；84px单层格、稀有度、锁定与强化是否协调；图标是否只是把泛用符号换成另一套生成式画片；比较、需求、宝石孔与滚动暗示是否有效。不要把演示库存不同误认成同模板改变外观。
- 成本与收益：等级/效果变化、概率、所需资源、持有数和不足条件是否易读；投入芯片是否完整显示；主按钮附近的信息是否充分；颜色预算是否让可行动处真正突出。
- 养成：五项属性和下一步推荐是否形成实用入口；角色展示、左侧属性、两组行与动作提示是否有轻重关系；模拟安全区下不能挤到标题。
- 展示：宠物是否有落脚、影与展台；64px原生展示图的三倍显示是否仍显模糊或与现有角色风格冲突；未知宠物剪影与解锁路径是否合理；技能预览与正文是否统一。
- 背景与辅助页面：专用胸箧、图鉴陈列、招式场地是否提供页面身份；出征标题/引句是否落在可读的暗场；介绍页是否没有机械空白；登记纸签是否干净；加载金字在金色天空上是否足够醒目。
- 跨页：字体层级、边框重量、间距、材质尺度、图标光源与色彩密度，800与1067长屏构图，44px热区与安全区位置。

你可以大胆要求结构和美术重做，但不能新增战斗规则、货币、成长门槛、奖励或传送，也不能删除既有入口来换取简洁。不可实现的机制建议只标为可选提案，不进入默认执行清单。不要重新另选风格。

输出要求：
开头用一段话判断“已通过／有条件通过／未通过”，给出最多3个最核心的质量差距。然后只列最多8个最有价值、能推动成熟游戏观感的问题；不足8个则写实际数量，不凑数。

每项必须包括：
1. P0/P1/P2，页面名、截图文件和具体位置；多页通用问题作为一项处理。
2. 截图中可见的事实及其影响，区分功能缺失、布局、信息表达、素材质量。
3. 目标效果；需要整块重排时明确指出为什么局部修饰不够。
4. 可执行要求：结构、区域占比/参考坐标、尺寸、字号、间距、状态、层级与保留的功能。坐标只作对应截图的参考，不冒充实机响应式验收。
5. 新素材需求：用途、显示与源尺寸、透明/九宫格、轮廓、材质、色彩与光源。若现有素材可用，请明确保留并写布局修复。
6. 完成判据和必要补拍状态。截图不能证明的行为标“待实机核实”，不得猜测通过或失败。

末尾给出按投入收益排序的实施顺序，明确哪些能立刻工程修改、哪些依赖美术、哪些必须实机确认。不要重复已合格部分；不要泛泛写“加强质感、丰富层次、优化留白”。

只读本包。不探索工程，不扫描磁盘，不调用Godot MCP，不运行项目/测试，不修改代码，不生成图片，不启动子代理。直接将最终报告保存为outputs/UI_REVIEW_FIXES_NEXT.md，完成后停止。
'''
(pack/'PROMPT_NEXT_ACCEPTANCE.md').write_text(prompt,encoding='utf8')
data=dict(engine='Godot 4.7.2',native_render=True,isolated_demo_save=True,
          core=manifest,state_count=len(states),state_files=['states/'+s+'.png' for s in states],
          device_tested='Windows desktop; portrait sizes 480x800 and 480x1067; safe area and keyboard simulated')
(pack/'capture_manifest.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
css='body{margin:0;background:#17141a;color:#f3e8d0;font:16px/1.6 system-ui,sans-serif}main{max-width:1120px;margin:auto;padding:24px}h1{font-size:26px}p,figcaption{color:#bfb096}nav{display:flex;flex-wrap:wrap;gap:8px;margin:18px 0}button,a{font:inherit;color:#f3e8d0;background:#221e26;border:1px solid #6e5434;padding:7px 12px;cursor:pointer;text-decoration:none}button[aria-selected=true]{border-color:#f0b95a;color:#f0b95a}.pair{display:flex;gap:20px;overflow:auto}figure{margin:0;flex:0 0 480px}img{width:480px;max-width:90vw;display:block}section[hidden]{display:none}.links{display:flex;flex-wrap:wrap;gap:8px;margin:20px 0}'
sections=[]
for i,(key,title,_) in enumerate(pages):
    sections.append(f'<section id="{key}"'+(' hidden' if i else '')+f'><div class="pair"><figure><figcaption>上轮审查画面 · {title}</figcaption><img loading="lazy" src="before/{key}.png"></figure><figure><figcaption>本轮原生运行 · {title}</figcaption><img loading="lazy" src="current/{key}.png"></figure></div></section>')
nav=''.join(f'<button data-page="{key}" aria-selected="{str(i==0).lower()}">{title}</button>' for i,(key,title,_) in enumerate(pages))
state_links=''.join(f'<a href="states/{s}.png">{html.escape(s)}</a>' for s in states)
script='document.querySelectorAll("button[data-page]").forEach(b=>b.onclick=()=>{document.querySelectorAll("button[data-page]").forEach(x=>x.setAttribute("aria-selected",String(x===b)));document.querySelectorAll("section").forEach(s=>s.hidden=s.id!==b.dataset.page)});'
(pack/'index.html').write_text('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>远征 · 第二轮整改</title><style>'+css+'</style><main><h1>远征 · 18个主要界面整改对照</h1><p>全部是引擎原生渲染，使用隔离演示存档。背包品种与HUD地点前后不完全相同；不能据截图推断功能变化。</p><nav>'+nav+'</nav>'+''.join(sections)+'<details><summary>长屏与关键状态</summary><div class="links">'+state_links+'</div></details><p><a href="PROMPT_NEXT_ACCEPTANCE.md">Cloud 验收提示词</a>　<a href="IMPLEMENTATION_NOTES.md">整改说明</a></p></main><script>'+script+'</script></html>',encoding='utf8')
archive=pack.with_suffix('.zip')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for file in pack.rglob('*'):
        if file.is_file():z.write(file,file.relative_to(pack.parent))
print(json.dumps(dict(core=len(pages),states=len(states),zip=str(archive),MB=round(archive.stat().st_size/1024**2,2)),ensure_ascii=False))
