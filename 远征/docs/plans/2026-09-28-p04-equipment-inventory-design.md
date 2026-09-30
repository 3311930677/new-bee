# P04 设计：装备实例、背包、工坊、宝石与旧档等值迁移

> 编写日期：2026-09-28。对应交接文档 §4「P04：装备实例、加工与旧档保值」（第 90–94 行）与 §3 表第 43 行门槛
> 「旧强化价值保留；满包／失败／重复点击不丢物」。上游契约见 [P02 设计](2026-09-28-p02-world-session-design.md) 与
> [P03 设计](2026-09-28-p03-battle-slice-design.md)。
> 本文件是 P04 的设计权威；实施记录写进 [主世界重构进度](2026-09-27-world-rebuild-progress.md)。

## 0. 目标与边界

把装备从「6 个固定槽的等级」升级成**可掉落、可比较、可换装、可流通的实例**，并让旧档的强化投入
一分不丢地搬进新模型；补上背包、待领取箱、工坊拆装、确定性 3 合 1 宝石。

玩家可见交付（验收链，缺一不算完成）：

```text
普通怪掉一件可装备物 → 与在身装备比较 → 穿上（地图上至少一处外观变化）
  → 强化／镶嵌 → 卸下 → 卖出
```

同时必须成立的四条硬事实：**满包不丢物**、**缺钱不扣物**、**重复点击只生效一次**、
**读档与「迁移再迁移」后余额与物件 UID 全部不变**。

不做（明确留给后包）：

- 第二首领、支线、章节世界变化 → P05。
- 交易点／订单／期货 → P06。
- 装备等级需求门槛、套装、附魔转移、重铸 → 本包不做（避免在平衡未定前加隐藏倍率）。
- 联机市场与物品 UID 联网校验 → L1 起。
- 重绘装备图标 → 沿用现有 `slot_*` 图标，稀有度只用**边框色**区分（不新增美术）。

## 1. 数据模型

### 1.1 实例形状（`prog.inventory.instances[]`）

```jsonc
{
  "uid": 12,                 // 全局唯一、单调递增、永不重用（背包/在身/待领取共用一个计数器）
  "tpl": "tpl_sword_wolf",   // 模板 id → data/equip.json 的 templates[]
  "slot": "sword",           // sword/spear/staff/hammer/armor/accessory（从模板冗余，便于按槽过滤）
  "rarity": 2,               // 1 普通 / 2 精良 / 3 稀有 / 4 史诗
  "lv": 0,                   // 强化等级（旧 equip 的 lv 原样搬入）
  "sockets": 3,              // 可镶孔数（模板给）
  "gems": ["gem_atk_3"],     // 已镶宝石（长度 ≤ sockets，数组下标即孔位）
  "affixes": [ {"stat": "atk_pct", "v": 0.05, "locked": true} ],
  "locked": false            // 锁定：防误卖、防误拆宝石（不可出售）
}
```

名称与基础属性**只从模板取**，实例不存名称（改名/平衡调整不必迁移存档）。

### 1.2 存档容器（v5 新增 `prog.inventory`）

```jsonc
"inventory": {
  "instances": [ /* 拥有池：背包与在身实例都在这里，未穿戴者最多 60 件 */ ],
  "pending":   [ /* 待领取箱：掉落产出但尚未入包的实例，无上限 */ ],
  "next_uid":  1
},
"equip": { "sword": 3, "armor": 4, "accessory": 5, ... }   // 槽 → 实例 uid（0/缺省 = 未装备）
```

- **装备不是背包**：装备中的实例记录在 `prog.equip[slot]`，**不占** `instances[]` 的 60 格。
- **材料与宝石继续堆叠**（`items["gem_atk_3"]`／`items["enhance_stone"]`），不占格。
- **任务关键物沿用 P02 的独立 `items` 键**（`stele_fragment` 等），不占格 —— 与
  `VerifyWorldSession` 行 7「满包发奖」的既有契约一致，本包不改该语义。

### 1.3 为什么 `equip_state(slot)` 保留原签名

`G.equip_state(slot)` 改为返回**在身实例字典**（无装备时返回 `{}`）。实例键仍是
`lv / gems / affixes`，因此 `EquipPanel`、`GrowthPanel`、`growth_bonuses()` 的读取面几乎不用改；
真正的语义变化只有一处：**`prog.equip[slot]` 从内联状态变成 uid**，写入口从 `_equip_save_state()`
改为 `Inventory` 的实例操作。

## 2. 配置（`data/equip.json` 增量，不新建表）

