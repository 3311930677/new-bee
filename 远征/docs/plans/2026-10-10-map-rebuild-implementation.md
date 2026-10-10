# 昭元边城 / 枫林古道 重建 · 实施记录

依据：`ui_review_input/world_map_replan_20261010/outputs/WORLD_MAP_REBUILD_PLAN.md` 与 `WORLD_MAP_ASSET_BRIEF.md`，参考图1（亮色森林小路画法）、图2（枫树框景与城镇空地）。

## 改了什么

| 范围 | 改动 | 文件 |
|---|---|---|
| 地表 | 程序绘制：亮草（多层色 + 小花）、有机沙路（边缘起伏 + 草穗过渡）、城内奶油色广场（鳞纹铺砖 + 金黄草缘）、枫溪河道（石岸 + 水纹）与石桥。取代原来的纯色底 + 硬边路。 | `src/world/SunnyTravelArt.gd`、`tools/BakeSunnyGround.gd` |
| 框景 | 野外两侧成排秋色树（橙、黄、粉红），城内四角枫树；树冠与建筑矩形不重叠。 | `SunnyTravelArt.scenery` |
| 昭元边城 | layout v4：城门移到北端横跨主街，议事厅居南端为尽头焦点；9 栋建筑、9 名 NPC 与 2 名访客重排；默认出生点保持 (480,930)。 | `data/main_world_maps.json` |
| 枫林古道 | layout v3：枫溪横贯、只留石桥段通行；修桥四个任务点随桥移到河岸；旧路石匣移出桥头。 | `data/main_world_maps.json`、`src/explore/AftermathBridge.gd` |
| 碰撞 | 城门门洞可穿行（`city_passable`）；河道以阻挡体封闭，修桥后一侧木栏开口。 | `src/city/CityScene.gd`、`AftermathBridge.gd` |
| 存档 | 旧版城内坐标若落在新建筑底座内，读入时迁出；古道旧坐标若落在河道中，移到河岸。 | `src/explore/MapScene.gd` `_ready` |
| 寻路 | 自动前往跨河时先绕到桥轴，否则南岸去驿亭会卡在河岸。 | `src/explore/MapScene.gd` `_river_detour` |
| 散件 | 河道两侧 10px 内不落随机散件。 | `src/explore/MapScene.gd` `_build_decos` |

## 未改动

- 主角、NPC 美术与缩放；存档字段；任务脚本；出口的目标地图与开放条件（`requires_story: s12` 仍生效）；敌人种类、奖励与刷新。
- 地图尺寸 960×1248；相机 1.15；HUD。

## 验证

- 布局检查 `shots/map_rebuild_20261010/check_layout_v4.py`：148 项通过（NPC 与建筑底座边缘 ≥78px，NPC 彼此 ≥72px，出生点、到达点、出口、所有实体可达，实体不落在阻挡内）。
- 样板验证 `VerifySunnyTravelSamples`：227 项通过。
- 回归子集（18 项，含 VerifyMainWorld、VerifyMapScene、VerifyCity、VerifyWorldSession、VerifyQuests、VerifyTransit、VerifyStory、VerifySave、VerifyAftermath 系列、VerifySignpostEntry、VerifyNav 等）：17 项通过。
- 未通过：`VerifyFieldUI`（"货币不足应说明阻断原因"）。断言落在 `src/ui/` 与 `tools/VerifyFieldUI.gd`，这两处在工作区中已有未提交的既有改动（本次未修改）。是否在改动前已失败，尚未用 HEAD 版本单独核实。
- 寻路模拟：带绕行规则时 7 条路线全部到达；关闭绕行时南岸去驿亭会卡住。

## 测试调整

- `VerifyMainWorld`：原断言锁死上一版布局（店铺分列 x≤330 或 ≥630、NPC x≤400 或 ≥560、版本号 3）。改为：建筑底座在地图内且互不压住，NPC 不站进底座，版本号 4，旧档读入不落在建筑底座或出口牌内。
- `VerifySignpostEntry`：原断言要求"停在出口牌内读档必须登记防回切"。新布局下出生点附近的推开规则会把玩家移出触发区，因此改为不变量：要么已登记防回切，要么已离开触发区。

## 已知问题

- 巡界导师（npc_mentor）因中轴街道限制，无法同时离巡界厅与锻造铺 78px 以上，站位在广场边缘。
- 退出时的 RID/资源泄漏诊断仍在，按 issue #43 单列。
- 本次仅在 Windows、Godot 4.6.1 上验证，未在 Android 真机验收触控。
- `VerifyFieldUI` 失败需要单独排查：先确认它在 HEAD 上是否已失败。

## 对比图

`shots/map_rebuild_20261010/compare/`：每张为改前（左）/改后（右）同视角，共 10 张，覆盖边城入城、广场、议事厅、建筑与 NPC 同框、全图；古道南口、石桥与岔口、东侧盐道口、北坡、全图。
