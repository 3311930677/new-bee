import sys
from build_round_widget import make_widget

screens = [
    {
        "id": "growth",
        "name": "养成全景罗盘 (GrowthHub)",
        "before": "Version_3.5_before_growth.png",
        "after": "Version_3.5_after_growth.png",
        "issues": "1. 六大子系统切换导航栏当前激活页签高亮对比度弱\n2. 顶部立绘展台光影偏弱，灵宠与坐骑缺乏呼吸感",
        "solution": "1. 统一六大养成页签青铜雕花选框与金色高光指示\n2. 养成主副操作注入 HapticFeedback 轻触反馈与清脆金铁音效"
    },
    {
        "id": "talent",
        "name": "天赋星盘经络 (TalentPanel)",
        "before": "Version_3.5_before_talent.png",
        "after": "Version_3.5_after_talent.png",
        "issues": "1. 天赋连线暗线与亮线对比度不够锐利\n2. 点亮技能节点缺乏星宿脉冲微光",
        "solution": "1. 强化天赋经络星轨连线与朱砂封印印记\n2. 天赋点数分配数值高对比度排版与安全重置保护"
    },
    {
        "id": "forge_enhance",
        "name": "神兵强化工坊 (ForgeEnhance)",
        "before": "Version_3.5_before_forge_enhance.png",
        "after": "Version_3.5_after_forge_enhance.png",
        "issues": "1. 强化成功率与强化材料消耗排版略微局促\n2. 强化按键缺乏高亮沉金双线",
        "solution": "1. 强化材料槽统一八角铜框包装与数量色阶明示\n2. 强化突破按键增加金铁沉鸣音画同步反馈"
    },
    {
        "id": "forge_gem",
        "name": "宝石镶嵌工坊 (ForgeGem)",
        "before": "Version_3.5_before_forge_gem.png",
        "after": "Version_3.5_after_forge_gem.png",
        "issues": "1. 宝石孔插槽缺乏微光插拔指引\n2. 镶嵌费用说明对比度不足",
        "solution": "1. 宝石孔引入八角暗金槽与通透翡翠/幽夜紫辉光\n2. 镶嵌费用与拆卸零损耗明示，杜绝隐性扣费误解"
    },
    {
        "id": "pet_raise",
        "name": "灵宠御兽养成 (PetRaise)",
        "before": "Version_3.5_before_pet_raise.png",
        "after": "Version_3.5_after_pet_raise.png",
        "issues": "1. 灵宠星级显示（★）平淡，缺乏金色流星质感\n2. 灵宠突破与喂食按键缺乏明确层级区分",
        "solution": "1. 灵宠立绘强化脚底软阴影与呼吸微浮动\n2. 喂食与突破按键区分主操作（金漆）与次操作（幽铜）"
    },
    {
        "id": "mount",
        "name": "御灵坐骑结伴 (MountStables)",
        "before": "Version_3.5_before_mount.png",
        "after": "Version_3.5_after_mount.png",
        "issues": "1. 坐骑骑乘状态（当前骑乘/未激活）标识不够醒目\n2. 属性加成标签行距松散",
        "solution": "1. 当前骑乘坐骑增加【已御乘】朱砂玉牌标志\n2. 切换骑乘按钮与属性预览秩序化排版"
    }
]

critique = [
    "在修改前，养成系统的几个页面操作按键大多是单向缩小，缺少真实的弹簧回弹质感（Squash & Stretch）与马达微震。",
    "装备强化和灵宠突破是游戏最核心的数值成长反馈点，若缺少清脆的音画同步与品质金光，玩家的爽感会大打折扣。",
    "成熟手游在强化与进阶成功瞬间会有全屏光波与印章震落（Ceremony），将玩家的投入转化为强烈的心理满足。",
    "1. 召唤祭坛（GachaAltar）魂石召唤与金光天降动画\n2. 荣誉兑换（ExchangePanel）官市凭证与军功印章\n3. 贸易行（TradeContracts）商队行商与契约文书质感"
]

scores = {
    "before": "86.0", "after": "96.0", "delta": "10.0",
    "vis": "29.0/30", "ui": "24.5/25", "com": "19.0/20", "con": "14.5/15", "tec": "9.0/10"
}

make_widget(5, "Version 3.5", "养成系统与神兵工坊仪式感升级", scores, screens, critique)
