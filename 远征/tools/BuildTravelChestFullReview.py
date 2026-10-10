from pathlib import Path
import shutil, json, zipfile, html, re
root=Path(__file__).resolve().parents[1]
workspace=root.parent
pack=workspace/'ui_review_input/travel_chest_full_review_20261009'
for name in ('current','before','states/b3','states/b2','specs','outputs'):(pack/name).mkdir(parents=True,exist_ok=True)
b1=root/'shots/travel_chest_b1_20261009';b2=root/'shots/travel_chest_b2_20261009';b3=root/'shots/travel_chest_b3_20261009'
items=[('01_title','标题',b1/'title_800.png'),('02_home','营帐',b1/'home_800.png'),('03_town_hud','城镇 HUD',b2/'town_800.png'),('04_field_hud','野外 HUD',b2/'field_dark_1067.png'),('05_growth','养成',b2/'growth_800.png'),('06_equipment','装备',b2/'equipment_800.png'),('07_inventory','背包',b2/'bag_800.png'),('08_battle','战斗',b3/'battle_800.png'),('09_region_map','地区图',b3/'regions_800.png'),('10_departure','出征',b3/'deploy_800.png'),('11_login','登记',b3/'login_800.png'),('12_create_role','建角',b3/'create_role_800.png'),('13_loading','加载',b3/'loading_800.png'),('14_codex','图鉴',b3/'codex_unknown_800.png'),('15_settings','设置',b3/'settings_800.png'),('16_introduction','介绍',b3/'introduction_800.png'),('17_battle_skills','战斗技能',b3/'battle_skills_800.png')]
old=workspace/'ui_review_input/cloud_full_redesign_20261009/screenshots'
index=[]
for key,title,source in items:
    shutil.copy2(source,pack/'current'/(key+'.png'))
    matches=list(old.rglob(key+'.png'))
    if matches:shutil.copy2(matches[0],pack/'before'/(key+'.png'))
    index.append({'id':key,'title':title,'current':'current/'+key+'.png','before':'before/'+key+'.png','source':str(source.relative_to(workspace))})
newshots=sorted(p for p in b3.glob('*.png') if not p.stem.endswith('_first'))
for p in newshots:shutil.copy2(p,pack/'states/b3'/p.name)
for name in ['equipment_success_800','equipment_failure_800','bag_locked_800','bag_full_pending_800','riding_on_800','gems_800','growth_no_action_800']:
    shutil.copy2(b2/(name+'.png'),pack/'states/b2'/(name+'.png'))
