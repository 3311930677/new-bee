# 差异审计报告的复核与新增问题

> 复核日期：2026-10-02
> 复核对象：`docs/plans/2026-10-02-gap-audit-vs-target.md`（下称"原报告"）
> 复核人：本次独立实机复跑 + 全库代码/数据/资源审计
> 结论摘要：原报告对**内容缺口**的判断基本可靠，但**回归结论与用例计数存在事实错误**，且遗漏了一批优先级更高的实现层缺陷。

---

## 0. 三条推翻原报告结论的硬发现

### F-01 【最高优先】原报告"41/41 PASS、FAIL=0"不成立——实为 45/46，`VerifyPerf` 真失败

原报告 §2 与 D-02 声称 runner 用例表只有 41 项，并据此判定"全绿"。本次按其 §7 给的复现命令实机复跑（`APPDATA` 已正确导出、commit `f8dedff`、Godot 4.7.2）：

```
Cases  : 46
FAIL  VerifyPerf  <- exit code 1; missing completion line 'PERF_OK';
                    output contains [ERROR:]; output contains [FAIL:]
      PERF_FAIL fails=1
      ERROR: FAIL: CityScene 进场景 418 ms 超出预算 320 ms
FAILED: 1 / 46
```

**用例表实测是 46 条，不是 41 条**（`tools/run_regression.ps1:83-130`）：41 个 `.tscn` 场景用例 + 5 个 `.gd` 脚本用例（`verify_data` / `verify_battle` / `verify_route` / `verify_trait` / `verify_walk_assets`）。这 5 条脚本用例原报告**一条都没列**，全部被漏掉。原报告据此推出的 D-02「默认 `-Expected 46` 与用例表不符、会直接 FATAL」是**误判**——46 正是默认值，且默认值与用例表一致。

原报告 §2 那份 41 项清单里**包含 `VerifyPerf` 并判定它 PASS**，与本次实测直接矛盾。

**`VerifyPerf` 是 flaky 用例**：单独复跑 3 次全部 `PERF_OK`（26 秒内跑完），但在整套 46 条串行回归中超时（418ms vs 预算 320ms）。原因是 `VerifyPerf.gd:167` 的 `BUDGET_CITY_MS = 320` 在整套回归的长时运行后受 GC/缓存状态影响，而它跑在第 33 位、前面已加载 32 个场景。

> 影响：原报告把"一条会随机变红的性能用例"记成了"绿"，并据此写下"功能回归全绿"。这条恰恰是**唯一**测真实性能预算的用例——它的失效直接抽掉了"性能 ≥30fps"这条硬验收的唯一自动化证据（G-05）。

### F-02 runner 的"存档未被污染"检查存在三处盲区，真实存档目录已积累 61 个残留文件

原报告 §2 用"存档哈希前后一致 `BA8054B3…`"作为可信度背书。该结论**技术上为真但检查范围严重不足**：

真实目录 `C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\远征\` 现有 **61 个** `save_verify_*.json` / `save_probe_*.json` / `save_backup_*.json`。其中 `save_backup_*.json` 的内容是**真实玩家档**（慕容岚 / Lv12 / gold 13008 / `avatar_custom: custom_*.png`）。

盲区在 `tools/run_regression.ps1:291-297`：只对 `save.json` **本体**做哈希。新建的备份/验证档是**新增文件**，不改变 `save.json` 哈希，因此永远抓不到；且第 219 行 `Test-Path` 在真实档缺失时会让整段检查被跳过。

根因（已核实）：`src/autoload/G.gd:100` + `:298` 中 G 是 autoload，`_ready()` 就调 `_load_save()`，而各 Verify 用例是在**自己的** `_ready()` 里才改 `G.SAVE_PATH`——autoload 早于场景节点初始化，所以每个 headless 用例启动时都会先读一次真实 `user://save.json`，若被判 invalid/future 则触发 `SaveData.backup_file` 在真实目录落盘。

`tools/VerifyRouteScene.gd:230-231` 更直接：`G.wallet = wallet_bak; G.save_game()` 把整份 `prog`/`items`/`city` 写进真实档，注释里只还原了 `wallet`。

