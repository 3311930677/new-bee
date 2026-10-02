# 《远征》未修复问题总清单（截至 2026-10-02 20:xx）

> 本文是**唯一一份"还没修的东西"的合并清单**，把三份文档的未处理项收口到一处，供排期与逐条销项。
> 来源：`2026-10-02-gap-audit-vs-target.md`（原报告 G/D 条目）、
> `2026-10-02-gap-audit-review-and-new-findings.md`（复核 F/N 条目）、
> `2026-10-02-simple-fixes-applied.md`（本轮已修项）。
> 所有"现状"列均为**本次重新实机核验**的值，不是转抄。

## 已完成（不在本清单内）

本轮「简单问题」批修 7 个文件，回归 **46/46 全绿**，真实档哈希未变。已修项：
N-03 地图建议等级、N-17 `stretch/aspect`、N-05 词条硬编码（4 处）、普攻回能、层难度系数、
`verify_trait` 新增第 9 段守卫、`.gitignore` + 根目录清理、以及上一轮的 F-03 战斗结算丢战利。
详见 `2026-10-02-simple-fixes-applied.md`。**以下全部是没修的。**

---

## 一、P0 · 实现层缺陷（不修则"绿"是假的）

| # | 问题 | 现状实证 | 为什么没顺手修 |
|---|---|---|---|
| **F-01** | `VerifyPerf` 是 flaky 用例：整套回归中超时（CityScene 418ms > 预算 320ms），单独跑 3 次全绿 | 预算硬编码 `VerifyPerf.gd:167 BUDGET_CITY_MS = 320`；该用例排第 33 位，受前 32 个场景加载后的 GC/缓存状态影响。它是**唯一**测真实性能预算的用例 | 属"改阈值/加预热"还是"优化 CityScene"方向未定；改阈值等于放水，需你定 |
| **F-02** | runner「存档未污染」检查有盲区，真实存档目录残留文件**已从 61 涨到 69 个** | `run_regression.ps1:291-297` 只哈希 `save.json` **本体**，新增备份档不改变本体哈希→永远抓不到；真实目录现 69 项（`save_*` 61 + `save.json` + 7 other），其中 `save_backup_*.json` 内容是真实玩家档 | 修法明确（前后做 `user://` 全清单快照断言 + 统一重定向 13 个用例的 `SAVE_PATH`），但涉及 13 个用例改动，超出"简单" |
| **N-01** | 主线经验**双写冲突**：`story_quests.json`(s01–s28 旧值 / s29–s32 已与 v2 同值) 与 `campaign_growth.json` 两个可写源，无一致性断言 | `CampaignGrowth.gd:35` 旧档补领差额 = `steps.exp − story_quests.reward.exp`；s29–s32 两表同值 ⇒ **补领恒为 0**。加总 148,127 恰落 lv49，说明跳变是设计意图，但现在"只改一表无任何回归拦截" | 属数据源治理（要么 merge 成单源，要么加一致性断言），是设计决策 |
| **N-02** | 等级上限 60，但内容终点只有 **49 级** | 主线结束 lv49，lv49→60 还需 234,825 经验 ≈ **398 局历练**；而 `titles.t_legend`(lv60)、`growth.equip_visual_tiers` 后两档(50/120/250)、`talents` tier-10 都按 50–60 设计。**即使补完第四幕，这 11 级仍无正常经验来源** | 与 G-01 一起决策（补第四幕时顺带扩经验曲线），单独改会破坏前三幕等级校准 |

---

## 二、已识别但**需你拍板**（不猜）

