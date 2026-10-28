# 2026-10-24 静态素材补齐

33 张内置 imagegen 生成的透明 PNG，已接入正式界面和地图。

- `ready/equipment/`：6 件专属装备图标。
- `ready/items/`：7 张任务物品图，覆盖 9 个原物品 ID。
- `ready/home/`：6 张首页图标。
- `ready/world/`：14 张地图与机关素材。
- `source/`：生成母稿；`.gdignore` 阻止导入与运行引用母稿。
- `generation_manifest.json`：逐图完整提示词、来源、裁边和成品尺寸。

运行索引位于 `res://data/asset_completion_20261024.json`。准备脚本为 `res://tools/prepare_completion_assets.py`，在本机用带 Pillow 的 Python 执行。完整截图、文件哈希和验收说明见仓库根 `reports/asset_completion_20261024/README.md`。
