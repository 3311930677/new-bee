# 2026-10-02 「简单问题」批量修复记录

对应 `docs/plans/2026-10-02-gap-audit-review-and-new-findings.md` 中可直接落地、低风险的一批问题。
本文件只记录**本次真正改了什么、怎么验证的、什么故意没改**。

回归基线：`tools/run_regression.ps1` 用例表 **46 条**（41 个 `@tscn` 场景 + 5 个 `@gd` 脚本）。
修复后实跑 **46/46 ALL GREEN**，真实玩家档哈希未变（`BA8054B3…5BE7`）。

---

## 一、已修复（7 处文件）

### 1. N-03 两张地图「建议等级」越界 —— `data/main_world_maps.json`
`regions[].level` 是地区图 `RegionMapPanel` 显示的「建议 Lv%d–%d」，必须覆盖
`campaign_growth.json` 的 `enemy_levels`，否则玩家按推荐等级进图会撞上越级怪。

| 地区 | 原 level | 实际敌人等级 | 改为 |
|---|---|---|---|
| `tidal_gate` 退潮水闸（首领） | [16, 22] | 23 | **[16, 23]** |
| `frost_pass` 冰隘（首领） | [26, 36] | 40 | **[26, 40]** |

其余 13 张地图的区间均已包含各自 `enemy_levels`，未动。只抬高上限、保留原下限，
是最小改动（`red_sand_route` 等 `28`/`36` 边界相等的地区是合法写法，未动）。

### 2. N-17 长屏留黑边 —— `project.godot`
`[display]` 只有 `stretch/mode="canvas_items"`，**缺 `stretch/aspect`** → Godot 默认 `keep`，
720×1600 / 480×1067 这类长屏会按 480×800 等比缩放并上下留黑边。
新增：

```ini
window/stretch/aspect="expand"
```

`expand` 只放大逻辑视口高度、**宽度仍锁 480**，所以 480×800 基线画面逐像素不变，
横排布局不受影响（`VerifyUiLayout` / `VerifyPerf` 等 41 个场景用例全绿）。

### 3. N-05 词条数值硬编码覆盖表值 —— `src/combat/TraitSystem.gd`
原代码把 4 个数值写死，改 `traits.json` 不生效（已知问题：`docs/2026-09-21-可玩性提升方案.md:169`）。
全部改为读表，**取值与表当前值逐位相同 → 零行为变更**：

| 位置 | 原硬编码 | 现读表字段 |
|---|---|---|
| `dynamic_atk_pct` 越战越勇 | `0.06` | `tr_rampage.effect.atk_pct_per_kill` |
| `on_kill` 越战越勇叠层上限 | `5` | `tr_rampage.effect.stack` |
| `modify_outgoing` 凝神 | `0.12` | `tr_focus.effect.skill_dmg_pct` |
| `modify_outgoing` 碎冰 | `0.20` | `tr_ctrl_2.effect.vs_controlled_pct` |

新增 `first_strike_k()` 供普攻路径读取 `tr_first_strike.effect.first_hit_k`。

### 4. N-05（续）先发制人 ×2 —— `src/combat/Combatant.gd`
`do_basic_attack` 里 `dmg *= 2` → `dmg = int(float(dmg) * traits.first_strike_k())`。

### 5. N-04 普攻回能 20 —— `src/combat/Combatant.gd`
`gain_energy(20)` → 读 `growth.json energy.per_basic_attack`。
（`TableCache._load` 有静态缓存，每次查询为字典命中，无 IO 开销。）

### 6. N-04 层难度系数 0.12 —— `src/combat/BattleSim.gd`
`enemy_scale = 1.0 + 0.12 * layer` → 读 `nodes.json difficulty_scale_per_layer`。
与 `nodes.json` 自带说明「第 N 层怪全属性 ×(1+0.12N)」同源。

### 7. 防漂移守卫 —— `tools/verify_trait.gd`（新增第 9 段，+59 行）
沿用该文件第 6/7 段「表值 vs 代码值对拍」的既有范式，把上面 3~6 项锁进回归：
- 先发制人倍率 == `first_hit_k`
- 越战越勇 3 层 ATK 加成 == `atk_pct_per_kill × 3`，叠层上限 == `stack`
- 碎冰对受控目标 == `vs_controlled_pct`
- 凝神技能伤害 == `skill_dmg_pct`
- 普攻回能 == `growth.energy.per_basic_attack`