| # | 问题 | 两难在哪 | 候选改法 |
|---|---|---|---|
| **N-06** | `mentor_curriculum.json` 四职业第三档 `level:35` + `after:"s24"` 错位。`MentorCurriculum.gd:25` 先查 level 再查 story ⇒ s24 后玩家须**再打一场 s25** 才能学第四式，UI 却提示"先完成：矿道留痕" | 前两档 `level` 恰好等于 `after` 步 `target_level`（12↔s12、25↔s20），第三档 `level 35` 恰好等于 **s25** 的 target，`after` 却写 s24(32)。两种改法方向相反，数据无裁定依据 | ① `after→"s25"`（推迟一档）② `level→32`（提前一档）——**二选一，指向相反，需语义裁定** |
| **N-07** | `equip.json` 稀有度 4「史诗」**永不产出**：30 个模板分布 `{1:6,2:6,3:18}`，无任何 rarity=4；`drops.json` 装备池也只有 [1,2]/[2,3]，`drop_weight:3` 从未参与 | 是内容决策：要么补 4 条史诗模板并放开掉落池，要么删掉 rarity4 行（连带 `equip.json` 4 档定义） | ① 补模板+改 drops ② 删 rarity4 |
| **B** | `Combatant.MAX_ENERGY=100` / `BASIC_INTERVAL_TICKS=60` 与 `growth.json energy.max` / `basic_attack_interval` 同源但不联动 | 被 `BattleScene.gd` / `SkillSystem.gd` 以 `Combatant.MAX_ENERGY` **静态**访问（5 处），`const` 无法运行时读表 | 改成 `static func` 取值并同步 5 个调用点（本机已有注释提示"改表须同步"） |

---

## 三、死配置字段（改了也不生效 —— 策划最危险的一类）

| # | 字段 | 现状 | 说明 |
|---|---|---|---|
| **N-04a** | `growth.json equip_visual_tiers:[50,120,250]` | 全仓 0 引用 | 装备外观分档**功能未实现**，不是读错值 |
| **N-04b** | `growth.json basic_attack_interval:2.0` | 全仓 0 引用 | 与 `BASIC_INTERVAL_TICKS` 重复定义 |
| **N-04c** | `gacha.json daily_free:1` / `ten_guarantee:"purple"` | 0 引用，面板把 `n>=10` 与"每日免费"文案硬编码 | 每日免费抽/十连保底**未实现** |
| **N-04d** | `monsters.json` 46 条的 `theme` 字段 | 全 0 消费 | 怪物主题标签无读取方 |
| **N-04e** | `pets.json` 9 条 `evolve_to` / `star_cap` | 悬空，0 消费 | 宠物进阶**未实现** |
| **N-05b** | `traits.json` 的 `hook` 字段 | `TraitSystem.gd:44` 只判断 `== "passive"`，其余 `on_hit/on_crit/on_kill/...` 9/10 取值零消费 | 词条**数值**本轮已接线，但 `hook` 语义字段仍是死的 |

> 处理二选一：**接线**（等于做功能）或**删字段**（消除"看起来可配其实没用"的陷阱）。建议至少先在这几张表加 `_note` 标注"未接线"。

---

## 四、测试体系（未修）

| # | 问题 | 现状 |
|---|---|---|
| **N-08** | 4 个用例是**假验证**：`VerifyDrops` 仅 5 条断言；`VerifyPerf` 8 条纯耗时无功能不变量；`VerifyTransit` 11 条靠 `src.contains("change_scene_to_file")` **字符串扫描**；`VerifyNav` A 组靠文本匹配 `is_action_pressed("ui_cancel")` | 改名或注释掉按钮即假失败，"字段存在"证明不了行为正确 |
| **N-09** | 大量用例把**数据表当前值写死成期望值**：`VerifyCampaignGear.gd:31`(模板==30)、`VerifyGrowth.gd:98-101`(30 节点/6 槽/6 坐骑)、`VerifyGacha.gd:56`(pity==60)、`VerifyThirdSide.gd:39`(18 支线)、`VerifySecondAct.gd:279`、`VerifyStory.gd:173`、`VerifyRouteScene.gd:94,114,179` | 策划改表即批量假失败，无法区分"真回归"与"表改了" |
| **N-10** | `VerifyRouteScene.gd:230-231` 收尾只还原 `wallet` 就 `G.save_game()` 写盘 | 见 F-02，是污染真实档的直接来源之一 |
| **N-11** | `VerifyDrops` 恰恰缺**事务/幂等断言** | 而 F-03 的丢战利 bug 正在它该覆盖的领域；修 F-03 时未补对应用例 |

