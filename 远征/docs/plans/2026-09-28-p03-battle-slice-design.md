# P03 设计：主世界战斗完整纵切（接战状态机 / 预兆 / 首领阶段 / 结果恢复）

> 编写日期：2026-09-28。对应交接文档 §4「P03：主世界战斗完整纵切」（第 84–88 行）与 §3 表第 42 行门槛
> 「城／野／首领三类实机流程与历练回归」。上游契约见 [P02 设计](2026-09-28-p02-world-session-design.md)。
> 本文件是 P03 的设计权威；实施记录写进 [主世界重构进度](2026-09-27-world-rebuild-progress.md)。

## 0. 目标与边界

把战斗从「`sim.finished` + `_finished_ui` 两个标志」升级为一条**显式、可持久化、可重放**的流水线，
并补上四项玩家可见内容：敌人预兆、首领阶段、四指令详情、战后恢复。

不做（明确留给后包）：
- 第二个首领（失路兽）→ P05。
- 装备/背包结算 → P04。
- 联机战斗输入/结果校验 → L1 起。
- `BattleSim` 的数值平衡（TTK/职业强弱）不动，只加「阶段」与「破绽」两条表驱动钩子。

## 1. 战斗状态机

状态全部落在 `prog.main_world.encounters[<encounter_id>].status`（P02 已建表），
由 `WorldSession` 单点读写，`MapScene` 推动，`BattleScene` 只发结果。

```text
                 (接触)            (进战斗)          (战斗结束)
  "" ──► approach ──► locked ──► battle ──► result_pending ──► committed ──► return
                                        └──────────────────► fled ─────────► return
                                        └──────────────────► failed ───────► (结束/回城)
```

| 状态 | 写入时机 | 崩溃后重载的可解释状态 |
|---|---|---|
| `approach` | `_start_battle` 刚接触（与 `locked` 同一次写档） | 怪物仍在图上，玩家在接触点附近 → 安全位纠偏后重新接触 |
| `locked` | 同上（遭遇已确认，尚未进战斗层） | 同 `approach`，不重复发任何东西 |
| `battle` | `_launch_battle` 真的建好战斗层（写档） | 战斗层已丢，遭遇仍是 open → 再次接触可重打；不会二次发奖 |
| `result_pending` | `_on_battle_end` 收到结果、结算**之前**（仅内存） | 无（进程死掉 = 回到 `battle`，走补结算） |
| `committed` | `settle_result` 首次落地（战利+刷新同一次写档） | 已结算：重进不再发奖、刷点已记 |
| `fled` | 撤退结算 | 已撤退：该场不再能被 commit 发奖 |
| `failed` | 战败/超时（PVE 按败） | 已失败：该场不再发奖 |
| `return` | 回到地图、位置与怪物状态落盘 | 位置可解释，不落在怪物身上 |

转移表（`WorldSession.advance` 校验，非法转移返回 `bad_transition` 且不落盘）：

```text
""            -> approach
approach      -> locked | fled
locked        -> battle | fled
battle        -> result_pending | failed
result_pending-> committed | fled | failed
committed     -> return
fled          -> return
failed        -> (终态)
```

`commit()`（P02 既有）语义保持不变：从任意**非终态**进入 `committed`，重复上报返回 false。
`settle_result(state, ctx, result)` 在其上加「结果去重」：同一 `result_id` 只结算一次。

### 1.1 result_id

```text
result_id = "res|<encounter_id>|<result>"      # 确定性；同一次接战同一种结果恒定
```

`MapScene._on_battle_end` 用具名 `result_id` 作为**唯一结算入口**：
`WorldSession.settle_result(state, ctx, result)` 返回 true 才发奖、才推进主线。
重复上报（同 `result_id` 两次、或已 `committed` 再报）一律 false → 不再发金/物/经验。

## 2. 预兆（文字 + 图形）

规则层不改：`SkillSystem.enqueue_cast` 已在**前摇起点**发 `cast_start`，前摇长度写在
`sim.cast_queue[i].windup`（12–15 tick）。表现层据此做两种预兆：

- **文字**：顶部/头顶提示「首领技 · 碑震 · 蓄力 0.4s」，按剩余 windup 实时倒数。
- **图形**：
  - 施法者脚下生出一圈**预兆环**（脉动、随剩余前摇收缩），环内填色按技能危险度区分；
  - 技能**将要打到谁**用同样的环标出：`enemy_front_all` → 敌方前排全部；`enemy_all` → 全部；
    其余按当前普攻目标。玩家因此能提前决定「补药 / 换宠 / 打断 / 硬吃」。
  - 敌方**普通**施法只出细环（低危），首领技出粗环 + 震屏 + `boss_warn` 音（沿用既有）。

预兆层挂在震屏层内、单位之上；纯读 `sim.cast_queue`，不产生任何随机，不写规则。

## 3. 首领：失声碑灵两阶段 + 反击窗口

数据驱动，写在 `data/monsters.json` 的 `mon_stele_warden` 上，`BattleSim` 解释：

