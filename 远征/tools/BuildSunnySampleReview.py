"""Small review package: three native before/after pairs; extras are optional."""
from pathlib import Path
from PIL import Image
import json, shutil, zipfile, re, hashlib, html

root=Path(__file__).resolve().parents[1];workspace=root.parent
shots=root/'shots/world_art_samples_20261010'
assets=root/'assets/world/sunny_travel_20261010'
spec=workspace/'ui_review_input/world_art_direction_20261010/outputs'
pack=workspace/'ui_review_input/world_art_sample_review_20261010'
for directory in ['before','current','states','references','specs','outputs']:(pack/directory).mkdir(parents=True,exist_ok=True)
pairs=[('01_town','城镇正常HUD','lorin_wilds_spawn_800'),('02_field','野外正常HUD','maple_road_spawn_800'),('03_hall_npc_debug','建筑与NPC同框 · 隐藏HUD调试图','hall_npc_art_debug_800')]
manifest=[]
for key,title,name in pairs:
    for phase,folder in [('before','before'),('after','current')]:
        source=shots/phase/(name+'.png');target=pack/folder/(key+'.png');shutil.copy2(source,target)
        manifest.append(dict(file=str(target.relative_to(pack)),source=str(source.relative_to(workspace)),size=list(Image.open(source).size),sha256=hashlib.sha256(source.read_bytes()).hexdigest()))
for name in ['lorin_wilds_sample_800','maple_road_sample_800','lorin_wilds_spawn_1067','maple_road_spawn_1067']:
    for phase in ['before','after']:shutil.copy2(shots/phase/(name+'.png'),pack/'states'/(phase+'_'+name+'.png'))
for name in ['steward','guard','hall','terrain']:
    shutil.copy2(assets/'ready'/(name+'.png'),pack/'references'/(name+'.png'))
for name in ['WORLD_ART_DIRECTION.md','WORLD_ASSET_REBUILD_BRIEF.md']:shutil.copy2(spec/name,pack/'specs'/name)
for name in ['pixel_validation.json','npc_validation.json','original_npc_metrics.json','generation_manifest.json','revision_prompts.json','hall_revision_prompt.json']:
    shutil.copy2(assets/name,pack/'references'/name)
shutil.copy2(root/'docs/plans/2026-10-10-sunny-world-samples-delivery.md',pack/'IMPLEMENTATION_NOTES.md')
for phase in ['before','after']:shutil.copy2(shots/phase/'measurements.json',pack/'references'/(phase+'_measurements.json'))
cases=['VerifyAssets','VerifyMapScene','VerifyMainWorld','VerifyWorldSession','VerifyCity','VerifyStory','VerifyQuests','VerifyNav','VerifyPerf','VerifyFrostArt','VerifyPortGrowth','VerifySignpostEntry']
for name in cases:
    text=(shots/'regressions'/(name+'.log')).read_text(encoding='utf8')
    assert not re.search(r'SCRIPT ERROR|Parse Error|\bFAIL:|_FAIL\b',text),name
    assert re.search(r'^\w+_OK\b',text,re.M),name
