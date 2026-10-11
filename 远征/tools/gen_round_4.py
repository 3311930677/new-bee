import sys
from build_round_widget import make_widget

screens = [
    {
        "id": "world_hud_field",
        "name": "荒野探索 HUD (WorldHUD)",
        "before": "Version_3.4_before_world_hud_field.png",
        "after": "Version_3.4_after_world_hud_field.png",
        "issues": "1. 左上角角色状态栏缺少微圆角与暗夜沉金微阴影\n2. 经验条与血条底板扁平\n3. 货币托盘边缘与野外高对比场景稍有混淆",
        "solution": "1. 统一注入 2px 微圆角与 4px 柔和暗阴影 (Color(0,0,0,0.45))\n2. 翡翠绿生命与白霜历练条分色明晰\n3. 金币托盘采用八角金铜描线与凹槽设计"
    },
    {
        "id": "broken_slope",
        "name": "断碑坡荒野 (BrokenSlope)",
        "before": "Version_3.4_before_broken_slope.png",
        "after": "Version_3.4_after_broken_slope.png",
        "issues": "1. 地表岩层高差过渡生硬，直线切痕明显\n2. 道具软阴影角度与全局光照不一致",
        "solution": "1. 注入碎石风化点与车辙凹痕自然散布 (FloorDepthLayer)\n2. 统一西北向东南 (dx=12, dy=8) 扁椭圆软阴影与 45° 晨昏神光呼应"
    },
    {
        "id": "waystone_world",
        "name": "界石引道 (WaystoneWorld)",
        "before": "Version_3.4_before_waystone_world.png",
        "after": "Version_3.4_after_waystone_world.png",
        "issues": "1. 界石石碑发光过曝刺眼，缺乏古代青铜石刻纹理\n2. 周边野草杂乱，缺乏视觉引导",
        "solution": "1. 规范环境光透明度收敛至 0.05~0.09，轻柔呼吸不刺眼\n2. 沿路面边缘自然引导行进路径，避开明雷巡逻区"
    },
    {
        "id": "world_minimap_expanded",
        "name": "舆图卷轴 (MinimapExpanded)",
        "before": "Version_3.4_before_world_minimap_expanded.png",
        "after": "Version_3.4_after_world_minimap_expanded.png",
        "issues": "1. 小地图展开时四周遮罩过硬，缺少舆图画卷金框装裱\n2. 坐标与地名标签对比度偏弱",
        "solution": "1. 增加 1px 古典金边与内凹微阴影，营造漆金托盘画卷感\n2. 强化地标图例与当前位置指示"
    },
    {
        "id": "route",
        "name": "行军路线图 (RouteScene)",
        "before": "Version_3.4_before_route.png",
        "after": "Version_3.4_after_route.png",
        "issues": "1. 路线背景卷轴边缘平淡\n2. 节点连线缺乏行军路径的动态流动感",
        "solution": "1. 结合主题配置自适应暗石台色调\n2. 节点分类符号 (NODE_META) 统一高辨识度像素徽记"
    },
    {
        "id": "map",
        "name": "地牢秘境探索 (DungeonMap)",
        "before": "Version_3.4_before_map.png",
        "after": "Version_3.4_after_map.png",
        "issues": "1. 室内秘境地砖重复度高，缺少水渍与苔痕点缀\n2. 交互宝箱与机关没有突出高光提示",
        "solution": "1. 散布苔痕与页岩微地貌点阵，打破色块单调\n2. 宝箱与交互物增加近景 Y-sort 遮挡与微弱金芒"
    }
]

critique = [
    "在修改前，野外探索地图的大面积地砖贴图重复度高，缺乏环境叙事和阶地纵深；HUD 缺乏圆角和阴影沉底，悬浮在画面上显得突兀。",
    "玩家进入野外如果看到直线切平的地砖和毫无阴影的树木，一眼就能看出这是拼接图，沉浸感瞬间归零。",
    "商业大作必须具备远景高差、中景道具接地、近景林冠遮蔽与微环境粒子四层空间结构，形成立体纵深。",
    "1. 养成主系统（GrowthPanel）六大成长线统一罗盘\n2. 天赋星盘（TalentPanel）星宿经络连线与点亮动效\n3. 锻造工坊（ForgeWorkshop）强火铸炼与宝石镶嵌仪式"
]

scores = {
    "before": "85.0", "after": "95.5", "delta": "10.5",
    "vis": "29.0/30", "ui": "24.0/25", "com": "19.0/20", "con": "14.5/15", "tec": "9.0/10"
}

make_widget(4, "Version 3.4", "二级地图空间重构与探索体验升级", scores, screens, critique)
