# 《远征》第一轮主场景 UI 设计输入包

整理日期：2026-10-09。用途：给 Opus 做视觉决策，再由 Codex 实现。此包不包含待执行的 UI 改造，也不包含已经定稿的设计规范。

## 本轮已确认范围

用户已选择 **启动主菜单 + 游戏内主场景一起设计**。请使用 `OPUS_ROUND1_PROMPT.md`，这是本包正式提示词；其他提示词仅供以后拆分任务参考，不要一起执行。

本轮最少输入：正式提示词、`ui_functions.md`、`ui_constraints.md`、`ui_references.md`、`screenshots/title_context.png` 和 `screenshots/world_current.png`。营帐图不必读取。

正式交付：`outputs/UI_MASTER_SPEC.md`、`outputs/MAIN_SCENES_UI_PLAN.md`。后者分别给出启动菜单方案与城镇/野外 HUD 方案。

## 页面必须分清

| 页面 | 实际含义 | 本轮用途 |
|---|---|---|
| 营帐主页 GameHome | 角色展示、成长信息、功能入口、继续旅程 | 独立设计任务 A |
| 游戏内主场景 MapScene | 城镇/野外地图、移动、任务、地图及操作 HUD | 本轮核心页面 |
| 启动主菜单 Title | 开始游戏、介绍、设置、退出 | 本轮核心页面 |

`OPUS_HOME_PROMPT.md` 是日后营帐独立设计的备用提示词；`OPUS_WORLD_PROMPT.md` 是单独处理 HUD 的备用提示词。当前使用联合提示词。

## 备用独立任务材料

任务 A：`OPUS_HOME_PROMPT.md` + `ui_functions.md` + `ui_constraints.md` + `ui_references.md` + `screenshots/home_current.png`。

任务 B：`OPUS_WORLD_PROMPT.md` + 同样三个说明文件 + `screenshots/world_current.png`。

正式联合任务必读 `title_context.png` 与 `world_current.png`。`home_tall_baseline.png` 只供以后营帐任务参考。不必上传所有截图，更不必上传工程、脚本、日志或此前几十份设计记录。

在 Claude Code 中，可把本文件夹作为独立工作目录打开，选择 Opus 后粘贴对应提示词全文。产物放入 `outputs/`。不要把包复制进旧的长对话后继续讨论。

## 截图来源与限制

`*_current.png` 是便于提交的文件名，表示本包选用的设计基线；不是本轮重新运行游戏拍摄的证明。

| 文件 | 来源 | 来源日期 | 地位 |
|---|---|---|---|
| home_current.png | 远征/shots/main_ui_20261008/home.png | 2026-10-08 | 营帐设计基线 |
| world_current.png | 远征/shots/main_ui_20261008/main_world.png | 2026-10-08 | 昭元边城 HUD 设计基线 |
| title_context.png | 远征/shots/main_ui_20261008/title.png | 2026-10-08 | 启动菜单设计基线；文件名保留以兼容备用提示词 |
| home_tall_baseline.png | 远征/shots/icons_20261007/home_1067.png | 2026-10-07 | 较早的长屏适配参考 |

图片直接复制原生截图，未加滤镜、调色、放大或重绘。刻意没有选用 showcase 中经过后期加工的图片，避免把展示效果误当成游戏现状。截图使用演示角色与数值，不代表玩家真实存档。

已对照当前项目的页面脚本、显示设置、字体和既有 UI 记录提取功能与约束，但未在本轮运行游戏。截图与当前代码可能存在细小差异：尤其主按钮当前代码隐藏了动态目标地点文字，而基线截图仍显示地点；设计时应保留主操作语义，并明确未来地点信息由运行时文本绘制。城镇截图的文字审计还含隐藏地点文字，不应将隐藏节点误认为屏幕上实际可见内容。

若设计后立即实施，应由 Codex 在实施前重新截图确认基线；不要让 Opus 为此探索工程。

## 交付与下一步

任务 A 输出 `outputs/UI_MASTER_SPEC.md`、`outputs/HOME_UI_PLAN.md`。

任务 B 若先做，输出 `outputs/UI_MASTER_SPEC.md`、`outputs/WORLD_HUD_PLAN.md`。若 A 已完成，将其规范作为输入，B 改为只输出 `WORLD_HUD_PLAN.md`，不重写全局方向。

本轮同时设计启动菜单与 HUD，工程实现可按页面分批交付真实截图。角色养成、装备、营帐和战斗窗口本轮只保留相关入口，不设计内部页面。`ui_observations.md` 是 Codex 的预审备注，默认不提交，避免限制 Opus 的独立判断。
