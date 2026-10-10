"""Build a new review bundle without replacing the previous verdict or captures."""
from pathlib import Path
import json, shutil, hashlib, html, zipfile, re
from PIL import Image
root=Path(__file__).resolve().parents[1]
shots=root/'shots/next_review_20261009'
pack=root.parent/'ui_review_input/next_review_20261010'
prior=root.parent/'ui_review_input/full_review_fixes_20261009'
for folder in ['current','before','states','assets_reference','logs','outputs']:(pack/folder).mkdir(parents=True,exist_ok=True)
pages=[('01_title','标题','title_800'),('02_home','营帐','b1/home_800'),('03_town_hud','城镇HUD','hud_lorin_wilds_partner_800'),('04_field_hud','野外HUD','hud_maple_road_partner_800'),('05_growth','人物养成','growth_800'),('06_equipment','装备整备','equipment_800'),('07_inventory','行旅背包','bag_800'),('08_battle','战斗集火','battle_focus_800'),('09_region_map','地区行路图','regions_800'),('10_departure','出征筹备','departure_800'),('11_login','旅人登记','login_800'),('12_create_role','建立旅人','b3/create_role_800'),('13_loading','加载','loading_800'),('14_codex','灵宠图鉴','codex_owned_800'),('15_settings','设置','settings_800'),('16_introduction','远征手记','introduction_800'),('17_battle_skills','战斗技能','battle_energy30_800'),('18_skill_book','技能研习','skill_study_800')]
records=[]
for key,title,file in pages:
 source=shots/(file+'.png');assert source.exists(),source
 shutil.copy2(source,pack/'current'/f'{key}.png');shutil.copy2(prior/'current'/f'{key}.png',pack/'before'/f'{key}.png')
 records.append(dict(id=key,title=title,source=str(source.relative_to(root.parent)),size=list(Image.open(source).size),sha256=hashlib.sha256(source.read_bytes()).hexdigest()))
states=['battle_switched_800','battle_dead_800','battle_cooldown_800','battle_focus_1067','battle_energy30_1067','battle_safe_low_800','regions_detail_800','regions_deep_800','regions_legend_800','regions_safe_1067','regions_1067','equipment_result_800','equipment_shortage_800','equipment_gems_800','equipment_safe_800','bag_locked_800','bag_safe_800','bag_material_800','bag_1067','codex_unknown_800','codex_evolved_800','codex_owned_1067','skill_study_safe_800','departure_shortage_800','departure_safe_800','departure_safe_1067','login_keyboard_800','introduction_last_800','introduction_1067','loading_1067','title_1067','settings_1067','hud_lorin_wilds_partner_1067','hud_maple_road_partner_1067']
for file in states:shutil.copy2(shots/(file+'.png'),pack/'states'/(file+'.png'))
for file in (root/'assets/ui/next_review_20261009').glob('*'):
 if file.suffix in ['.png','.json']:shutil.copy2(file,pack/'assets_reference'/file.name)
shutil.copy2(prior/'outputs/UI_REVIEW_FIXES_NEXT.md',pack/'BASELINE_REVIEW.md')
for file in ['native_stdout.log','hud_stdout.log','b1_native_stdout.log','b3_native_stdout.log','regression_runner.log','final_regression_runner.log','perf_isolated_runner.log']:
 shutil.copy2(shots/file,pack/'logs'/file)
shutil.copy2(shots/'perf_isolated/VerifyPerf.log',pack/'logs/VerifyPerf.log')
verification={}
for key,file,pattern in [('native_ui','native_stdout.log',r'NEXT_REVIEW_OK checks=(\d+) failures=0'),('hud','hud_stdout.log',r'REVIEW_HUD_OK checks=(\d+)'),('camp','b1_native_stdout.log',r'TRAVEL_CHEST_B1_OK checks=(\d+)'),('flow','b3_native_stdout.log',r'B3_OK checks=(\d+) failures=0')]:
 text=(shots/file).read_text(encoding='utf8',errors='replace');match=re.search(pattern,text);assert match,(key,'missing completion')
 assert 'SCRIPT ERROR' not in text and '_FAIL' not in text,(key,'script failure')
 verification[key]={'checks':int(match[1]),'failures':0,'log':'logs/'+file}
