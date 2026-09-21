# 批 0 v2：原版逻辑分辨率重做

本批使用内置图像生成工具，并将原版解包图集、原版 UI PNG、实机截图分别作为对应素材的参考图。

与 v1 的主要差异：

- 角色按 64×96、怪物按 64×64、按钮按 160×32、标题按 192×256、地图按 256×160 的逻辑分辨率处理。
- 后处理限制为 24～48 色，关闭抖动，最终只使用 nearest-neighbor 放大。
- 怪物和按钮使用硬透明边缘；标题背景改回羊皮纸、木棕栏、描金角饰和龙纹印章构造。
- `raw/` 保存生成母稿，`ready/` 保存原版技术规格约束后的预览。

建议审核文件：

- `ready/a1_zs_nan_anchor_v2_transparent_512x768.png`
- `ready/b_bandit_v2_128x128.png`
- `ready/f1_button_normal_v2_480x96.png`
- `ready/g_title_background_v2_768x1024.png`
- `ready/h1_grass_map_anchor_v2_1024x640.png`
