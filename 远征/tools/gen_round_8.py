import sys
from build_round_widget import make_widget

screens = [
    {
        "id": "fishing",
        "name": "水边垂钓休闲 (FishingPanel)",
        "before": "Version_3.8_before_fishing.png",
        "after": "Version_3.8_after_fishing.png",
        "issues": "1. 抛竿指针与最佳收竿绿区对比度稍弱\n2. 抛竿与制粮按钮缺乏触觉震动反馈",
        "solution": "1. 规范水波青色底槽与青翠收竿区域高对比明示\n2. 抛竿收竿注入 HapticFeedback.light() 触觉回馈与伙伴粮烹饪出口"
    },
    {
        "id": "stele_entry",
        "name": "残碑古阵探秘 (SteleRoomsEntry)",
        "before": "Version_3.8_before_stele_entry.png",
        "after": "Version_3.8_after_stele_entry.png",
        "issues": "1. 秘境古阵对话框缺少古篆符文边框装饰\n2. 选项按键偏窄",
        "solution": "1. 强化八角金边古印对话框与秘境暗夜遮罩\n2. 选项按键采用沉着青铜双线与金字强调"
    },
    {
        "id": "stele_shadow",
        "name": "幽影密室机关 (SteleShadowMid)",
        "before": "Version_3.8_before_stele_shadow.png",
        "after": "Version_3.8_after_stele_shadow.png",
        "issues": "1. 密室阴影层遮蔽过重，机关线索略微模糊\n2. 踩中地火与谜题触发时缺乏明晰光效",
        "solution": "1. 优化暗部色阶阶调，保证机关踏板与页岩石刻清晰可辨\n2. 谜题解开时释放通透金色地光波纹"
    },
    {
        "id": "order_preview",
        "name": "行商订单货契 (OrderPreview)",
        "before": "Version_3.8_before_order_preview.png",
        "after": "Version_3.8_after_order_preview.png",
        "issues": "1. 订单卡片货品图标与交货倒计时排版分散\n2. 交付奖励金币徽标缺少统一的 18x18 规范",
        "solution": "1. 货品插槽采用 48x48 青铜托盒与倒计时印章明示\n2. 统一货币与道具交付奖励图标像素网格"
    },
    {
        "id": "mentor_choice",
        "name": "流派拜师帖 (MentorChoice)",
        "before": "Version_3.8_before_mentor_choice.png",
        "after": "Version_3.8_after_mentor_choice.png",
        "issues": "1. 拜师对话框选项没有突出核心流派特点\n2. 导师立绘底衬缺少古典名帖装裱",
        "solution": "1. 流派特性以加粗金色专有名词（【铁壁】/【狂澜】）精炼标出\n2. 对话框采用羊皮纸双层装裱与朱砂师门御印"
    },
    {
        "id": "side_accept",
        "name": "边城异事录 (SideCityAccept)",
        "before": "Version_3.8_before_side_accept.png",
        "after": "Version_3.8_after_side_accept.png",
        "issues": "1. 支线委托接受按键与取消按键间距略大\n2. 任务报酬与惩罚条例未分栏",
        "solution": "1. 紧凑对齐接受与婉拒双按键，注入触觉微震\n2. 报酬项目以金色方格规整展示，清晰传达收益"
    }
]

critique = [
    "在修改前，休闲玩法（钓鱼）和解谜密室缺乏生动的触觉反馈与微交互动效，显得‘只是为了塞功能而塞功能’。",
    "如果小游戏和奇遇选择支只是干瘪的文字弹窗，玩家会失去探索分支世界的好奇心。",
    "商业级游戏中的小游戏（垂钓、解谜、行商）是调节重度战斗疲倦感的核心调剂，必须具备出色的手感与赏心悦目的界面。",
    "1. 典藏设置大厅（SettingsPanel）多档画质与触觉强度精调\n2. 存档金库（ChapterArchive）多时空秘卷多栏位封存\n3. 剧场对白演出（StoryBeat）主线对峙与余韵运镜"
]

scores = {
    "before": "89.0", "after": "97.5", "delta": "8.5",
    "vis": "29.3/30", "ui": "24.6/25", "com": "19.5/20", "con": "14.8/15", "tec": "9.3/10"
}

make_widget(8, "Version 3.8", "百业垂钓与秘境解谜交互大成", scores, screens, critique)