```jsonc
"bag":  { "capacity": 60 },
"merge":{ "gem_merge_n": 3, "gem_merge_cost_gold": 300 },
"rarity": [
  { "id": 1, "name": "普通", "color": "b8b8b8", "sell_mult": 1.0, "drop_weight": 60 },
  { "id": 2, "name": "精良", "color": "6cc06c", "sell_mult": 2.0, "drop_weight": 25 },
  { "id": 3, "name": "稀有", "color": "5aa0e0", "sell_mult": 4.0, "drop_weight": 12 },
  { "id": 4, "name": "史诗", "color": "c070e0", "sell_mult": 8.0, "drop_weight": 3 }
],
"templates": [
  { "id": "tpl_sword_basic", "name": "生铁大剑", "slot": "sword", "rarity": 1,
    "icon": "slot_sword", "base": { "atk": 10 }, "sockets": 3, "price": 300 },
  { "id": "tpl_armor_basic", "name": "皮甲", "slot": "armor", "rarity": 1,
    "icon": "slot_armor", "base": { "def": 6, "hp": 50 }, "sockets": 3, "price": 400 }
  // 6 槽各一条 *_basic，base **必须逐字段等于** slots[<slot>].base（见 §4 等值口径）
  // 掉落模板（狼牙大剑等）另加，base 可略高，rarity ≥ 2
],
"drop": { "normal": { "chance": 0.12 }, "elite": { "chance": 0.35 }, "boss": { "chance": 1.0 } }
```

**稀有度不加成战斗数值**：只决定展示色、回收价倍率与掉落权重。差异化由模板 `base` 承担
（打到的装备基础数值略高于初始装）。这样迁移是纯搬运、不会偷偷改战力，也避免平衡未定时引入隐藏倍率。

## 3. 服务模块 `src/world/Inventory.gd`（`class_name Inventory`）

沿用 P02 的「纯静态、无 autoload 依赖」写法：状态以 `inv: Dictionary` 传入，模板以 `tpl: Dictionary`
传入，便于直接跑边界矩阵。`G.gd` 提供同名的薄封装（负责解析表、写 `prog`、落盘）。

| 方法 | 契约 |
|---|---|
| `ensure(inv)` | 补齐 `instances/pending/next_uid`；幂等 |
| `new_instance(inv, tpl, rarity) -> Dictionary` | 分配 uid、构造实例；**不落盘** |
| `add(inv, cfg, inst) -> Dictionary` | 入包；`instances.size() >= capacity` → 进 `pending`，返回 `{ok:true, to_pending:true}`（**不丢物**） |
| `claim(inv, cfg, uid) -> Dictionary` | 待领取箱 → 背包；背包满则拒绝并保留待领取 |
| `equip(inv, equip_map, uid) -> Dictionary` | 换装只交换在身 uid 指针：新件离开背包、旧件回背包，占用不变；满包也可换装，重复装备同一 uid 拒绝 |
| `unequip(inv, cfg, equip_map, slot)` | 卸下 → 背包；满则拒绝 |
| `set_locked(inv, uid, on)` | 只改标记（免费） |
| `sell_price(cfg, tpl, inst)` | `(tpl.price × rarity.sell_mult + 强化返还) × …`，见 §3.1 |
| `sell(inv, cfg, equip_map, uid, confirm) -> Dictionary` | 在身／锁定 → 拒绝；强化过或稀有 → 需 `confirm=true`，否则返回 `{need_confirm:true}` |
| `gem_pop(inv, cfg, inst, idx) -> Dictionary` | 拆下一颗宝石（免金币）；背包只装实例，宝石回 `items`，故**不会因满包失败** |
| `gem_merge(items, wallet, cfg, gem_id) -> Dictionary` | 3 颗同级同色 → 1 颗 +1 级；扣 `merge_cost_gold`；满级／不足 3 颗 → 拒绝且**不改动** |
| `count(cfg, inv) -> int` | 背包已用格 |
| `appearance(tpl_of, equip_map) -> Dictionary` | 对外观钩子 `{weapon_tpl, weapon_name, rarity, color}` |

### 3.1 卖价与「旧强化价值保留」

```text
sell_price = round( ( tpl.price × rarity.sell_mult ) + Σ_{i=0..lv-1}( cost_gold_base + cost_gold_step × i ) × 0.5 )
```

强化返还用**同一条 `equip_enhance_cost` 公式**累加，确定性、可被测试重算；强化过的装备不会以
"0 级白装价"被卖掉（旧强化投入在经济上被承认，而不是归零）。

### 3.2 幂等

