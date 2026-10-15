from pathlib import Path
from PIL import Image
import json, shutil, hashlib, re
root=Path(__file__).resolve().parents[3]
pack=root/'ui_review_input/cloud_full_redesign_20261009'
fresh=Path(__file__).parent
latest=root/'远征/shots/opus_review_fixes_20261009'
entries=[
 ('core','01_title.png','启动主菜单',latest/'title_normal_800.png'),
 ('core','02_home.png','营帐主页',fresh/'home.png'),
 ('core','03_town_hud.png','城镇 HUD',latest/'town_800.png'),
 ('core','04_field_hud.png','野外 HUD／枫林古道',latest/'field_maple_road.png'),
 ('core','05_growth.png','养成总览',fresh/'growth.png'),
 ('core','06_equipment.png','装备与强化',fresh/'equip.png'),
 ('core','07_inventory.png','背包',fresh/'bag.png'),
 ('core','08_battle.png','战斗主视图／指令',fresh/'main_world_battle_commands.png'),
 ('core','09_region_map.png','地区行路图',fresh/'worlds.png'),
 ('core','10_departure.png','出征准备',fresh/'deploy_plain.png'),
 ('support','11_login.png','旅人登记',fresh/'login.png'),
 ('support','12_create_role.png','创建角色',fresh/'createrole.png'),
 ('support','13_loading.png','加载',fresh/'load.png'),
 ('support','14_codex.png','图鉴',fresh/'codex.png'),
 ('support','15_settings.png','设置',fresh/'settings.png'),
 ('support','16_introduction.png','游戏介绍／世界页',fresh/'title_intro.png'),
 ('support','17_battle_skills.png','战斗技能页',fresh/'main_world_battle_skills.png'),
 ('states','S01_title_long.png','启动页长屏',latest/'title_1067.png'),
 ('states','S02_hud_long.png','城镇 HUD 长屏',latest/'town_1067.png'),
 ('states','S03_hud_safe.png','HUD 安全区',latest/'town_safe_800.png'),
 ('states','S04_long_text_currency.png','长任务／长名字／大金币',latest/'stress_800.png'),
 ('states','S05_sprint_on.png','疾行开启',latest/'sprint_on_800.png'),
 ('states','S06_sprint_gray.png','疾行开启灰度诊断',latest/'sprint_on_gray_800.png'),
 ('states','S07_potion_zero.png','药剂为零',latest/'potion_zero_800.png'),
 ('states','S08_tasks_collapsed.png','任务收起',latest/'tasks_collapsed_800.png'),
 ('states','S09_map_expanded.png','同源地形地图展开',latest/'map_expanded_800.png'),
 ('states','S10_interaction_near.png','靠近提示',latest/'interaction_near_800.png'),
 ('states','S11_interaction_ready.png','有效距离交互诊断',latest/'interaction_ready_800.png'),
 ('states','S12_hud_gray.png','HUD 灰度诊断',latest/'town_gray_800.png'),
]
manifest=[]
for group,name,title,source in entries:
    destination=pack/'screenshots'/group/name
    destination.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(source,destination)
    with Image.open(destination) as img:
        width,height=img.size
    original_hash=hashlib.sha256(source.read_bytes()).hexdigest()
    assert original_hash==hashlib.sha256(destination.read_bytes()).hexdigest()
    assert width==480 and height in [800,1067]
    manifest.append({'file':str(destination.relative_to(pack)).replace('\\','/'),'title':title,'group':group,'width':width,'height':height,'source':str(source.relative_to(root)).replace('\\','/'),'source_date':'2026-10-09','fresh_capture':source.parent==fresh,'sha256':original_hash,'diagnostic':group=='states'})
(pack/'outputs').mkdir(exist_ok=True)
(pack/'capture_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
lines=['# 截图索引','', '所有图片保持原生尺寸，来源均为 2026-10-09。先读取 core 10 张，再读 support 7 张；states 12 张仅按问题选读。不要把不同状态误当成不同页面。','']
for group,heading in [('core','主要页面'),('support','配套页面'),('states','按需状态')]:
    lines+=['## '+heading,'','| 文件 | 内容 | 尺寸 | 来源 |','|---|---|---|---|']
    for item in manifest:
        if item['group']!=group: continue
        source_label='本次重新拍摄' if item['fresh_capture'] else '同日最新已验证渲染'
        lines.append(f"| `{item['file']}` | {item['title']} | {item['width']}×{item['height']} | {source_label} |")
    lines+=['']
lines+=['战斗主视图和技能页使用同一游戏的演示战斗状态，模拟推进已冻结以便看清 UI。交互就绪图暂停自动接触步骤，条件与诊断含义见 README。灰度诊断在 Godot 中渲染；其余图片均为正常色彩。','', '登记、建角、图鉴等页面仅展示代表性页/状态，未提交的子页与隐藏功能不要据图猜测。','']
(pack/'SCREENSHOT_INDEX.md').write_text('\n'.join(lines),encoding='utf-8')
html=['<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>远征主要界面评审包</title><style>body{background:#17151a;color:#f3e8d0;font:16px/1.6 system-ui;margin:0}main{max-width:1080px;margin:auto;padding:24px}nav{display:flex;gap:10px;flex-wrap:wrap}a{color:#dfbf82}section{margin-top:28px}.grid{display:flex;gap:24px;flex-wrap:wrap}figure{margin:0 0 24px;max-width:480px}img{width:480px;max-width:100%;height:auto;display:block}figcaption{color:#bfb096;margin-bottom:8px}h1{font-size:26px}</style><main><h1>《远征》主要界面 · 完整重构评审</h1><p>17 个视图 + 12 张按需状态图。点击图片查看原尺寸，不用缩略图判断字体或细节。</p><nav><a href="PROMPT_FULL_REDESIGN.md">详尽提示词</a><a href="SCREENSHOT_INDEX.md">截图索引</a><a href="#core">主要页面</a><a href="#support">配套页面</a><a href="#states">状态</a></nav>']
for group,heading in [('core','主要页面'),('support','配套页面'),('states','按需状态')]:
    html.append(f'<section id="{group}"><h2>{heading}</h2><div class="grid">')
    for item in manifest:
        if item['group']!=group:continue
        html.append(f'<figure><figcaption>{item["title"]} · {item["width"]}×{item["height"]}</figcaption><a href="{item["file"]}"><img loading="lazy" src="{item["file"]}" alt="{item["title"]}"></a></figure>')
    html.append('</div></section>')
html.append('</main></html>')
(pack/'index.html').write_text('\n'.join(html),encoding='utf-8')
for reference in re.findall(r'(?:src|href)="([^"]+)"','\n'.join(html)):
    if reference.startswith('#'):continue
    assert (pack/reference).is_file(),reference
print('Validated:',len(manifest),'screenshots; 17 views and 12 state captures; file hashes match originals.')
