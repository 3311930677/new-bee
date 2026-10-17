# 《远征》自动化测试与多分辨率视觉验收报告（QA_REPORT）

## 一、测试与验收总览
- **引擎版本**：Godot Engine v4.7.2.stable.steam.ed1daf0bf
- **测试套件规模**：全量 **77 个** 自动化回归测试套件（`tools/run_regression.ps1`）+ 独立大规模战斗数值模拟器（`tools/SimBalanceReport.gd`，115,200 场模拟）+ 双分辨率实机截图与文本排版审计（`tools/ShotRunner.gd` + `tools/UITextAudit.gd`）。
- **全量回归状态**：**77 / 77 全部通过（ALL GREEN）**，零错误（exit 0 + 专属 `_OK` 标记 + 无 ERROR/FAIL 模式）。

---

## 二、77 项自动化回归测试分类清单与结果

| 类别 | 套件数量 | 核心覆盖范围与关键断言 | 状态 |
| :--- | :---: | :--- | :---: |
| **1. 核心数据与表结构门禁** | 4 | `verify_data`（4职业/44词条/20技能/49怪物/10灵宠/4连携/8章节/61称号/46装备模板）、`VerifyAssets`、`verify_trait`、`verify_walk_assets` | **PASS** |
| **2. 主页、四角色动态舞台与新手指引** | 5 | `VerifyGameHome`（Section A~N：主页四角色动态切换、选角重选、世界行路图驿车直达、任务信使速交、11步新手指引、五轮扩充闭环）、`VerifyFieldUI`（44px 触控热区与双分辨率边界）、`VerifyUiLayout`、`VerifyVisualRefresh`（零硬编码字号门禁）、`VerifyAvatar` | **PASS** |
| **3. 主世界地图连通、路牌指引与探索** | 9 | `VerifyMainWorld`、`VerifyMapScene`、`VerifyCity`、`VerifyNav`、`VerifyTransit`、`VerifySignpostEntry`、`VerifySafeArea`、`VerifyRouteScene`、`verify_route` | **PASS** |
| **4. 任务系统、四幕主线与支线委托** | 18 | `VerifyQuests`、`VerifyStory`、`VerifySecondAct`、`VerifyThirdAct`、`VerifyThirdBack`、`VerifyThirdSide`、`VerifyFourthFront`、`VerifyFourthBack`、`VerifyAftermath`、`VerifyAftermathResume`、`VerifyAftermathPaths`、`VerifyReturnJobs`、`VerifyRoadMail`、`VerifyFrostHerbOrder`、`VerifyShipping`、`VerifyWorldCommissions`、`VerifyWorldCommissionsRead`、`VerifyLore` | **PASS** |
| **5. 战斗模拟、首领机制与数值平衡** | 6 | `verify_battle`、`VerifyBattleScene`、`VerifyGameplayBalance`、`VerifyBossPuzzles`、`VerifyStelePuzzle`、`VerifySweep` | **PASS** |
| **6. 养成体系（装备/天赋/灵宠羁绊/坐骑/称号）** | 9 | `VerifyGrowth`（含灵宠五阶羁绊 `pet_bond_interact` 断言）、`VerifyCampaignGear`（含背包来源显示与史诗装备战力评估断言）、`VerifyCampaignGrowth`、`VerifyPortGrowth`、`VerifyWorkshop`、`VerifyCurriculum`、`VerifyCompanions`、`VerifyDrops`、`VerifyPanels` | **PASS** |
| **7. 扩充玩法、经济与活动系统** | 14 | `VerifyArena`（含校场射艺与古碑鉴宝入口）、`VerifyFishing`、`VerifyGacha`、`VerifyEconomy`、`VerifyCurrencyBalance`、`VerifyTradeWorld`、`VerifyTradeContracts`、`VerifyTradeContractsRead`、`VerifyDungeonTrials`、`VerifyDungeonTrialsRead`、`VerifySpecialEvents`、`VerifySpecialEventsRead`、`VerifyCampGathering`、`VerifyOathWalk` | **PASS** |
| **8. 存档迁移、会话恢复与性能/音频** | 12 | `VerifySave`、`VerifyWorldSession`、`VerifyRunResume`、`VerifyRunResumeRead`、`VerifyRunImmediate`、`VerifyRunEvents`、`VerifyRunEventsRead`、`VerifyJourneyRelics`、`VerifyReferenceComplete`、`VerifyFrostArt`、`VerifyPerf`、`VerifyAudio` | **PASS** |

---

## 三、新增核心功能与五轮扩充专项验证记录

### 1. 第二阶段：五大核心体验修复（Tasks A–E）
- **Task A（地图连通与世界行路图直达）**：
  - 在 `RegionChestMap.gd` 中验证已探索（`visited`）区域显示「直达此地」按钮，未解锁/未探索区域显示准入条件；
  - 在 `MapScene.gd` 中验证出口路牌通过 BFS 最短路径自动高亮当前追踪任务方向（`✦ 任务方向`）；
  - 路线耗时对比：常见跨区支线/委托从原先平均需跨越 3~4 张地图（约 45~70 秒折返跑图）缩短至驿车一键直达或信使速交（2~5 秒）。