**修法**：`_check` 前后各做一次 `user://` 全清单快照（文件名+哈希+数量）断言完全一致；把 `G.SAVE_PATH` 重定向提到最早可执行点。

### F-03 原报告漏掉了"战斗结算失败丢战利"这条 P0 实现缺陷

`src/explore/MapScene.gd:3136-3153`：`RewardLedger.apply()` 返回 `ok=false` 时只 `push_warning` 并清空 `msg_suffix`，**没有 return**；随后 `3145-3149` 无条件把 `st.gold/st.exp/st.soul/st.honor` 清零，而 `3153` 的提示文案仍用局部 `gold/exp` 拼出 **"战利 · 铜钱 +N · 经验 +M"**。

调用方 `MapScene.gd:2956` 拿到这个假成功后照常 `G.save_game()`，把"遭遇已推进 + 刷点已重置"落盘——**钱没到账，且玩家无法重打找回**（txid 未应用但遭遇已 advance）。

**对比**：同项目 `src/autoload/G.gd:924`（主线结算失败 `return {}`）与 `G.gd:1755`（支线失败完整回滚 wallet/prog/items）是正确写法，MapScene 是漏网的第三处。

> 复现：`data/equip.json` 某模板 id 改名，或 `drops.json` 引用不存在的 tpl，然后打任意怪。

---

## 1. 原报告漏掉的数据/数值层问题

| 编号 | 问题 | 证据 |
|---|---|---|
| **N-01** | **主线经验双写冲突**：`story_quests.json` s01–s28 仍是 v1 旧值，s29–s32（5924/13104/15178/17885）却已与 `campaign_growth.json` v2 **同值**。`CampaignGrowth.gd:35` 的旧档补领差额 = `steps[id].exp − story_quests.reward.exp`，因两表同值，**这四步补领恒为 0**。跳变本身是设计意图（逐级累加验证 32 步总经验 148,127 恰落 lv49，与 growth 曲线 100% 吻合），但"同一事实两个可写源且无一致性断言"，只改一表无任何回归拦截 | `story_quests.json:39-42`；`campaign_growth.json`；`CampaignGrowth.gd:12,35` |
| **N-02** | **等级上限 60 但内容终点只有 49 级**：主线结束时 lv49（余 90），lv49→60 还需 **234,825** 经验，按历练单局约 590 经验需 **约 398 局**。而 `titles.json` 的 `t_legend`(lv60)、`growth.json` 的 `equip_visual_tiers:[50,120,250]` 后两档、`talents.json` tier-10（lv60 仅 12 点）全按 50–60 区间设计。**即使 G-01 补齐第四幕，这 11 级仍无正常经验来源** | `growth.json`；`titles.json`；`talents.json` |
| **N-03** | **两张地图的建议等级与实际敌人等级矛盾**：`tidal_gate` 声明 [16,22] 实际刷 23 级；`frost_pass` 声明 [26,36] 实际刷 **40 级**。`RegionMapPanel.gd:112-115` 直接把 `regions[].level` 渲染成"建议 Lv26–36"给玩家 | `main_world_maps.json` vs `campaign_growth.json` 的 `enemy_levels` |
| **N-04** | **大量"改了也不生效"的死配置字段**（策划最危险的一类）：`nodes.json` 的 `difficulty_scale_per_layer` 零引用（`BattleSim.gd:57` 写死 `0.12`）；`growth.json` 的 `equip_visual_tiers`/`energy.*`/`basic_attack_interval` 零引用（`Combatant.gd:8` 写死 `MAX_ENERGY:=100`）；`gacha.json` 的 `daily_free`/`ten_guarantee` 零引用（面板硬编码）；`monsters.json` 46 条的 `theme` 字段全部零消费；`pets.json` 9 条 `evolve_to` 悬空 | 各文件 + 全仓 grep |
| **N-05** | **词条表 `hook` 字段 9/10 取值是死字段**：`TraitSystem.gd:44` 只判断 `== "passive"`，其余 `on_hit/on_crit/on_kill/...` 零消费。且三条词条数值代码硬编码覆盖表值：`tr_rampage`(0.06/stack5) 写死在 `TraitSystem.gd:154,331`；`tr_ctrl_2`(0.20) 写死在 `:245`；`tr_first_strike`(2.0) 写死在 `Combatant.gd:436`。`verify_trait.gd:87` 的表值对拍**只覆盖双刃词条**，这三条漂移无人看守 | `TraitSystem.gd`；`Combatant.gd`；`verify_trait.gd:87` |
| **N-06** | **导师第三档等级门槛与主线曲线错位（4 职业全中）**：`mentor_curriculum.json` `roles.*[2]` 写 `level:35, after:"s24"`，但 s24 的 target_level=32，lv35 要到 s25。`MentorCurriculum.gd:25-26` 先查 level 再查 story ⇒ s24 后 `status()` 返回 `"level"`，玩家必须**再打一场 s25 首领战**才能学第四式，UI 却提示"先完成：矿道留痕" | `mentor_curriculum.json`；`MentorCurriculum.gd:25-26` |
| **N-07** | **装备稀有度 4「史诗」永不产出**：`equip.json` 有 4 档 rarity，但 30 个模板的分布是 `{1:6, 2:6, 3:18}`，**无任何 rarity=4**；`drops.json` 的 tier 也只允许 [1,2]/[2,3]。其 `drop_weight:3` 从未参与计算 | `equip.json`；`drops.json`；`Inventory.gd:313-326` |

