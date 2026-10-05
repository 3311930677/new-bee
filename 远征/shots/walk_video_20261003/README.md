# 霜语行走视频修订 v15

视频：`C:\Users\tsz\Downloads\video_20261003_204732.mp4`，10.134 秒，1080×1920，30 FPS。

从正面、背面、左右侧面各截取 6 帧，帧号和时间保存在 `source_frames.json`，带时间标记的原始提取结果见 `extracted_keyframes_labeled.png`。这些截图是视频原帧；成品经过内置 image_gen 去除灰底和投影，并参考视频修正交替落脚与经过位，因此并非逐像素原帧抠图。完整提示词见 `generation_prompts.md`。

运行图：`image/role/fs/shuangyu_walk_4dir.png`；另存版本：`image/role/fs/shuangyu_walk_video_v15.png`。继续使用已有 `shuangyu_walk_frames.tres`，无需修改场景代码。规格：768×512，6 列×4 行，单帧 128×128，方向顺序 down/left/right/up，12 FPS；所有方向共用同一裁剪范围、缩放与放置坐标，透明区 RGB 为零，像素边缘硬 alpha。

原图备份：`image/role/fs/source/shuangyu_walk_before_video_v15.png`。角色身份保留银发、蓝色蝴蝶结、白毛领、蓝金衣服和蓝宝石法杖，外观比例按视频修订。

预览：`before_after_64.gif` 为游戏常用 64px 尺寸的新旧对比；`walk_video_v15_128.gif` 为四方向 128px 动画；`walk_video_v15_phases.png` 为逐帧检查图。

验证：24 个新帧均非空且互不相同、人物与法杖无切边、脚底在 y=120 附近、alpha 仅 0/255。Godot 4.7.2 资源重新导入成功；现有 `verify_walk_assets.gd` 通过，检查全部四职业 96 帧的尺寸、切块、四向移动、停步和斜向速度。详见 `technical_checks.json` 和 `verify_walk_assets.log`。验证使用独立测试数据目录。

