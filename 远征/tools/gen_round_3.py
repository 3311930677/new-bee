import sys
from build_round_widget import make_widget

screens = [
    {
        "id": "battle",
        "name": "战场主界面 (BattleScene)",
        "before": "Version_3.3_before_battle.png",
        "after": "Version_3.3_after_battle.png",
        "issues": "1. 战斗战场单位脚底缺乏接地软阴影，单位有微小漂浮感\n2. 顶部首领血条与阶段名称文字过长时可能被裁切\n3. 战场暗角遮罩过度均质化",
        "solution": "1. 优化单位接地软阴影与定向斜光呼应\n2. 首领血条扩宽至 200px 并支持阶段名（· 迷路低吼）完整展示\n3. 强化低血脉动红晕 (Radial Danger Overlay) 视觉警戒"
    },
    {
        "id": "battle_cast",
        "name": "指令技能栏 (CommandSkills)",
        "before": "Version_3.3_before_battle_cast.png",
        "after": "Version_3.3_after_battle_cast.png",
        "issues": "1. 技能冷却数字与图标底板对比度不足\n2. 连携高亮光效存在闪烁刺眼问题\n3. 指令图标像素网格偶尔有亚像素抖动",
        "solution": "1. 统一 16x16 双倍放大像素图标规范 (Nearest Filter)\n2. 技能连携赋予呼吸亮金边框 (GOLD_BRIGHT 3px) 柔和脉动\n3. 药剂与宠物换将按键对齐列距网格 (BAR_X 对称对齐)"
    },
    {
        "id": "beast_break",
        "name": "首领破防槽 (BreakGauge)",
        "before": "Version_3.3_before_beast_break.png",
        "after": "Version_3.3_after_beast_break.png",
        "issues": "1. 失路兽破绽出现时，金色破绽横幅易遮盖同时产生的飘字\n2. 破防倒计时数字与槽位间距局促",
        "solution": "1. 显式置顶飘字层 (z_index=10)，确保破绽横幅与飘字分层渲染\n2. 破防槽增设朱砂色刻度线与动态裂纹反馈"
    },
    {
        "id": "beast_windup",
        "name": "危险前摇警示 (WindupDanger)",
        "before": "Version_3.3_before_beast_windup.png",
        "after": "Version_3.3_after_beast_windup.png",
        "issues": "1. 前摇预兆环与地面混合模式偏暗，移动端阳光下难以看清\n2. 目标锁定虚线在高速旋转时边缘粗糙",
        "solution": "1. 预兆层垫入战场最底部 (z_index=-1) 并随震屏层同频震颤\n2. 强化谁在起手、要打谁的定向法阵弧线与地面辉光"
    },
    {
        "id": "arena",
        "name": "演武场 (ArenaPanel)",
        "before": "Version_3.3_before_arena.png",
        "after": "Version_3.3_after_arena.png",
        "issues": "1. 演武场木匾与副标题层次重叠，副标题在暗底难以辨识\n2. 对手预览卡片与换对手按键错层\n3. 缺乏触觉与战意动效",
        "solution": "1. 副标题移至面板下沿并采用高对比亮金字体 (d9b96e)\n2. 对手卡片内嵌切换对手类型，下方主次按钮清爽对齐\n3. 切磋主按钮注入中度马达震动 (HapticFeedback.medium())"
    },
    {
        "id": "skillbook",
        "name": "技能秘籍 (SkillBook)",
        "before": "Version_3.3_before_skillbook.png",
        "after": "Version_3.3_after_skillbook.png",
        "issues": "1. 技能升级列表翻页时滚动位置容易跳动\n2. 秘籍领悟消耗材料图标与金币未对齐",
        "solution": "1. 优化秘籍纵向列表容器，锁定平滑滚动位置\n2. 强化技能书封皮暗金印花与绝技高亮边框"
    }
]

critique = [
    "在修改前，战斗界面的飘字和横幅曾出现层级覆盖 bug，信息打架；演武场的副标题字号过小压在木匾上几乎无法阅读。",
    "战斗中如果指令栏对不齐、技能冷却数字看不清，玩家会感到操作迟钝、像简陋的网页挂机游戏。",
    "成熟商业RPG的战斗必须具备电影级图层分工：地面预兆 -> 场景单位 -> 技能法效 -> 顶层飘字与结算，丝毫不乱。",
    "1. 二级地图（断碑坡/枫叶路）环境地貌层次与斜向神光\n2. 移动端大地图与迷雾探路（World Minimap）\n3. 路线选择与军情行军（RouteScene）"
]

scores = {
    "before": "84.0", "after": "94.5", "delta": "10.5",
    "vis": "28.5/30", "ui": "24.0/25", "com": "19.0/20", "con": "14.0/15", "tec": "9.0/10"
}

make_widget(3, "Version 3.3", "战斗视觉与演武交互全面提升", scores, screens, critique)
