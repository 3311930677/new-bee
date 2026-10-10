# 地图与NPC · 一次Cloud美术指导输入包

把整个小包交给Cloud，使用 `PROMPT_CLOUD_WORLD_ART.md`。本轮只输出美术方向与重绘制作说明，不运行工程、不生成图片、不实施修改。

## 必读输入

- `STYLE_AND_SCOPE.md`：简短风格和功能边界。
- `TECHNICAL_FACTS.md`：Codex已核对的帧条、显示尺寸、地面及锚点事实。
- `screenshots/01_town_current.png`、`02_field_current.png`：来自2026-10-10现有验收包的引擎运行图，分别为昭元边城和枫林古道。使用隔离演示存档，未在本轮重新运行游戏；不是整张地图全景。
- `references/03_steward_idle.png`、`04_guard_idle.png`：现有通用NPC待机源帧条，帮助判断角色风格与一致性；最终显示比例以运行截图为准。

共2份短说明和4张必要图片，不需要读全部UI设计文档、18页截图或工程历史。可打开 `index.html` 查看图片。

## 按需参考

`optional/` 中港口运行图来自2026-10-05，HUD为旧版，只观察场景、建筑、NPC与主角的关系；不作为最新界面的验收证据。铁匠和孩童为现有源帧条。只有确定人物类型或地域差异需要时才查看这3张图。

## 两步工作流

1. Cloud集中输出 `outputs/WORLD_ART_DIRECTION.md` 和 `outputs/WORLD_ASSET_REBUILD_BRIEF.md`。只定一个方向，用母提示词加差异表，完整样板生图提示词最多4条；不要按全部NPC/地图逐项重复长提示词。
2. Codex先排查透明/遮罩/缩放问题，再制作与接入少量样板。用相同地点和视角补拍2–3组前后图，把已定规范及样板图交给Cloud，使用 `PROMPT_CLOUD_SAMPLE_REVIEW.md` 做一次限定验收。样板合格后再推广。

这能减少探索工程、反复生图和长对话的消耗，不保证固定调用价格；实际额度仍由所用API的计费与账户限额控制。
