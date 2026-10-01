# 主世界重构实施记录（2026-09-27）

后续执行任务与下一位 agent 的首轮交接见 [后续实施交接方案](2026-09-27-next-agent-implementation-handoff.md)。
P00–P04 交叉审查的已修问题和高风险待办见 [审查问题清单](2026-09-28-p00-p04-review-issues.md)；此清单是后续交接的质量门槛，不能用既有 29 项全绿替代其中的进程中断与整段游玩验收。
当前前端和图像的同屏问题、局部修正与后续重绘顺序见 [前端 UI 与图片风格复查](2026-09-28-ui-art-review.md)。
该方案 P00「锁定可复现基线」已完成，事实记录见 [P00 基线锁定记录](2026-09-28-baseline.md)：`bdcd474` 工作树全量保留、回归 28/28 全绿且未写真实存档、夹具与五张 480×800 实机图已归档。P00 未改动玩法代码。

P01 的布局、可用性规范与主城可走性已完成（2026-09-28）；**参考画风与整套美术样板仍未验收**。规范见 [480×800 同屏视觉样板](2026-09-28-style-spec.md)，实施记录见下文「2026-09-28 P01」段；2026-10-01 依据用户反馈与录屏重新核对的根因见 [参考画风偏差诊断](2026-10-01-reference-style-diagnosis.md)。

P02「世界事件与事务」已完成（2026-09-28），契约与存档字段见 [P02 世界会话与一次结算设计](2026-09-28-p02-world-session-design.md)，实施记录见下文「2026-09-28 P02」段：新增 `WorldSession`／`QuestService`／`RewardLedger`，存档升 v4 并加逐版迁移与语义校验，7 行崩溃点矩阵通过，回归 29/29 全绿。

P03「主世界战斗完整纵切」已完成（2026-09-28），设计与测试计划见 [P03 主世界战斗完整纵切设计](2026-09-28-p03-battle-slice-design.md)，实施记录见下文「2026-09-28 P03」段：遭遇升级为显式状态机与 `result_id` 幂等结算，敌方预兆（图形环 + 实时倒数）、失声碑灵两阶段与破绽窗口、四指令竖排详情与首领战禁撤退、战后位置／镜头／怪物状态恢复全部落地，回归 29/29 全绿。

P04「装备实例、背包、工坊、宝石与旧档等值迁移」已完成（2026-09-28），设计与测试计划见 [P04 装备实例与背包设计](2026-09-28-p04-equipment-inventory-design.md)，实施记录见下文「2026-09-28 P04」段：新增 `Inventory` 拥有池模型（`instances[]`／`pending[]`／`next_uid`，装备不占格），存档升 v5 并做 v4→v5 等值迁移与幂等，满包掉落进待领取箱、缺钱不扣物、重复点击只生效一次，`BagPanel` 与 `EquipPanel` 入口落地可见换装，回归 29/29 全绿。

本记录对应《远征》总方案 `2026-09-24-yuanzheng-master-plan.md` 的 S1、S2 一部分，以及 S3 的货币来源清理。总方案与联机附件仍是后续改动的设计基准；现有内容是可运行的首批纵切，不代表四幕单机内容已经完成。

## 本批玩家能做什么

1. 新角色完成序章后直接出生在昭元边城；旧角色读档后回到主世界最近记录位置。角色头顶显示创角昵称，不显示登录账号。
   旧档若已有职业但缺昵称，登录时只补填昵称，原职业和养成不会重新创建。
2. 边城基础设施开局开放，建筑与 NPC 位于中央主路两侧。北门通往枫林古道，古道通往断碑坡，各出口可双向返回。地区图展示连通关系、当前位置及等级段；历练八主题仍由巡界厅进入。
3. 城内与野外的明雷只游荡，靠近接战。野外战斗胜利直接结算金币和经验；地图各自记录怪物刷新时间，切图重返不串档。历练仍保留原来的战斗收益与词条玩法。
4. “边城失声”首章共有 12 步：前 8 步走访边城、古道和断碑坡；青姨的旧卷线索开启碑窟入口；玩家进入碑窟、击败失声碑灵取得碑文，带回铁匠修复，最后向闻叔复命。任务物领取与消耗同任务进度一起存档，不能重复领。
5. 金币是主世界日常流通币；远征币服务界碑历练，魂晶服务伙伴，荣誉来自演武。签到、城内活动和一般世界战斗不再混发专用货币；荣誉兑换不能直接制造金币、远征币或魂晶。
6. 边城锻造铺明示五种材料的购价与回收价。野外所得的同类材料可出售换金币；回收价严格低于购价，且没有库存不能重复出售。
7. 枫林古道和断碑坡的主路已改为连通的连续道路。主世界同图战斗保留敌左我右、宠物参战，四个指令改为底部稳定横排，角色移动时按钮不跳位。碑窟首领有独立立绘、顶部血条和单怪战斗编成；首次击败后不再刷新。
8. 装备改为**实例**：每件有独立 UID，掉落进背包或待领取箱，可在背包里比较、穿上、卸下、卖出，也可在工坊强化／镶嵌宝石／拆宝石／合成高阶宝石，并做精炼词条。穿上不同稀有度装备后，地图上玩家名签描边与手中武器外观随之改变。旧档的三槽强化／宝石／词条按等值迁移保留，不归零。

## 2026-09-28 前端 UI 调整

- 主世界将药剂、伙伴、疾行、营帐收成右下角四个 52×52 操作钮；主线签贴状态栏，在城内避开城务委托签。点击主线签仍可看完整目标与奖励。
- 营帐页改为明确的“返回主世界”主按钮，显示上次所在地区；上方目标改读当前主世界主线，不再显示界碑历练首领目标。角色预览缩小，右侧补充玩法入口收紧间距。
- 登录页羊皮纸上的辅助文案加深以提高对比。主世界同图战斗取消与“技能”指令重复的常驻技能格；展开“技能”后仍可点选五项技能，历练战斗保留原技能栏。
- 已用 Godot 4.7.2 在 480×800 实际画面检查营帐、边城、古道、古道战斗与技能展开页，截图在 `tools/_logs/preview_home_ui.png`、`preview_lorin_wilds.png`、`preview_maple_road.png`、`preview_maple_road_battle.png`、`preview_battle_skills_ui.png`。28 项全量回归通过，真实玩家存档未改动。当前只是主页面第一轮布局清理，P01 的各地区视觉样板与全局字体／弹窗规范仍待完成。

