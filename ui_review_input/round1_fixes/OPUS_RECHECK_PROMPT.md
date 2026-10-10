请复验《远征》第一轮 UI 的五项验收修正。只判断原 `UI_REVIEW_FIXES.md` 的问题是否解决，不重新设计整套 UI。

必读：`UI_REVIEW_FIXES.md`、`FIXES_IMPLEMENTED.md`，以及 `title_before/after.png`、`world_before/after.png`、`title_after_long.png`。before 是你审查的 V1，after 是本轮真实 Godot 渲染。

按需再读：`world_after_long.png`、`world_gray.png`、`sprint_on.png`、`sprint_on_gray.png`、`interaction_ready.png`、`potion_zero.png`、`map_expanded.png`。不要反复读同一图，不扫描工程、不运行游戏、不联网、不启动子代理。

核对五项：新字标/实时副标题/天空融合；局部地形图和三种标记；帐篷/卷轴/疾行图标；摇杆/圆盘/数量角标；主按钮铜边/分隔点/退出降级。原有地图半透明木板仍在本次范围之外。

注意：工程的旧营帐资源实际是篝火，因此补了填色帐篷。地形为真实底图与建筑数据的导航简图，不能把它当碰撞图。交互图为了拍到靠近自动对话前的一帧，暂停了自动接触步骤，点击原对话已验证；请勿据此推断平时交互逻辑改变。

只生成 `UI_RECHECK.md`：五项逐条给出“通过/仍需修正/无法从截图判断”和具体证据。若还有问题，最多列 3 个最关键的具体修复，写明位置、目标效果、实施要求和是否需要资产。不要重复合格部分，也不要泛泛提出新风格方向。完成后停止。