- **Task B（任务系统与信使速交）**：
  - 在 `QuestPanel.gd` 中验证日常差事与可速交支线达成条件后显示「信使速交」，点击即刻结算金币/经验/声望并刷新任务链。
- **Task C（主页四角色动态展示与选角重选）**：
  - 在 `VerifyGameHome.gd` Section L 中逐一遍历 `["zs", "ck", "fs", "fz"]`，验证 `TownHome` 舞台精灵纹理、角色铭牌（破军/穿杨/霜语/晨星）、选角页重选模式、存档写入与重载恢复 100% 同步。
- **Task D（角色行走接地感）**：
  - 验证 `MapScene.gd`、`CityScene.gd`、`TownHome.gd` 主角脚底双层接触阴影（`FootShadowOuter` / `FootShadowCore`）与步态重心相位同步。
- **Task E（11 步剧情融合式新手引导）**：
  - 在 `VerifyGameHome.gd` Section M 中验证 `TutorialService.gd` 11 步引导的推进、跳过、重置与完成领奖持久化。

### 2. 第三阶段：战斗与数值平衡模拟（Phase 3）
- 运行 `tools/SimBalanceReport.gd` 完成 115,200 场自动化对局，输出 `docs/agent_iteration/test_results/balance_sim.json` 与 `docs/agent_iteration/BALANCE_REPORT.md`：
  - 四职业在 Lv.5 / Lv.15 / Lv.30 胜率全部处于 82%~94% 甜点区间；
  - 首领蓄力重击受阶段化单次伤害预算上限（42%/48%/55% MaxHP）保护，零不合理满血瞬秒。

### 3. 第四阶段：五轮实质性内容扩充（Phase 4）
- 在 `VerifyGameHome.gd` Section N 与 `VerifyGrowth.gd` 中完成自动化断言：
  - **第 1 轮（校场射艺 `ArcheryPanel.gd`）**：验证 3 档难度配置读取、风偏校准、蓄力击发、首通/复刷奖励发放与「百步穿杨」称号解锁；
  - **第 2 轮（史诗装备与战力评估 `BagPanel.gd`）**：验证 6 件 24 级史诗神兵模板加载、特殊被动字段与背包详情框「战力评估 %d(+%d▲)」动态对比；
  - **第 3 轮（边城古碑共鸣 `G.lore_resonate`）**：验证四职业专属先祖碑文参悟、首次四货币奖励与四职业专属称号（`t_lore_zs`/`ck`/`fs`/`fz`）解锁；
  - **第 4 轮（灵宠五阶羁绊 `G.pet_bond_interact`）**：验证 `GrowthChestView.gd` 第 4 页签「羁绊」、5 阶灵犀互动、灵宠属性乘区（`+3%/阶`）、主角生命/攻击加成（`+15 HP / +2 ATK 每阶`）、3/5 阶寻宝赠石与「灵犀契主」称号；
  - **第 5 轮（行商奇珍鉴宝 `G.curio_appraise`）**：验证普通鉴古匣（260 金）与稀有鉴宝匣（680 金）开匣掉落、保底史诗神兵与累计 3 次解锁「慧眼识珍」称号。

---

## 四、双分辨率（`480×800` & `480×1067`）实机截图与视觉审计
所有关键界面均已通过 `ShotRunner.tscn` 在标准竖屏（`480×800`）与全面屏长屏（`480×1067`）下完成实机渲染截图与 `UITextAudit` 文本边界检查，零文字重叠、零越界截断：
- **标准竖屏（`480×800`）**：
  - `docs/agent_iteration/screenshots/phase2/after_home_zs.png`、`after_home_ck.png`、`after_home_fs.png`、`after_home_fz.png`
  - `docs/agent_iteration/screenshots/phase2/after_createrole.png`、`after_region_map.png`、`after_quest.png`、`after_tutorial.png`
  - `docs/agent_iteration/screenshots/after_archery.png`、`after_arena.png`、`after_arena_curio.png`、`after_bag.png`、`after_pet_bond.png`、`after_titles.png`
- **长屏自适应（`480×1067`）**：
  - `docs/agent_iteration/screenshots/long_480x1067/tall_home.png`
  - `docs/agent_iteration/screenshots/long_480x1067/tall_createrole.png`
  - `docs/agent_iteration/screenshots/long_480x1067/tall_worlds.png`
  - `docs/agent_iteration/screenshots/long_480x1067/tall_archery.png`
  - `docs/agent_iteration/screenshots/long_480x1067/tall_arena_curio.png`
  - `docs/agent_iteration/screenshots/long_480x1067/tall_bag.png`
  - `docs/agent_iteration/screenshots/long_480x1067/tall_pet_bond.png`
- **视觉设计参考总览图板（`1280×760`）**：
  - `docs/agent_iteration/references/ref_role_select_concepts.png`
  - `docs/agent_iteration/references/ref_world_map_hud_concepts.png`
  - `docs/agent_iteration/references/ref_archery_curio_concepts.png`