## 2026-09-28 P01 视觉样板与主城可走性

按 [交接文档](2026-09-27-next-agent-implementation-handoff.md) §4 的 P01 执行；唯一权威规范是 [480×800 同屏视觉样板](2026-09-28-style-spec.md)（§10 九项落地清单全部完成）。

- **同屏规范**：四图 20×26 格（960×1248 世界 px，格 48）、主世界镜头 zoom 1.15 偏移 −34，同屏世界范围 ≈417×696px；脚点/显示高度、名签框、主街净宽、HUD 四周 12px、触控区 ≥44px、字号六档下限 13（FS_XS）全部写进样板并落地。
- **连续路带**：查清「古道/断碑坡像稀疏踩踏土块」的真实原因是路面只有 1 格宽 48px（不是掩码断带）；`_path_cells` 改为 2 格宽连续路带（净宽 ≥96px），每格必有正交前驱。
- **出生安全**：出生安全圈改为按**本图真实出生点**避让 150px（原用「地图底部中央」估算点，与实际 `spawn` 差上百像素）；主世界散件新增 `_foot_hits_road()` 二次筛选——脚部碰撞盒（40×s × 26 @ y=−13）压到主路格即剔除，修掉「走在路上被树根绊住」。
- **地表光色**：四图 `main_world_maps.json` 加 `tint`（边城原色 / 古道 `ffd9a3` 暖琥珀 / 断碑坡 `cfc7ba` 冷灰褐 / 碑窟 `cdbede` 紫灰），`_ground_tint()` 统一作用于背景图、地砖层与程序土路；两张野外加 `decos` 地貌识别点池。
- **战斗背景机制修正**：主世界战斗 cfg 是 `presentation == "classic_inline"`，`BattleScene._build_background()` 直接 return，战斗画面叠在当前地图地表上，**自动继承该图 tint**，不走 `bg_battle_*`。
- **可读性**：怪物名签 `_clamp_label()` 按画布变换钳进屏幕，盒宽按文本实测；玩家名签与城务 NPC 名签收进 `G.FS_SM 16`；建筑木牌状态行 10px→13px；HUD 小钮 40→44、`BTN_S` 120×38→120×44。
- **出口可辨**：小地图新增出口绿菱（`requires_story` 未完成时画灰菱），出生点与主街任一位置都能看到出口方向。
- **实测**：主街最窄净宽 **316px ≥240**（forge↔gate 那排）；四图「出生→最远出口」实机行走 `WALK_OK`（`frames/dist/stuck`：边城 465/60.7/0、古道 2258/60.7/10、断碑坡 1697/60.6/0、碑窟 35/56.4/0）。
- **交付物**：`shots/style_20260928/spec_01..04_<map>.png`（标注图）与 `walk_<map>.png`（实机行走图）；`tools/PreviewMainWorld.gd` 重写为支持无参/`battle`/`annotate`/`walk` 四模式。**本包未新增任何 PNG 资产**，来源清单见 style-spec §9。
- **验证**：全量回归 **28/28 ALL GREEN**（每个用例 exit 0 + 自身 `_OK` 行 + 无错误模式；真实存档未改），`git diff --check` 退出码 0。
- **未完成**：跨图连续返城（一条进程内走完主线）尚未验收；底图/怪物/NPC 图像重绘属后续批次。

## 2026-09-28 P02 世界会话与一次结算

按 [交接文档](2026-09-27-next-agent-implementation-handoff.md) §4 的 P02 执行；契约与存档字段的权威定义是 [P02 世界会话与一次结算设计](2026-09-28-p02-world-session-design.md)。

- **三个稳定契约**：`WorldEvent`（`event_id = "<type>|<map_id>|<source_id>"`，只描述「发生了什么」）、`EncounterContext`（`encounter_id = "<map_id>#<spawn_id>#<tick>"`，含确定性种子）、`RewardTransaction`（`tx_id` + `costs` + `grants` + `world_flags`）。
- **三个服务模块**（`src/world/`，全为 `class_name` 静态类）：
  - `WorldSession`：地图状态、唯一刷点 `spawn_id(map_id,idx)` 跨图不撞键、到达点与安全位 `safe_position()`、怪物生命周期（`mark_spawn_defeated` / `spawn_respawn_at`）、遭遇锁 `new_encounter` / `commit`（首次 `true`、重复 `false`）、首领首胜 `mark_boss_cleared`、`normalize_state()` 归一。
  - `QuestService`：`plan(state, rows, event, inventory)` 只从事件推进目标，纯函数返回 `{ok, reason, step_id, next_state, consume_item, reward, event_id}`；`reason ∈ no_step／no_match／duplicate／missing_item／ok`。
  - `RewardLedger`：按 `tx_id` 去重发放，`apply(tx, ledger, host)` 付不起时零副作用，`host` 约定走 `wallet`／`items`／`prog` + `gain_exp`／`grant_item`。