---

## 2. 原报告漏掉的测试体系问题

| 编号 | 问题 |
|---|---|
| **N-08** | **4 个用例基本是假验证**（`VerifyDrops` 仅 **5** 条断言、`VerifyPerf` 8 条纯耗时无任何功能不变量、`VerifyTransit` 11 条全是"节点/字段存在"且靠 `src.contains("change_scene_to_file")` **字符串扫描**、`VerifyNav` 11 条中 A 组靠 `src.contains("is_action_pressed(\"ui_cancel\")")` 文本匹配）。改名或注释掉按钮即假失败，而"字段存在"证明不了行为正确 |
| **N-09** | **大量用例把数据表当前值写死成期望值**：`VerifyCampaignGear.gd:31`（模板==30）、`VerifyGrowth.gd:98-101`（30 节点/6 槽/6 坐骑）、`VerifyGacha.gd:56`（pity==60）、`VerifyThirdSide.gd:39`（18 支线）、`VerifySecondAct.gd:279`（6 条）、`VerifyStory.gd:173`（6 条）、`VerifyRouteScene.gd:94,114,179`（节点 11 / gold+200 / soul>=15）。策划改表即批量假失败，无法区分"真回归"与"表改了" |
| **N-10** | `VerifyRouteScene.gd:230-231` 收尾只还原 `wallet` 就写盘（见 F-02） |
| **N-11** | `VerifyDrops` 恰恰缺了事务/幂等断言——而 F-03 的丢战利 bug 正在它该覆盖的领域 |

---

## 3. 原报告漏掉的资源层问题（可直接回收 ~165 MB）

