# 主要界面重拍 · 2026-10-07

## 为什么要重拍

`shots/all_scenes_20261001/` 那批 256 张全量图**已整体过期**：UI 在 2026-10-02 被重做
（`570fb43f feat(ui): 用切角像素厚度语言统一全界面与场景层`），此后又经 10-04 / 10-05 / 10-07 多轮打磨。
旧图里的主页、城内 HUD、建筑渲染、面板配色与当前版本已完全不同，作为参照会误导。

旧目录已删除（含当时的 6 张总览与临时残留）。如需找回：

```bash
git checkout HEAD -- 远征/shots/all_scenes_20261001
```

## 本目录内容

**61 张，全部 480×800**（项目基准竖屏分辨率），对应当前代码重新拍摄：

| 分类 | 张数 | 用例 |
| --- | --- | --- |
| 启动与流程 | 8 | `load` `title` `title_intro` `title_settings` `login` `createrole` `prologue` `home` |
| 主界面与浮层 | 13 | `deploy` `worlds` `codex` `arena` `gacha` `exchange` `settings` `growth` `bag` `quests` `avatar` `gm` `gm_open` |
| 养成子页 | 6 | `talent` `equip` `pet_raise` `skillbook` `mount` `titles` |
| 工坊 | 3 | `forge_enhance` `forge_gem` `forge_refine` |
| 城内 | 8 | `city` `city_built` `city_shop` `city_notice` `city_guests` `city_deploy` `city_build_panel` `city_built_panel` |
| 主世界与 HUD | 8 | `main_world` `world_hud_city` `world_hud_field` `world_minimap_expanded` + 4 张地图 `mw_*` |
| 战斗 | 7 | `battle` `battle_cast` `battle_low` `main_world_battle` `main_world_battle_skills` `picker` `picker_school` |
| 随机秘境 | 3 | `route_forest` `map` `map_boss` |
| 剧情演出 | 2 | `story_intro` `story_outro` |
| 第四幕 | 3 | `fourth_regions` `fourth_preparation` `fourth_battle` |

先看 `_overview.png`（一张拼好的总览）。

## 怎么重跑

```bash
cd 远征
bash shots/main_ui_20261007/_capture.sh          # 重拍 61 张
python shots/main_ui_20261007/_overview.py       # 重拼总览
```

逐项结果见 `_run.log`。本次 **61/61 全部成功，0 失败**；全部 480×800，无空帧。
截图工具已把存档重定向到 `res://tools/_logs/`，**不会动真实存档**。

## 与其它截图目录的分工

- `frontend_polish_20261007/` —— 项目自带的 `CaptureFrontend` 工具产出，只覆盖启动与主界面
  10 个用例 × 480×800 / 480×1067 两档，并带 `*.text.json` 文案审计与 `index.html` 审阅页。
  **需要逐字核对文案时用那套**；本目录是覆盖面更宽的画面参照。
- `frontend_overhaul_20261004/`、`ui_all_polish_20261005/`、`icons_20261007/` 等 —— 各轮专项改动的过程留档。
- 本目录是**当前状态**的主要界面参照。

## 过期截图清理（2026-10-07 已完成）

本次一并清掉了 `shots/` 顶层的过期内容，顶层从 69 张减到 **16 张**：

| 处理 | 张数 | 说明 |
| --- | --- | --- |
| 已删除 | 53 | 10-02 UI 重做**之前**的单张截图：47 张 9/24（`home` `title` `main_world` `growth` `city` `battle` `arena` `avatar` `equip` `gacha` `map` `mount` `picker` `settings` …）+ 9/28–9/30 共 6 张（`p05_repair` `p06_trade_*`）。均为**重做前**画面，同名新图在本目录。 |
| 保留 | 16 | 10/03 那批（`road_mail_*` `tidal_*` `stele_*` `frost_herb_*` `city_tide_choice_cargo`），属新 UI，仍有效。 |

这批文件**全部在 git HEAD 中**，需要任何一张可直接找回：

```bash
git checkout HEAD -- 远征/shots/home.png          # 单张
git checkout HEAD -- 远征/shots/all_scenes_20261001   # 10-01 全量图集
```

文档里的悬空引用已同步处理：`2026-10-01-global-visual-issues.md`、`2026-10-02-gap-audit-vs-target.md`
与权威总方案 `2026-09-24-yuanzheng-master-plan.md` 均已加注「该图集已退役，现状见本目录」。

> 其余 9/24–9/29 的过程文档里还有 6 处对旧文件名的**文字提及**（非链接、非图片嵌入），
> 属当时状态的记录，未改动。
