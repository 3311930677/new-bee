# -*- coding: utf-8 -*-
"""把 P0-P4 全部 Before|After 对比图汇总成一个可浏览的本地画廊。
生成：shots/v4_gallery/{thumbs,big}/*.webp + manifest.json
不改动任何原图。
"""
import os, json
from PIL import Image

ROOT = r"D:/new bee/远征"
OUT = os.path.join(ROOT, "shots/v4_gallery")
THUMB_W = 660
BIG_Q = 92
THUMB_Q = 80

GROUPS = [
    ("P0", "P0 · 阻塞级缺陷清零（12 项）", "shots/v4_p0/compare", [
        ("cmp_D1_storybeat_intro.png",  "D1 · 剧情幕（第一幕）", "正文框不再溢出、底部提示从黑边下移出来"),
        ("cmp_D1_storybeat_outro.png",  "D1 · 剧情幕（第二幕）", "同上，第二幕同规格复核"),
        ("cmp_D2_login.png",            "D2 · 登录页",           "从表单回退版恢复成参考稿的插画版"),
        ("cmp_D3_oath.png",             "D3 · 誓约面板",         "三张誓约卡按文字高度动态排版，描述不再压边框"),
        ("cmp_D4_gacha.png",            "D4 · 唤灵阁",           "标题在牌匾内居中，移除重叠的半透明横幅"),
        ("cmp_D6_D15_home.png",         "D6 + D15 · 主城顶栏与头像", "货币胶囊加宽并缩写大数；左上头像不再显示罗盘"),
        ("cmp_D7_map_hud.png",          "D7 · 地图 HUD 动作键",  "图标加亮金衬底，对比度 > 6.5:1，0 态不再黑成一团"),
        ("cmp_D9_deploy.png",           "D9 · 出征说明",         "PC 键盘提示改为触屏手势文案"),
        ("cmp_D11_shop.png",            "D11 · 商店（字距）",    "手工空格改成 FontVariation 真字距"),
        ("cmp_D11_arena.png",           "D11 · 竞技场（字距）",  "同上"),
        ("cmp_D11_journey.png",         "D11 · 远征（字距）",    "同上"),
        ("cmp_D13_currency_gold.png",   "D13 · 货币详情（金币）", "正文按标点断行，底部「可以用于」不再被裁"),
        ("cmp_D13_currency_expedition.png", "D13 · 货币详情（远征）", "同上"),
        ("cmp_D13_currency_soul.png",   "D13 · 货币详情（魂）",  "同上"),
        ("cmp_D13_currency_honor.png",  "D13 · 货币详情（荣誉）", "同上"),
        ("cmp_D14_stele_resonance.png", "D14 · 碑林回响·共鸣导槽", "1:1 平铺 + 提亮，不再是两条黑条"),
        ("cmp_D17_title_lore_ck.png",   "D17 · 称号「朔风听刃」", "描述职业由「刺客」改正为「枪骑」"),
    ]),
    ("P1", "P1 · 视觉底座与组件层", "shots/v4_p1/comparisons", [
        ("cmp_s01_loading.png",         "加载页",   "统一玄漆鎏金底与进度条"),
        ("cmp_s02_title.png",           "标题页",   "标题牌匾与按钮统一"),
        ("cmp_s03_login.png",           "登录页",   "按钮与输入框统一描金"),
        ("cmp_s04_createrole.png",      "创角页",   "职业卡与信息区统一"),
        ("cmp_s05_home.png",            "主城营地", "顶栏 / 底部导航 / 面板统一"),
        ("cmp_s08_currency_gold.png",   "货币详情", "卡片排版与字号阶梯统一"),
    ]),
    ("P2", "P2 · 核心主循环 10 屏", "shots/v4_p2/comparisons", [
        ("cmp_s07_bag.png",             "背包",         "网格与详情区重排"),
        ("cmp_s07_mail.png",            "邮件",         "列表与正文统一"),
        ("cmp_s07_quests.png",          "任务",         "章节 / 条目层级重做"),
        ("cmp_s07_worlds.png",          "世界舆图",     "节点与连线重绘"),
        ("cmp_s09_map_broken_slope.png","探索地图 · 断坡", "HUD 与场景构件"),
        ("cmp_s09_map_lorin_wilds.png", "探索地图 · 洛林荒野", "HUD 与场景构件"),
        ("cmp_s10_battle_start.png",    "战斗开场",     "单位站位与指令区"),
        ("cmp_s13_settlement_lose.png", "结算 · 失败",  "结算卡与图标"),
        ("cmp_s13_settlement_win.png",  "结算 · 胜利",  "结算卡与图标"),
    ]),
    ("P3", "P3 · 二级养成 / 玩法 / 社交", "shots/v4_p3/comparisons", [
        ("cmp_s07_growth.png",          "角色养成",   "主面板重排"),
        ("cmp_s07_growth_equip.png",    "装备",       "槽位与属性对比"),
        ("cmp_s07_growth_skill.png",    "技能",       "技能树节点"),
        ("cmp_s07_growth_talent.png",   "天赋",       "天赋盘"),
        ("cmp_s07_growth_pet.png",      "宠物",       "宠物卡"),
        ("cmp_s07_growth_mount.png",    "坐骑",       "坐骑卡"),
        ("cmp_s07_growth_title.png",    "称号",       "称号列表"),
        ("cmp_s07_shop.png",            "商店",       "货架与购买区"),
        ("cmp_s07_gacha.png",           "唤灵阁",     "召唤区与结果"),
        ("cmp_s07_arena.png",           "竞技场",     "对手列表与排名"),
        ("cmp_s07_contract.png",        "悬赏契约",   "契约卡"),
        ("cmp_s07_curio.png",           "珍宝图鉴",   "图鉴格"),
        ("cmp_s07_journal.png",         "手札秘闻",   "条目与正文"),
        ("cmp_s07_companion.png",       "伙伴小聚",   "伙伴卡"),
        ("cmp_s07_gathering.png",       "采集",       "采集点与产出"),
        ("cmp_s07_journey.png",         "远征",       "路线与队伍"),
        ("cmp_s07_oath.png",            "誓约",       "誓约卡"),
        ("cmp_s07_deploy.png",          "出征",       "步骤与阵容"),
        ("cmp_s07_activities.png",      "活动中心",   "活动入口"),
        ("cmp_s07_archery.png",         "射艺",       "靶场界面"),
        ("cmp_s07_exchange.png",        "交易所",     "挂单列表"),
        ("cmp_s07_fishing_salt.png",    "钓鱼 · 盐湖", "钓场界面"),
        ("cmp_s07_relic_hunt.png",      "遗物寻踪",   "线索与进度"),
        ("cmp_s07_trade_city.png",      "贸易城",     "商路与货价"),
        ("cmp_s07_avatar.png",          "头像",       "头像框与选择"),
        ("cmp_s07_settings.png",        "设置",       "分组与开关"),
    ]),
    ("P4", "P4 · 18 张探索地图地貌", "shots/v4_p4/comparisons", [
        ("cmp_s09_map_lorin_wilds.png",     "洛林荒野", ""),
        ("cmp_s09_map_maple_road.png",      "枫道", ""),
        ("cmp_s09_map_broken_slope.png",    "断坡", ""),
        ("cmp_s09_map_old_salt_road.png",   "旧盐道", ""),
        ("cmp_s09_map_red_sand_route.png",  "红沙道", ""),
        ("cmp_s09_map_rift_mine_road.png",  "裂矿道", ""),
        ("cmp_s09_map_rift_mine_vault.png", "裂矿窟", ""),
        ("cmp_s09_map_shenyuan_port.png",   "深源港", ""),
        ("cmp_s09_map_tidal_gate.png",      "潮门", ""),
        ("cmp_s09_map_tideflat.png",        "潮滩", ""),
        ("cmp_s09_map_frost_pass.png",      "霜关", ""),
        ("cmp_s09_map_frost_boardwalk.png", "霜桥", ""),
        ("cmp_s09_map_frost_post.png",      "霜驿", ""),
        ("cmp_s09_map_stele_entry.png",     "碑林入口", ""),
        ("cmp_s09_map_stele_cavern.png",    "碑窟", ""),
        ("cmp_s09_map_stele_core.png",      "碑心", ""),
        ("cmp_s09_map_stele_resonance.png", "碑林回响", "三声部导光石槽 1:1 渲染"),
        ("cmp_s09_map_abyss_ring.png",      "深渊环", ""),
    ]),
]

