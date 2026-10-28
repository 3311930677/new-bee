from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps
import json
import hashlib
import difflib
import shutil

ROOT = Path(r"D:\new-bee")
PROJECT = ROOT / "远征"
OUT = ROOT / "reports/visual_fixes_20261027"
BEFORE = PROJECT / "shots/visual_review_current_20261026"
AFTER = PROJECT / "shots/visual_fixes_20261027/release_review"
ACCEPTANCE = PROJECT / "shots/visual_fixes_20261027/acceptance_final"
BACKUP = ROOT / "reports/visual_fixes_20261026/before"
OUT.mkdir(parents=True, exist_ok=True)
(OUT / "comparisons").mkdir(exist_ok=True)
(OUT / "validation").mkdir(exist_ok=True)
FONT = r"C:\Windows\Fonts\msyh.ttc"
BOLD = r"C:\Windows\Fonts\msyhbd.ttc"

# Refresh the bag examples with the final interactive balance control present.
for dim, name in [("320x640", "bag_320x640"), ("480x800", "bag_800"), ("480x1067", "bag_1067")]:
    shutil.copy2(ACCEPTANCE / f"bag_{dim}.png", AFTER / f"{name}.png")

def grid(rows, destination, cols=3, width=384, height=640):
    gap, header = 16, 64
    lines = (len(rows) + cols - 1) // cols
    canvas = Image.new("RGB", ((width+gap)*cols+gap, (height+header+gap)*lines+gap), "#10151d")
    draw = ImageDraw.Draw(canvas)
    for i, (path, title, subtitle) in enumerate(rows):
        x, y = gap+(i%cols)*(width+gap), gap+(i//cols)*(height+header+gap)
        draw.rectangle((x,y,x+width,y+height+header),fill="#1c2631")
        draw.text((x+10,y+7),title,font=ImageFont.truetype(BOLD, max(14,round(width/17))),fill="#f5d291")
        draw.text((x+10,y+37),subtitle,font=ImageFont.truetype(FONT,max(12,round(width/24))),fill="#ced6df")
        image=Image.open(path).convert("RGB")
        image=ImageOps.contain(image,(width,height),Image.Resampling.LANCZOS)
        canvas.paste(image,(x+(width-image.width)//2,y+header+(height-image.height)//2))
    canvas.save(destination,quality=94)

grid([
    (AFTER/"bag_320x640.png","窄屏背包","金额完整收进边框，点按可看精确数值"),
    (AFTER/"map_800.png","地理详图","建筑、短名称、分类颜色与当前位置"),
    (AFTER/"world_frost_boardwalk_middle.png","雪地补景","沿路补入雪松、冰晶与地貌层次"),
    (AFTER/"world_frost_post.png","场景比例","NPC、主角与房屋协调，散开道具"),
    (AFTER/"activities_800.png","页面样式","商城、活动、地图、垂钓共用金框木纹"),
    (AFTER/"battle_800.png","战斗表现","敌方站位错开，目标卡加宽并支持横滑"),
],OUT/"final_overview.jpg")

cases=[
    ("01_bag","窄屏金额与操作", "bag_320x640", "缩写金额完整显示；卖出按钮采用短文案。"),
    ("02_map","地图辨识与默认视野", "map_800", "增加实际建筑、名称、分类色；先看身边，缩小可看全图。"),
    ("03_desert","沙漠可见地标", "world_red_sand_route_middle", "按路段放置岩体，限制枯井重复。"),
    ("04_snow","雪地景物层次", "world_frost_boardwalk_middle", "沿路安排雪松、冰晶，保留道路和交互点。"),
    ("05_scale","人物与场景比例", "world_frost_post", "人类 NPC 接近主角身高，放大建筑，散开货车与灯桌。"),
    ("06_style","共用页面视觉", "activities_800", "金框、深木纹、玉色主按钮与背包、任务保持一致。"),
    ("07_battle","战斗目标辨识", "battle_800", "拉开前后排、分离编号与血条、加宽可横滑目标卡。"),
    ("08_region","地区图固定入口", "worlds_800", "地理详图按钮无需滚动即可完整看到。"),
    ("09_home","长屏主城构图", "home_1067", "拉近城景与主角，将任务条移近角色。"),
]
for code,title,name,description in cases:
    grid([(BEFORE/f"{name}.png","修复前",title),(AFTER/f"{name}.png","修复后",title)],OUT/"comparisons"/f"{code}.jpg",cols=2,width=480,height=1067 if name.endswith("1067") else 800)

maps=json.loads((PROJECT/"data/main_world_maps.json").read_text(encoding="utf-8"))["maps"]
map_ids=["lorin_wilds","maple_road","broken_slope","old_salt_road","shenyuan_port","tideflat","tidal_gate","stele_cavern","red_sand_route","frost_post","rift_mine_road","rift_mine_vault","frost_pass","frost_boardwalk","abyss_ring","stele_entry","stele_resonance","stele_core"]
grid([(AFTER/f"world_{key}.png",str(maps[key]["name"]),key) for key in map_ids],OUT/"worlds_18_review.jpg",cols=6,width=240,height=400)

page_names=["title_800","login_800","home_800","bag_800","quests_800","activities_800","exchange_800","gacha_800","worlds_800","fishing_salt_800","map_800","map_320x640"]
grid([(AFTER/f"{name}.png",name,"最终实际渲染") for name in page_names],OUT/"pages_review.jpg",cols=4,width=240,height=400)

changed=[]
patch=[]
for before in sorted(BACKUP.rglob("*")):
    if not before.is_file():continue
    rel=before.relative_to(BACKUP)
    after=PROJECT/rel
    a,b=before.read_bytes(),after.read_bytes()
    if a==b:continue
    changed.append({"path":rel.as_posix(),"before_sha256":hashlib.sha256(a).hexdigest(),"after_sha256":hashlib.sha256(b).hexdigest()})
    patch.extend(difflib.unified_diff(a.decode("utf-8-sig").splitlines(keepends=True),b.decode("utf-8-sig").splitlines(keepends=True),fromfile="before/"+rel.as_posix(),tofile="after/"+rel.as_posix()))
for rel in ["tools/VerifyVisualPolish.gd","tools/VerifyVisualPolish.tscn"]:
    content=(PROJECT/rel).read_bytes()
    changed.append({"path":rel,"new_file":True,"after_sha256":hashlib.sha256(content).hexdigest()})
(OUT/"source_manifest.json").write_text(json.dumps(changed,ensure_ascii=False,indent=2),encoding="utf-8")
(OUT/"changes.patch").write_text("".join(patch),encoding="utf-8")

for name in ["requested_final.log","inventory_final.log","experience_final.log","home_final.log","battle_presentation_final.log","visual_acceptance_final.log","capture_release_review.log"]:
    shutil.copy2(ROOT/"reports/visual_fixes_20261026"/name,OUT/"validation"/name)
shutil.copy2(ACCEPTANCE/"results.json",OUT/"validation"/"visual_acceptance.json")

text="""# 游戏画面修复与截图复验

2026 年 10 月 27 日。已完成此前检查列出的八项修复，经过多轮实际渲染、对照和调整；最终主截图共 42 张，覆盖十八张地图及主要页面，另有三档尺寸专项截图和六敌同屏交互截图。

![最终画面](./final_overview.jpg)

| 原问题 | 最终行为 |
| --- | --- |
| 窄屏金币越界、卖出按钮拥挤 | 320 宽度下显示“金 12.84万”；点按金额区可查看精确金币数，完整数值提示也留在屏内。卖出采用短文案，保持完整触摸区域。 |
| 地图圆点难以辨认 | 底图加入实际建筑、景物与地点短名；标记按类别区分颜色，名称避让图标。默认查看人物附近，缩小能看全图，保留缩放、拖动、分类、列表、追踪与取消。 |
| 野外画面空旷 | 补景优先按路段安排，再填充外围；加入可见岩体、雪松、冰晶，限制重复枯井，并避让主路、出入口和交互点。 |
| 人物、NPC、房屋与道具不协调 | 人类 NPC 身高接近主角，建筑适当放大；将霜关的灯桌与货车分开放置。 |
| 新旧页面风格差异大 | 商城、活动、地理详图和垂钓控件共用背包体系的金框、深木纹与玉色主按钮。 |
| 敌群及目标信息拥挤 | 拉开敌方前后排并错开纵向站位，编号移到形象侧上方、血条靠近脚下；目标卡加宽，支持点按选敌和横向拖动，拖动不误选。窄屏另适配战场与指令区。 |
| 地区图入口被裁切 | “地理详图与玩法地点”固定在底部，三档尺寸都无需滚动即可完整看到并打开。 |
| 长屏主城留白过多 | 拉近城景和主角，将任务条移近角色，底部出征与导航保持可用。 |

## 修复前后对照

每张对照图左侧为修复前，右侧为修复后；均来自游戏实际运行。沙漠与雪地采用相同主角位置，页面采用相同窗口尺寸；地图对照展示各版本打开后的默认视野。

"""
for code,title,name,description in cases:
    text+=f"### {title}\n\n{description}\n\n![{title}](./comparisons/{code}.jpg)\n\n"
text+="""## 覆盖与验证

| 检查 | 结果 |
| --- | --- |
| 本轮专项布局与真实触摸回放 | 199 项通过，0 失败；覆盖 480×800、480×1067、320×640、极端金额、地图全图与局部视野、固定入口、六敌同屏、横滑与点按选敌、鼠标兼容 |
| 背包交互回归 | 528 项通过，0 失败；含物品选择、锁定、卖出、装备、宝石及焦点导航 |
| 地图与世界回归 | 410 项通过，0 失败；覆盖十八张地图和地图筛选、缩放、定位、点选、追踪、取消 |
| 商城、活动、垂钓与导航回归 | 78 项通过，0 失败；包含兑换回滚和实际骑乘导航到钓点后现场交互 |
| 主城入口回归 | 248 项通过；两档高度下实际点击主要入口，验证打开、关闭和首页恢复 |
| 既有战斗与短屏表现回归 | FULL_PLAY_VISUAL_OK，0 失败；六目标卡、血条、召唤结果短屏及天赋入口 |

合计 1,463 项有计数的功能与布局检查通过，另有既有表现回归通过。首次专项测试发现了目标卡触摸点选缺失，修复后重新验收；记录保留在本轮工作目录。

验证使用隔离存档。以上为桌面 Godot 4.7.2 按手机比例实际渲染和输入事件回放；手机触摸手感、安全区和设备性能仍需要真机复验。引擎日志中的本机证书读取错误、既有验收脚本退出资源清理提示，以及保存失败用例的预期锁写警告均保留，功能断言通过不等于这些日志已消失。

![十八张地图](./worlds_18_review.jpg)

![主要页面](./pages_review.jpg)

## 文件

- [专项结果](./validation/visual_acceptance.json)
- [验证日志](./validation/visual_acceptance_final.log)
- [本轮源码清单与哈希](./source_manifest.json)
- [相对实施前工作区的增量修改](./changes.patch)
- [最终主截图记录](../../远征/shots/visual_fixes_20261027/release_review/capture_manifest.json)
- [专项截图目录](../../远征/shots/visual_fixes_20261027/acceptance_final)
- [新增专项验收](../../远征/tools/VerifyVisualPolish.gd)

实施前源码位于 `reports/visual_fixes_20261026/before/`。修改基于当前工作区，保留之前已有的玩法与素材工作。
"""
(OUT/"README.md").write_text(text,encoding="utf-8")
print(json.dumps({"report":str(OUT/"README.md"),"changed_sources":len(changed),"main_captures":len(list(AFTER.glob('*.png')))},ensure_ascii=False))