- **存档 v3→v4**：`prog.main_world` 加 `encounters`／`respawn_by_map`／`bosses_cleared`，`prog` 加 `ledger`／`flags`，`prog.story` 加 `goals`；`SaveData.CURRENT_VERSION = 4`，逐版迁移链 `v1→v2→v3→v4` 齐全，旧档 v1–v3 可读、未来版本仍拒绝覆盖。**读档安全位不落盘**，进图时由 `WorldSession.safe_position()` 按当前存活怪当场算（确定性、可单测）。
- **崩溃点矩阵 7 行**（`tools/VerifyWorldSession.gd`，token `WORLD_SESSION_OK`）：开战前 / 战斗中 / 结算前 / 结算后未返回地图 / 切图写档中 / 交付任务物时 / 满包发奖时。各行断言「不重奖、不卡档、状态可归一」，结算重放只发一次金，满包时任务物照常入账。
- **接入**：`MapScene` 的接战、结算、切图、位置恢复改为经三个服务调用（`_start_battle` → `new_encounter`，`_on_battle_end` → `commit` + `mark_boss_cleared`／`mark_spawn_defeated`，`_bank_main_world_rewards` → `RewardLedger.apply`，`_check_world_exits`／`_persist_main_world_progress` → `normalize_state`）；`G.story_event()` 重写为事件 → `QuestService.plan` → `RewardLedger.apply` → 落盘的事务路径。
- **本轮修掉一类静默数据丢失缺陷**：GDScript 的 `dict.get(k, {})` 在缺键时返回**临时默认容器**，之后对该值写入会丢。全部改为不带缺省值的 `var v = dict.get(k)` 再判类型显式赋值，涉及 `SaveData._ensure_v4`、`WorldSession`、`QuestService`、`RewardLedger`、`G.ledger()`。若不修，遭遇锁、刷新计时、首领首胜、主线 `goals`、账本去重会全部失效。
- **验证**：全量回归 **29/29 ALL GREEN**（每用例 exit 0 + 自身 `_OK` 行 + 无错误模式；真实存档未改），`git diff --check` 退出码 0；`run_regression.ps1` 用例表新增 `VerifyWorldSession`、`-Expected` 28→29。
- **未完成**：历练局落档（`RouteScene.pending_run` 仍在进程内）未在 P02 解决，归入 P03「胜败逃闭环与结果恢复」；跨图连续返城同 P01 仍未验收。

## 2026-09-28 P03 主世界战斗完整纵切

按 [交接文档](2026-09-27-next-agent-implementation-handoff.md) §4 的 P03 执行；设计与测试计划的权威定义是 [P03 主世界战斗完整纵切设计](2026-09-28-p03-battle-slice-design.md)。

- **显式状态机**：`WorldSession` 把遭遇从"一个 status 字段"升级为转移表驱动的状态机 `""→approach→locked→battle→result_pending→committed→return`（分支 `fled`／`failed`）。`advance()` 走 `ALLOWED` 表，非法转移返回 `bad_transition` 且不落盘；`record()` 改为**合并写入**（保留 `result`／`result_id`），修掉"`committed→return` 之后查不到这场结算过"的问题。
- **唯一结算入口**：`result_id = "res|<encounter_id>|<result>"`；`settle_result()` 先按 `encounter_id` 去重、再记 `result_id`，只有返回 true 才发奖——同结果上报两次、已 `committed`／`fled`／`failed` 一律 false。`MapScene` 的接战、结算、返回改由该状态机驱动。
- **敌方预兆（文字 + 图形）**：`BattleSim` 前摇期（`WINDUP_TICKS` 12 tick / 首领 15 tick）在场地上出脉动环——施法者脚下 + 将要挨打者身上（首领技粗环、普通细环，随剩余前摇收缩），同时按剩余前摇实时倒数「首领技 · 碑震 · 蓄力 0.4s」。表现层是 `SkillSystem._pick_targets` 的**确定性镜像**（不调用 `pick_basic_target`，逐帧刷新不摇 `sim.rng`，不污染战斗随机序列）。
- **失声碑灵两阶段 + 反击窗口**：`mon_stele_warden` 配 `phases`（表驱动，仅该怪生效）：≤50% 血解锁「失声悲鸣」+ 永久加速；≤22% 血永久破防 + 自身硬直。阶段只触发一次（记 `once_flags`），阈值按整数血量比例判定、无随机；广播 `{"t":"phase"}`，表现层出居中横幅并把阶段名追加到顶部血条。新 buff `break_window`（破绽）在 `Combatant.take_damage` 内按 `(1+pct)` 放大受击伤害，与技能 `after.self_buff` 共用 `BattleSim.apply_buff_spec` 一处口径。**未配 `phases` 的主题首领（含历练编成）行为与数值完全不变**。
- **四指令详情**：技能／道具页由"一排 62px 小签"改为整宽竖排列表（行 402×28，底边固定、按行数向上长）：技能行写 Lv／耗能／冷却（就绪或 `X.Xs`）／范围；道具行写数量与效果（药剂 ×N · 恢复 35% 生命；换宠「每场一次 · 替补名」）。四枚指令之上新增常驻信息条「攻 集火 X 42% ｜ 技 2/5 ｜ 物 药×2」。「逃」的后果文案说在点之前：普通怪「退出本节点，保留战损与进度」，剧情首领（`flee_rule=blocked`）按钮置灰、点击只出「首领战不可撤退」。
- **战后恢复**：主世界战斗是**叠在地图上的表现层**（`classic_inline`），地图／玩家／相机／怪物对象全程不销毁；P03 显式补齐 `_restore_after_battle()`（动画回待机、`_world`／`_hud` 复现、清接触锁）、存活怪 `retreat_home()` + 接触冷静期（结算层消失的下一帧不会被同一只怪二次拖入）、结算后立刻 `_persist_main_world_progress()` + `G.save_game()`（位置与刷新时间同一次写档）。
- **验证**：`VerifyWorldSession` 崩溃点矩阵 7 → **10 行**（新增①状态机顺序与非法转移不落盘、②`result_id` 确定性与 `settle_result` 幂等、③`fled`／`failed` 为终态）；`VerifyBattleScene` 新增预兆环与蓄力倒数、阶段横幅与血条阶段名、剧情首领禁撤退（置灰 + 文案 + 点击不结算）、弹页竖排几何与「逃」后果文案断言；`verify_battle`（纯 sim）新增失声碑灵阶段阈值与"只触发一次"、`break_window` 放大且确定性、无 `phases` 首领同种子哈希不漂移三组断言。全量回归 **29/29 ALL GREEN**（每用例 exit 0 + 自身 `_OK` 行 + 无错误模式），`git diff --check` 退出码 0，真实存档哈希未变；**用例数保持 29**（`-Expected` 不动）。
- **未完成**：历练局落档（`RouteScene.pending_run` 仍在进程内，进程被杀则该局不可恢复）本轮未做，转 P04；跨图连续返城（单进程走完主线）同 P01 仍未验收。

