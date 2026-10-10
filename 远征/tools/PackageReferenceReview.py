from pathlib import Path
import json,shutil,zipfile,re
project=Path(__file__).resolve().parents[1]
workspace=project.parent
art=project/'assets/world/reference_complete_20261011'
old=workspace/'ui_review_input/reference_world_frontend_20261010/outputs'
package=workspace/'ui_review_input/reference_complete_20261011'
for d in ['core','states','reference','outputs']:(package/d).mkdir(parents=True,exist_ok=True)
shots=project/'shots/reference_complete_20261011'
core=['lorin_wilds_hall_800','lorin_wilds_stable_800','lorin_wilds_forge_800','maple_road_meadow_800','maple_road_bridge_800','maple_road_red_maples_800','title_800','login_800','loading_800']
states=['lorin_wilds_default_construction_800','lorin_wilds_sign_exit_800','lorin_wilds_south_800','lorin_wilds_overview','maple_road_fork_800','maple_road_overview','lorin_wilds_spawn_1067','maple_road_spawn_1067','title_1067','login_1067','loading_1067','login_error_800','login_keyboard_800','login_keyboard_1067','density_comparison']
index=[]
for folder,items in [('core',core),('states',states)]:
    for n,name in enumerate(items,1):
        src=shots/(name+'.png');assert src.exists(),src
        target=package/folder/(f'{n:02d}_'+name+'.png');shutil.copy2(src,target)
        index.append({'path':str(target.relative_to(package)).replace('\\','/'),'source':str(src),'state':'isolated all-built fixture' if name.startswith('lorin_wilds') and 'default' not in name else 'default/state capture'})
shutil.copy2(workspace/'ui_review_input/reference_world_frontend_20261010/reference/01_target_forest.jpg',package/'reference/01_target_forest.jpg')
for name,src in [('02_before_town.png',project/'shots/world_art_samples_20261010/before/lorin_wilds_sample_800.png'),('03_before_field.png',project/'shots/world_art_samples_20261010/before/maple_road_sample_800.png')]:
    if src.exists():shutil.copy2(src,package/'reference'/name)
