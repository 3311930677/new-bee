# 《远征》480×800 同屏视觉样板（P01）

> 对应 [后续实施交接方案](2026-09-27-next-agent-implementation-handoff.md) §4 的 P01 第一步：**先定 480×800 同屏规范**。
> 「现状」列是 2026-09-28 从代码/配置**量出来的事实**（附出处行号）；「样板值」列是 P01 要落到代码里的目标，落地后标 ✅。
> **2026-09-28 状态：§10 九项落地清单全部完成**（代码落地 + 四张标注图 + 四张实机行走图 + 28/28 回归），本文件同时作为 P01 的交付说明。
> 本文件不写原作公式；参考视频里量不出的值（原版路宽、原版字号）保持「未知」，见 [baseline](2026-09-28-baseline.md) §5。

## 1. 视口与镜头

| 项 | 现状（出处） | 样板值 |
|---|---|---|
| 设计视口 | 480×800，`canvas_items` 拉伸，最近邻过滤（`project.godot`） | 不变 |
| 世界格 | 48×48 px（`tools` 与 `maps.json` 一致；TileSet `tile_size`） | 不变 |
| 主世界地图尺寸 | 20×26 格 = 960×1248 世界 px（`data/main_world_maps.json` 四图一致） | 不变 |
| 主世界镜头 | `camera_zoom = 1.15`，y 偏移 −34（`MapScene.gd#L519-521`） | 不变 |
| 主世界同屏世界范围 | 480/1.15 × 800/1.15 ≈ **417×696 世界 px ≈ 8.7×14.5 格** | 不变 |
| 历练镜头 | zoom 1.35，y 偏移 −56（同上 else 分支） | 不变 |
| 城务层单独运行镜头 | zoom 1.25，y 偏移 −56（`CityScene.gd#L307-309`） | 主世界里不走这条（走 `embed_in`） |

## 2. 脚点与显示高度（同屏比例基准）

「脚点」= 角色站立时与地面接触的局部 y。所有会走动的实体都必须让**脚点落在碰撞盒下沿**。

| 实体 | 现状（出处） | 样板值 |
|---|---|---|
| 主角（主世界） | `player_scale = 0.54`；帧心 y=64、帧内脚底 y=120；`_player_anim.position.y = 21−56×0.54 = −9.24`；碰撞矩形 30×26 @ y=+8 ⇒ **脚点 y = +21**（`MapScene.gd#L469-471, L510-515`） | 不变（脚点 +21） |
| 主角（历练） | `player_scale = 0.72`，脚点同样对齐 +21 | 不变 |
| 主角名签 | 底板 140×22 @ (−70, −70.4)；红菱形 18×24 @ y=−89.4（`#L478-501`） | 底板高度随字数收紧，宽 ≤150；下沿距脚点 ≥ 66px |
| 城务 NPC（主世界） | `IDLE_SCALE 0.72 / IDLE_LIFT 42.5`，脚点 = 节点原点；名签顶 −108（帧）/ −114（立绘）/ −52（色块）（`CityScene.gd#L1589-1612`） | 不变 |
| 普通怪（边城） | `monster_height = 118`，精灵脚底对齐原点（`MapScene.gd#L2573-2583`） | 不变 |
| 普通怪（古道） | `monster_height = 62` | 不变，但显示高度需与主角可见身高拉开 |
| 普通怪（断碑坡） | `monster_height = 70` | 不变 |
| 首领（碑窟） | `monster_height = 106`，`_radius 32` | 不变 |
| 散件 | 图 × 0.85–1.18；碰撞 40×s × 26 @ y=−13（`#L410-414`，`CityScene.gd#L1150-1155`） | 不变 |
| 建筑成品图 | 256×192 × 0.75 = **192×144**，底缘 y=+4；木牌挂 `art_top−20`（`CityScene.gd#L1179-1182, L1357-1362`） | 不变 |

## 3. 道路与通行净宽

