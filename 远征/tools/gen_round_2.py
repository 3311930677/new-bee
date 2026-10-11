import sys
from build_round_widget import make_widget

screens = [
    {
        "id": "home",
        "name": "主城枢纽 (GameHome)",
        "before": "Version_3.2_before_home.png",
        "after": "Version_3.2_after_home.png",
        "issues": "1. 顶部货币栏和状态栏缺少与底部操作栏的纵向张力\n2. 继续旅程按键缺乏高阶主操作的沉金双线描边\n3. 导航底托缺少古典螺钿暗花，与夜色背景略有生硬分离",
        "solution": "1. 强化四大货币微边框与翡翠夜晶经验槽对比度\n2. 英雄基座升级为烫金漆木八角托盘与正统宋体角色标题\n3. 注入触觉轻震与动效时长精准克制 (0.05s~0.18s)"
    },
    {
        "id": "equip",
        "name": "英雄装备 (EquipPanel)",
        "before": "Version_3.2_before_equip.png",
        "after": "Version_3.2_after_equip.png",
        "issues": "1. 六件套九宫格插槽缺乏高阶传世装备的暗金角线\n2. 强化/镶嵌/洗练工作台的数字对比度略弱，材料消耗图标缺少规整包装",
        "solution": "1. 装备槽位升级为青铜内凹八角暗金边框与呼吸悬停\n2. 增加高阶宝石孔宝石预览与属性增减双色明示"
    },
    {
        "id": "bag",
        "name": "行旅背包 (BagPanel)",
        "before": "Version_3.2_before_bag.png",
        "after": "Version_3.2_after_bag.png",
        "issues": "1. 物品网格滚动区域没有规整的物品格子内凹微阴影\n2. 右侧物品详情面板的对比标签缺少清晰的红绿双色差异化印戳\n3. 装备与卖出操作缺少触控弹性",
        "solution": "1. 背包物品槽位引入 5 列规整漆盒栅格与品质微边\n2. 详情栏属性增减强制对齐 ▲翡翠绿 与 ▼朱砂红 对比\n3. 所有背包操作按钮注入 HapticFeedback 轻触反馈"
    },
    {
        "id": "shop",
        "name": "物资铺 (ShopPanel)",
        "before": "Version_3.2_before_shop.png",
        "after": "Version_3.2_after_shop.png",
        "issues": "1. 物资铺货架卡片为单薄扁平纯色，商品图标周围缺少品质光晕\n2. 买入/卖出按钮为单调小方块，缺乏高级商业手游的雕花回弹\n3. 外框缺乏黑漆描金的商柜厚重感",
        "solution": "1. 外框升级为沉金黑漆柜台 (141118 + c29a5b 90%金边)，投射 16px 软阴影\n2. 买入与出售按钮分别匹配丹霞红与幽铜黑双色阶，支持触觉微震\n3. 顶部增加黄铜钱币小徽章与边城特惠明晰提示"
    },
    {
        "id": "quests",
        "name": "任务卷宗 (QuestPanel)",
        "before": "Version_3.2_before_quests.png",
        "after": "Version_3.2_after_quests.png",
        "issues": "1. 任务卡片世界事务按键略显突兀\n2. 主线传书与边城委托之间的分割线不够精致\n3. 任务追踪状态缺少明确的图章标识",
        "solution": "1. 统一官驿委任板质感，强化漆器木框与内衬羊皮纸层级\n2. 边城委托卡片采用微圆角金铜描线与单内容容器防压字设计\n3. 状态标签强化朱砂色进行中与金色奖励标示"
    },
    {
        "id": "avatar",
        "name": "旅人小像 (AvatarPanel)",
        "before": "Version_3.2_before_avatar.png",
        "after": "Version_3.2_after_avatar.png",
        "issues": "1. 头像选择列表网格排版偏紧凑，缺少当前选中头像的金色流光框\n2. 自选画像导入提示层级较低",
        "solution": "1. 头像展台升级为碧玉青铜双层装裱相框 (29423d + b79d68)\n2. 优化关闭与自选导入按钮的古典圆角排版"
    }
]

critique = [
    "在修改前，物资铺与背包等高频操作界面的按键缺乏物理触感反馈；商店面板边框单薄，缺乏商业手游该有的材质厚重感。",
    "玩家进入商店和背包如果看到纯色卡片和没有阴影的悬浮框，会本能地觉得是网页嵌套或简陋UI套件拼凑的。",
    "成熟商业RPG手游在每一个物品格、每一个交易按钮上都有清晰的下沉状态（Pressed）、音效与微触震，让收集和买卖充满成就感。",
    "1. 战斗界面（BattleScene）HP 血条与指令技能环形展开微交互\n2. 首领遭遇战（Boss Encounter）破防槽（Break Gauge）与蓄力警示光效\n3. 演武场（ArenaPanel）段位印章与对手匹配卡牌质感"
]

scores = {
    "before": "82.0", "after": "93.0", "delta": "11.0",
    "vis": "28.0/30", "ui": "23.5/25", "com": "18.5/20", "con": "14.0/15", "tec": "9.0/10"
}

make_widget(2, "Version 3.2", "核心枢纽与英雄系统深度升级", scores, screens, critique)