shutil.copy2(b3/'skill_book_800.png',pack/'current/18_skill_book.png')
specs=workspace/'ui_review_input/cloud_full_redesign_20261009/outputs'
for name in ('UI_REDIRECTION_MASTER.md','MAIN_UI_REBUILD_BLUEPRINT.md','ASSET_PRODUCTION_BRIEF.md'):shutil.copy2(specs/name,pack/'specs'/name)
for batch in (1,2,3):shutil.copy2(root/f'docs/plans/2026-10-09-travel-chest-b{batch}-delivery.md',pack/f'IMPLEMENTATION_B{batch}.md')
manifest={'engine':'Godot 4.7.2','actual_native_render':True,'core_count':17,'b3_native_states':len(newshots),'core':index,'additional_growth_page':'current/18_skill_book.png','notes':['旧图来自全面重构设计输入包。','当前图沿用同一日期三批的实际运行结果；B3战斗暂停步进以固定状态。','04为1067高暗场野外，旧图与新图位置不同，不能作为同地图美术对照。','安全区、软键盘为模拟；各状态用隔离演示存档，不使用真实玩家存档。']}
(pack/'capture_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
readme='''# 灯下行箧 · 17 个主要界面完整审查包

打开 `index.html` 查看全部前后对照。`current/` 有 17 个主要界面和新增的技能研习页。所有当前画面都是 Godot 真实运行输出，不是设计效果图。

给 Cloud 的入口是 `PROMPT_FULL_ACCEPTANCE.md`。先读本文件、`REVIEW_RULES.md` 和 `IMPLEMENTATION_B3.md`，再看指定的主要画面；其余状态图按问题查看，避免整包重复读取。三份原设计放在 `specs/`，需要核对细节时再读相关章节。

`states/b3/` 为本批 800、1067、安全区、软键盘、错误、锁定、自动、低血与危险确认等状态；`states/b2/` 只补充七张关键状态。

截图使用隔离演示存档。战斗暂停场景步进以固定时刻，仍显示正常的 ×1／×2 设置。加载继续使用真实队列进度；模拟比例只作检查，不生成假进度界面。

野外当前图是暗场 1067 高画面，与旧图位置不同，主要检查 HUD；原地图、人物和敌人美术不是本包的全面重做对象。部分宠物大图仍受旧素材清晰度限制。

审查输出请保存为 `outputs/UI_REVIEW_FIXES_FULL.md`。包内没有游戏工程，无需搜索外部项目或调用 Godot 工具。
'''
(pack/'00_README.md').write_text(readme,encoding='utf-8')
rules='''# 本轮验收的共同规则

方向：灯下行箧。深漆是基础，旧铜用于结构边和角，纸签只承载笔记与表单，灯金标记下一步，朱漆用于唯一主行动。

色票：夜墨 #17141A、漆面 #221E26、旧铜 #6E5434／#C29A5B、纸字 #F3E8D0、旧纸 #BFB096、灯金 #F0B95A、朱砂 #CF4A33、玉绿 #63B784、霜蓝 #8DB3C7、灰烬 #77705F。

字体：标题与对象名用 Serif，正文用 Regular，数值／状态用 Bold。小字不低于12；动态文字由引擎渲染，不烧入贴图。不要大段书法或粗体正文。

布局：页面突出一个当前对象与一个主要行动；返回用顶部44px入口，避免重复返回；边角切2px，按钮与行最少44px触控区；长屏分配给舞台或列表；避免桌面滚动条、网页白板、等重按钮堆叠。

功能边界：连续战斗不能被改成回合制；攻击仍切换集火目标；地区图按真实18地点及门槛展示，不增加传送；补给累计预选、出征才结算；登录没有远程认证；建角不增加现有系统没有的昵称限制；存档危险操作需要确认。

这些是检查基准，不是为现有实现找理由。结构、比例、展示质量有具体问题时可以要求重排；美术资产不够时应提出素材需求，而不是假装换颜色就能解决。
'''
(pack/'REVIEW_RULES.md').write_text(rules,encoding='utf-8')
prompt='''你是成熟商业竖屏 RPG 的 UI 美术验收总监，严格审查 Godot《远征》“灯下行箧”三批实现后的真实界面。

目标：判断这套界面是否真正形成成熟游戏的构图、层次、物品展示和操作重点，并找出下一轮最值得修复的问题。请大胆且有依据：必要时可要求整块区域或页面重新布局，保持既定美术方向与现有功能。不要把“已经统一配色”当成验收合格。

低成本阅读顺序：
1. 读00_README.md、REVIEW_RULES.md、IMPLEMENTATION_B3.md。
2. 先检查current/中的02营帐、05养成、06装备、07背包、08战斗、09地区图、10出征、14图鉴。
3. 再检查01标题与03/04HUD的跨页一致性，以及11登记、12建角、13加载、15设置、16介绍、17战斗技能；18技能研习作补充。
4. 需要确认具体问题时才打开states/或before/。需要精确原规范时才读specs/中相应章节。不要机械读完全部状态图和工程历史。

重点：
- 是否仍有套用同一骨架造成的机械感、过量空白、视觉断层、网页化容器。
- 角色、宠物、装备和地标的大小、材质、清晰度、边框重量与背景关系。
- 连续战斗中的主攻击入口、集火选择、技能可用／能量不足／冷却、伙伴、目标、血量、能量与危险确认是否清楚。
- 地图的真实拓扑与拖动暗示，当前／可达／条件受限状态是否靠形状和文字区分。
- 页签、开关、滑杆、输入框、主行动和返回是否各司其职。
- 字体层级、数值可读性、色彩预算、图标重量、长屏和安全区构图。
- 旧宠物图片清晰度等素材问题须与布局问题区分；既有地图占位或半透明建筑可标为跨范围素材依赖。

只列最多8个最有价值的问题，按影响排序；不足8个则写实际数量，不凑数。每项必须有：
1. P0/P1/P2优先级、页面名、截图文件与具体位置。
2. 当前的可见事实，以及它为什么削弱成熟游戏质感。
3. 目标效果，可要求重排结构，但不能另换美术方向。
4. 工程师能直接执行的布局、比例、尺寸、字体、间距、状态、层级要求。
5. 是否需要新素材；需要则给用途、源／显示尺寸、透明或九宫格要求与风格。
6. 需要补拍的真实状态及可检查的验收标准。

不得新增战斗规则、货币、成长门槛、传送或奖励。若确有机制建议，只作为不进入默认任务的可选提案。不要声称截图不能证明的操作已经验收。不要泛泛写“增加质感”“丰富层次”“优化留白”；不要大篇幅重复合格部分。

只读本包；不读取游戏工程、不搜索整个磁盘、不调用Godot MCP、不运行游戏或测试、不修改代码、不生成图片、不启动子代理。不要自动实施整改。

直接保存outputs/UI_REVIEW_FIXES_FULL.md，末尾给出建议修复顺序。完成后停止。
'''
(pack/'PROMPT_FULL_ACCEPTANCE.md').write_text(prompt,encoding='utf-8')
css='''body{margin:0;background:#17141a;color:#f3e8d0;font:16px/1.6 system-ui,sans-serif}main{max-width:1100px;margin:auto;padding:24px}h1{font-size:26px}p,figcaption{color:#bfb096}nav{display:flex;gap:8px;flex-wrap:wrap;margin:18px 0}button,a{font:inherit;color:#f3e8d0;background:#221e26;border:1px solid #6e5434;padding:7px 12px;cursor:pointer;text-decoration:none}button[aria-selected=true]{border-color:#f0b95a;color:#f0b95a}.pair{display:flex;gap:20px;overflow:auto}figure{margin:0;flex:0 0 480px}img{width:480px;max-width:90vw;display:block}section[hidden]{display:none}.links{display:flex;gap:8px;flex-wrap:wrap;margin:20px 0}'''
sections=[]
for i,(key,title,source) in enumerate(items):
    sections.append('<section id="'+key+'"'+(' hidden' if i else '')+'><div class="pair"><figure><figcaption>重构前 · '+title+'</figcaption><img loading="lazy" src="before/'+key+'.png"></figure><figure><figcaption>当前实际运行 · '+title+'</figcaption><img loading="lazy" src="current/'+key+'.png"></figure></div></section>')
nav=''.join('<button data-page="'+key+'" aria-selected="'+('true' if i==0 else 'false')+'">'+title+'</button>' for i,(key,title,_) in enumerate(items))
states='<details><summary>长屏、安全区与状态图</summary><div class="links">'+''.join('<a href="states/b3/'+p.name+'">'+html.escape(p.stem)+'</a>' for p in newshots)+'</div></details>'
gallery='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>灯下行箧 · 全界面验收</title><style>'+css+'</style><main><h1>灯下行箧 · 17 个主要界面</h1><p>左侧是全面重构前，右侧是三批实现后的 Godot 原生画面。横向滑动看完整对照，状态图按需打开。</p><nav>'+nav+'</nav>'+''.join(sections)+states+'<p><a href="current/18_skill_book.png">技能研习页</a>　<a href="PROMPT_FULL_ACCEPTANCE.md">Cloud 详细审查提示词</a></p></main><script>document.querySelectorAll("button[data-page]").forEach(b=>b.onclick=()=>{document.querySelectorAll("button[data-page]").forEach(x=>x.setAttribute("aria-selected",String(x===b)));document.querySelectorAll("section").forEach(s=>s.hidden=s.id!==b.dataset.page)});</script></html>'
(pack/'index.html').write_text(gallery,encoding='utf-8')
(b3/'index.html').write_text('<!doctype html><meta charset="utf-8"><meta http-equiv="refresh" content="0;url=../../../ui_review_input/travel_chest_full_review_20261009/index.html">',encoding='utf-8')
archive=pack.with_suffix('.zip')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for p in pack.rglob('*'):
        if p.is_file():z.write(p,p.relative_to(pack.parent))
print(json.dumps({'core':len(items),'b3_states':len(newshots),'zip':str(archive),'zip_bytes':archive.stat().st_size},ensure_ascii=False))