以后谁再把表值改回硬编码、或改了表忘了改代码，`verify_trait` 直接红。
单独实跑输出 `TRAIT_OK all tests passed`。

### 8. 工作区卫生
- `D:\new bee\.gitignore`：新增 `.workbuddy/`（该文件注释写明「工作区记忆与本地配置…不进仓库」，
  但旧条目只匹配 `.workbuddy-ai/`，导致当前目录 `.workbuddy/` 一直是未跟踪状态）、
  `/_*.py`、`/_*.txt`。已用 `git check-ignore` 验证生效。
- 清理仓库根 14 个临时草稿（`_audit*.py/txt`、`_py.txt`、`_run*.txt`、`_ui*.txt` 等），
  均为上一轮审计的中间产物；正式结论已在 `2026-10-02-gap-audit-review-and-new-findings.md`。
  保留可复用的 `_reg_run.py`（见下）。

---

## 二、故意没改（需要设计决策或更大改动）

| # | 项 | 为什么停手 |
|---|---|---|
| A | `mentor_curriculum.json` 四职业第三档 `level:35` + `after:"s24"` | 现状**语义自洽但可疑**：前两档 `level` 恰好等于 `after` 步的 `target_level`（12↔s12、25↔s20），第三档 `level 35` 恰好等于 **s25** 的 32→35 中的 35，而 `after` 写的是 s24（s24 target 32）。两种改法方向相反：`after→"s25"`（推迟一档）或 `level→32`（提前一档）。数据里找不到裁定依据，不猜。 |
| B | `Combatant.MAX_ENERGY` / `BASIC_INTERVAL_TICKS` 常量 | 与 `growth.json energy.max` / `basic_attack_interval` 同源，但被 `BattleScene.gd` / `SkillSystem.gd` 以 `Combatant.MAX_ENERGY` **静态**访问（5 处），`const` 无法运行时读表。已在这两个常量上补注释说明「改表须同步」；彻底改造需把常量改成静态取值并同步 5 个调用点，超出「简单」范围。 |
| C | `equip.json` rarity 4「史诗」无任何模板产出 | 30 个模板只分布 rarity 1/2/3，`drops.json` 装备池也只有 [1,2]/[2,3]。要么补 4 条史诗模板，要么删掉 rarity4 行——是内容决策，不是 bug 修复。 |
| D | `gacha.json daily_free/ten_guarantee`、`pets.json star_cap/evolve_to`、`growth.json equip_visual_tiers` | 这些字段**没有对应实现**（不是读错值，是功能没写）。接线等于新做功能（每日免费抽、进化、装备外观分档），已记入审计报告待排期。 |
| E | 删除 `image/role2/`（62.9 MB，58 文件，git 已跟踪） | 已核实 `src/` **0 引用**、带 `.gdignore`、与 `image/role/` 大量同路径（9 张不同但 mtime 更早，是改到一半的旧分支）。**可以安全删**，但属不可逆删素材，且 `docs/plans/2026-09-24-yuanzheng-master-plan.md:215` 还把它列为 P0 素材来源，所以只报告不代删。<br>确认后一条命令：`git rm -r "远征/image/role2"`（可从 `f8dedff` 恢复）。 |
| F | N-13 地表纯色块（`image/map/tileset/base/` 真图未接线） | 属功能接线改造，不是一两个值的问题，另行排期。 |

---

## 三、环境备注（下次省时间）

- 本机 Bash 缺 coreutils（`ls`/`head`/`tail`/`sed` 全部 not found），文件遍历一律走
  `C:\Users\Administrator\.workbuddy\binaries\python\versions\3.13.12\python.exe`。
- **PowerShell 工具无回显**，且 `run_regression.ps1` 末尾 `exit` 会终结宿主会话 → 无法在对话里驱动。
  本次改为用 `D:\new bee\_reg_run.py`（Python 逐字复刻该脚本的 5 条判定：退出码 / 行首 token /
  错误模式 / 超时 / 真实存档哈希），跑出 46/46。需要复跑时：`python _reg_run.py [用例名…]`。
- Godot 引擎：`…\WinGet\Packages\GodotEngine…\Godot_v4.7.2-stable_win64_console.exe`（`_console` 变体才有 stdout）。
  直接跑 `-s` 脚本用例必须 `stdin=DEVNULL`，否则 console 变体会挂住等输入。