readme='''# 新版地图与三页前端：Claude 复审包

先读 `01_FUNCTIONS_AND_CONSTRAINTS.md`，再看 `core/` 的 9 张图及 `reference/01_target_forest.jpg`。像素问题另看 `states/15_density_comparison.png`，左旧右新，同主角、同相机。

`core/` 是真实 Godot 运行截图，不是生成概念图。城镇使用隔离的已建成预览档，方便比较所有建筑；默认玩家状态见 `states/01_lorin_wilds_default_construction_800.png`。拍地图时暂停输入和接战以固定视角，不改实际场景布局或功能。overview 是缩小的空间诊断图，不代表正常游戏倍率。

最新修订：加载与标题首页恢复原背景；两张地图重新生成自然单条主路、没有岔路；小地图与展开地图不显示道路。最新版本通过 7 个相关回归用例和 179 项接入检查。手机硬件表现尚未验证；审美达标仍需本次复审。

把 `CLAUDE_REVIEW_PROMPT.md` 作为任务提示词。不要让 Claude 扫工程或读取整套旧设计史。需要更多状态时再打开指定的 `states/` 图片。

本包是设计审查资料，不是游戏安装包。工作区内可双击 `D:/new-bee/远征/tools/LaunchReferencePreview.cmd` 试玩已建成城镇；使用独立存档。WASD/方向键或摇杆移动，走近 NPC/门前交互，靠近北侧路牌出城。
'''
functions='''# 当前真实功能与设计约束

## 不再回退的方向

纯 2D 手绘细像素，参照森林图的自然配色与俯视投影。禁止预渲染 3D、旋转等距底座、电影透视和模糊像素滤镜。主角沿用现有红发、红披风、暗甲帧与动画。

城镇左右摆各式建筑；中间一条适中宽度、略弯的土路，背景为自然草地。出口只用路牌，不用门楼。树木独立放置、适量点缀，保证门前和 NPC 不拥挤。底部不强制直路接屏幕，可自然淡出草地。

最新明确要求：只保留自然歪曲、宽窄不均的主路，不画岔路或通往门口的横向支路；小地图与展开本地图都不显示道路。加载和标题首页已经恢复原背景，不得再换成草地/林道背景或新增主角背影；登记页保持当前文牒背景。

出城路牌位于城镇地图最北端，不能放回主街中段；触发区和返城落点已同步调整，牌下文字避开 HUD。

可以大胆调整建筑/树木比例、位置、路缘、地面笔触、背景构图和前端排版，前提是保留功能和可达性。改坐标必须由 Codex 重新验证，不把设计建议冒充已运行的结果。

## 实际规格

逻辑视口 480×800 和 480×1067。城镇 1200×2112，野外 960×2112；允许后续按内容调整。相机 1.15；主角源像素约 0.65 世界像素，实际可见高度约 71.5。成人 NPC 身体约 72、孩童约 52，长枪等附件另计。

地表实际纹理采样是 0.5 世界像素/纹理像素，2 倍密度上下分块；不是把旧的小图放大，也不是只给整图加锐化。笔触块大小仍需截图判断。使用最近邻，地图、建筑、树木和 NPC 都是独立 2D 层。

## 功能不可丢失

- 八座设施：议事厅活动、图志阁世界/图志入口、兽栏伙伴、巡界厅/演武功能、仓廪、马厩、祭坛、铁匠。各自原有面板、成本、条件和状态保留。
- gate ID 改画访客簿，访客记录功能保留。北侧路牌进入枫林古道，野外南侧返回；东侧旧盐道仍受原主线条件限制。
- 九名常驻 NPC、今日访客、原对白和任务实体保留。走近门前或 NPC 仍触发原有交互，不新增室内探索。
- 默认只有议事厅、访客簿已建成，其余是工地；核心图展示全建成隔离预览档。不能因工地截图推断素材缺失，也不能设计成默认全部免费建成。
- 原四个城镇怪物在南部荒院；野外五个刷新点，原类型、等级、刷新、奖励和接战规则保留。
- 中央桥在修桥前可通行。两侧桥按原支线选择开放；河流碰撞、导航和画面使用同一河道坐标。
- HUD：生命/经验/金币、任务、营帐、小地图、交互、伙伴、药剂、疾行以及解锁后的骑乘；地图中心保持可读。
- 标题：开始、介绍、设置、退出。加载：真实预热和进度。登记：账号、密码显隐、画像导入、游客、错误提示、返回、软键盘下可提交。
- 手记/介绍不属于本轮新增重做范围。

## 审查边界

重点评价草地/道路是否自然安静、像素颗粒是否与角色协调、建筑尺度与门前区、树木在常用视口的构图、NPC/任务可见性、场景与 UI 是否属于同一游戏。前端既可局部优化，也可在本风格内重新排版。

截图不能证明动态交互、触控硬件、性能或所有存档情况；标记待实机核实，不凭静态画面宣布功能丢失。不要要求平均铺满装饰、扩大噪点、把主角重新生成，或为了美术改变主线和奖励。
'''
prompt='''你是成熟商业手游的场景美术总监与 UI 视觉验收总监，审查《远征》已经接入游戏的地图和前端。

本次只做一次集中、明确、可执行的审查。先读 `00_READ_ME.md` 和 `01_FUNCTIONS_AND_CONSTRAINTS.md`，然后看 `core/` 9 张实机图及森林参考图。像素密度另看 `states/15_density_comparison.png`；需要验证特定构图/状态时，再打开相关 states 图片，不逐个重读全部旧资料。

你可以大胆一点。不要把“比之前好”当作成熟游戏的标准；如果现有草地、树木、建筑、NPC 或前端构图仍显廉价、机械、噪杂、比例失调，可以提出整块替换、重绘或重新布局。尤其检查地图是否只是高频草地纹理加一条沙路，以及树木是否真正参与构图。

同时守住用户明确选择的方向：纯 2D 手绘细像素；保留现有主角；自然草地和土路；城镇左右各式建筑，中央适中宽度的主路；出口只用一个路牌；独立树木适量点缀；交互和可达性不丢失。UI 沿用克制的深漆木、旧铜和纸面语言，不把地图做成深色纸板。

请生成两个文件并停止：

1. `outputs/REFERENCE_REVIEW_FIXES.md`：只列最影响成熟游戏观感的 8 个问题，按影响排序。每项必须写截图文件与明确位置、具体缺陷、应达到的效果、实施尺寸/比例/材质/状态要求、是否重绘和涉及哪些独立素材。对已经合格的部分不重复给建议。动态问题标待实机核实。
2. `outputs/REFERENCE_ASSET_RETOUCH_BRIEF.md`：为确实需要重绘的优先素材给一条统一母提示词和差异表，最多 5 条完整可复制的英文生图提示词；明确纯 2D 投影、像素密度、透明背景/地面层分离、锚点与参考图用途。没有重绘必要就明确写无需新增，而不是凑满。

实施分批按“最少返工、最大视觉收益”排序，先做一段野外和一个城镇视口，再推广。可以修改位置和比例，但不要擅自改变任务、建筑成本、进度、出口条件、战斗奖励或主角身份。

限制：不扫描工程、不读取脚本、不调用 Godot MCP、不运行游戏/测试、不改代码和数据、不启动子代理、不生成图片、不输出审美理论长文。不要重新复述全部设计史，不写模糊的“加强层次、提升质感”。重要设计细节要写具体，最终只交这两个文件。
'''
(package/'00_READ_ME.md').write_text(readme,encoding='utf-8')
(package/'01_FUNCTIONS_AND_CONSTRAINTS.md').write_text(functions,encoding='utf-8')
(package/'CLAUDE_REVIEW_PROMPT.md').write_text(prompt,encoding='utf-8')
(package/'SCREENSHOT_INDEX.json').write_text(json.dumps(index,ensure_ascii=False,indent=2),encoding='utf-8')
shutil.copy2(project/'docs/plans/2026-10-11-reference-delivery.md',package/'02_IMPLEMENTATION_REPORT.md')
shutil.copy2(art/'ready/sprite_manifest.json',package/'ASSET_SPECS.json')
# Update the reusable recipes while keeping the old documents as design history.
doc=old/'IMAGE_PROMPTS_ALL.md'
text=doc.read_text(encoding='utf-8')
text=re.sub(r'> 城镇最新方向：[^\n]+', '> 2026-10-11 已正式接入：左右各式建筑、中央自然主路、路牌出口、独立树木；城镇1200×2112、野外960×2112，相机1.15，主角0.65。运行地表为2倍密度分块，纹理像素0.5世界单位。最新交付见 `D:/new-bee/远征/docs/plans/2026-10-11-reference-delivery.md`。',text,count=1)
text=text.replace('2 倍母版、1 倍世界输出','2 倍母版与2倍密度运行地表').replace('flat solid #FF00FF background','genuinely transparent alpha background, no baked checkerboard or colored backdrop')
text=re.sub(r'(?i)flat(?: solid)? #FF00FF background','genuinely transparent alpha background, no baked checkerboard or colored backdrop',text)
text=text.replace('plus surrounding magenta margin','plus clear transparent margin').replace('plus magenta margin','plus clear transparent margin')
text=text.replace('按 C–F 组在品红底上单独生成，再做像素整理、去边和定锚点。','按 C–F 组请求原生透明背景，检查 alpha、完整轮廓与脚底锚点后单独接入；原始生成图保留。')
text=text.replace('本清单 C–F 的品红底按正文执行；去底后保留原始文件，并检查残边和落地点。若另行选择原生透明输出，应明确记录为背景处理方式变更，不把透明结果当品红底结果。','当前生产优先原生透明 alpha；不得把棋盘格、深色渐变或带色光晕当作透明。仅当工具无法输出透明时另行约定纯色底，并保留原图、检查残边与锚点。')
text=text.replace('Deliberate pixel color clusters, upper-left daylight','Fine single working pixels and tiny 2-pixel clusters matching the existing hero; never enlarge 4–8-pixel mosaic blocks. Deliberate pixel color clusters, upper-left daylight')
doc.write_text(text,encoding='utf-8')
for name in ['IMPLEMENTATION_STATUS_20261010.md','MAP_REFERENCE_REBUILD_PLAN.md','FRONTEND_REDESIGN_PLAN.md','REFERENCE_ASSET_PRODUCTION_BRIEF.md','MAP_INTEGRATION_AUDIT.md']:
    file=old/name
    note='> 2026-10-11 落地更新：本文件保留设计历史；当前正式实现、坐标和像素规格以 `D:/new-bee/远征/docs/plans/2026-10-11-reference-delivery.md` 与 `assets/world/reference_complete_20261011/layout.json` 为准。已完成两图与加载、标题、登记三页接入，不再是未接入原型。\n\n'
    prior=file.read_text(encoding='utf-8')
    if not prior.startswith('> 2026-10-11 落地更新'):file.write_text(note+prior,encoding='utf-8')