---

## 五、资源层（未修，含可直接回收空间）

| # | 问题 | 现状实证（本次重核） | 可回收 |
|---|---|---|---|
| **N-12** | `image/role2/` 是 `image/role/` 的整目录副本 | 58 文件 / **62.9 MB**；同路径 48 相同 / **9 不同** / 1 仅 role2 有；`src/` 0 引用；带 `.gdignore`。**待你点头后 `git rm -r 远征/image/role2`**（可从 `f8dedff` 恢复） | **62.9 MB** |
| **N-13** | `image/map/` 完全未被运行时引用，跑的是 `image/map_proc/` | `map/` 145 文件 / **49.9 MB**，全 1254×1254 RGB 整幅；`map_proc/` 94 文件 / 0.5 MB，同名 94 组 **MD5 全不同**，proc 是 48×48 RGBA。运行时只加载 `map_proc`（`data/maps.json`/`city.json` 的 `asset_dir`）；`map/` 仅被 `tools/verify_data.gd:38,41` 以 `file_exists` 断言引用 | 需接线（但整幅图不是 48px tile，用法待定） |
| **N-15** | 多版本素材并存，重绘必选错 | `main_world/*_reference_v*` **52 个**（v1/v2/v3…并存）；`classic_floor_reference_v1/v2` 两版；`generated_334_341/ready/world_*.png` **8 张各约 1.5MB，仅 `world_forest.png` 被引用**（⇒ 雪原/沙漠/火山/墓地都用森林图当背景） | ~16 MB |
| **N-16** | 坐骑图 4 张各 1330×1182 / 约 1.06MB，`MountPanel.gd:92-97` 用 `EXPAND_IGNORE_SIZE` 缩到 ~120px | `image/mounts/` 4 张真图（+4 import） | 显存 ~25MB |
| **N-21** | 字体 4 个共 **46.0 MB** 均被引用 | `NotoSerifCJKsc-SemiBold.otf` **23.6MB**、NotoSansSC Bold 8.3 / Regular 8.1、ZCOOLXiaoWei 6.0 | 子集化可省 **40 MB+** |
| **N-22** | 目录卫生 | `远征/tools/_logs/` **4010 文件 / 77.6 MB** —— 已被 `远征/.gitignore:8 tools/_logs/` 忽略 ✅；真实 `user://` 残留 **69 项**（见 F-02，**未清**） | 清理残留 |

> 注：`NVIDIA Corporation/` 目录**已不存在**（不在清单）；`image/ui_kenney/` 顶层目录**不存在**，Kenney 素材实际在 `image/generated_201_333/ready/ui_kenney/`（见第八节更正）。

---

## 六、功能缺口 G-01 ~ G-24（原报告口径，本轮**未碰**）

> 复核结论见 `2026-10-02-gap-audit-review-and-new-findings.md` §4：除 D-02 与 §2 的计数/结论外，**G 条目全部成立**。