## 2026-09-28 P04 装备实例、背包、工坊与旧档等值迁移

按 [交接文档](2026-09-27-next-agent-implementation-handoff.md) §4 的 P04 执行；数据模型、服务契约与测试计划的权威定义是 [P04 装备实例与背包设计](2026-09-28-p04-equipment-inventory-design.md)。

- **拥有池模型（唯一权威口径）**：新增 `src/world/Inventory.gd`（`class_name` 静态类）。`prog.inventory = {instances[], pending[], next_uid}`，`instances` 是**拥有池**（背包里的与穿在身上的**都在里面**），`prog.equip[slot] = uid` 只是「槽位指向哪个实例」。**装备不占背包格**：背包已用格 = instances 中未被 `equip_map` 指向的条数。实例形状含 `uid / tpl / slot / rarity / lv / gems[] / affixes[] / locked / sockets`；模板决定名称／基础／孔数，稀有度只决定展示色、回收价倍率与掉落权重，**不加战斗数值**。
- **配置增量**（`data/equip.json` v2）：`slots[].base` 与 `templates[]` 里 `tpl_<slot>_basic.base` **逐字段相等**（旧档等值迁移的前提）；新增 `templates[]`（含 `tpl_sword_wolf` 精良 / `tpl_sword_ruin` 稀有等掉落模板）、`rarity[]`（四档，色 1=b8b8b8 / 2=6cc06c / 3=5aa0e0 / 4=c070e0）、`bag.capacity=60`、`merge`（3 合 1 宝石，确定性）、`drop`（普通 0.12／精英 0.35／首领 1.0）。
- **存档 v4→v5 等值迁移**：`SaveData.CURRENT_VERSION = 5`，新增纯函数 `_migrate_v4_to_v5` + `_ensure_v5`（逐版链 `v1→v2→v3→v4→v5` 齐全）。旧档的 `prog.equip.{sword,armor,accessory}`（旧 dict：`lv / gems[] / affixes[]`）按槽搬成实例并回填 `equip[slot]=uid`，模板取 `tpl_<slot>_basic`，**lv／gems／affixes 逐字段保留**；`cur is int or float` 时跳过，因此迁移幂等。`_normalize()` 对**所有版本**都跑 `_ensure_v4 + _ensure_v5`；`validate()` 增加 v5 形状检查（`prog.inventory` 与 `prog.equip.*` 必须是非负整数 uid）。旧钱包材料与已投入强化不删除、不折损。
- **掉落到待领取箱**：`RewardLedger` 增 `EQUIP_PREFIX := "equip:"`，`apply()` 的 equip 分支调 `host.inv_grant_equip({"tpl":…, "rarity":…, "n":…})`。**满包时装备进 `pending[]` 待领取箱，任务物仍照常入账**（不整单失败、不静默丢物）；缺钱时零副作用、不扣物；同 `tx_id` 重复点击只生效一次。`MapScene` 掉落入事务并挂外观刷新钩子。
- **UI**：新增 `src/ui/BagPanel.gd`（背包：页签／容量 x/60／列表／详情／与在身装备对比／装备·锁定·卖出按钮）；`EquipPanel` 与 `GameHome` 增入口，工坊可强化／镶嵌／拆宝石／合成宝石／精炼。卖出带二次确认（强化／稀有／锁定装备必须确认），0 级普通装备无需确认。**可见换装**：`G.equip_appearance()` 让玩家名签描边随稀有度变色、手中出现武器图标，`MapScene._refresh_player_appearance()` 应用。
- **测试（用例数保持 29）**：`VerifyGrowth` 新增 10.5 节（背包实例／卖出确认／锁定不可卖）；`VerifySave` 新增 **B3 段**「v4→v5 装备实例化：旧强化投入等值搬运」——断言 `steps == ["v4→v5"]`、三槽 `equip[slot]` 为整数 uid、实例 `tpl == tpl_<slot>_basic`、`lv/gems/affixes` 与旧档逐字段相同、`G.equip_slot_bonus(sid)` 与按旧档权威口径独立重算的期望加成一致、**再迁移一次 uid 不变且 instances 不增长**、结果通过 `validate`；新增合成夹具 `tools/fixtures/saves/v4_equip_progress.json`。`VerifyWorldSession` 行 7「满包发奖」语义改写为「满包时装备掉落进待领取箱、任务物仍照常入账」。
- **截图**：`shots/p04_20260928/` 四张 480×800——`equip_basic_lorin_wilds.png`（卸下武器：名签回落原绿、手中无武器）与 `equip_rare_lorin_wilds.png`（稀有武器：名签描边变蓝 `5aa0e0` + 手中武器）为**除在身武器外完全同参的对照图**；`bag.png`（页签／容量 3/60／列表／详情／比较「攻击 −9」／装备·锁定·卖出 1200 金）；`equip_panel.png`（背包按钮、合成切换、卸下按钮）。
- **修掉一处截图工具风险**：`tools/ShotRunner.gd` 原先**未重定向 `SAVE_PATH`**，其 `_demo_prog()` 会整体替换 `G.prog` 并落盘，可能把真实 `user://save.json` 改写成演示档；已与 `PreviewMainWorld.gd` 同做法加守卫（`G.SAVE_PATH = "res://tools/_logs/save_shot_runner.json"`），实测截图运行前后真实存档哈希不变。
- **验证**：全量回归 **29/29 ALL GREEN**（每用例 exit 0 + 自身 `_OK` 行 + 无错误模式；真实存档哈希未变），`git diff --check` 退出码 0；**用例数保持 29**（新断言塞进既有用例，`run_regression.ps1` 的 `-Expected` 不动）。
- **未完成**：历练局落档（`RouteScene.pending_run` 仍在进程内）本轮仍未解决，转后续包；跨图连续返城（单进程走完主线）同 P01 仍待验。

## 2026-09-28 P00–P04 审查修复（第二轮）

依据 [P00–P04 审查问题清单](2026-09-28-p00-p04-review-issues.md) 处理。R-01／R-02／R-03 接手时已是工作树中修好的状态，本轮只核验、未重做；新修三项、补一项工具、延后一项。

- **R-04 安全写盘与启动恢复**（`src/save/SaveData.gd`、`src/autoload/G.gd`、`src/explore/MapScene.gd`、`src/world/Inventory.gd`）：新增 `SaveData.save_text(path, text, stamp, backup)`——完整写临时文件 → 回读校验 → 滚动备份（`BACKUP_KEEP=3`）→ `.prev` 改名就地替换 → 失败回滚；`write_text_atomic()` 委托它（`backup=false`）。启动恢复改 `SaveData.pick_readable()`，显式区分 `main/tmp/prev/backup/none/unreadable` 六态：`none` 才是真新档，`unreadable` 只告警、不改写内存、不锁写，非 `main` 的可用档写回主档。`G.save_game() -> bool`（锁定/写失败 `false` + `push_error`）；`G.inv_claim()` 写盘失败用新增的 `Inventory.return_to_pending()` 回滚；`MapScene._settle_main_world()` 改回 `"ok"/"dup"/"save_failed"`，写失败提示「战利未落袋」。坏档解析改走静默的 `SaveData._parse_silent()`（`JSON.new().parse()`），避免坏档 fixture 刷引擎错误被判红。
- **R-05 v5 装备引用深校验**（`src/save/SaveData.gd`）：`_ensure_v5()` 对「容器存在但类型错」不再静默替换成空数组（只补缺键，类型错交给 `validate()` 判非法），`next_uid` 只向上修 `maxi(next_uid, max_uid+1)`、不复用号、不删物；新增 `_validate_inventory()` 挂进 `validate()`：实例必需字段、槽/模板/稀有度枚举、UID 跨 `instances+pending` 唯一、`equip[slot]` 指向同槽拥有池实例、`next_uid > max_uid`。**顺带修掉一处真实缺陷**：深校验块与 `last_ts` 未来水位校验原先被误缩进在 `if eq_v != null:` 内，导致既有两条断言失效。
- **R-07 账本装备预校验**（`src/world/RewardLedger.gd`）：`apply()` 把 `grants` 提取上移到扣成本之前，新增 `_precheck_equips()` 预校验 `equip:` 奖励的模板（`host.equip_tpl()` 非空）与稀有度（`equip_cfg()["rarity"]`；cfg 缺失降级 `rarity >= 1`），不过则整单拒绝、零副作用；发放回调 `host.inv_grant_equip(...)` 返回值必须为 `ok`，否则整单 `_fail` 且不登记事务 ID。
- **R-06 整段真实输入回放工具**：新增 `tools/PlaythroughMainWorld.gd`（+ `.tscn` 与 `tools/run_playthrough.ps1`），不冻结怪物、不调用 `_nudge()`、不瞬移、不直接改 `story`/钱包，用真实移动输入与真实战斗 UI 走完新档主线并做进程重开校验；**不进 `run_regression.ps1` 的 29 用例数**。
- **R-08 显式延后**：四图地表与主线怪／NPC 逐张重绘属整批美术生产，本轮不交付，登记在 [UI 与图片风格复查](2026-09-28-ui-art-review.md) 与审查清单「修复状态」；P01 勾选不代表美术升级完成。
- **测试**：新断言塞进既有用例（**用例数保持 29**）——`tools/VerifySave.gd` 增 F2（`pick_readable` 三态、`save_text` 不残留 `.tmp/.prev`、生成滚动备份、非 JSON 被拒且原档不变）与 B4（R-05 六例 + `next_uid` 倒退），G/J 分区加 `save_game()` 返回值断言；`tools/VerifyWorldSession.gd::_test_ledger()` 加 R-07 三段。`run_regression.ps1` 的 `-Expected 29` 与纯 ASCII 未动。
- **验证**：全量回归 **29/29 ALL GREEN**（每用例 exit 0 + 自身 `_OK` 行 + 无错误模式；真实存档哈希未变），`git diff --check` 退出码 0。

## 2026-09-28 第三轮核验与 P05-A 开始

- R-06 的 `run_playthrough.ps1 -Roles zs,fs` 已在两个独立临时新档通过 A 阶段真实输入和 B 阶段跨进程读档，覆盖 s01–s12、胜／败／逃、满包掉落、任务物交付、返城和账本重放；真实玩家存档哈希不变。回放脚本自身修正了 NPC 提前触发、出口提前停步、撤退二次点击与战斗节点释放后的回调。
- 全流程发现 `Inventory.roll_drop()` 的真实缺陷：JSON 稀有度读成浮点，整数 `Array.has()` 把首领必掉装备池判空。稀有度先归一为整数后，满包首领胜利确有 1 件装备进入待领取箱；`VerifyWorldSession` 增固定种子断言。
- R-07 进一步做到发放回调意外失败的内存回滚：成本、已发金币／经验／材料和装备容器全部恢复，事务 ID 不登记。定向 `VerifyWorldSession` 通过。
- `VerifyPerf` 首轮发现旧城进场偶超 320ms；`CityScene` 散件贴图按种类预取后，定向实测旧城 278ms、召唤首次 87ms。更完所有用例后全量回归 **29/29 ALL GREEN**，真实存档哈希不变，`git diff --check` 通过。
- **P05-A 修碑纵切已交付**，实施目标与剩余批次见 [P05 第一幕内容闭环](2026-09-28-p05-first-act-implementation.md)。s11 从碰到石头即自动交物改为可选择的“精炼石锻合”或“金币拓录”；`QuestService` 记录方法与成本，`RewardLedger` 同笔扣发，`G.story_event` 保存失败恢复快照；断碑坡光色／出口名签与石头、青姨的对白随修碑状态改变。`VerifyStory/VerifyCity/VerifyMainWorld` 定向通过，**骑士与法师分别真实点击回放 A+B 通过**，480×800 画面见 `shots/p05_repair.png`。P05 的六支线、可选首领、导师／首宠／首骑等仍待实施。

## 2026-09-28 P05-B 野外交互与支线底座

- **支线表与状态机**：新增 `data/side_quests.json` 六条（`a1_rel_guard`／`a1_rel_child`／`a1_eco_roots`／`a1_eco_tracks`／`a1_trade_cart`，`a1_elite_beast` 待 P05-C 开门）；`QuestService` 增独立支线状态机 `SIDE_ACTIVE/SIDE_READY/SIDE_DONE`——collect／observe 按实体 `source_id` 的 `seen` 去重、defeat 按地图计数、deliver 需持有 `objective.item`，交付消耗 `turn_in_item`；接取前发生目标不计数，同一时间只追踪 1 条。`WorldSession.entity_taken` 提供 `once` 永久／日期键仅当天两种实体取走语义。
- **野外实体**：`main_world_maps.json` 六处实体（古道：旧风铃、草根 ×2、古道驿亭；断碑坡：足迹 ×2），`MapScene` 按 `G.side_entity_visible` 生成、接触半径 44px 交互，采集／观察／送达后即时清场；HUD 新增支线蓝签（只显示当前追踪，城内 y172／野外 y132，点击开日志），小地图支线目标画蓝菱（主线金）。
- **城内钩子**：`CityScene._open_dialog` 调 `G.side_npc_interact`——接取／交付台词优先于每日委托与闲聊，交付走 `_side_complete` 单事务（扣交付物＋发奖＋记线索＋清追踪，同次落盘，失败整体回滚）；`G.side_line()`／`side_info_lines()` 给 HUD 与日志单向文案。
- **拍板记录**（禁用二选一询问，自行拍板并落文档）：①奖励口径调整——`a1_rel_guard` 的“药剂 1”改发**强化石 1**、`a1_eco_roots` 的“药草材料”改发**强化石 2**（局内药剂是历练局 run 内资源不落档；全仓无 `herb` 引用，药草未登记为道具，改成已登记 id 免悬空引用）；②实体生命周期按 `seen` 判生成、**不做每日刷新**（写入 `act1.side_quests.<qid>.seen`，跨读档跨天一致）；③支线交易 ID 实际落盘为 4 段 `side|<qid>|complete|`。
- **真实缺陷修复**：`G._load_save` 的 prog 白名单漏加载 `prog["act1"]`，读档后 `repair_method`／`side_quests`／`tracked`／`discoveries` 静默丢失（也是 P05-A 的隐藏 bug：读档后修碑台词走错分支）。已补白名单加载，缺键由 `act1_state()` 懒归一兜底；`VerifyStory` 覆盖读档往返。
- **素材**：新增 `image/generated_201_333/ready/icons/itm_wind_chime.png`、`itm_salt_pack.png`（48×48 RGBA，同存量图标口径，已导入；`VerifyAssets` 由 `ITEM_NAMES` 全量推导，此前 `MISS: itm_wind_chime, itm_salt_pack` 即由此转绿）。
- **测试与证据**：P05-B 断言全部内嵌 `VerifyStory`（用例数保持 29）；全量回归 **29/29 ALL GREEN**、`git diff --check` 退出码 0、真实 `save.json` 哈希未变；480×800 截图 `shots/p05b_20260928/` 三张（`side_world_chime` 蓝签＋风铃实体＋小地图蓝菱、`side_world_tracks` 追踪 0/2、`side_city_accept` 小满接取台词＋toast），`ShotRunner` 增 `side_world_chime`／`side_world_tracks`／`side_city_accept` 场景。
- **未完成**：失路兽首领与第六条支线 `a1_elite_beast`（P05-C）；导师第二技能／岩龟／首骑／定向装备／订单预览／固定奇遇（P05-D）；四职业 30–45 分钟计时验收（P05-E）。

## 2026-09-28 P05-C 可选首领「失路兽」与首领支线