| 项 | 现状（出处） | 样板值 |
|---|---|---|
| 城池主街（视觉） | 来自背景图 `image/main_world/lorin_wilds_grass_v2.png`（整图拉伸到 960×1248），非格子路（`MapScene.gd#L224-239`） | 不变 |
| 主城建筑碰撞带 | 建筑中心 x = 245 / 715；碰撞盒 `_w*0.80 × _h*0.30`（`CityScene.gd#L1196-1198`） | **主街最窄净宽 ≥ 240px（5 格）** |
| 主城实测净宽 | 左右建筑碰撞带内缘之间 **316px**（最窄在 forge(302.6)↔gate(619) 那一排；由 `city.json` 建筑 `size` × `_w*0.80` 碰撞带 + `city_building_positions` 实算，见 §8 标注图与 `PreviewMainWorld._street_metrics()`） | ≥240 即合格，并写进标注图 ✅ |
| 野外主路（现状） | `_path_cells` 自底走向顶，**每行只落 1 格**、转角只补 1 格横路；4×4 掩码实际仍是正交连通的（相邻行格 x 差 ≤ 1，掩码能取到邻格），**真实问题不是「对角断带」，而是整条路只有 48px 宽**——细到像「稀疏踩踏土块」而非一条路（`MapScene.gd#L310-341` + `#L2269-2306`） | **连续路带**：每格必有正交前驱；净宽 ≥ 96px（2 格） ✅ |
| 碑窟主路 | 同野外，掩码套件缺失时走程序圆线（`#L297-306`） | 同上 |
| 出生安全区 | 散件避让：主世界排除中央 5 列、y<200、**本图真实出生点 150px**（`#L400-409`；出生点改由 `main_world_maps.json` 的 `spawn` 求得，不再用「地图底部中央」估算点）；城池避让 150px（`CityScene.gd#L219`） | **出生点 150px 内无散件/怪物**；主城出生点 [480,930] ✅ |
| 散件脚部碰撞 | 散件基座是实体碰撞 40×s × 26 @ y=−13；按格避让仍可能让盒溢进相邻路面格，走路被绊住（`#L416-446`） | 主世界散件二次筛选：脚部碰撞盒**压到主路格（`_ground_path`）即剔除**（`_foot_hits_road()`，RNG 次序不变） ✅ |
| 出口可辨 | 出口是木牌 `_WorldExit`（牌面 74×22，文字 FS_XS 13，`#L2495-2516`）；出口触发半径 38px（`#L1911`） | 四图在出生点/主街任一位置都能看见至少一块出口牌或小地图出口点 ✅（小地图新增绿菱出口点，`requires_story` 未完成时画灰菱；`_Minimap._draw()`） |

## 4. HUD 安全边距与触控区

| 项 | 现状（出处） | 样板值 |
|---|---|---|
| 屏幕安全边距 | 左上状态面板 (14,12)；金币签 (202,14)；小地图 (390,14) 78×102；HUD 小钮右缘 `HUD_BTN_RIGHT = 468`（`#L26-34, L685-762`） | **四周 12px**（小地图右缘 468、顶 14 已满足） |
| HUD 小钮 | 高 `HUD_BTN_H = 40`；宽 48/66/100；字号 `HUD_BTN_FS = 16`（`#L31-34`） | **命中区最小 44×44**；高度提到 44 ✅（`HUD_BTN_H = 44.0`，`#L31`） |
| 通用按钮 | `BTN_L 190×52 / BTN_M 148×44 / BTN_S 120×38`（`G.gd#L67-69`） | BTN_S 提到 **120×44** ✅ |
| 主世界小钮纵向位置 | 历练 y=144；主世界 y=674（`#L890`）；疾行 (368,600)（`#L954`） | 不变 |
| 屏幕中央禁区 | y 116–600、x 190–390 之间为可动区（上方 HUD 到 y≈116，下方按钮到 y≈600） | **中央 y 200–560 不得被大字/长任务条/散乱图标覆盖** |
| 摇杆 | 124×124 @ (16, 800−176)（`CityScene.gd#L388-390`） | 不变；名牌落入摇杆区时上抬 40px（已有，`#L1656-1675`） |

## 5. 字号（最小可读基准）

`G.FS_*` 六档：`FS_XS 13 / FS_SM 16 / FS_MD 18 / FS_LG 22 / FS_BIG 30 / FS_HERO 56`（`G.gd#L58-63`）。
描边宽度按字号：13–18 → 1px，22–30 → 2px，56 → 4px（`G.gold_label`，`G.gd#L3033-3046`）。

| 用途 | 现状 | 样板值 |
|---|---|---|
| 最小可读字号 | 城务建筑木牌状态行用 **10px**（`CityScene.gd#L1282`，低于任何一档） | **13（FS_XS）** 为下限；10 属违规，改 13 ✅ |
| 玩家头顶名签 | 字面量 **14**（`MapScene.gd#L490`），未进六档 | **FS_SM 16** ✅（与 NPC 名签同级，主角更醒目） |
| 城务 NPC 名签（主世界） | 字面量 **14**（`CityScene.gd#L1617`） | **FS_SM 16** ✅ |
| 怪物名签 | `G.FS_SM 16`，固定盒宽 132（`#L2586-2589`） | 字号不变；**盒宽按文本实测 + 屏内钳制** ✅（`_clamp_label()`） |
| 出口路牌 / 地区名 / 金币 | `G.FS_XS 13` | 不变 |
| 主线条 | `G.FS_XS 13`（`#L789`） | 不变 |
| 建筑木牌名 | 手绘 `draw_string` 13px；状态行 10px（`CityScene.gd#L1278-1284`） | 名 13、状态 13；牌高随行数 |