native=(shots/'native_verify.log').read_text(encoding='utf8')
assert 'SUNNY_SAMPLE_OK checks=227 failures=0' in native and 'SCRIPT ERROR' not in native
verification=dict(native_checks=227,regressions=cases,final_case_logs_pass=True,notes=['主世界旧整图背景断言更新为地表覆盖及层级检查后单独复测通过。','退出资源诊断按既有issue43单列。','未进行Android真机或最终商业美术验收。'])
(pack/'verification_manifest.json').write_text(json.dumps(verification,ensure_ascii=False,indent=2),encoding='utf8')
(pack/'capture_manifest.json').write_text(json.dumps(dict(engine='Godot4.7.2',native_render=True,isolated_demo_save=True,pairs=manifest,states=8),ensure_ascii=False,indent=2),encoding='utf8')
readme='''# 晴野行旅 · 首轮六组样板限定验收

请使用 `PROMPT_SAMPLE_ACCEPTANCE.md`。只先读本文件和 `TECHNICAL_AUDIT.md`，看3组主要前后图；状态、原规范与制作说明按需读，避免重复长上下文。

- 01：昭元边城正常HUD，原位置/视角。
- 02：枫林古道正常HUD，原位置/视角。
- 03：议事厅、执事、主角同框；两图均隐藏HUD，是明确标注的美术调试视图，不是普通游戏HUD截图。

所有图是Windows上的Godot原生运行结果，使用隔离演示档。前后图采用同地图、位置、相机参数与存档设置；角色待机时刻可能有差异。before通过隔离的样板开关使用原美术，未倒退玩法或地图数据。states/补充两处中段视角和两张长屏的前后对照。

本次完成的6组是：执事、巡界人、城镇地表、枫林地表与树石组、议事厅、路牌。只重做两位NPC和一栋建筑，其他访客/孩童/建筑/敌人仍是旧资产；不宣称全图已经统一。未建成工地仍为待建，不能要求把全部建筑直接变为落成来改善画面。

导入数据合格不等于艺术合格。请独立判断图面质感、比例、疏密、道路边缘、树冠色彩、像素密度和接触影。未通过前不推广其他NPC或地域。

只写 `outputs/WORLD_ART_SAMPLE_FIXES.md`。包内不含工程，不需要查磁盘、运行游戏或工具。
'''
(pack/'00_README.md').write_text(readme,encoding='utf8')
audit='''# 实测摘要与范围

主角未重做：城镇显示可见高约83.5px，野外约68.3px。相机1.15倍，一格48世界像素=55.2显示像素，未改变缩放。

新执事显示约77.3px，约为城镇主角0.93倍。巡界人总高约87.6px包含长矛，不等于人体高度。两位帧条512×128、4帧、48色、二值alpha，脚底最低不透明行全部y123，下半身固定；局部动效由规范关键帧原生构造，避免生成式帧间变脸/变装。

新地表族及两张正式地面均≤20色，建筑≤40色；颜色统计针对不透明源像素，不是叠加阴影、UI与字体后的整张截图。

旧NPC测得执事4138色、巡界人3416色；以alpha≥128统计脚底122/121/122/123，有整体漂移。透明阈值不同会与原审查相差一行，不影响漂移结论。

旧“空壳”其实是未建成工地，不是成品楼体alpha损坏。基线只落成议事厅、城门；其余绘制半透明翻土、桩绳与材料。新方案保留建造状态，仅将工地显示改为实心基础和材料。视口边缘裁切不等于原图缺屋顶。

原地面已用最近邻、关闭mipmap、没有有损压缩；高色数主要来自源图及野外着色器混色。新地面按原中心线和宽度生成，没有移动出口、碰撞或交互点。树冠当前靠摆位避开关键对象，未加入自动淡出机制。

运行检查227项与12组相关回归最终日志通过，包含静态碰撞对照、主角比例、地图配置、模拟移动、执事原自动交谈与真实点击离开。路牌回归也通过。Windows退出仍有已有资源诊断；Android触控和最终美术尚未验收。
'''
(pack/'TECHNICAL_AUDIT.md').write_text(audit,encoding='utf8')
prompt='''你是《远征》世界美术验收总监。现在只验收“晴野行旅 · 3/4俯视手绘像素”的首轮6组样板，决定它是否可以推广。

先读00_README.md和TECHNICAL_AUDIT.md，再看before/与current/中01城镇、02野外、03建筑/NPC调试视图，共3组图。只有具体问题需要证据时才读states/、references/源帧条、specs/相应章节或IMPLEMENTATION_NOTES.md。不要重复读取整个旧UI包和项目历史。

保持已定方向，主角不重做，地图向人物靠拢；地表低对比，建筑有地点身份，人物和交互物突出。请严格、具体，必要时可要求样板重画或重排，但不得换风格、添加玩法或删除功能。

重点看：
1. 新NPC的描边、脸、衣料、色块尺度、比例与主角是否统一；脚底与接触影是否落地，局部待机是否比整体漂移自然。
2. 地表是否仍均匀铺纹、重复或过空；道路是否清楚且融入草地，不能只因色数减少就判合格。
3. 枫树是否真有地域感，树冠的饱和度、块面、轮廓、大小与主角一致，边缘框景是否抢焦点或遮关键对象；岩石与落叶是否成组、贴地。
4. 议事厅的完整屋顶、立面、门窗、墙基、尺度和光向；门相对NPC的比例仍需你独立判断。03是隐藏HUD的真实美术调试图，不能据此推断正常HUD被删除。
5. 待建工地是否清晰、体面，既保留未落成含义又避免“半透明空壳”；路牌是否与人物、地表同一密度，文字/交互仍可读；800和长屏构图有无断层。

只重做的NPC是闻叔/执事和老赵/巡界人；旧访客、孩童、宠物、敌人及其他建筑未进入本轮重绘。可以说明它们是推广依赖，但不要把未改对象当成新样板导入失败。重点判断新样板与主角、空间及同屏层级的关系，不能为了统一让新样板迁就旧高色数资产。

开头直接给“样板可推广／需修正后复审”，理由最多3条。仅列最多5个最值得修的问题，不凑数。每项写图片/位置、可见事实、为何影响质感、目标效果、具体工程或重绘要求、完成判据和必要补拍状态。区分素材问题与采样/摆位/遮挡问题；截图无法确认的行为或成因标待实机核实。

未通过时只修这6组样板，不展开全部NPC与18地区的生产。不要重设计UI、战斗、成长、奖励、建造门槛或传送。

只读指定包内材料；不扫描工程或磁盘、不运行Godot/测试、不调用MCP、不修改代码、不生成图片、不启动子代理。只保存outputs/WORLD_ART_SAMPLE_FIXES.md，完成后停止。
'''
(pack/'PROMPT_SAMPLE_ACCEPTANCE.md').write_text(prompt,encoding='utf8')
css='body{background:#17141a;color:#f3e8d0;margin:24px;font:16px/1.6 system-ui}main{max-width:1080px;margin:auto}nav{display:flex;gap:8px;flex-wrap:wrap}button,a{background:#221e26;color:#f3e8d0;border:1px solid #6e5434;padding:8px 12px;text-decoration:none;cursor:pointer;font:inherit}button[aria-selected=true]{color:#f0b95a;border-color:#f0b95a}.pair{display:flex;gap:20px;overflow:auto}figure{margin:16px 0;flex:0 0 480px}img{width:480px;max-width:90vw;display:block}section[hidden]{display:none}p,figcaption{color:#bfb096}'
nav=''.join(f'<button data-page="{key}" aria-selected="{str(i==0).lower()}">{title}</button>' for i,(key,title,_) in enumerate(pairs))
sections=''.join(f'<section id="{key}"'+(' hidden' if i else '')+f'><p>{title}</p><div class="pair"><figure><figcaption>修改前 · 原生运行</figcaption><img src="before/{key}.png"></figure><figure><figcaption>样板 · 原生运行</figcaption><img src="current/{key}.png"></figure></div></section>' for i,(key,title,_) in enumerate(pairs))
links=''.join(f'<a href="states/{p.name}">{html.escape(p.stem)}</a> ' for p in sorted((pack/'states').glob('*.png')))
script='document.querySelectorAll("button[data-page]").forEach(b=>b.onclick=()=>{document.querySelectorAll("button[data-page]").forEach(x=>x.setAttribute("aria-selected",String(x===b)));document.querySelectorAll("section").forEach(s=>s.hidden=s.id!==b.dataset.page)});'
(pack/'index.html').write_text('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>晴野行旅 · 首轮样板</title><style>'+css+'</style><main><h1>晴野行旅 · 六组样板对照</h1><p>先看3组前后图；其他视角按需查看。建筑同框图隐藏HUD，已明确标注为调试视图。</p><nav>'+nav+'</nav>'+sections+'<details><summary>长屏与补充视角</summary>'+links+'</details><p><a href="PROMPT_SAMPLE_ACCEPTANCE.md">Cloud验收提示词</a>　<a href="IMPLEMENTATION_NOTES.md">制作与检查说明</a></p></main><script>'+script+'</script></html>',encoding='utf8')
archive=pack.with_suffix('.zip')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    z.writestr(pack.name+'/outputs/','')
    for file in pack.rglob('*'):
        if file.is_file():z.write(file,file.relative_to(pack.parent))
with zipfile.ZipFile(archive) as z:assert z.testzip() is None
print(json.dumps(dict(pairs=3,state_images=8,zip_MB=round(archive.stat().st_size/1024**2,2),final_regressions=len(cases)),ensure_ascii=False))
