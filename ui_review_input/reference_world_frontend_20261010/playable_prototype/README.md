# 左右建筑与草坪主路样板

最新地表已接入：主路和门前路缘变为自然磨损边，南侧小径从约1740处开始变窄变浅，融进草地，不再有圆头和强制连接画面底边的路带。建筑、NPC、出口及交互位置不变。70项运行检查通过。前后对照：screenshots/town_south_comparison.png（左旧右新），长屏效果：screenshots/town_south_tall.png。本次地表为生图预览候选，实际生成945×1663，经一次原生最近邻尺寸整理为1200×2112；未声称最终像素网格验收完成。普通房屋和NPC仍为位置占位。

当前版本3：出口为一个独立路牌，门楼已去掉。地图范围按内容加留白计算，当前约1200×2112，主路136宽、支路较窄；8座房屋与独立访客簿保留原设施ID。启动后直接进入城镇，E或交互按钮可在路牌处出城并从野外返回。最新详细规则以../outputs/TOWN_NEIGHBORHOOD_PLAN.md为准；下方旧版本说明仅作历史记录。

最新方向及坐标在 ../outputs/TOWN_NEIGHBORHOOD_PLAN.md。旧版绕行广场方案已归档；当前配置为 town_neighborhood_layout.json（version2）。

双击 Launch.cmd 直接进入城镇。方向键/WASD或点击地面行走；沿路向北，在“出城·枫林古道”标记按E或底部交互按钮离开。野外沿路向南，在返回标记交互回城。到达点不会立即重触发出口。底部按钮提供场景切换、视距、长屏、当前交互和碰撞显示。

9座设施、9名NPC、6个任务物件保持原功能ID。NPC站在门前侧边，拥有身体碰撞与独立交互范围；近处只显示当前目标姓名。大树单独摆放、树冠遮挡减透明；门楼通道也可行走，穿门时减透明。

目前517项空间检查、68项运行检查通过；检查文件为neighborhood_checks.json和checks.json，实际启动日志为launch.stdout/launch.stderr。此样板没有游戏存档、任务奖励或正式建筑功能，仅检验地图构图、通行和交互点。

新增美术生成前已确认房屋图框、出口、NPC站位、树位置与道路连续性。本轮没有新增AI图片；城镇地面、普通屋形和NPC简形仍为明确标注的空间占位，不是最终美术。正式地图数据未改动。已有独立地面与散件用于早期野外/单楼测试，保存在远征/assets/world/reference_playable_20261010。

草图：screenshots/neighborhood_plan.png。
出口：screenshots/neighborhood_north_exit.png。
风格参考仅为 ../reference/01_target_forest.jpg 等实际画面；草图及道路几何指导图只指导坐标。
最新67条生图配方：../outputs/IMAGE_PROMPTS_EXPANDED.md。
六块地表的明确制作区：../outputs/TOWN_PRODUCTION_PREFLIGHT.json。
