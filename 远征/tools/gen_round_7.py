import sys
from build_round_widget import make_widget

screens = [
    {
        "id": "worlds",
        "name": "九州大域图 (RegionMapPanel)",
        "before": "Version_3.7_before_worlds.png",
        "after": "Version_3.7_after_worlds.png",
        "issues": "1. 区域省份卡片缺少古典山水舆图的墨韵烘托与金边包角\n2. 解锁与锁定状态区分稍显生硬",
        "solution": "1. 注入古典金箔折叠舆图画卷视觉与典雅地标徽记\n2. 引入通关百分比翡翠微光槽与据点点亮连线"
    },
    {
        "id": "codex",
        "name": "山海灵兽谱 (CodexPanel)",
        "before": "Version_3.7_before_codex.png",
        "after": "Version_3.7_after_codex.png",
        "issues": "1. 左右翻页仅使用普通单字符 ‹ 与 ›\n2. 展台底座光效偏弱 (0.25)，灵兽悬浮发虚",
        "solution": "1. 左右翻页升级为青铜实心箭头 ◀ ▶ 并注入轻触微震\n2. 展台光圈不透明度强化至 0.75，立绘咬合青铜法阵"
    },
    {
        "id": "road_mail",
        "name": "边塞驿传 (RoadMailBoard)",
        "before": "Version_3.7_before_road_mail.png",
        "after": "Version_3.7_after_road_mail.png",
        "issues": "1. 边塞信件缺少古典火漆封缄印与竹简信筒质感\n2. 信件阅读区域行距过挤",
        "solution": "1. 信札边角增加火漆印戳与古典封笺纹理\n2. 优化长文本智能换行与宣纸阅读留白"
    },
    {
        "id": "city",
        "name": "边城烟火 (CityScene)",
        "before": "Version_3.7_before_city.png",
        "after": "Version_3.7_after_city.png",
        "issues": "1. 城镇街道建筑接地阴影单薄\n2. NPC 头顶名字与交互光圈缺乏古典青铜铭牌感",
        "solution": "1. 强化建筑 192px 接触阴影地基复用 (Grounding.prepare)\n2. 交互光圈增加西北斜向软阴影与接近触发微光"
    },
    {
        "id": "city_repair",
        "name": "城务营建 (CityRepair)",
        "before": "Version_3.7_before_city_repair.png",
        "after": "Version_3.7_after_city_repair.png",
        "issues": "1. 建筑修复材料消耗缺乏明确的红绿双色满足/不足提示\n2. 完工效果文字偏小",
        "solution": "1. 材料槽位红绿双色明示，完工加成属性以高对比烫金展示\n2. 营建确认按钮统一古典金铜按压反馈"
    },
    {
        "id": "city_built",
        "name": "据点盛景 (CityBuilt)",
        "before": "Version_3.7_before_city_built.png",
        "after": "Version_3.7_after_city_built.png",
        "issues": "1. 建筑落成全景中，功能入口按键层级与城防工事视觉略有杂糅\n2. 缺少统一的官府布告板装裱",
        "solution": "1. 梳理建筑交互热区，功能气泡与建筑顶檐错落排布\n2. 议事厅、锻造坊、兽栏分别匹配青铜门匾标识"
    }
]

critique = [
    "在修改前，主城场景与图鉴系统虽然功能完整，但细节处（如翻页字符、展台亮度）依然残留‘个人Demo’痕迹。",
    "图鉴是展示美术资产最集中的橱窗，如果连展台光圈都发灰透明，玩家对整个游戏的资产精细度评价会大打折扣。",
    "商业级RPG的大地图和图鉴必须具备‘典藏品’装裱感，如同翻阅一本厚重真实的古代山海秘录。",
    "1. 钓鱼系统（FishingPanel）碧波垂钓与抛竿收线微交互\n2. 残碑古阵密室解谜（SteleRoomsEntry）地脉灵气光晕\n3. 历程事件（SpecialEventPanel）奇遇弹窗与抉择文牒"
]

scores = {
    "before": "88.0", "after": "97.0", "delta": "9.0",
    "vis": "29.2/30", "ui": "24.5/25", "com": "19.5/20", "con": "14.8/15", "tec": "9.0/10"
}

make_widget(7, "Version 3.7", "大千世界志异与边城营造大成", scores, screens, critique)
