# 霜语侧面停走修订 v16

问题：上一版停止时直接冻结 walk 第 1 帧，该帧仍是弯膝迈步。左右循环还存在头、躯干、法杖的对齐差异。

本次增加独立 `idle_left` / `idle_right` 单帧动画，双脚落地、身体直立。主城、探索地图和 WalkActor 预览统一在停下时选用独立静息资源，再次移动时返回相应 walk。未提供独立静息图的角色继续使用原先停步帧。

素材：`image/role/fs/shuangyu_idle_side_v16.png` 是左右侧面静息；`shuangyu_walk_side_v16.png` 是修订版四向行走图；现有 `shuangyu_walk_4dir.png` 和 `shuangyu_walk_frames.tres` 已更新。正背面像素与 v15 完全相同。侧面按面部位置对齐，使用统一缩放并保持脚底 y=120 附近。前一版素材与资源已留备份。

身份核对：用户指定的 `exports/role_standing_4dir_v1/shuangyu_4dir_source.png` 具备直立侧面姿态，但法杖底部蓝色装饰、腰扣与披风细节存在差异，因此未直接接入。以它生成的候选稿仍带入这些差异，也未采用。最终采用基于当前霜语身份图生成的侧面母稿，保留银发、蓝色发饰、白毛领、蓝金短衣、蓝金靴和原法杖；原静息目录未修改。工具为内置 image_gen，提示词与选择记录见 `generation_prompts.md`。

预览：`walk_stop_comparison.gif` 左 v15、右 v16，按实际 12 FPS 展示两轮行走再停步；`side_idle_walk_phases.png` 展示静息和全部侧面帧。

验证：Godot 4.7.2 的 `verify_shuangyu_side_idle.gd` 通过：真实主城/地图动画更新函数、预览实际左右移动、停止并保持静息、再次起步以及其他角色回退行为。脚本不启动主城/地图完整场景，不改玩家存档。资源导入成功，代码空白检查通过。资源加载与行为验证不代表人物造型可以免于视觉复核，检查图和动画均已提供。

