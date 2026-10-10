# 新版地图与三页前端：Claude 复审包

先读 `01_FUNCTIONS_AND_CONSTRAINTS.md`，再看 `core/` 的 9 张图及 `reference/01_target_forest.jpg`。像素问题另看 `states/15_density_comparison.png`，左旧右新，同主角、同相机。

`core/` 是真实 Godot 运行截图，不是生成概念图。城镇使用隔离的已建成预览档，方便比较所有建筑；默认玩家状态见 `states/01_lorin_wilds_default_construction_800.png`。拍地图时暂停输入和接战以固定视角，不改实际场景布局或功能。overview 是缩小的空间诊断图，不代表正常游戏倍率。

最新修订：加载与标题首页恢复原背景；两张地图重新生成自然单条主路、没有岔路；小地图与展开地图不显示道路。最新版本通过 7 个相关回归用例和 179 项接入检查。手机硬件表现尚未验证；审美达标仍需本次复审。

把 `CLAUDE_REVIEW_PROMPT.md` 作为任务提示词。不要让 Claude 扫工程或读取整套旧设计史。需要更多状态时再打开指定的 `states/` 图片。

本包是设计审查资料，不是游戏安装包。工作区内可双击 `D:/new-bee/远征/tools/LaunchReferencePreview.cmd` 试玩已建成城镇；使用独立存档。WASD/方向键或摇杆移动，走近 NPC/门前交互，靠近北侧路牌出城。