所有写操作都先校验后改动，且**同一 uid 重复点击只生效一次**：
换装第二次点击因"已在身上"返回 `{ok:false, err:"已装备"}`；卖出后 uid 不再存在于任何容器，
第二次返回 `{ok:false, err:"找不到这件装备"}`；领取第二次同样找不到。测试按此断言。

## 4. 存档 v4 → v5 与等值迁移

`SaveData.CURRENT_VERSION := 5`，新增 `_migrate_v4_to_v5(data)` → `_ensure_v5(prog)`，
并让 `_normalize()` 对所有版本调用 `_ensure_v5`（与 `_ensure_v4` 同样的"修脏档"策略）。

迁移规则（**只搬运、不改数值**）：

1. `prog.inventory` 不存在 → 建 `{instances: [], pending: [], next_uid: 1}`。
2. 遍历 `equip.json.slots` 的 6 个槽：
   - `prog.equip[slot]` 已是**整数**（v5 形状）→ 跳过（幂等：再迁移一次 uid 不变）。
   - 是**字典**（旧形状 `{lv,gems,affixes}`）或缺失 → 用 `tpl_<slot>_basic` 建实例，
     `lv/gems/affixes` **原样复制**，`rarity=1`、`sockets=模板孔数`、`locked=false`，
     然后 `prog.equip[slot] = uid`。
3. 旧字典被 uid 取代即自然消失，不残留双份状态。
4. 未知槽键（表里没有的）不删除、不猜测，原样留在 `prog.equip` 里（`validate()` 不因此判非法）。

**等值口径（必须等于迁移前）**：由于 `tpl_<slot>_basic.base ≡ slots[slot].base`，
`equip_base_stat(slot)`、`equip_slot_bonus(slot)`、`growth_bonuses()` 的输出逐字段不变。
`VerifySave` 用表数据程序化比对（而不是写死期望值），并额外断言：迁移两次 uid 不变、
未来版本仍拒绝导入、真实存档不被测试改写。

新档路径：与 `ensure_starter_pets()` 并列新增 `ensure_starter_equip()`，在 `_load_save()` 应用
`prog` 之后调用；若无 `inventory` 或 6 槽全空，则建 6 件 `*_basic` 并全部装备 —— **保证新档/旧档
的战力与 P03 完全一致**（P03 的平衡断言不因 P04 而变）。

`validate()` 新增：`prog.inventory` 存在时必须是对象，`instances`/`pending` 是数组、`next_uid` 是数值；
`prog.equip` 的值必须是整数（负数/非整数判非法）。

## 5. 掉落到待领取箱（与 P02 事务同源）

- `RewardLedger` 的 grants 增开一个前缀 `"equip:<tpl_id>:<rarity>"`：命中时调用宿主方法
  `inv_grant_equip(spec)`（`G.gd` 实现），把实例放进 `inventory.pending`。**其余前缀行为不变**，
  `VerifyWorldSession` 的 10 行矩阵必须继续全绿。
- `MapScene._bank_main_world_rewards(txid)` 内**掷一次**装备掉落（读 `data/drops.json` 的 `drop`
  概率 + 稀有度权重），把结果并进同一笔事务。因此：
  - 同一 `txid` 重放 → `RewardLedger` 命中 `applied` → **不再掷、不再发**。
  - 结算落盘与刷新计时仍是同一次写档（P03 的不变式）。
- 掉落模板按当前地图主题过滤（`templates[].theme` 可选，缺省全体）；拾取提示并入既有战利 toast。
- 历练（非主世界）路径继续用 `_grant_drops(tier)` 的堆叠材料，**不接装备掉落到待领取箱**
  （历练局尚未落档，见 §8 遗留）。

## 6. UI

### 6.1 新增 `src/ui/BagPanel.gd`（背包）

480×800，与 `EquipPanel` 同一套 `G.veil / G.parchment_box / G.gold_button` 语言：

- 顶部四个页签：**装备 / 材料 / 宝石 / 待领取**（材料与宝石页只读汇总，指向工坊操作）。
- 装备页：每页 8 行（行高 34），行 = 稀有度色边框图标 + 名称 + `+lv` + 锁定标记；
  右上角 `已用/60`。分页按钮沿用 `EquipPanel` 的 ◀ ▶ 写法。
- 详情区固定在面板下半：名称·稀有度·强化等级·基础属性·宝石孔·词条；
  **比较区**逐项显示与在身同槽实例的差值（`攻击 +2`／`攻击 -2`／`持平`）。
- 操作按钮：`装备`/`卸下`、`锁定`/`解锁`、`卖出`（强化过或稀有 → 二次确认文案
  「再次点击确认卖出」）、`拆除宝石`（点在已镶孔位上）。