**P0（阻塞"复刻完成"）**
| # | 缺口 | 现状实证（重核） |
|---|---|---|
| **G-01** | 结局与第四幕后半整体缺失 | `story_quests.json` 仍 **32 步**，s32 `next:""` 且发放 `stele_key`；全库「界碑深处」仅 1 处 goal 文案，无对应地图 ⇒ **断头仍在**（未提交的 G.gd/MapScene 改动触及第四幕旗标，但未补 s33–s36） |
| **G-02** | 副本仍是单房 | `stele_cavern`/`tidal_gate`/`rift_mine_vault` 三图 `node_type:boss`、`monster_count:1`、`entities:{}`（零实体）、仅 1 出口 |
| **G-03** | 支线只完成一半 | `side_quests.json` **18 条**（a1/a2/a3 各 6），第四幕 0 条；`live` 字段多为 `null` 靠代码硬判 |
| **G-04** | 美术风格整体未达标 | 地表仍是程序化纯色块（根因见 N-13）；R-08 逐张重绘多轮延后未交付 |
| **G-05** | 无人工时长与安卓真机验收 | 只有自动化回放；从未真机触控；唯一性能用例还是 flaky（F-01） |

**P1**
| # | 缺口 |
|---|---|
| **G-06** | 守碑誓约（庇护/征伐/丰收三契约）完全缺失 —— 全库 grep 0 命中 |
| **G-07** | 阵营关系系统完全缺失 —— grep 0 命中 |
| **G-08** | 延期交割合约完全缺失 —— grep 0 命中 |
| **G-09** | 坐骑地形特性缺失；6 坐骑只有"首骑"1 种有四职业骑乘图（`image/mounts/` 4 张真图） |
| **G-10** | 骑乘四向为单帧静态、无走路动画（`MountVisual.frames_for()` 每方向仅 1 帧） |
| **G-11** | 8 个历练主题复用同一卷轴+相同节点排列，仅主题染色区分 |
| **G-12** | 长屏/异形屏适配未验证（`stretch/aspect` 本轮已补，安全区代码仍 0 引用） |
| **G-13** | 背包/工坊信息架构未收敛（三物品时下方约 200px 空白） |
| **G-14** | 战斗信息层优先级未收敛（预兆/施法/宠物名/能量/操作面板叠读） |
| **G-15** | 历练局不落档（`RouteScene.pending_run` 仅进程内，已跨 3 包未解决） |

**P2**
| # | 缺口 |
|---|---|
| **G-16** | 两项命名/结构差异未收口（第一幕 12 步 vs 8 节点；"碎碑守卫"≠"失声碑灵"） |
| **G-17** | 装备模板 30 个仍不足以支撑四幕换代；逐幕职业保底首通验收在推进 |
| **G-18** | 宠物养成维度偏薄（只有 3 条 `companion_growth.traits`，III 幕 s24 后才开放） |
| **G-19** | 图鉴仅宠物一类（无怪物/地理图鉴、无"可能来源"掉落展示） |
| **G-20** | 图标语义未统一（高光/描边/主体占比/分辨率混用） |
| **G-21** | 建筑落地阴影雪地/草地逐张核对未完成 |
| **G-22** | issue #43：引擎退出期 RID 泄漏诊断长期未解决（每轮回归 67–77 条） |
| **G-23** | 音频量偏少、无地区专属 BGM（6 BGM 按"界面类型"划分） |
| **G-24** | 无发布包（总方案 §11.1 要求"安装包与操作说明"，S7 未启动） |

---

## 七、文档层 D-01 ~ D-07（未更正）

| # | 问题 | 复核状态 |
|---|---|---|
| **D-01** | 历轮把 `VerifyStory` 18 条 / `VerifySave` 1 条记为"未定位失败"并逐轮复制 | 根因实为 `APPDATA` 未导出致 `user://` 变相对路径（环境假象）——**文档尚未更正** |
| **D-02** | 用例总数记录混乱（出现 28/29/…/46 多种说法） | 实为 **46 条**，默认 `-Expected 46` **正确**；原报告据此写的"会 FATAL"是**误判**，待更正 |
| **D-03** | P01"视觉样板已完成"表述过时 | 未更正 |
| **D-04** | 总方案正文未同步"失声碑灵"更名与"第一幕 12 步" | 未更正 |
| **D-05** | 存档哈希迭代 `C5D29EE5…` 与 `BA8054B3…` 并存 | 实测当前 `BA8054B3…`；未统一 |
| **D-06** | 设计卡自述"装备模板 14 个"，实测 30 个 | 未同步，会让排期基于错误基数 |
| **D-07** | 大量"未完成项"只写结论不写证据 ID | 未补充 |