records=json.loads((art/'generation_manifest_final.json').read_text(encoding='utf-8'))
lines=['# 本轮实际使用的生图提示词','','使用内置 image_gen；不支持固定种子。原图与生成路径见 generation_manifest_final.json。地面场景候选没有拉伸上线；正式地表是材料和真实路线遮罩烘焙。','']
for row in records['records']:
    if row['status']=='production_source' and row['id'] not in ['frontend_loading','frontend_title']:lines += ['## '+row['id'],'',row['prompt'],'']
(old/'IMAGE_PROMPTS_PRODUCTION_20261011.md').write_text('\n'.join(lines),encoding='utf-8')
delivery={'core_screens':len(core),'state_screens':len(states),'latest_regression_cases_passed':7,'integration_checks':179,'art_mode':'pure 2D maps','hero_preserved':True,'player_save_changed':False,'android_hardware_tested':False,'review_quality_approval_pending':True,'branch_roads':False,'minimap_roads':False,'loading_and_title_backgrounds':'restored original'}
(package/'DELIVERY_MANIFEST.json').write_text(json.dumps(delivery,ensure_ascii=False,indent=2),encoding='utf-8')
archive=package.with_suffix('.zip')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for file in sorted(package.rglob('*')):
        if file.is_file():z.write(file,str(file.relative_to(package)))
print(f'REVIEW_PACKAGE_OK core={len(core)} states={len(states)} zip={archive} bytes={archive.stat().st_size}')
