# V4 P4 阶段验收报告（18 张探索地图地貌重绘、出生阵纹、第四幕石槽与全量打磨）

## 1. 阶段目标与范围
按照 [`docs/2026-10-28-商业化画面重构方案.md`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/docs/2026-10-28-%E5%95%86%E4%B8%9A%E5%8C%96%E7%94%BB%E9%9D%A2%E9%87%8D%E6%9E%84%E6%96%B9%E6%A1%88.md) §4.24 及第 6 节 P4 要求，完成 18 张区域探索地图的商业化地貌构件替换、出生点阵纹与路牌避让、头顶名牌清晰度修复、第四幕三色导光石槽重绘，并通过全部自动化验证套件。

## 2. P4 核心技术实现

### 2.1 出生点阵纹与路牌防遮挡（[`MapScene.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/explore/MapScene.gd)）
- **出生点阵纹 (`_SpawnGlyph`)**：在玩家出生坐标脚下新增 `z_index = -6` 的契约法阵纹理节点（绑定 `F-01` 的 `spawn_glyph_1..3`），当玩家离开出生点超过 `48px` 时平滑淡出。
- **路牌视觉避让 (`visual_offset`)**：当 `_WorldExit` 锚点距离玩家出生点 `< 132px` 时，保持 `marker.position` 与 `_world_exit_touch_rect(row)` 物理交互框 100% 不变（确保导航与触发测试零回归），自动将路牌精灵与文字胶囊平移至路侧（纵向道路偏移 `Vector2(-96, 0)`，横向道路偏移 `Vector2(0, -72)`），彻底解决出生点路牌遮挡「沈舟」角色模型的问题。
- **路牌与头顶名牌胶囊底板**：为 `_WorldExit._caption_label`、`_SteleRoomGate`、`_TidalRoomGate`、`_QuestEntity._caption_label` 统一配备黑漆金边圆角胶囊底板 (`Color("120f10", 0.90)` + `1px Color("c29a5b", 0.78)`)。

### 2.2 全屏环境层豁免与头顶名牌 100% 清晰度（[`MapScene.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/explore/MapScene.gd)）
- 修复 `_name_tag_exclusions()`（第 6579 行），将 `["TopScrim", "AmbientVignette", "WeatherVFX", "DirectionalSunbeams", "ForegroundCanopy"]` 加入全屏遮罩豁免列表，防止 `TopScrim` (`960x186`) 误触发角色与怪物的名牌半透明避让逻辑，使 18 张地图的 `沈舟 Lv35` 与怪物等级名牌恢复 100% 不透明度。

### 2.3 五大生态区域地貌构件精确映射（[`KitV4.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/ui/KitV4.gd) / [`IllustratedScenery.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/explore/IllustratedScenery.gd) / [`WorldDressing.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/world/WorldDressing.gd) / [`SecondaryMapEnhancer.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/explore/SecondaryMapEnhancer.gd)）
- 彻底清理非林地地图中跨区复用的绿色苔藓石块，按 18 张地图所属的 5 大生态绑定 `F-02..F-06` 专属商业化地貌边缘群：
  1. **断碑坡 / 岗哨营 / 风裂谷 / 沉木泽 / 碑窟** (`broken_slope`, `watch_post`, `wind_valley`, `marsh_wood`, `stele_cavern`) → `F-06` 青苔残碑、倒塌石柱、石灯笼与枯木构件。
  2. **旧盐道 / 潮滩 / 沉渡口 / 潮门** (`old_salt_road`, `tideflat`, `sunken_ferry`, `tidal_gate`) → `F-03` 盐晶簇、晒盐木架、破损盐车与潮湿礁石。
  3. **赤砂道** (`red_sand_route`) → `F-02` 风蚀赤砂岩柱、荒漠兽骨与商队木桩。
  4. **白岭关 / 霜望营 / 雪桥** (`white_ridge_pass`, `frost_watch_camp`, `snow_bridge`) → `F-04` 覆雪松木、冰凌岩石与冰封拒马。
  5. **裂矿口 / 裂矿深层 / 渊环 / 碑林外围 / 碑林圣所** (`rift_mine_mouth`, `rift_mine_depths`, `abyss_ring`, `stele_outskirts`, `stele_sanctum`) → `F-05` 锁链黑曜石方尖碑、暗紫矿晶簇与深渊符文石板。

### 2.4 第四幕三色导光石槽与 T 型节点重绘（[`FourthActGround.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/explore/FourthActGround.gd) / [`AssetCompletion.gd`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/src/world/AssetCompletion.gd)）
- 接入 `F-07` (`f07_base_h`, `f07_glow_h`, `f07_base_t`, `f07_glow_t`)，将石槽宽度收敛为精致的 `24px` 雕刻凹槽 + `18px` 发光内芯，补齐中央竖向主干道 (`x=480, y=880..266`) 与 `(480, 880)`、`(480, 625)`、`(480, 375)` 三处 T 型交汇石座 (`38x38`)，并根据三声部（绿 `#93bf95`、蓝 `#82bacb`、白 `#d1dceb`）动态着色。

## 3. 自动化测试与全量审计结果
- **全流程视觉审计 (`CurrentVisualAudit.tscn`)**：`CURRENT_VISUAL_AUDIT_OK steps=141`（产物位于 [`shots/v4_p4/audit/`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p4/audit/)）
- **多分辨率响应式审计 (`CurrentResponsiveAudit.tscn`)**：`RESPONSIVE_CAPTURE_OK shots=132 overruns=0`（产物位于 [`shots/v4_p4/responsive/`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p4/responsive/)）
- **视觉打磨专项验证 (`VerifyVisualPolish.tscn`)**：`VISUAL_POLISH checks=199 failures=0`（产物位于 [`shots/v4_p4/polish/`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p4/polish/)）
- **路牌入口与碑林解谜验证 (`VerifySignpostEntry.tscn` / `VerifyStelePuzzle.tscn` / `VerifyRequestedOptimizations.tscn`)**：全部 0 失败通过。
- **18 张地图 Before | After 对比图**：[`shots/v4_p4/comparisons/`](file:///D:/new%20bee/%E8%BF%9C%E5%BE%81/shots/v4_p4/comparisons/)
