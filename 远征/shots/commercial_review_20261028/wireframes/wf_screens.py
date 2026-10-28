"""逐屏绘制重构线框 + 与实拍并排对照图。运行：python wf_screens.py"""
import math
import os
from wf_lib import *

HERE = os.path.dirname(os.path.abspath(__file__))
SHOTS = os.path.dirname(HERE)
OUT = HERE


def home():
    w = WF((30, 34, 58))
    w.stage(0, 0, W, H, "", (40, 48, 86), (34, 30, 44))
    w.text(240, 300, "主城夜景插画（保留现有 home_bg）", 14, (200, 200, 230, 150), "bold", anchor="mm")
    # 1 玩家卡
    w.panel(8, 8, 232, 74, "glass", 8)
    w.circle(46, 45, 30, "职业头像", "face", lsize=11)
    w.d.arc([12, 11, 80, 79], 135, 135 + 270 * 0.62, fill=JADE, width=4)
    w.d.rounded_rectangle([30, 68, 62, 84], 6, fill=RED, outline=BGOLD)
    w.text(46, 76, "35", 12, CREAM, "bold", anchor="mm")
    w.text(86, 16, "沈舟", 17, CREAM, "serif")
    w.text(86, 40, "破军 · 战士", 13, MUTED)
    w.text(86, 58, "战力 12,480", 14, BGOLD, "bold")
    w.tag(1, 14, 14)
    # 2 货币
    x = 250
    for lab in ["金 12.8万 +", "晶 860 +"]:
        w.d.rounded_rectangle([x, 12, x + 106, 36], 12, fill=(10, 8, 12, 220), outline=(201, 151, 63, 180))
        w.text(x + 53, 24, lab, 13, CREAM, "bold", anchor="mm")
        x += 112
    w.d.rounded_rectangle([250, 44, 356, 68], 12, fill=(10, 8, 12, 220), outline=(201, 151, 63, 180))
    w.text(303, 56, "荣誉 1240", 13, CREAM, "bold", anchor="mm")
    w.circle(380, 56, 13, "≡", "dark", lsize=14)
    w.text(400, 56, "菜单/设置", 11, MUTED, anchor="lm")
    w.tag(2, 470, 14)
    # 3 右侧功能栏
    for i, (nm, dot) in enumerate([("邮件", True), ("背包", False), ("小聚", True), ("公告", False)]):
        cy = 120 + i * 66
        w.circle(446, cy, 22, nm, "face", lsize=12)
        if dot:
            w.dot(462, cy - 18)
    w.tag(3, 470, 96)
    # 4 左侧活动/日常
    w.panel(8, 98, 132, 64, "glass", 6)
    w.text(16, 106, "限时 · 风雪祭典", 13, BGOLD, "bold")
    w.text(16, 128, "剩余 2天03时", 12, MUTED)
    w.dot(132, 104)
    w.panel(8, 170, 132, 44, "glass", 6)
    w.text(16, 176, "每日活跃 60/100", 12, CREAM, "bold")
    w.bar(16, 198, 112, 8, 0.6, BGOLD)
    w.tag(4, 14, 92)
    # 5 主角+宠物放大
    w.figure(226, 590, 120, "主角 ×1.4", (190, 80, 70))
    w.figure(292, 600, 54, "宠物", (110, 170, 140))
    w.tag(5, 300, 470)
    # 6 主线条
    w.panel(16, 620, 448, 52, "glass", 8)
    w.circle(44, 646, 18, "主", "red", lsize=13)
    w.text(70, 628, "主线 · 归路仍在", 15, CREAM, "serif")
    w.text(70, 650, "三城可回访 · 推荐战力 11,000", 12, MUTED)
    w.btn(380, 630, 74, 32, "前往", "primary", size=15)
    w.tag(6, 20, 616)
    # 7 底部导航
    w.d.rectangle([0, 700, W, H], fill=(16, 13, 20, 245))
    w.d.line([(0, 700), (W, 700)], fill=GOLD, width=2)
    for i, (nm, dot) in enumerate([("角色", True), ("伙伴", False), (None, False), ("任务", True), ("活动", False)]):
        cx = 48 + i * 96
        if nm is None:
            w.circle(cx, 728, 46, "出征", "red", lsize=22)
            continue
        w.circle(cx, 736, 24, None, "face")
        w.text(cx, 736, nm[0], 16, BGOLD, "serif", anchor="mm")
        w.text(cx, 772, nm, 13, CREAM, "bold", anchor="ma")
        if dot:
            w.dot(cx + 18, 716)
    w.tag(7, 12, 712)
    return w