---

## 八、⚠️ 需从审计报告**更正/撤销**的发现（本次重核结论）

这三条原本记在 `gap-audit-review-and-new-findings.md` 里，**本次复查判定为误报/过期**，清单中不再作为待办：

| 原编号 | 原报告说法 | 实测结论 |
|---|---|---|
| **N-14** | 4 处 `res://` 引用指向不存在的文件（`city_%s_reference_v2.png` 仅 3 个 `frost_*`、`mon_lost_beast_reference_v2.png` 等） | ❌ **误报**。`image/main_world/` 下 `city_*_reference_v2.png` **11 张全在**（archive/barracks/forge/frost_guardhouse/frost_lodge/frost_supply/gate/hall/kennel/shrine/storehouse）；`mon_lost_beast.png`、`mon_shadow_wolf.png` 也都在（是改名后的成品）。引用**未断裂** |
| **N-19** | 505 张 ≥4096px 的图完全不透明（无 alpha） | ❌ **本次未复现**。全 `image/` 扫描"≥4096 且 无 alpha(ct=0/2)"命中 **0 张**。该条目作废（若曾存在，已被后续重绘覆盖） |
| **N-20** | `ui_kenney/` 是外部素材包，含 9 张奇数边长图导致抖动 | ⚠️ **路径写错**。顶层 `image/ui_kenney/` **不存在**；Kenney 素材实际在 `image/generated_201_333/ready/ui_kenney/`（含 `LICENSE.txt`，CC0）。**"风格偏离来源"的定性待重新取证** |

> 另：`NVIDIA Corporation/` 目录已不存在；`远征/tools/_logs/` **已被 gitignore**（原 N-22 的两半已解决一半）。

---

## 九、建议处理顺序（合并后）

| 序 | 事项 | 类型 | 成本 |
|---|---|---|---|
| 1 | **F-03 已有修复 + 补 `VerifyDrops` 事务断言（N-11）** | 正确性 | 低 |
| 2 | **F-02** runner 加 `user://` 快照断言 + 清真实目录 69 个残留 | 止血 | 中 |
| 3 | **F-01** `VerifyPerf` 去 flaky（定阈值 or 预热） | 可信度 | 低–中 |
| 4 | **N-12 删 `role2/`**（等你点头，回收 62.9MB） | 清理 | 极低 |
| 5 | **N-02 + N-01** 与 **G-01** 一起决策（等级上限/经验单源/补第四幕） | 设计 | 高 |
| 6 | **N-13/N-15** 美术**接线+清理**（不是重绘）；N-21 字体子集化 | 资源 | 中 |
| 7 | **N-06/N-07** 等三个"需拍板"项定方向 | 决策 | 低 |
| 8 | **G-02/G-03** 副本多房 + 支线补 36；**N-08/N-09** 测试体系整改 | 功能/质量 | 高 |
| 9 | G-06~G-24、D-01~D-07 按原报告顺序 | 收尾 | — |

---

## 十、当前工作区状态（提醒）

- 分支 `xajh-remake`，HEAD `f8dedff`。**工作树有大量未提交改动**：本轮 7 个文件 + 上一轮遗留的
  `src/autoload/G.gd`(+49) / `src/explore/MapScene.gd`(+51)（含第四幕旗标、`world_puzzle_interact`、`requires_flags` 路由）。
  **这些未提交改动不属于"未修清单"，是进行中的工作，勿回退。**
- `远征/shots/fourth_front_20261002/evidence/*.log` 有一批被回归运行改写的日志（M 状态），属产物噪音。
- 真实存档已备份：`D:\new bee\_audit_backup\save.json.bak`（哈希 `BA8054B3…5BE7`）。