| 编号 | 问题 | 量级 |
|---|---|---|
| **N-12** | **`image/role2/` 是 `image/role/` 的整目录副本**。`src/` 中 `role2` 出现 **0 次**（加载点全指向 `image/role/`）。57 个同路径文件中 48 个 MD5 一致，但 9 个不同——**其中 4 张正是代码实际加载的四职业行走图集**。含义：这是"改到一半的旧分支"，改它不生效、重绘时极易误改 | **62.9 MB，建议整删** |
| **N-13** | **`image/map/` 49.9 MB 完全未被引用**，代码只加载 `image/map_proc/`（0.5 MB）。94 个同名文件 0 个相同：`map/001_tile_forest_1.png` = 1254×1254/991KB，`map_proc/` 同名 = **48×48/4KB**。即**素材库里有真图但没接上，跑的是程序化纯色块**——这正是 G-04"地表是纯色矩形"的物理成因 | **49.9 MB** |
| **N-14** | **4 处 `res://` 引用指向不存在的文件**：`CityScene.gd:2149` 与 `LoadScreen.gd`/`VerifyCity.gd` 的 `city_%s_reference_v2.png`（库中仅 3 个 `frost_*` 存在）；`tools/register_monster_art.py` 的 `mon_lost_beast_reference_v2.png` / `mon_shadow_wolf_reference_v2.png`（同目录已有改名后的文件）。运行时走 `G.res_tex` 兜底**静默显示空图** | 4 处 |
| **N-15** | **多版本素材并存，重绘时必选错**：`main_world/` 下 `lorin_wilds_reference_v3/v4/v5/v6` 四版并存（仅 v6 被引用）、`grass_v1/v2` 两版**都无引用**、`classic_floor_reference_v1/v2` 尺寸 971×**1619/1620**；`generated_334_341/ready/` 8 张 `world_*`（各约 1.5MB）**只有 `world_forest.png` 被引用**——意味着雪原/沙漠/火山/墓地把森林图当背景 | **约 16 MB** |
| **N-16** | **坐骑图 4 张各 1330×1182 / 约 1.06MB**，`MountPanel.gd:92-97` 用 `EXPAND_IGNORE_SIZE` 缩到约 120px 宽——**解出约 25 MB 显存，UI 里只用到 3%**。建议出 256×256 版 | 显存 |
| **N-17** | **安全区适配代码完全缺失**：77 个 `.gd` 中 `get_display_safe_area()` 调用数 = **0**。`project.godot` 的 `stretch/aspect` 未设置 → 默认 `keep`(letterbox)。720×1600(比例0.45) 比 480×800(0.6) 更窄，`keep` 会左右留黑边。**原报告 G-12"缺长屏验证"的根因在此**——不是没测，是没配 `expand` | 配置 |
| **N-18** | **`src/ui/` 410 处硬编码像素**（334 处 `position` + 76 处 `custom_minimum_size`），3 处超出 480×800 画布：`RegionMapPanel.gd:38` 宽 **900** vs 屏宽 480；`CreateRole.gd:56` x=-120；`GameHome.gd:226` x=-115。**字号缩放系数不存在**（字号统一走 `G.FS_*` 固定像素常量，`content_scale_factor` 在 `.gd` 中出现 0 次） | UI |
| **N-19** | **505 张 ≥4096px 的图完全不透明**（`mode=RGB` 根本无 alpha 通道）：`assets_regen/batch5_scene_map/ready/backgrounds/` 4 张背景全不透明、`batch3_combat/ready/effects/` 8 张 256×256 特效图全不透明。特效/建筑本应带 alpha 边缘 | 内存 |
| **N-20** | **`ui_kenney/` 是 Kenney 外部素材包**（9 张奇数边长：22×21、9×18、16×15、34×37），在 `nearest` 过滤下产生半像素抖动与接缝；**这也是"美术风格与参考图偏离"的来源之一**（第 7 条） | 风格 |
| **N-21** | **字体 4 个共 46.0 MB**：`NotoSerifCJKsc-SemiBold.otf` 单文件 **23.6 MB**、NotoSansSC Bold 8.3MB / Regular 8.1MB、ZCOOLXiaoWei 6.0MB，均被引用。移动端应按实际用字子集化，**可省 40 MB+** | 40 MB |
| **N-22** | 项目根目录误入 `NVIDIA Corporation/`（显卡驱动目录）；`tools/_logs/` 已积累 387 个日志 / 77.5 MB，应 gitignore | 清理 |

---

## 4. 对原报告既有结论的复核意见

