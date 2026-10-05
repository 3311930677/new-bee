# 四位主角的 Universal LPC 行走试用

双击 `打开游戏内试用.cmd`，在现有昭元边城地图里查看人物。按方向键或 WASD 行走，数字 1–4 或人物按钮切换破军、穿杨、霜语、晨星，空格切换 LPC 与原版。试玩存档使用 `tools/_logs/save_lpc_preview.json`。

四套人物均通过本机 Universal LPC 官方发布版的角色组合与导出功能制作，原始 ZIP、可编辑的 character.json、Credits TXT/CSV 和原生行走图保存在各角色子目录。`presets.json` 是重新打开这些配置的本地地址。

| 角色 | 本次部件 |
|---|---|
| 破军 | 棕红刺发、黑甲、金肩甲、红披风、长剑 |
| 穿杨 | 深蓝高马尾、深色轻甲、铜肩甲、青披风、长枪 |
| 霜语 | 银色长发、深蓝袍、深蓝披风、冰蓝晶体法杖 |
| 晨星 | 金色长发、白头巾、白袍披风、金色锤头 |

LPC 的基础人物比例更接近传统像素 RPG，细节精度低于游戏原有素材。这是用于判断整体画风是否适合的试用，白毛领、修女帽、原版大剑和圣锤的细节没有一模一样的部件。

原始行走图每格 64×64，顺序为上、左、下、右。项目用图通过最近邻放大到 128×128 格，重排行顺序为下、左、右、上，保留每方向八个连续行走帧和一帧站立；没有生成或补绘动作。Atlas 尺寸 1152×512，SpriteFrames 内含 walk_* 和 idle_*，行走速度为 12 FPS。

`review/four_roles.gif` 是四人四方向循环；`review/in_game.gif` 是游戏引擎实际地图渲染的近景拼图。`review/world/` 保存完整游戏画面。

验证：Godot 4.7.2 实际加载四套资源，检查全部 128 个行走帧与 Atlas 区域，并验证每个角色四方向实际位移、朝向切换、停止动画。记录在 `review/verify.log`；真实地图逐帧渲染记录在 `review/capture.log`。

许可：本次组合是 LPC 原作的衍生人物图；各部件许可和作者以每个角色的 Credits 为准，发布游戏时应随使用的素材保留相应署名与许可。

上游：https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator
