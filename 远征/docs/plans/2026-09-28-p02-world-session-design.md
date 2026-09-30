# P02 设计：WorldSession、QuestService 与一次结算（2026-09-28）

> 对应 [后续实施交接方案](2026-09-27-next-agent-implementation-handoff.md) §4「P02」。
> 本文件先定契约与存档字段，再落代码；代码实现与验收结果写在
> [主世界重构进度](2026-09-27-world-rebuild-progress.md) 的 P02 段。
> 硬约束沿用交接文档：不重置 `s01`–`s12` 与 `lorin_wilds`；不写真实 `user://save.json`（测试用 `tools/fixtures/saves/`）；
> `tools/run_regression.ps1` 保持纯 ASCII；不清理/覆盖/重置工作树。

## 1. 问题边界

现状（P00 基线 §3）：

- `G.story_event(kind, target, map_id)` 是唯一的主线推进入口，靠 `prog.story.{step,done[]}` 顺序推进；奖励与状态在同一函数里直接改 `wallet` / `items` / `prog`，再 `save_game()`。**没有事务 ID，重复上报只能靠 `done[]` 兜。**
- `MapScene.gd` 同时承担刷怪、接战、奖励、切图与写档：一场主世界战斗的入账顺序是「改 `bosses_cleared` / 写 `respawn_at` → `_bank_main_world_rewards()`（内部 `save_game`）→ `G.story_event("defeat",…)`（内部又一次 `save_game`）」，中途崩溃会落在「材料已进包、主线未推进」这类可解释性差的中间态。
- 历练局状态完全不落档（`RouteScene.pending_run` 只在进程内），进程中途被杀＝该局丢失且不可恢复。
- 存档版本 3，`prog.main_world` 只有单图 `respawn_at`，`respawn_by_map` 是新加的兼容键；没有「这场战斗是否已经结算过」的记录。

P02 要解决的是**可解释性**，不是新玩法：任何一个崩溃点重新加载后，只能落到一种能说清的状态，且不重复发物、不丢任务物、不把玩家放到怪物身上。

## 2. 三个稳定契约

三个契约都定义为**纯数据字典**，由静态服务生成与读取；场景只负责显示与交互，不自己拼字段。

### 2.1 WorldEvent

```text
WorldEvent = {
  event_id:   String,   # 确定性："{type}|{map_id}|{target}"（同一事实重复上报得到同一 id）
  type:       String,   # talk / visit / defeat / collect / deliver / craft / choose / boss
  source_id:  String,   # 触发者：npc_id / map_id / monster_id / item_id
  map_id:     String,   # 事件发生地图
  actor_id:   String,   # 玩家侧标识（当前为职业 id 或 "player"，为联机预留）
  payload:    Dictionary,  # 附加数据（count / item / choice …），P02 只用到 count
  game_tick:  int       # 单调递增的逻辑帧计数（不是墙钟），用于遭遇与重放排序
}
```

### 2.2 EncounterContext

```text
EncounterContext = {
  encounter_id:    String,   # "{map_id}:{spawn_id}:{game_tick}"，一次接战一个
  spawn_id:        String,   # WorldSession.spawn_id(map_id, idx) → "{map_id}:{idx}"，全局唯一刷点
  map_id:          String,
  position:        [x, y],   # 怪物接战时的世界坐标
  enemy_id:        String,
  enemy_level:     int,
  return_position: [x, y],   # 撤退/失败要回到的安全位
  story_source:    String,   # 触发的任务步骤 id（可空）
  rng_seed:        int,      # 战斗种子（确定性重放用）
  status:          String    # locked → battle → committed / fled / failed
}
```

`status` 生命周期：

```text
locked  --开始战斗--> battle --胜利--> committed
                            --撤退--> fled
                            --失败--> failed
```

`committed` 是**唯一**会发放战利的状态；同一 `encounter_id` 再次 commit 直接返回原结果，不再发奖。

### 2.3 RewardTransaction

```text
RewardTransaction = {
  transaction_id: String,      # 确定性，写入 prog.ledger.applied[] 去重
  costs:          Dictionary,  # {"gold": n, "item:<id>": n}
  grants:         Dictionary,  # {"gold","exp","expedition","soul","honor","item:<id>","flag:<name>"}
  world_flags:    Dictionary   # 写进 prog.flags 的世界旗标
}
```

`RewardLedger.apply(tx, ledger, host)` 语义：**已应用 → 原样返回不重复发放**；未应用 → 校验 `costs` 付得起 → 扣除 → 发放 → 记 `transaction_id` → 返回。任一环节失败整体不落地（调用方不写档）。

## 3. 存档 v4：字段与 v3→v4 迁移

### 3.1 新增/变更字段

| 路径 | 类型 | 含义 |
|---|---|---|
| `prog.story.goals` | `{step_id: "done"}` | 新目标状态（权威），由旧 `done[]` 映射而来 |
| `prog.story.done` | `[step_id]` | 保留（旧读法与回归仍看它），与 `goals` 同步写 |
| `prog.main_world.encounters` | `{encounter_id: {status, spawn_id, enemy_id, tick}}` | 遭遇锁与重放去重 |
| `prog.main_world.bosses_cleared` | `[map_id]` | 既有字段，迁移时保证存在 |
| `prog.main_world.respawn_by_map` | `{map_id: {idx: ts}}` | 既有字段，迁移时保证存在；旧单图 `respawn_at` 折进来 |
| `prog.main_world.respawn_at` | `{idx: ts}` | 兼容保留（本图快照），`VerifyMainWorld` 仍断言它 |
| `prog.ledger.applied` | `[transaction_id]` | 已结算事务去重表 |
| `prog.flags` | `{name: value}` | 世界旗标（事务副作用） |

> 读档安全位不落盘：进图时由 `WorldSession.safe_position(saved, 存活怪物坐标, 传送阵坐标, 地图形状)`
> 按当前存活怪**当场算**（存活集合每局都不同，存下来的 `safe_at` 反而会过期）。算法是确定性的，可单测。

### 3.2 v3 → v4 迁移映射

逐版迁移保持「纯函数、幂等、对已是目标版本的档再跑不改动」：

1. `prog` 非字典则补 `{}`；`prog.main_world` 非字典则补 `{"map_id": "lorin_wilds"}`。
2. `bosses_cleared` 非数组则补 `[]`；`respawn_by_map` 非字典则补 `{}`。
3. 旧单图 `respawn_at`（非空）且 `respawn_by_map` 里没有当前 `map_id` → 折进 `respawn_by_map[map_id]`；`respawn_at` 本身**保留**。
4. 旧永久击杀表 `killed[]` → 逐项转成 `respawn_by_map[map_id][str(idx)] = now + 0`（即"下次进图即刷新"），随后删除 `killed`。
5. 补 `prog.main_world.encounters = {}`、`prog.ledger = {"applied": []}`、`prog.flags = {}`。
6. `story.done[]` → 生成 `story.goals`（`{id: "done"}`）；已有 `goals` 的档以 `goals` 为准并回填 `done`。
7. 未来版本（`version > 4`）仍拒绝迁移；导入路径继续拒绝覆盖。

`CURRENT_VERSION` 由 3 升到 4；`MIN_READABLE_VERSION` 仍为 1，v1/v2/v3 旧档继续可读（回归夹具 `v1/v2/v3/new_game/legacy_v3_progress` 全部走迁移）。

### 3.3 语义校验（v4 新增）

- `prog.ledger` 必须是对象，`prog.ledger.applied` 必须是数组。
- `prog.flags` 必须是对象。
- `prog.main_world.encounters` 必须是对象。
- `prog.story.goals` 必须是对象。
- 其余沿用 v3 规则（钱包非负、道具非负、等级范围、未来时间水位）。

## 4. 崩溃点矩阵

每个点「重新加载后的唯一可解释状态」。测试用 `tools/VerifyWorldSession.tscn` 覆盖（合成夹具，不写真实档）。

| # | 崩溃点 | 落盘时机 | 重载后应有状态 | 不允许发生 |
|---|---|---|---|---|
| 1 | 开战前（刚接触） | 无写档 | 怪物仍在，无遭遇记录 | 玩家被放到怪物身上 |
| 2 | 战斗中（`status=battle`） | 遇敌不写档 | 怪物仍在，无战利，HP 按存档 | 提前记 `respawn_at` 导致怪消失 |
| 3 | 结算前（胜利动画中） | 未写档 | 怪物仍在，可重打，奖励只发一次 | 发出未经 commit 的奖励 |
| 4 | 结算后未返回地图（`status=committed`） | `respawn_at`/`bosses_cleared`/战利同一次写档 | 怪物已按刷新计时，战利在账，重放 commit 不再发 | 重复发金/经验/任务物 |
| 5 | 切图写档中（`_check_world_exits`） | 先 `_persist` 后写档再切场景 | 回到旧图或新图**之一**，坐标合法 | 半写档（缺 `map_id` 或坐标） |
| 6 | 交付任务物时（`s11` 铁匠） | 事务：扣物＋推进＋发奖一次写档 | 碑文已扣、步骤已完成、奖励已发；重按 NPC 不再结算 | 扣物未推进，或推进未扣物 |
| 7 | 满包发奖时（任务物 1 格） | 事务内校验 | 任务物照常入账（任务物不占 60 格普通背包，P04 前为独立 `items` 键） | 静默丢物 |

## 5. 模块与适配层

| 文件 | 职责 | 是否引用 autoload |
|---|---|---|
| `src/world/WorldSession.gd` | 刷点唯一 ID、遭遇生命周期、Boss 首胜、刷新计时、安全位 | 否（纯静态，可 `-s` 测；场景测试有 G 亦可） |
| `src/world/QuestService.gd` | 事件 → 目标推进的**纯计划**（不改状态），含旧 `done[]` 迁移 | 否 |
| `src/world/RewardLedger.gd` | 事务 ID、去重、按一次扣除与发放 | 否（`host` 由调用方传入） |

适配层：`G.story_event()` 与 `MapScene` 的战斗/切图路径改为「构造契约 → 调服务 → 服务返回计划/结果 → 适配层落地一次写档」。
旧分支（`MapScene` 里读 `killed`、`G` 里散落的保底迁移）在验证旧档后逐步移除；P02 先保留读取兼容，不再写新值。