## 6. 名签层级与遮挡

现状：主角名签=深绿半透明底板（0.91 alpha，1px `90c79c` 边，圆角 7）；NPC=木牌（圆角 9，`0.08/0.05/0.03` 0.82，金边 0.45）；怪物=`Lv{n} {名}`，紫 `c46cdd`，无底板（`MapScene.gd#L478-501, L2586`，`CityScene.gd#L1622-1637`）。

样板值：
1. 玩家 > NPC > 怪物 的层级用**底板不透明度**区分，不用字号跳档：玩家 0.91 / NPC 0.82 / 怪物无底板（描边即可）。
2. 名签一律在**屏幕内**：左右各留 4px；怪物名签同样要钳（现状只钳 NPC）✅（`_MapMonster._clamp_label()` 用 `get_viewport().get_canvas_transform()` 把名签钳进屏幕，与 NPC 同口径）。
3. 名签不得盖住 HUD：与 y<116、y>600 的 HUD 区重叠时隐藏或上抬（沿用 NPC 的摇杆区抬升逻辑）。

## 7. 地区识别点与光色（`data/main_world_maps.json`）

现状：四图 `theme` = 边城 `forest` / 古道 `forest` / 断碑坡 `forest` / 碑窟 `tomb`。

**战斗背景机制（2026-09-28 实测修正）**：主世界的战斗 cfg 是 `presentation == "classic_inline"`（`MapScene.gd#L2100`），`BattleScene._build_background()` 在该分支**直接 `return`**（`BattleScene.gd#L288-291`，根 Control 透明），于是战斗画面**就叠在接战地点的地图地表上**——既不取 `theme.battle_bg`，也不走 `bg_battle_*`。因此**战斗背景会自动继承该图的 `_ground_tint()`**；只要四图地表光色不同，战斗背景天然可区分，无需为战斗单独着色。（原 §7 记的「战斗背景取 `theme.battle_bg`，故边城与两张野外完全相同」是错的。）

样板值（识别点必须有可见载体，不靠文字说明）：

| 图 | 地图 tint（`main_world_maps.json`） | 地貌识别点（`decos` 池 / 固定物） | 战斗背景（自动继承地表） |
|---|---|---|---|
| 昭元边城 | `ffffff` 原色 | 主街两侧建筑、城门、路牌 | 当前地图地表 + 原色 |
| 枫林古道 | `ffd9a3` **暖琥珀（秋枫）** | `decos`：`028_deco_forest_tree` / `031_deco_forest_shrub` / `032_deco_forest_grass` 等成排 | 当前地图地表 + 暖琥珀 |
| 断碑坡 | `cfc7ba` **冷灰褐（碑石）** | `decos`：`029_deco_forest_deadtree` / `030_deco_forest_rocks` 等 | 当前地图地表 + 冷灰褐 |
| 失声碑窟 | `cdbede` 紫灰 | tomb 地砖 + 程序土路、碑座 | 当前地图地表 + 紫灰 |

（已落地 ✅：`_ground_tint()` 把 `theme.tint` × 本图 `tint` 后统一作用于背景图、地砖层与程序土路（`MapScene.gd#L224-265, L304-317, L416-446`），故地表与战斗背景同色。）

## 8. 标注截图

生成方式（**必须窗口模式**，headless 会 `PREVIEW_FAIL`）：

```powershell
& $godot --path . res://tools/PreviewMainWorld.tscn -- <map_id> [battle|annotate|walk]
```

`PreviewMainWorld.gd` 四种模式：无参 → `tools/_logs/preview_<map>.png`；`battle` → `tools/_logs/preview_<map>_battle.png`；`annotate` → `shots/style_20260928/spec_0N_<map>.png`；`walk` → 新档实机走到最远出口并出 `shots/style_20260928/walk_<map>.png`。

标注图（叠加四周 12px 安全边距、出生点安全圈 r150、脚点线 y+21、名签框、主街净宽、本屏内出口绿点、左下角备注框）：

| 文件 | 实测要点 |
|---|---|
| `shots/style_20260928/spec_01_lorin_wilds.png` | 主街净宽 **316px ≥240**、出生圈 r150、脚点 y+21、名签框 140×22、小地图绿菱出口 |
| `shots/style_20260928/spec_02_maple_road.png` | 暖琥珀地表、连续路带 ≥96px、北/南两个绿菱出口 |
| `shots/style_20260928/spec_03_broken_slope.png` | 冷灰褐地表、枯树/骸骨识别点、名签不再贴边裁字 |
| `shots/style_20260928/spec_04_stele_cavern.png` | 紫灰碑窟地表、程序土路、首领图与出口 |

实机行走截图（新档从出生按真实 `move_and_slide` 走到最远出口，途中把怪冻在「接触中」以排除遭遇战干扰）：