perf=(shots/'perf_isolated/VerifyPerf.log').read_text(encoding='utf8',errors='replace');assert 'PERF_OK all tests passed' in perf
city=re.search(r'CityScene.*?(\d+) ms',perf)[1]
verification['performance']={'passed':True,'city_entry_ms':int(city),'city_budget_ms':320,'initial_parallel_city_ms':350,'log':'logs/VerifyPerf.log'}
verification['text_audit']={key:sum(len(json.loads(f.read_text(encoding='utf8')).get(key,[])) for f in shots.glob('*.text.json')) for key in ['compact_art','nonlinear_text','short_text_boxes']}
assert not any(verification['text_audit'].values())
(pack/'capture_manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf8')
(pack/'verification_manifest.json').write_text(json.dumps(verification,ensure_ascii=False,indent=2),encoding='utf8')
notes=f'''# 灯下行箧 · 第三轮整改交付（2026-10-10）

依据上一轮有条件通过的 `UI_REVIEW_FIXES_NEXT.md` 落实本轮8项整改。标题01和设置15已补看旧图并重新运行拍摄。商业美术质量保留给独立复审判断；本说明记录实现及验证。

| 问题 | 本轮处理 | 主要证据 |
|---|---|---|
| 战斗对应 | 稳定编号对应敌人和底托芯片；同名敌人加编号；集火目标脚下环和头顶标记；移除浮动集火文字；次键改换目标，保持原循环回调；攻击和循环图形重绘 | 08，battle_switched/dead/focus |
| 地区图 | 测量原图空地并换算18地点显示坐标；原图缺1块独立空地，局部补图；删除UI独立路线层；默认0.5倍全览、1倍详图；裁切拖动范围；条件受限用朱砂印，锁定用锁；图例展示四种形状，提示2秒后消失 | 09，regions_detail/deep/legend/safe |
| 物品技能 | 全44装备模板和20技能使用新像素图集，固定60像素网格、最近邻导入；五技能采用劈、穿盾、回旋、侧脸喊声、断链剪影；不可用时由代码去饱和；传世色改E07038并加专属亮点，详情降低亮度 | 06、07、17，pixel_items及pixel_skills |
| 图鉴 | 按不透明像素底边落台，补接触阴影；进化后标签与+25%芯片；未知页移除重复途径并加入如何结缘卡，里程领取置后 | 14，codex_unknown/evolved/owned_1067 |
| 出征 | 人物、伙伴双画像卡；补给加减、单价、数量和总价；金币不足禁用加号；零扫荡券或未通关首领禁用扫荡并说明原因；安全区缩小时弹性压缩插画 | 10，departure_shortage/safe |
| 投入收益 | 精确资源差额；装备、技能与进化增量芯片；成功强化结果环为0.72秒反馈，实测结束后释放 | 06、18，equipment_result/shortage |
| 辅助流程 | 手记插画随余量伸展，托盘延伸到底，翻章控件守住底部；加载字标暗晕和描边；登记纸签收紧，查看密码嵌入输入框，空错误行隐藏 | 11、13、16，keyboard/last/1067 |
| HUD | 普通伙伴边框与其他圆盘统一，真实替补状态仅加小朱砂点；宠物名签按实际不透明头顶定位，仅竖直避让最多16px，仍冲突时淡出；敌名E58A72并加Lv小芯片 | 03、04，两高度HUD |

本轮保留现有战斗规则、循环集火、地图出口/门槛、补给在出征时统一结算、装备和存档操作。地图仅更改显示坐标和底图，点击地点仍查看详情。所有截图使用隔离演示档，库存和战斗状态用于审图，安全区和触摸均为桌面模拟。

运行检查：新验收场景308项、HUD16项、营帐758项、流程158项通过。七组相关功能回归的战斗、布局、装备成长、面板、养成、返回均通过。首次并行截图时性能用例记录城镇350ms/预算320ms；单独复测通过，城镇{city}ms，未放宽预算。最终另外复测战斗和布局通过。80份文本审计的小号艺术字、非平滑文字、过短文字框均为0。日志仍包含原有退出资源诊断和本机无法写着色器缓存的启动诊断，未声称零告警。

原生运行检查已验证真实鼠标换目标、目标徽记同步、阵亡徽记消失、补给加减与金币不提前扣除、扫荡禁用、地图鼠标拖动/双击/两级缩放、模拟触摸拖动、强化成功与反馈释放。Android触控硬件和长期运行未做。本包包含18张主页面、{len(states)}张精选状态及前后对照；不能用截图代替Android验收，也不能把生图提示词的调色板要求当成已逐色认证的结论。

素材目录：`远征/assets/ui/next_review_20261009/`。内置ImageGen产出三张物品源图集、一张技能源图集，地图做两次局部编辑；原始源文件保留。完整提示词与来源在 `generation_manifest.json`、`map_generation_manifest.json`；原生导入图集及坐标在 `regions.json`、`map_layout.json`。本包已复制这些资料到assets_reference。

复现：使用Godot4.7.2运行 `tools/VerifyNextReview.tscn -- --capture`、`tools/VerifyNextHUD.tscn -- --capture`；原生图集可由 `tools/ImportNextIcons.gd` 重建。工作跨越午夜，资产与运行截图目录保留开始时的20261009标签；交付日期为2026-10-10。
'''
report=root/'docs/plans/2026-10-10-next-review-fixes-delivery.md';report.write_text(notes,encoding='utf8');(pack/'IMPLEMENTATION_NOTES.md').write_text(notes,encoding='utf8')
(pack/'00_README.md').write_text('打开index.html查看18页前后对照。先读IMPLEMENTATION_NOTES.md，再看current/；states/补充目标切换、阵亡、短缺、缩放、图例、未知伙伴、长屏与模拟安全区。标题和设置已补拍。原审查在BASELINE_REVIEW.md，素材和完整生图提示词在assets_reference/。日志保留退出诊断和首次性能失败及复测，不把实现完成当作商业美术验收通过。\n',encoding='utf8')
(pack/'PROMPT_NEXT_ACCEPTANCE.md').write_text('请独立审查《远征》灯下行箧第三轮整改。先读00_README.md和IMPLEMENTATION_NOTES.md，按BASELINE_REVIEW.md核对8项；优先检查08战斗、09地图、07背包、17技能、14图鉴、10出征，再检查辅助流程和03/04 HUD；补查01标题和15设置。用实际画面判断空间对应、轮廓辨识、像素语言、落脚、对比度、短屏/长屏和信息层次，允许继续指出素材不合格。涉及坐标可参考map_layout.json；它只改变显示坐标。截图不能证明Android真机行为，桌面运行证据见说明。最多列8个最值得修的问题，区分工程、美术及实机依赖，给出具体位置和完成判据，保持现有玩法。最终只写outputs/UI_REVIEW_FIXES_NEXT.md，勿把交付说明或检查数当作视觉质量通过的依据。\n',encoding='utf8')
cards=[]
for key,title,file in pages:cards.append(f'<section><h2>{html.escape(title)}</h2><div><figure><figcaption>上一轮</figcaption><img loading="lazy" src="before/{key}.png"></figure><figure><figcaption>本轮</figcaption><img loading="lazy" src="current/{key}.png"></figure></div></section>')
links=' '.join(f'<a href="states/{file}.png">{file}</a>' for file in states)
(pack/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>灯下行箧 · 第三轮整改对照</title><style>body{background:#17141a;color:#f3e8d0;font:16px system-ui;margin:24px}section{margin-bottom:32px}section div{display:flex;gap:20px;flex-wrap:wrap}figure{margin:0}img{width: min(42vw,480px);height:auto}figcaption{margin:8px 0;color:#bfb096}a{color:#c29a5b;display:inline-block;margin:8px}h2{font-size:20px}</style><h1>灯下行箧 · 第三轮整改对照</h1><p>2026-10-10 · 18页原生运行截图，当前/上一轮对照；商业美术质量仍需独立复审。</p><a href="IMPLEMENTATION_NOTES.md">实现与运行验证</a>'+''.join(cards)+'<h2>精选状态</h2>'+links,encoding='utf8')
archive=pack.with_suffix('.zip')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
 for f in pack.rglob('*'):
  if f.is_file():z.write(f,f.relative_to(pack.parent))
print(json.dumps({'package':str(pack),'zip':str(archive),'main_pages':len(pages),'states':len(states),'zip_mb':round(archive.stat().st_size/1048576,1),'native_checks':sum(v.get('checks',0) for v in verification.values())},ensure_ascii=False))