- **数据**：`data/monsters.json` 新增 `mon_lost_beast`（首领档 hp 240／atk 15／def 8；「嗅踪」`k 1.5`／`cd 11`／表驱动前摇 2.0s；`phases[0]` ≤50% 血解锁「迷路低吼」召 `mon_shadow_wolf`，死亡钩子给 4 秒破绽）与召唤物 `mon_shadow_wolf`（hp 52／atk 11／def 3）；`broken_slope.optional_bosses` 独立于普通怪随机池（刷点序号 1000 起、`level_offset 3`、`respawn 600` 秒、路西 `[140,880]`）；`side_quests.json` 第六条 `a1_elite_beast`「路西兽影」开门（`live: true`），六条支线全部可玩。
- **战斗内核**：`SkillSystem.enqueue_cast` 支持技能级 `windup`（秒 → tick，「嗅踪」2.0s = 60 tick），预兆环与逐帧倒数复用 P03 表现；「迷路低吼」召影狼 → 影狼先死 → 首领 4 秒 `break_window`（×1.35，与 P03 同一口径），`phase` 事件只广播一次（横幅＋「绽」飘字同源）。
- **地图与交互**：可选首领不主动追逐、接触才开战；接触前 **180px 内看见即算一次 observe**（大于接触半径 56px，玩家不必开战，只推进已接支线）；`flee_rule` 对可选首领为 `free`（剧情首领仍 `blocked`）；紫色首领名签＋等级、小地图蓝菱、布告栏线索与闻叔台词随世界旗变化。
- **首胜事务**：`tx = act1|lost_beast|first|`，四职业各一件 rarity 3 蓝装（zs `tpl_sword_ruin`／ck `tpl_spear_iron`／fs `tpl_staff_frost`／fz `tpl_hammer_dawn`）＋图鉴条目＋首杀记录＋世界旗 `act1_lost_beast_down` 同批落盘、写盘失败快照回滚；重复首胜只给普通收益；**可选首领不掷随机装备**。
- **真实缺陷修复**：①首领血条名签宽 118→200px、血条起点 122→204，修掉阶段名被 `clip_text` 裁切（P03 遗留显示缺陷）；②`_fx_layer.z_index = 10`，修掉阶段横幅压住同刻「绽」飘字；③召唤文案「敌方召唤 reinforcements！」中文化。
- **素材**：`image/main_world/mon_lost_beast.png`、`mon_shadow_wolf.png`（AI 母稿洋红底抠图，成品长边 1400，`hard_alpha` 导入）；`monster_sprite_paths` 为召唤物挂独立立绘；`verify_data` monsters 断言 37→39。
- **测试与证据**：P05-C 断言全部内嵌 `VerifyStory`（用例数保持 29）；全量回归 **29/29 ALL GREEN**、`git diff --check` 退出码 0、真实 `save.json` 哈希未变；480×800 截图 `shots/p05c_20260928/` 四张（`beast_world` 明雷＋名签、`beast_windup` 预兆环＋蓄力倒数、`beast_break` 阶段横幅＋破绽＋影狼、`beast_notice` 布告栏置灰），`ShotRunner` 增 `beast_world`／`beast_windup`／`beast_break`／`beast_notice` 场景。
- **未完成**：导师第二技能／岩龟／首骑／定向装备／订单预览／固定奇遇（P05-D）；四职业 30–45 分钟计时验收（P05-E）。

## 工程与旧档

- 保留旧主世界 ID `lorin_wilds` 及旧坐标迁移，以便 v1–v3 存档继续读入。新增 `prog.story` 缺省为第一步；原钱包四币数量不删除或折损。
- 地区和主线步骤以稳定 ID 在 JSON 表中声明。所有地区出口必须指向存在的目标地图和目标到达点；`VerifyStory` 检验该约束与 12 步结算、任务物领取消耗、读档防重领及碑灵单怪编成。
- 新图像 `image/main_world/mon_stele_warden.png` 与 `image/generated_201_333/ready/icons/itm_stele_fragment.png` 由本地 imagegen 生成，分别作为碑窟首领立绘和任务物图标；已在 480×800 Godot 画面核对首领透明边缘和比例。
- `LoadScreen` 预热主城场景和地区图，避免首次进入时同步编译导致卡顿。
- 主世界入口统一由 `G.enter_main_world()` 设置地图上下文；`GameHome` 保留为营帐菜单和旧内容入口。

## 尚未完成的总方案条目

- S0 美术样板：**P01 已完成同屏视觉规范与地区光色**（[style-spec](2026-09-28-style-spec.md)）；首领立绘和任务物图标已有第一版；主城地面、两野外与碑窟底图、角色／怪物／NPC 图像的**逐张重绘**仍属后续批次。
- S1 的完整支线、任务定位和多种敌影行为反馈；本批只有先行主线与地图引导。
- S2 战斗表现：主世界已重排同图操作区并接入碑窟首领，尚缺分地区战斗美术、首领预兆、宠物站位与结果中断恢复审查。
- S3 物品实例、可见装备、四商品现货、订单、游戏内时间与跨地区交易经济；本批完成既有货币边界和边城材料回收，**P04 已完成装备实例化、背包、工坊（强化／宝石／合成／精炼）与可见换装、旧档 v4→v5 等值迁移**，尚未开始四商品现货、订单与游戏内时钟。
- S4 第一幕已有碑窟入口、1 个独立首领和 12 步主线闭环；**P05-A 已交付可选择的碑文制作，P05-B 已交付 5 条支线（第六条随 P05-C）与古道／断碑坡探索交互，P05-C 已交付第二个机制首领「失路兽」与第六条支线**；仍缺导师／首宠／首骑／定向装备／订单预览／固定奇遇等成长纵切与完整 30–45 分钟体验，未宣称第一幕内容完成。
- S5–S7 的其余城镇与野外、长期养成、完整四幕、视觉统一与安卓发布验收；之后才按联机附件交付 1v1、2v2、3v3 等在线玩法。

## 下一批的实施顺序

1. ~~以 480×800 实机截图确定主街、野外、碑窟和战斗的同屏比例~~ 已由 P01 完成（规范见 [style-spec](2026-09-28-style-spec.md)）；剩余为**按该样板逐张重绘**不合格底图与怪物／NPC 图像，保留可对齐脚点的资源。
2. ~~完成 `WorldSession`、`QuestService` 与主线事件日志，把对话、掉落、战斗和切图从场景脚本迁入可测试的服务，补中断恢复。~~ 已由 P02 完成（另加 `RewardLedger`、存档 v4 与 7 行崩溃点矩阵）；剩余为辅助小接口与体验打磨。
3. ~~做装备实例、背包、工坊、宝石与旧档等值迁移。~~ 已由 P04 完成（见 [P04 设计](2026-09-28-p04-equipment-inventory-design.md) 与实施记录「2026-09-28 P04」段：`Inventory` 拥有池、存档 v5 与 v4→v5 等值迁移、满包进待领取箱、`BagPanel`／`EquipPanel` 与可见换装）；剩余为历练局落档与跨图连续返城。
4. 在已有碑窟和任务物基础上加入第二首领、可选择的碑文制作、6 支线、探索物件与章节奖励，实测第一幕时长和难度。~~可选择的碑文制作~~ 已由 P05-A 完成；~~5 条支线底座与古道／断碑坡探索交互~~ 已由 P05-B 完成；~~失路兽首领与第六条支线 `a1_elite_beast`~~ 已由 P05-C 完成（首胜定向蓝装、可战可察、180px 观察上报、十分钟重刷），剩余为成长纵切（P05-D）与四职业 30–45 分钟实测（P05-E）。
5. 建四商品现货、稳定工作和订单的游戏内时钟与交易台账；再扩到第二座城镇。经济模拟通过后才加入延期合约。

## 2026-10-01 P08-D1 伙伴协战

霜关驿舍新增两项特性训练，覆盖九种已有伙伴、护卫/追击/元素响应、胜利协战与选择随行；原图志、宠物等级/星级/突破/进化和装备投入保留。加入 `VerifyCompanions`，最终39项回归与 runner 11项故障自检通过。四职业从 P08-C 完成档真实走回昭元领取岩龟，再回驿购买所缺宠粮、训练第一项、撤退一次并胜利三次、返驿训练第二项，A/B 重启状态及原始存档相同。截图18张，存档/日志/源文件哈希见 `shots/p08d_20261001/acceptance.json`。

实测修复了随机散件压住明雷巡逻接触范围和 `WorldSession.return` 未挡住重复结算的问题。中文规则换行、Esc返回、败局不加协战、换宠冷却及替补入场快照均有断言；退出时资源诊断 issue43 继续未解决。详见 [本包记录](2026-09-30-p08-third-act-companions.md)。主线28/36、支线18/36、首领6/8、地图14未增加；第三幕等级资源曲线、坐骑/合约/阵营/誓约、第四幕、房间机关、其余任务量及 S4/S7 门槛仍待实施。

## 2026-10-01 P08-E1 等级校准

前三幕固定主线首通经验改为累计 96,036，旧档逐任务版本只补差额；十四图明雷改为固定地区等级。同地图升级立即同步等级/生命，地图血条纳入原装备等生命加成；旧档批量补记仅播放一次升级音。等级公式与 Lv60 上限、原主线剧情及资源奖励不改。

最终完整 40 项回归、11 项运行器自检及声音专项通过。四职业从新档真实 s01–s28 逐幕达到 Lv12/Lv25/Lv42，主线经验占比超过98%；另四职业旧 P08-D1 Lv10 验收档实际入图补记93,511经验至Lv42，原装备/伙伴/金币/道具/任务和永久世界记录保留。新旧两组 A/B 状态和原始存档字节一致；六张截图目检、35张JSON无BOM，正式玩家存档未动。详见 [等级校准记录](2026-10-01-p08-campaign-growth.md) 和 `shots/p08e_20261001/acceptance.json`。

本次内容数仍为主线28/36、支线18/36、首领6/8、地图14。装备保底在下方P08-E2补齐；资源收支、伙伴材料/后续技能路径、六坐骑/阵营/合约/誓约与第四幕继续待做。多房间机关副本、剩余十八支线及十二委托总量、人工计时、动画与Android发布验收仍未完成。

## 2026-10-01 P08-E2 装备保底与画风V1

七个主线节点新增职业适配装备保底和24强化石/3宠粮，已有14模板、随机池与旧投入保留。完成档一次补领，满包进入待领并支持翻页，失败回滚、来源与等级门槛均已验证。41项全量回归与11项运行器自检通过，四职业新档实际主线、四职业旧档补领/实际换装及A/B重启相同，见 [装备切片](2026-10-01-p08-campaign-gear.md)。金币夹具出售收益不能作为资源经济验收。

用户反馈画风严重偏离参考后，修正P01“视觉完成”的验收口径，制定 [四批画风重绘方案](2026-10-01-reference-style-remake.md)。V1已接入昭元新地表、人物占屏调整、共用硬边纸木UI及主世界独立战斗地表，六张双尺寸截图已检查；最终41项回归及真实背包点击恢复通过，正式存档未动。**角色/NPC/建筑仍是旧图，V2–V4及完整参考画风尚未验收**。当前优先继续人物/NPC样板和建筑重绘，避免扩内容再次放大美术差异。issue43退出资源诊断继续保留。

用户随后调整顺序：主角重绘暂缓，其余自主推进、背景不能粗糙。已接入昭元v6细化草石地表、森林战斗v2、锻造铺v2样板，并调整主世界NPC大小/脚点与硬边名牌。原主角素材与动画不动，后续先统一其他建筑与地区；详见 [本轮细化](2026-10-01-reference-style-refinement.md)。

## 2026-10-01 P08-E3 工坊保底与昭元建筑

昭元其余七座建筑已统一并接入，马厩复用同系列兽栏图。强化+1至+3确定成功，中高阶公开失败积累每次15个百分点，失败扣费不掉级，成功清零；实例旧字段兼容、写失败完整回滚。最终42项全量回归和11项运行器自检通过，扩展专项覆盖至+20每阶最坏序列；四职业源档副本实际点击强化及独立进程重读一致。16张实际渲染图完成检查，见 [本包记录](2026-10-01-town-art-workshop.md)。主角原图/动画不改，其他地区/NPC与怪物图像、美术整体、资源完整预算及原整体方案待办仍未完成；内容数28/36、18/36、6/8不变。

## 2026-10-01 P08-E4 自然资源装备路线

四职业正常初始档实际s01–s28，无填包或夹具销售；三幕加工600/1350/2250金、3/5/8石，共4200金/16石，终态均剩1665金。保底新装当前武器/甲+3、饰品+2，前幕投入留在旧实例；A/B状态及原始存档字节一致。未改奖励、价格或成长数值。四职业背包与建筑名牌修正六张图完成检查；图标与箭头移出名称区域后相关3项通过，基线42项全量回归和11自检有效。见 [自然预算](2026-10-01-p08-resource-budget.md)。该示例不代表全养成经济；伙伴培养材料、后三式导师、稳定工作/其他组合及其余完整单机待办继续。