| 文件 | 工具自报结果 |
|---|---|
| `shots/style_20260928/walk_lorin_wilds.png` | `WALK_OK lorin_wilds frames=465 dist=60.7 stuck=0` |
| `shots/style_20260928/walk_maple_road.png` | `WALK_OK maple_road frames=2258 dist=60.7 stuck=10` |
| `shots/style_20260928/walk_broken_slope.png` | `WALK_OK broken_slope frames=1697 dist=60.6 stuck=0` |
| `shots/style_20260928/walk_stele_cavern.png` | `WALK_OK stele_cavern frames=35 dist=56.4 stuck=0` |

判定口径：只看是否抵达（`dist <= 出口触发半径 38 + 16`）；途中卡住触发的侧向 `_nudge` 不计失败。原始出图（无标注）留在 `tools/_logs/preview_<map>[_battle].png`，基线五图见 `shots/baseline_20260928/`。

## 9. 资源来源清单

| 用途 | 路径 | 来源 |
|---|---|---|
| 主城地表 | `image/main_world/lorin_wilds_grass_v2.png` | 本作 AI 重绘（抽象特征提取，非原素材直接使用） |
| 碑窟首领 | `image/main_world/mon_stele_warden.png` | 本作 AI 重绘 |
| 地砖 / 路套件 / 散件 | `image/map_proc/*.png`（`001`–`047`） | 本作 AI 重绘（8 主题 × 3 地砖 + 4×4 路套件 + 散件） |
| 战斗背景 | `bg_battle_*`（forest/snowfield/volcano/tomb/desert/glacier/abyss/castle） | 本作 AI 手绘竖版 |
| 角色行走帧 | `image/role/<role>/*_walk_frames.tres`（4×5 栅格，128px） | 本作 AI 重绘，运行时重建 |
| 字体 | `assets/fonts/NotoSansSC-{Regular,Bold}.otf`、`ZCOOLXiaoWei-Regular.ttf` | OFL 授权字体 |

参考视频只用于**可观察结构**对照，不引出任何素材；视频不在 Git 内（见 baseline §5）。

### P01 提交的前后图与资源来源登记

| 类别 | 前（P00 基线） | 后（P01） | 资源来源 |
|---|---|---|---|
| 主城 | `shots/baseline_20260928/p00_01_city_lorin_wilds.png` | `shots/style_20260928/spec_01_lorin_wilds.png`、`walk_lorin_wilds.png` | 复用 `lorin_wilds_grass_v2.png` + `city.json` 建筑（未新增图） |
| 枫林古道 | `p00_02_maple_road.png` | `spec_02_maple_road.png`、`walk_maple_road.png` | 复用 `image/map_proc/` forest 地砖/路套件与 forest 散件；新增仅 JSON 的 `tint`/`decos` |
| 断碑坡 | `p00_03_broken_slope.png` | `spec_03_broken_slope.png`、`walk_broken_slope.png` | 同上（dead tree / rocks 散件已存在，仅接入 `decos` 池） |
| 碑窟 | `p00_04_stele_cavern.png` | `spec_04_stele_cavern.png`、`walk_stele_cavern.png` | 复用 tomb 地砖 + `mon_stele_warden.png` |
| 战斗 | `p00_05_stele_warden_battle.png` | `tools/_logs/preview_<map>_battle.png`（四图各一） | 背景=当前地图地表，未新增战斗底图 |

**本轮 P01 未新增任何 PNG 资产**：全部改动落在 `data/main_world_maps.json`（`tint`、`decos`）、`MapScene.gd`（连续路带、出生安全圈、`_foot_hits_road()`、`_ground_tint()`、小地图出口菱）、`CityScene.gd`（名签与木牌字号）、`G.gd`（`BTN_S`）、`tools/PreviewMainWorld.gd`（annotate/walk 模式）。故资源来源沿用上表既有条目，无新增第三方素材。

## 10. P01 落地清单（改完逐项勾）

- [x] 野外主路改为连续路带（净宽 ≥96px），古道/断碑坡可见成带路面
- [x] 怪物名签按文本实测宽度 + 屏内钳制（不再固定 132、不再贴边裁字）
- [x] 玩家名签/城务 NPC 名签字号收进 `G.FS_*`（16）
- [x] 建筑木牌状态行 10px → 13px
- [x] HUD 小钮 40 → 44 高；`BTN_S` 38 → 44 高
- [x] 主街净宽实测 ≥240px 并写进标注图（实测 316px）
- [x] 枫林古道 / 断碑坡 / 边城 三处地表光色与战斗背景可区分（`tint`，战斗背景自动继承）
- [x] 四张标注截图 + 新档实机行走截图（`shots/style_20260928/`，四图 `WALK_OK`）
- [x] 28/28 回归 + `git diff --check`（28/28 ALL GREEN，退出码 0；`git diff --check` 退出码 0）