def character():
    w = WF()
    w.topbar("角色", ["战力 12,480"])
    w.stage(0, 57, W, 343, "", (44, 50, 78), (26, 22, 32))
    w.text(240, 376, "背景 E-02 成长台", 11, (200, 200, 230, 140), anchor="mm")
    w.d.ellipse([150, 330, 330, 372], fill=(201, 151, 63, 60), outline=GOLD)
    w.figure(240, 352, 210, "职业立绘 / 像素放大", (190, 80, 70))
    w.tag(1, 240, 120)
    names_l = ["兵刃", "铠甲", "宝饰"]
    names_r = ["灵宠", "坐骑", "称号"]
    rars = ["史诗", "稀有", "精良", "传说", "稀有", "普通"]
    for i in range(3):
        w.slot(14, 90 + i * 84, 66, rars[i], names_l[i], "+12")
        w.slot(400, 90 + i * 84, 66, rars[3 + i], names_r[i], ["Lv60", "烈焰", "初出"][i])
    w.dot(76, 94)
    w.tag(2, 14, 84)
    w.panel(110, 66, 260, 30, "glass", 6)
    w.text(240, 81, "破军 · Lv.35   ▲ 战力 12,480", 14, BGOLD, "bold", anchor="mm")
    # 属性条
    w.panel(12, 384, 456, 92, "face", 6)
    stats = [("生命", "2410"), ("攻击", "272"), ("防御", "88"), ("暴击", "10.4%"), ("速度", "1.10"), ("等级", "35")]
    for i, (k, v) in enumerate(stats):
        x = 28 + (i % 3) * 148
        y = 396 + (i // 3) * 38
        w.text(x, y, k, 13, MUTED)
        w.text(x + 120, y, v, 16, CREAM, "bold", anchor="ra")
    w.text(456, 456, "全部属性 ›", 12, BGOLD, anchor="ra")
    w.tag(3, 18, 380)
    # 图标页签
    w.d.rectangle([0, 488, W, 560], fill=(16, 13, 20))
    for i, (nm, dot) in enumerate([("装备", True), ("天赋", True), ("技能", False), ("灵宠", False), ("坐骑", False), ("称号", False)]):
        cx = 40 + i * 80
        active = i == 0
        w.circle(cx, 514, 20, None, "gold" if active else "face")
        w.text(cx, 514, nm[0], 15, INK if active else BGOLD, "serif", anchor="mm")
        w.text(cx, 540, nm, 12, BGOLD if active else MUTED, "bold", anchor="ma")
        if dot:
            w.dot(cx + 16, 496)
    w.tag(4, 12, 492)
    # 当前页内容：装备列表/强化
    w.panel(12, 572, 456, 140, "face", 6)
    w.slot(26, 588, 64, "史诗", "兵刃", "+12")
    w.text(104, 588, "生铁大剑 +12", 17, RAR["史诗"], "serif")
    w.text(104, 614, "攻击 +186   暴击 +3.2%", 13, CREAM)
    w.text(104, 636, "宝石 ◆◆◇   精炼 词条 2/3", 13, MUTED)
    w.text(104, 664, "强化石 99/1   金币 12.8万/150   成功率 100%", 12, JADE)
    w.tag(5, 18, 576)
    w.btn(12, 728, 140, 56, "一键强化", "secondary")
    w.btn(166, 728, 140, 56, "宝石镶嵌", "secondary")
    w.btn(320, 728, 148, 56, "强化", "primary", "+12 → +13")
    w.tag(6, 18, 722)
    return w


def talent():
    w = WF()
    w.topbar("天赋", ["可用 7 点", "重置"])
    w.tabs(64, ["狂战", "坚壁", "迅捷"], 0, dots=(0,))
    w.stage(0, 112, W, 520, "", (30, 30, 52), (20, 18, 28))
    w.text(20, 612, "背景：暗纹星图（D-02 节点图标）· 路径可上下滑动", 11, (200, 200, 230, 140))
    names = ["锐利", "破甲", "嗜血", "猛进", "怒意", "裂伤", "绝杀"]
    pts = []
    for i, nm in enumerate(names):
        x = [190, 290][i % 2] if i < 6 else 240
        y = 160 + i * 66
        pts.append((x, y, nm, i))
    for a, b in zip(pts, pts[1:]):
        lit = a[3] < 1
        w.d.line([(a[0], a[1]), (b[0], b[1])], fill=BGOLD if lit else (80, 70, 60), width=4 if lit else 2)
    for x, y, nm, i in pts:
        st = "点满" if i == 0 else "可点" if i == 1 else "锁"
        cap = i == 6
        r = 30 if cap else 24
        kind = {"点满": "gold", "可点": "face", "锁": "dark"}[st]
        w.circle(x, y, r, None, kind)
        w.text(x, y, "★" if cap else "◆", 16, INK if kind == "gold" else (BGOLD if st == "可点" else (90, 80, 70)), "bold", anchor="mm")
        if st == "可点":
            w.d.ellipse([x - r - 5, y - r - 5, x + r + 5, y + r + 5], outline=(85, 216, 168, 220), width=2)
        side = -1 if x < 240 else 1
        tx = x + side * (r + 12)
        anchor = "lm" if side > 0 else "rm"
        if cap:
            side, tx, anchor = 1, x + r + 12, "lm"
        lv = {"点满": "3/3", "可点": "0/3", "锁": "需本系 %d 点" % (i * 3)}[st]
        w.text(tx, y - 9, "第%d阶 · %s" % (i + 1, nm), 14, CREAM if st != "锁" else MUTED, "bold", anchor=anchor)
        w.text(tx, y + 11, lv, 12, JADE if st == "可点" else MUTED, anchor=anchor)
    w.tag(1, 230, 128)
    w.text(240, 600, "… 第 8–10 阶（狂澜 / 战意 / 破军之势）", 12, MUTED, anchor="mm")
    w.panel(12, 640, 456, 76, "face", 6)
    w.circle(46, 678, 24, "◆", "face", lsize=16)
    w.text(82, 650, "第2阶 · 破甲  0/3", 16, BGOLD, "serif")
    w.text(82, 674, "每点：普攻削减目标防御 +3%", 13, CREAM)
    w.text(82, 694, "加满后解锁 第3阶 · 嗜血", 12, JADE)
    w.tag(2, 18, 644)
    w.btn(12, 728, 210, 56, "重置天赋", "secondary", "每 5 级免费 1 次")
    w.btn(236, 728, 232, 56, "加点", "primary", "剩余 7 点")
    w.tag(3, 18, 722)
    return w


def bag():
    w = WF()
    w.topbar("背包", ["金 12.8万", "128/200"])
    w.tabs(64, ["全部", "装备", "材料", "消耗", "珍品"], 0, dots=(3,))
    w.text(20, 116, "排序：品质 ▼", 13, MUTED)
    w.text(460, 116, "一键出售 · 分解", 13, BGOLD, anchor="ra")
    rars = list(RAR)
    s, gap = 80, 10
    for i in range(30):
        r, c = divmod(i, 5)
        x = 20 + c * (s + gap)
        y = 142 + r * (s + gap)
        if y + s > 700:
            break
        rr = rars[(i * 7 + r) % 5]
        w.slot(x, y, s, rr, ["剑", "甲", "石", "药", "符", "卷"][(i + r) % 6], "x" + str((i * 13) % 99 + 1))
        if i == 0:
            w.d.rectangle([x - 3, y - 3, x + s + 3, y + s + 3], outline=BGOLD, width=3)
        if i in (2, 9):
            w.text(x + 6, y + 4, "新", 11, (255, 120, 100), "bold")
    w.tag(1, 14, 140)
    # 底部详情抽屉
    w.panel(0, 560, W, 240, "face", 14)
    w.handle(560)
    w.slot(20, 586, 72, "史诗", "剑")
    w.text(106, 584, "生铁大剑", 20, RAR["史诗"], "serif")
    w.text(106, 614, "史诗 · 兵刃 · 破军专属", 13, MUTED)
    w.text(106, 636, "攻击 +186   暴击 +3.2%   ▲ 比当前 +24", 13, CREAM)
    w.d.rectangle([20, 670, 460, 700], fill=PAPER)
    w.text(30, 676, "「采自裂谷的陨铁，至今仍带余温。」", 13, INK)
    w.btn(20, 718, 128, 52, "出售", "ghost")
    w.btn(160, 718, 128, 52, "分解", "secondary")
    w.btn(300, 718, 160, 52, "装备", "primary")
    w.tag(2, 14, 566)
    return w


def battle():
    w = WF()
    w.stage(0, 0, W, 560, "", (70, 96, 60), (54, 74, 44))
    w.text(240, 96, "战场背景（保留）", 14, (230, 240, 210, 120), "bold", anchor="mm")
    # 顶栏
    w.panel(8, 8, 90, 40, "glass", 6)
    w.text(53, 28, "撤退", 15, CREAM, "bold", anchor="mm")
    w.panel(160, 8, 160, 40, "glass", 6)
    w.text(240, 20, "遭遇战 · 第 1/3 波", 13, BGOLD, "bold", anchor="mm")
    w.bar(178, 34, 124, 6, 0.33, BGOLD)
    w.panel(332, 8, 66, 40, "glass", 6)
    w.text(365, 28, "×2", 15, CREAM, "bold", anchor="mm")
    w.panel(404, 8, 68, 40, "glass", 6)
    w.text(438, 28, "自动", 15, JADE, "bold", anchor="mm")
    w.tag(1, 14, 54)
    # 单位
    w.figure(120, 380, 130, "主角", (190, 80, 70))
    w.figure(60, 440, 70, "伙伴", (110, 170, 140))
    pos = [(310, 280, 92), (410, 300, 92), (320, 420, 96), (420, 460, 80)]
    for i, (x, y, h) in enumerate(pos):
        w.figure(x, y, h, "敌" + str(i + 1), (150, 110, 90))
        w.bar(x - 36, y + 12, 72, 7, [0.48, 1, 1, 0.7][i], (220, 70, 56))
        if i == 0:
            w.d.ellipse([x - 44, y - 12, x + 44, y + 16], outline=(255, 214, 64), width=3)
            w.text(x, y + 22, "目标", 12, (255, 214, 64), "bold", anchor="ma")
    w.text(310, 150, "-1,284", 28, (255, 230, 90), "bold", anchor="mm")
    w.d.text((310, 150), "-1,284", font=font(28, "bold"), fill=(255, 230, 90), anchor="mm", stroke_width=2, stroke_fill=(60, 20, 0))
    w.text(310, 176, "暴击!", 14, (255, 150, 60), "bold", anchor="mm")
    w.tag(2, 250, 140)
    w.text(240, 520, "点选敌人即锁定 · 血条贴身不遮挡（编队槽位）", 12, CREAM, "bold", anchor="mm")
    # 底部
    w.d.rectangle([0, 560, W, H], fill=(16, 13, 20))
    w.d.line([(0, 560), (W, 560)], fill=GOLD, width=2)
    w.circle(46, 610, 32, "头像", "face", lsize=12)
    w.text(88, 580, "破军 Lv.35", 14, CREAM, "bold")
    w.bar(88, 602, 200, 12, 0.92, (220, 70, 56))
    w.text(190, 601, "1490/1620", 10, CREAM, "bold", anchor="ma")
    w.bar(88, 620, 200, 8, 0.2, (90, 160, 240))
    w.text(296, 616, "能量 20", 11, (140, 190, 250), "bold")
    w.circle(300, 590, 14, "伙", "face", lsize=11)
    w.tag(3, 14, 572)
    for i, (nm, cd) in enumerate([("裂山", 0), ("破阵", 0), ("回风斩", 0.6), ("战吼", 1), ("断罪", 0.3)]):
        cx = 36 + i * 62
        w.circle(cx, 704, 27, "图标" if cd == 0 else None, "face", lsize=11)
        w.text(cx, 736, nm, 12, CREAM, "bold", anchor="ma")
        if cd > 0:
            w.d.pieslice([cx - 27, 677, cx + 27, 731], -90, -90 + 360 * cd, fill=(0, 0, 0, 160))
            w.text(cx, 704, "3s" if cd < 1 else "缺能", 12, CREAM, "bold", anchor="mm")
    w.tag(4, 14, 666)
    w.circle(336, 652, 20, "药", "face", lsize=12)
    w.text(352, 664, "3", 12, CREAM, "bold")
    w.circle(336, 760, 20, "换", "face", lsize=12)
    w.text(336, 784, "换目标", 11, MUTED, anchor="ma")
    w.circle(420, 706, 52, "攻击", "red", lsize=24)
    w.tag(5, 466, 640)
    return w


def settlement():
    w = WF((14, 12, 20))
    for k in range(18):
        a = math.radians(k * 20)
        w.d.polygon([(240, 150), (240 + 400 * math.cos(a), 150 + 400 * math.sin(a)), (240 + 400 * math.cos(a + 0.12), 150 + 400 * math.sin(a + 0.12))], fill=(242, 199, 106, 16))
    w.d.rectangle([90, 104, 390, 190], fill=(120, 30, 20), outline=BGOLD, width=2)
    w.text(240, 146, "胜  利", 54, BGOLD, "serif", anchor="mm")
    for i, lit in enumerate([1, 1, 0]):
        cx = 180 + i * 60
        w.text(cx, 64, "★", 46 if i == 1 else 38, BGOLD if lit else (70, 60, 50), "bold", anchor="mm")
    w.tag(1, 70, 110)
    w.text(240, 208, "首领 · 裂谷兽王   用时 63.4 秒", 14, CREAM, anchor="ma")
    w.panel(16, 240, 448, 176, "face", 8)
    w.text(32, 252, "战利品", 17, BGOLD, "serif")
    rr = ["传说", "史诗", "稀有", "稀有", "精良", "精良", "普通", "普通", "普通", "普通"]
    for i, r in enumerate(rr):
        c, rw = i % 5, i // 5
        w.slot(32 + c * 84, 282 + rw * 64, 58, r, ["灵", "剑", "石", "卷", "药", "金", "铁", "木", "皮", "羽"][i], "x" + str(i + 1))
    w.tag(2, 22, 236)
    w.panel(16, 428, 448, 70, "face", 8)
    w.text(32, 438, "Lv.35", 16, CREAM, "bold")
    w.bar(96, 444, 280, 12, 0.78, BGOLD)
    w.text(382, 440, "+1,280 经验", 13, BGOLD, "bold")
    w.text(32, 468, "伙伴 青鸾 +320 亲密   远征点 +40", 13, JADE)
    w.tag(3, 22, 424)
    w.panel(16, 510, 448, 100, "groove", 8)
    for i, (k, v) in enumerate([("最高单击", "23,456"), ("我方输出", "45.7万"), ("承受伤害", "23,456"), ("剩余生命", "41%")]):
        x = 32 + (i % 2) * 220
        y = 524 + (i // 2) * 38
        w.text(x, y, k, 13, MUTED)
        w.text(x + 196, y, v, 16, CREAM, "bold", anchor="ra")
    w.text(240, 590, "MVP · 破军 输出占比 72%", 12, BGOLD, anchor="ma")
    w.tag(4, 22, 506)
    w.panel(16, 622, 448, 70, "sel", 8, border=BGOLD)
    w.slot(30, 632, 50, "传说", "箱")
    w.text(96, 636, "三星通关奖励 · 鎏金宝箱", 15, BGOLD, "serif")
    w.text(96, 662, "点击开启（开箱动画 + 物品飞入背包）", 12, CREAM)
    w.dot(452, 630)
    w.tag(6, 22, 618)
    w.btn(16, 712, 140, 64, "再战", "secondary", "体力 -6")
    w.btn(170, 712, 294, 64, "继续征途", "primary")
    w.tag(5, 22, 706)
    return w


def gacha():
    w = WF((20, 14, 30))
    w.stage(0, 0, W, H, "", (52, 30, 72), (18, 12, 26))
    w.topbar("唤灵阁", ["魂晶 860 +"])
    w.panel(110, 66, 260, 36, "glass", 6)
    w.text(240, 84, "灵宠召唤 · 本期主推", 15, BGOLD, "serif", anchor="mm")
    w.d.ellipse([90, 520, 390, 600], fill=(201, 151, 63, 60), outline=BGOLD, width=2)
    w.d.ellipse([130, 534, 350, 586], outline=(242, 199, 106, 120), width=1)
    w.figure(240, 560, 330, "主推灵宠立绘（大）", (110, 170, 220))
    w.tag(1, 240, 200)
    w.panel(16, 118, 132, 106, "glass", 8)
    w.text(28, 128, "金 · 主推灵宠", 15, RAR["传说"], "serif")
    w.text(28, 152, "当期主推宠物名", 12, CREAM)
    w.text(28, 172, "金 2% · 紫 8%", 12, MUTED)
    w.text(28, 194, "查看详情 ›", 12, BGOLD)
    w.tag(2, 22, 114)
    w.d.ellipse([372, 120, 460, 208], outline=(70, 50, 80), width=8)
    w.d.arc([372, 120, 460, 208], -90, -90 + 360 * 0.62, fill=BGOLD, width=8)
    w.text(416, 156, "37/60", 15, CREAM, "bold", anchor="mm")
    w.text(416, 176, "保底", 11, MUTED, anchor="mm")
    w.tag(3, 466, 114)
    w.text(240, 618, "概率公示 · 召唤记录", 12, MUTED, anchor="ma")
    w.btn(16, 650, 210, 76, "召唤一次", "secondary", "今日免费 / 魂晶 ×80")
    w.btn(240, 650, 224, 76, "召唤十次", "primary", "魂晶 ×720 · 必出紫")
    w.text(240, 748, "每日免费 1 次 · 18:42:10 后刷新", 13, JADE, anchor="ma")
    w.tag(4, 22, 644)
    return w


def dialog():
    w = WF()
    w.stage(0, 0, W, H, "", (40, 48, 70), (30, 28, 36))
    w.text(240, 260, "地图（压暗 40%）", 14, (220, 220, 240, 120), "bold", anchor="mm")
    w.d.rectangle([0, 0, W, H], fill=(0, 0, 0, 90))
    # 半身像
    w.figure(120, 548, 300, "NPC 半身像", (170, 140, 110))
    w.tag(1, 60, 260)
    w.panel(8, 520, 464, 200, "face", 10)
    w.d.polygon([(26, 504), (170, 504), (186, 524), (170, 544), (26, 544)], fill=RED, outline=BGOLD)
    w.text(40, 524, "执事 · 闻叔", 16, CREAM, "serif", anchor="lm")
    w.tag(2, 196, 520)
    w.text(28, 560, "（示例台词）北门外的古道这几天不太平，", 16, CREAM)
    w.text(28, 588, "你若要出城，先去岳教头那里打个招呼。", 16, CREAM)
    w.text(452, 696, "▼", 14, BGOLD, "bold", anchor="ra")
    w.tag(3, 452, 676)
    # 选项
    opts = [("接取委托", "primary"), ("打听消息", "secondary"), ("离开", "ghost")]
    for i, (t, kind) in enumerate(opts):
        w.btn(240, 296 + i * 64, 224, 52, t, kind, size=15)
    w.tag(4, 470, 290)
    w.d.rectangle([0, 740, W, H], fill=(16, 13, 20))
    w.text(240, 770, "地图 HUD 收起；点击空白或 ▼ 推进", 12, MUTED, anchor="mm")
    return w


def map_hud():
    w = WF()
    w.stage(0, 0, W, H, "", (60, 82, 54), (46, 60, 40))
    w.text(240, 360, "地图（保留像素地图）", 14, (230, 240, 210, 120), "bold", anchor="mm")
    # 左上：区域+返回
    w.panel(8, 8, 178, 52, "glass", 8)
    w.text(20, 14, "林地 · 罗林荒野", 15, CREAM, "serif")
    w.text(20, 38, "推荐战力 9,800", 12, MUTED)
    w.tag(1, 196, 14)
    # 右上小地图
    w.panel(360, 8, 112, 112, "glass", 8)
    w.text(416, 64, "小地图", 12, MUTED, anchor="mm")
    w.circle(452, 136, 14, "全", "face", lsize=11)
    w.tag(2, 470, 8)
    # 任务追踪
    w.panel(8, 70, 200, 78, "glass", 6)
    w.text(18, 78, "主线 · 断路疑云", 13, BGOLD, "bold")
    w.text(18, 100, "· 读港务水痕  0/1", 12, CREAM)
    w.text(18, 120, "· 进入上闸", 12, MUTED)
    w.text(196, 78, "›", 14, BGOLD, "bold", anchor="ra")
    w.tag(3, 14, 156)
    # 出生点
    w.d.ellipse([200, 470, 280, 500], outline=(85, 216, 168), width=2)
    w.d.ellipse([214, 476, 266, 494], outline=(85, 216, 168, 140), width=1)
    w.figure(240, 486, 70, "主角", (190, 80, 70))
    w.d.rounded_rectangle([196, 402, 284, 420], 4, fill=(16, 13, 20, 200), outline=(201, 151, 63, 140))
    w.text(240, 411, "沈舟 Lv.35", 11, CREAM, "bold", anchor="mm")
    w.text(240, 512, "出生点改为地面传送纹，路牌移出 96px 外", 11, CREAM, "bold", anchor="ma")
    w.tag(4, 300, 470)
    # 提示条
    w.panel(60, 560, 360, 36, "glass", 18)
    w.text(240, 578, "先读港务水痕，再进上闸", 14, CREAM, "bold", anchor="mm")
    w.tag(5, 56, 556)
    # 摇杆
    w.d.ellipse([24, 640, 144, 760], fill=(0, 0, 0, 60), outline=(242, 199, 106, 100), width=2)
    w.d.ellipse([64, 680, 104, 720], fill=(242, 199, 106, 120))
    # 动作键
    w.circle(400, 700, 46, "交互", "red", lsize=20)
    for nm, (x, y), badge in [("骑乘", (300, 742), None), ("疾行", (320, 660), "CD"), ("药剂", (390, 616), "3")]:
        w.circle(x, y, 26, nm, "gold", lsize=12)
        if badge:
            w.d.rounded_rectangle([x + 10, y + 10, x + 34, y + 26], 6, fill=RED, outline=BGOLD)
            w.text(x + 22, y + 18, badge, 10, CREAM, "bold", anchor="mm")
    w.tag(6, 470, 600)
    for i, nm in enumerate(["背包", "营帐"]):
        w.circle(452, 182 + i * 54, 20, nm, "face", lsize=11)
    return w


def fishing():
    w = WF()
    w.stage(0, 0, W, H, "", (150, 190, 214), (38, 64, 90))
    w.text(240, 140, "钓点专属背景（寒霜：冰面裂口 / 港口：栈桥夜灯 / 盐湖 / 潮汐）", 12, (20, 30, 50), "bold", anchor="ma")
    w.topbar("霜关冰缘池", ["规则 ?"])
    w.d.line([(330, 260), (250, 470)], fill=(240, 240, 240), width=2)
    w.d.ellipse([240, 462, 262, 484], fill=(220, 60, 50), outline=CREAM, width=2)
    w.text(270, 476, "浮漂", 12, CREAM, "bold")
    # 鱼王日：鱼王鱼影 + 金色细描边（平日为普通鱼影，无描边）
    w.d.ellipse([186, 516, 314, 564], fill=(20, 30, 50, 120), outline=GOLD, width=2)
    w.text(250, 540, "鱼王鱼影", 12, CREAM, "bold", anchor="mm")
    w.tag(1, 230, 456)
    # 竖向张力计（鱼王日绿区收窄，顶上加"王"角标）
    w.panel(420, 220, 44, 330, "glass", 8)
    w.d.rectangle([432, 236, 452, 534], fill=(12, 10, 14))
    w.d.rectangle([432, 356, 452, 414], fill=(85, 216, 168, 200))
    w.d.rectangle([432, 236, 452, 270], fill=(220, 60, 50, 200))
    w.d.polygon([(426, 380), (434, 386), (426, 392)], fill=BGOLD)
    w.circle(442, 210, 12, "王", "gold", lsize=12)
    w.text(442, 560, "张力", 12, CREAM, "bold", anchor="ma")
    w.tag(2, 404, 214)
    # 底部信息栏：本钓点鱼 + 今日余竿 + 图鉴 + 鱼王提示（无钓竿、无鱼饵）
    w.panel(16, 596, 448, 84, "glass", 8)
    w.slot(28, 606, 60, "稀有", "鳟", badge="×5")
    w.text(100, 608, "霜鳍鳟", 15, CREAM, "bold")
    for i in range(3):
        x = 100 + i * 22
        w.d.ellipse([x, 634, x + 14, 648], fill=BGOLD if i < 2 else (60, 52, 44), outline=GOLD)
    w.text(172, 641, "今日余 2 竿", 12, MUTED, anchor="lm")
    w.text(452, 610, "图鉴 3/4", 13, BGOLD, "bold", anchor="ra")
    w.text(100, 660, "鱼王今日现身：冰缘出现长涟漪，霜鳍鱼王游过暗水", 12, BGOLD)
    w.tag(3, 22, 592)
    w.btn(16, 692, 160, 80, "鲜鱼制粮", "secondary", "1 换 1")
    w.btn(188, 692, 276, 80, "收竿", "primary", "浮标进入绿区时点击")
    w.tag(4, 22, 686)
    return w


SCREENS = [
    ("01_home", home, "s05_home.png", "主城：玩家卡 / 货币缩写 / 右侧功能栏 / 主线条 / 导航重排"),
    ("02_character", character, "s07_growth.png", "角色总览：立绘居中 + 六装备槽 + 图标页签原地切换"),
    ("03_talent", talent, "s07_growth_talent.png", "天赋：三系分页 + 十阶路径树（数据不变，只换表现）"),
    ("04_bag", bag, "s07_bag.png", "背包：5 列品质框网格 + 底部详情抽屉"),
    ("05_battle", battle, "s10_battle_start.png", "战斗：统一大比例 / 点选锁敌 / 技能图标冷却 / 大攻击键"),
    ("06_settlement", settlement, "s13_settlement_win.png", "结算：胜利仪式感 + 战利品优先 + 再战"),
    ("07_gacha", gacha, "s07_gacha.png", "唤灵阁：全屏祭坛 + 主推大立绘 + 保底环"),
    ("08_dialog", dialog, "extra/x01_dialog_npc_steward.png", "对话：统一底部对话框 + 半身像 + 选项堆叠"),
    ("09_map_hud", map_hud, "s09_map_lorin_wilds.png", "地图 HUD：追踪器 / 出生点 / 提示条 / 高亮动作键"),
    ("10_fishing", fishing, "s07_fishing_frost.png", "钓鱼：钓点专属背景 + 浮漂鱼影 + 竖向张力计（无钓竿、无鱼饵）"),
]

if __name__ == "__main__":
    for name, fn, before, title in SCREENS:
        wf = fn()
        p = os.path.join(OUT, "wf_" + name + ".png")
        wf.save(p)
        compare(os.path.join(SHOTS, before), p, os.path.join(OUT, "cmp_" + name + ".png"), title, "黄色数字 = 方案文档中的条目编号")
        print("ok", name)