os.makedirs(os.path.join(OUT, "thumbs"), exist_ok=True)
os.makedirs(os.path.join(OUT, "big"), exist_ok=True)

manifest = []
missing = []
for key, title, rel, items in GROUPS:
    for fname, label, note in items:
        src = os.path.join(ROOT, rel, fname)
        if not os.path.exists(src):
            missing.append(src)
            continue
        slug = "%s_%s" % (key.lower(), fname[:-4])
        im = Image.open(src).convert("RGB")
        w, h = im.size
        big = os.path.join(OUT, "big", slug + ".webp")
        im.save(big, "WEBP", quality=BIG_Q, method=6)
        tw = THUMB_W
        th = max(1, round(h * tw / w))
        im.resize((tw, th), Image.LANCZOS).save(
            os.path.join(OUT, "thumbs", slug + ".webp"), "WEBP", quality=THUMB_Q, method=6)
        manifest.append({"p": key, "t": title, "label": label, "note": note,
                         "slug": slug, "w": w, "h": h})

with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=1)

tot = sum(os.path.getsize(os.path.join(OUT, "big", m["slug"] + ".webp")) for m in manifest)
print("images:", len(manifest), "missing:", len(missing))
print("big total MB:", round(tot / 1048576, 1))
for m in missing:
    print("MISSING", m)
