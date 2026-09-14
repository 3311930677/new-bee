# 破军战斗素材包

- `pojun_spritesheet.png`：512×640，4 列×5 行，每格 128×128，透明背景。
- `pojun_sprite_frames.tres`：Godot 3.x `SpriteFrames`，可直接赋给 `AnimatedSprite.frames`。
- `pojun_icon.png`：128×128 透明角色图标，可用于选人、队伍和排行榜。
- 动画行顺序：`idle`、`attack`、`cast`、`hit`、`death`，每个动画 4 帧。
- 推荐纹理导入设置：关闭 Filter、关闭 Mipmaps，开启 Lossless 压缩。
- 角色朝右；敌方若允许镜像，可设置 `flip_h = true`。

生成母图保存在 `source/`，仅用于追溯和重新切图。