```json
"skills": [
  { "id": "boss_slam", "name": "碑震", "k": 1.4, "cd": 12, "target": "enemy_front_all",
    "after": { "self_buff": { "type": "break_window", "dur": 4.0, "pct": 0.35 } } }
],
"phases": [
  { "id": "wail",  "hp_below": 0.50, "name": "碑鸣",
    "announce": "失声碑灵发出低鸣——攻势加快",
    "add_skills": [ { "id": "boss_wail", "name": "失声悲鸣", "k": 0.0, "cd": 20,
                      "target": "enemy_all", "effect": { "type": "fear", "dur": 2.0 } } ],
    "buffs": { "spd_up": { "pct": 0.25 } } },
  { "id": "crack", "hp_below": 0.22, "name": "碎碑",
    "announce": "碑身碎裂——护壁崩解，抓住破绽！",
    "buffs": { "def_break": { "pct": 0.30 } },
    "self_buff": { "type": "stun", "dur": 2.0 } }
]
```

- **阶段 1（循环）**：碑震（前排 AoE，有预兆）→ 施法后自身「破绽」4 秒（受伤 +35%）。
  玩家可读到的两件事：预兆环 → 打完一轮后首领身上出「绽」字且血条变色 → **这是反击窗口**。
- **阶段 2（≤50% 血，一次）**：解锁失声悲鸣（全体恐惧 2 秒）+ 永久加速。
- **阶段 3（≤22% 血，一次）**：永久破防 30% + 自身硬直 2 秒 —— 第二个反击窗口。
- 反击窗口统一走新 buff `break_window`：`Combatant.take_damage` 里乘以 `(1 + pct)`。

实现约束：
- `_apply_phases()` 只在单位 `data.phases` 非空时生效 → **历练各主题首领无 `phases`，行为与数值完全不变**。
- 阶段只触发一次（记在 `Combatant.once_flags`），阈值用整数血量比例判定，无随机。
- 新事件 `{"t":"phase", uid, id, name, announce}`：表现层出居中横幅 + 变色，血条追加阶段名。

## 4. 四指令详情

指令层从「只有名字」升级为「名字 + 事实」：

| 指令 | 必须显示 |
|---|---|
| 攻 | 当前集火目标名 + 血量百分比；未指定时写「自动选敌」 |
| 技 | 每个技能：名字、**等级 Lv**、能量消耗、剩余冷却秒、**范围**（单体／前排全体／全体／自身／友方） |
| 物 | 药剂：剩余数、冷却、回复比例；换宠：每场一次、替补名 |
| 逃 | 后果文案：普通怪「退出本节点，保留战损与进度」；剧情首领「首领战不可撤退」（按钮置灰） |

技能/道具页由「一排 62px 小签」改为**整宽竖排列表**（每行 402×28，含右侧灰色详情），
字号仍为 FS_XS，触控行高 ≥28px。常驻信息条（4 之上）显示攻/技/物当前关键事实。

## 5. 战后恢复

主世界战斗是**叠在地图上的表现层**（`classic_inline`），地图、玩家、相机、怪物对象全程不销毁；
因此位置／朝向／镜头天然保留。P03 显式补齐三件事并让它们可断言：

1. `_restore_after_battle()`：恢复玩家动画到待机、`_world`/`_hud` 可见、清掉遗留的接触锁。
2. 存活怪物 `chasing_contact=false` + `retreat_home()`（既有可能已有），并把**接触冷静期**写进怪物；
   确保玩家不会在结算层消失的下一帧被同一只怪二次拖入。
3. 结算后立即 `_persist_main_world_progress()` + `G.save_game()`，位置与刷新时间同一次写档。

## 6. 测试计划

### VerifyWorldSession（`WORLD_SESSION_OK`，行数从 7 扩到 10）
- 行 8：完整状态机顺序 `approach→locked→battle→result_pending→committed→return` 逐步 `advance` 成功；
  非法转移（如 `locked→committed`）返回 `bad_transition` 且不落盘。
- 行 9：`result_id` 确定性 + `settle_result` 幂等：同结果两次只结算一次、钱包只发一次。
- 行 10：`fled`/`failed` 为终态，之后 `commit`/`settle_result` 均 false。

### VerifyBattleScene（`BATTLE_SCENE_OK`）
- 敌方施法时存在图形预兆（`_omens` 有 caster 条目 + 预兆环可见）且文字含技能名。
- `{"t":"phase"}` 事件 → 阶段横幅出现、首领血条带阶段名。
- 四指令：技能页每行含 Lv/耗/冷/范围；道具页含数量与效果；`flee_rule=blocked` 时逃按钮置灰且不出撤退结算。
- 既有断言（敌左我右、宠物站位、经典指令不压单位、远程弹道）保持全绿。

### verify_battle（`BATTLE_OK`，纯 sim）
- `mon_stele_warden` 阶段阈值：掉到 50% 解锁失声悲鸣、掉到 22% 进破绽；只触发一次。
- `break_window` 使同一次伤害放大（确定性、无随机）。
- 无 `phases` 的普通/历练首领行为不变；同种子 `hash_state()` 与改动前一致（确定性护栏）。

### 回归
`tools/run_regression.ps1 -TimeoutSec 180` 全绿（用例数与 `-Expected` 同步），`git diff --check` 退出码 0，
真实存档哈希不变。