- 待领取页：每行一件，`领取` 按钮；背包满时提示「背包已满，先腾出空位」并保留在待领取箱。

### 6.2 `EquipPanel` 改造（工坊）

- 数据源改 `G.equip_state(slot)`（在身实例）；`+lv`、宝石、词条、强化/精炼/换宝石全部落到实例上。
- 新增 `卸下` 按钮（满包拒绝并提示）。
- 已镶孔位点击 = 拆除宝石（修掉「宝石只能镶不能拆与文案不符」的既有问题）。
- 宝石区增加 `合成`（3 合 1）：显示「同级同色 3 颗 → 1 颗更高级」与金币费。

### 6.3 入口与登记

- `GameHome` 增加「背包」入口（与「养成 → 装备」并列）；`EquipPanel` 顶部加「背包」直达。
- 新面板需登记进 `VerifyNav` 的面板清单与 `VerifyUiLayout` 的布局检查（**用例数不变**）。

### 6.4 可见换装（地图外观）

`G.equip_appearance()` 返回 `{weapon_tpl, weapon_name, rarity, color}`；`MapScene` 依据它：

1. 玩家名签底板描边改为**稀有度色**（无武器时回落原色）；
2. 玩家手中绘制一件 14px 的武器小图标（模板 `icon`），换装即刻变化。

验收以 `shots/p04_20260928/` 的实机图为准（`tools/PreviewMainWorld.tscn`，**窗口模式**，非 headless），
至少一张「装备稀有武器后名签变色 + 手中出现武器」的前后对照。

## 7. 测试计划（**用例数保持 29**，不新增用例名）

| 用例 | 新增断言 |
|---|---|
| `VerifyGrowth` | 新节「实例与背包」：`ensure/new_instance` uid 单调且不重用；入包/满包进待领取（60 格）；领取在满包时保留；换装在满包时拒绝；`sell` 在身/锁定拒绝、强化或稀有需 `confirm`；`sell_price` 与强化投入公式一致；`gem_pop` 归还宝石；`gem_merge` 3→1、满级拒绝、金币不足不改动；**重复点击幂等**（换装/卖出/领取各两次）；存档往返后 uid 与容器一致。既有装备节改为实例模型，`growth_bonuses` 聚合期望值**逐项不变**（旧值等价）。 |
| `VerifySave` | 新增**合成样本** `tools/fixtures/saves/v4_equip_progress.json`（含 `lv/gems/affixes` 的旧装备）；断言 v4→v5 后 `prog.equip` 是整数 uid、实例的 `lv/gems/affixes` 与旧档逐字段相同、`equip_slot_bonus` 与 `slots[].base` 推出的期望值一致、**再迁移一次 uid 不变**、未来版本仍拒绝。 |
| `VerifyWorldSession` | 行 7 改为「满包时装备掉落进待领取箱、任务物仍照常入账」；确认 10 行矩阵与 `RewardLedger` 新前缀不冲突。 |
| `VerifyPanels` / `VerifyUiLayout` / `VerifyNav` | `BagPanel` 可实例化、可开关、关键控件（页签/行/详情/按钮）存在。 |

回归（在 `D:\new bee\远征`）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_regression.ps1 -Proj "D:\new bee\远征" -TimeoutSec 180
git diff --check
```

判定：**29/29 ALL GREEN**、`git diff --check` 退出码 0、`real player save … unchanged by this run`。
`tools/run_regression.ps1` 的 `-Expected` **维持 29**（保持纯 ASCII）。

## 8. 已知遗留（写进文档，不在本包解决）

- 历练局落档（`RouteScene.pending_run` 仍在进程内）→ 仍待后续包。
- 跨图连续返城（单进程走完主线）→ 与 P01 同一条待验。
- 装备图标沿用 `slot_*`，逐张重绘属美术批次。

## 9. 交付物清单

- 数据：`data/equip.json`（templates/rarity/bag/merge/drop）、`data/drops.json`（装备掉落段）。
- 代码：`src/world/Inventory.gd`（新）、`src/save/SaveData.gd`（v5 迁移）、`src/autoload/G.gd`
  （实例封装 + 外观钩子 + `inv_grant_equip`）、`src/world/RewardLedger.gd`（`equip:` 前缀）、
  `src/explore/MapScene.gd`（掉落入事务 + 外观）、`src/ui/BagPanel.gd`（新）、
  `src/ui/EquipPanel.gd`、`src/ui/GameHome.gd`。
- 夹具：`tools/fixtures/saves/v4_equip_progress.json`（合成样本）。
- 截图：`shots/p04_20260928/`（换装前后对照，480×800）。
