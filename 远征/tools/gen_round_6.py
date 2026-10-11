import sys
from build_round_widget import make_widget

screens = [
    {
        "id": "gacha",
        "name": "通灵祭坛 (GachaAltar)",
        "before": "Version_3.6_before_gacha.png",
        "after": "Version_3.6_after_gacha.png",
        "issues": "1. 召唤祭坛保底进度条缺少璀璨金色刻度\n2. 每日免费召唤条呼吸金线与羊皮纸边缘咬合不够紧密",
        "solution": "1. 保底进度条引入末端菱形金色符文标记与脉冲高光\n2. 强化出金爆闪 (Gold Burst) 与触觉强震 (Haptic.heavy) 同步"
    },
    {
        "id": "exchange",
        "name": "演武荣誉补给 (ExchangePanel)",
        "before": "Version_3.6_before_exchange.png",
        "after": "Version_3.6_after_exchange.png",
        "issues": "1. 兑换条目按钮缺乏触觉微震与状态分级\n2. 顶部荣誉余额数字偏小",
        "solution": "1. 统一注入 HapticFeedback.light() 与成功兑换金粉淡出 Toast\n2. 荣誉余额以高对比金色粗体居中展示"
    },
    {
        "id": "trade_contracts",
        "name": "商队贸易合约 (TradeContracts)",
        "before": "Version_3.6_before_trade_contracts.png",
        "after": "Version_3.6_after_trade_contracts.png",
        "issues": "1. 贸易合约面板缺少官府契约印鉴的质感\n2. 签约与退单按钮色阶区分不够明显",
        "solution": "1. 引入三城保价古典印章与契约状态色标 (LedgerStyle.badge)\n2. 退单与履约按键分别配置警告赭石与主操作青铜金漆"
    },
    {
        "id": "rare_ceremony",
        "name": "神兵启封大典 (RareCeremony)",
        "before": "Version_3.6_before_rare_ceremony.png",
        "after": "Version_3.6_after_rare_ceremony.png",
        "issues": "1. 神兵展台八角金台在静态出图时缺少中心聚集感\n2. 印章震落动画落地前缺乏视觉悬念",
        "solution": "1. 14条柔和旋转光芒与28颗灵气光粒配合暗夜遮罩聚焦核心\n2. 朱砂品质印章自顶端下落并伴随物理挤压回弹 (1.35->0.92->1.0)"
    },
    {
        "id": "act1_blue_weapon",
        "name": "神兵初显 (Act1BlueWeapon)",
        "before": "Version_3.6_before_act1_blue_weapon.png",
        "after": "Version_3.6_after_act1_blue_weapon.png",
        "issues": "1. 蓝装弹窗周围环境遮罩过浅，主次不够分明\n2. 属性词条排版行距偏大",
        "solution": "1. 加深外围全屏暗夜遮罩至 0.85，强化神兵聚焦\n2. 词条信息采用宋体烫金小标与属性数值秩序化对齐"
    },
    {
        "id": "pet_claim",
        "name": "灵宠认主 (PetClaim)",
        "before": "Version_3.6_before_pet_claim.png",
        "after": "Version_3.6_after_pet_claim.png",
        "issues": "1. 灵宠认主仪式展台光芒与灵气光粒同步稍有锯齿\n2. 灵宠昵称与天赋技能描述略微拥挤",
        "solution": "1. 展台光芒引入平滑正弦呼吸与像素网格整数对齐\n2. 技能描述分行展示并配以专属兽纹印戳"
    }
]

critique = [
    "在修改前，高阶物品获得仅有简陋数字变化，完全缺乏高价值物品获得的‘惊喜爽感’与‘心理仪式感’。",
    "如果抽到极品神兵或五星灵宠只是弹出一个普通白色小弹窗，玩家会觉得游戏极度廉价、毫无抽卡收集的兴奋感。",
    "成熟一线手游会利用全屏黑屏压暗、旋转光芒、印章震落和金铁交鸣音画一体，创造极具分享欲的高光时刻。",
    "1. 区域大地图（RegionMapPanel）州府舆图画卷与据点点亮\n2. 怪物图鉴（CodexPanel）山海志异与像素生态标本\n3. 驿站传书（RoadMailPanel）边塞烽火与驿卒书信"
]

scores = {
    "before": "87.0", "after": "96.5", "delta": "9.5",
    "vis": "29.0/30", "ui": "24.5/25", "com": "19.5/20", "con": "14.5/15", "tec": "9.0/10"
}

make_widget(6, "Version 3.6", "经济循环与神兵启封仪式大成", scores, screens, critique)