| 原报告条目 | 复核意见 |
|---|---|
| G-01 结局缺失 | ✅ 成立，已复核 s32 `next:""` 发放 `stele_key` 且全库无「界碑深处」 |
| G-02 副本单房 | ✅ 成立 |
| G-03 支线 18/36 | ✅ 成立（另见 N-01/N-06 的数据层问题） |
| G-04 美术风格 | ✅ 成立，**但根因应补 N-12/N-13/N-15/N-20**：真图存在却没接上，多版本素材与外部素材包并存 |
| G-05 无人工时长/真机 | ✅ 成立，**且比报告更严重**：唯一性能用例 VerifyPerf 本身 flaky（F-01） |
| G-06/G-07/G-08 三系统缺失 | ✅ 成立，grep 确认零命中 |
| G-09/G-10 坐骑 | ✅ 成立，另 N-16 补显存问题 |
| G-11~G-14 | ✅ 成立，另 N-17/N-18 补根因 |
| G-15 历练不落档 | ✅ 成立 |
| G-22 issue #43 RID 泄漏 | ✅ 成立且已复核：本次回归 29 个用例共 67 条退出期资源诊断 |
| G-23 音频 | ✅ 成立（6 BGM / 22 SFX 无地区维度），另 `bgm_battle.ogg` 1652KB、`bgm_home.ogg` 1397KB 明显大于其余 4 个（108–280KB），未做流式裁剪 |
| **D-01** APPDATA 归因 | ✅ 成立（`run_regression.ps1` 确实无 APPDATA 兜底） |
| **D-02** 用例计数混乱 | ❌ **误判**。用例表实为 46 条，默认 `-Expected 46` 正确；报告漏数了 5 个脚本用例，并据此得出"会 FATAL"的错误结论 |
| **§2 "41/41 PASS, FAIL=0"** | ❌ **事实错误**。实为 45/46，`VerifyPerf` 失败 |
| **§2 存档哈希背书** | ⚠️ 结论为真但证据不足，检查有 F-02 三处盲区 |
| D-03~D-07 | ✅ 成立 |

---

## 5. 建议的优先级重排

原报告把 G-04 美术列为第一优先（第二项），依据是"用户已明确反馈画风严重偏离"。但**美术问题里优先级最高的是接线而非重绘**：N-13 表明真图已存在却跑在 48×48 程序化纯色块上，N-12 表明重绘时极易改到不生效的 `role2/`。

建议顺序：

1. **F-01** 修 `VerifyPerf` 的 flaky（CityScene 预算或预热），恢复性能硬验收的可信度；**F-03** 修战斗结算丢战利 + 假成功文案
2. **F-02** runner 加 `user://` 全清单快照断言（止血），再统一重定向 13 个用例的 `SAVE_PATH`
3. **G-01** 第四幕后半 + 结局（唯一剧情断头）+ **N-02** 等级上限与内容终点的矛盾（一起决策，否则补完仍卡在 49 级）
4. **N-13/N-12** 美术**接线与清理**（不是重绘）：接上 `image/map/tileset/base/` 真图、删 `role2/`，再谈 R-08 逐张重绘
5. **N-17** 补 `stretch/aspect="expand"` + 安全区——这是长屏适配的根因，成本极低收益极高
6. **G-02** 四副本多房间 + 机关链；**G-03** 支线补至 36
7. **N-08/N-09** 测试体系整改：给 4 个假验证补真实行为断言；把写死的表值断言改为不变式断言
8. G-06~G-10、G-15 及 P2 各项按原报告顺序

---

## 6. 复现命令（本次实测通过）

```powershell
$env:APPDATA="C:\Users\Administrator\AppData\Roaming"   # 关键：否则 user:// 变相对路径
$env:GODOT_EXE="<Godot 4.7.2 路径>"
Set-Location "D:\new bee\远征"
& powershell -NoProfile -ExecutionPolicy Bypass -File "tools\run_regression.ps1" -Expected 46
```

**注意**：默认 `-Expected 46` 与用例表一致，**不要**按原报告改成 41（会 FATAL：预期 46 实调 46 虽一致，但把参数写成 41 会触发 `expected 41 cases, scheduled 46` 而退出）。

### 附：核实过程中使用的只读检查

- 存档已备份至 `D:\new bee\_audit_backup\save.json.bak`（原哈希 `BA8054B3D2F46D21D5CFE70E6EF5EFCADCC817A8267FF67FC7522379E2805BE7`，回归后未变）
- 未修改任何项目源码或数据表