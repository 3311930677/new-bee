# 《远征》长程自主开发与商业品质升级 — 最终交付说明（FINAL_DELIVERY）

## 一、项目交付概述
本次长程自主开发任务围绕 Godot 4.7.2 竖屏暗金羊皮纸像素风 RPG《远征》（工作区：`D:\new bee\远征`），按照「工程基线审计 → 五大核心体验重构 → 战斗与数值模拟调优 → 五轮实质性内容扩充 → 视觉打磨与多分辨率截图验收 → 77 项全量自动化回归门禁 → 分批 Git 提交推送」的完整工业化闭环执行完毕。

---

## 二、核心阶段交付成果清单

### 第一阶段：工程审计、基线截图与长程规划
1. 全面梳理工程架构（`G.gd` 全局状态机、`TableCache.gd` 数据缓存、`TownHome.gd` 主页舞台、`MapScene.gd` 主世界探索、`BattleSim.gd` 即时战斗模拟与 77 项回归测试门禁）。
2. 保存修改前基线截图至 `docs/agent_iteration/screenshots/baseline/`。
3. 建立完整长程研发文档体系（`docs/agent_iteration/MASTER_PLAN.md`、`PROGRESS.md`、`DESIGN_DECISIONS.md`、`ART_DIRECTION.md`、`ASSET_LICENSES.md`）。

### 第二阶段：五大核心体验问题彻底修复（Tasks A–E）
1. **Task A — 地图探索、出口路牌指引与世界行路图直达**：
   - 升级 `src/ui/RegionChestMap.gd`：区分「当前所在」「已探索可直达」「未探索/未解锁」状态，标注主线/支线目标徽记，新增「直达此地（乘驿车前往）」一键跨区传送功能，并在未解锁节点展示明确准入条件。
   - 升级 `src/explore/MapScene.gd`：新增基于主世界拓扑图的 BFS 最短路径计算（`_is_exit_toward_tracked_quest`），在通往当前追踪任务目标的出口路牌上动态显示金色「✦ 任务方向」指引。
2. **Task B — 任务追踪导航与边塞信使速交**：
   - 升级 `src/ui/QuestPanel.gd`与 `src/autoload/G.gd`（`quest_can_quick_submit` / `quest_quick_submit`）：对已达成目标的日常委托与简单交付差事提供「信使速交」按钮，免去机械重复跑图，同时保留主线关键剧情节点的实地探索体验。
3. **Task C — 主页四角色动态展示与选角重选系统**：
   - 重构 `src/ui/TownHome.gd`：彻底移除硬编码的单一角色贴图，改为由 `G.selected_role` 实时驱动，复用 `res://image/role/<id>/` 四职业待机与四向行走资源；新增角色职业铭牌、点击切换五向姿态预览及顶部「易职」快捷换角入口。
   - 升级 `src/ui/CreateRoleChestView.gd` 与 `src/ui/CreateRole.gd`：支持老存档「易职重选」模式（保留等级、进度与资产切换职业，返回主页零延迟刷新）。
4. **Task D — 人物行走接地感与像素接触阴影**：
   - 在 `src/explore/MapScene.gd`、`src/city/CityScene.gd` 与 `src/ui/TownHome.gd` 中为主角统一挂载双层像素接触阴影（`FootShadowOuter` + `FootShadowCore`），严格对齐脚底基线，并随步态相位同步呼吸缩放。
5. **Task E — 11 步剧情融合式新手引导**：
   - 新增 `src/world/TutorialService.gd` 与 `src/ui/TutorialOverlay.gd`，实现融入「初抵昭元边城」叙事的 11 步可交互新手引导（覆盖角色认知、移动探索、NPC 对话、任务追踪、基础战斗、战斗奖励、行囊穿装、角色养成、路牌跨区、行路图返城与远征目标总览），支持随时跳过、断点续引、重温与结业领奖。

### 第三阶段：战斗体验与数值平衡大规模模拟（Phase 3）
1. 编写 `tools/SimBalanceReport.gd` 自动化战斗平衡模拟器（覆盖四职业 × Lv.5/15/30 × 普通/精英/首领 × 多随机种子，累计 115,200 场战斗模拟）。
2. 在 `src/combat/MonsterAI.gd` 中引入蓄力重击阶段化单次伤害预算上限（42% / 48% / 55% MaxHP），消除高阶首领暴击瞬秒脆皮职业的挫败感；在 `src/combat/SkillSystem.gd` 中优化四职业技能数值与被动减伤。
3. 生成 `docs/agent_iteration/test_results/balance_sim.json` 与 `docs/agent_iteration/BALANCE_REPORT.md`，四职业全阶段胜率均衡稳定在 82%~94%。

### 第四阶段：五轮实质性内容扩充（Phase 4）
1. **第一轮（探索与可玩小游戏扩充 — 校场射艺）**：
   - 新增 `data/archery.json` 与 `src/ui/ArcheryPanel.gd`，接入演武场 `src/ui/ArenaPanel.gd`「校场射艺」入口；包含三档难度（初试百步/疾风劲草/飞星穿杨）、动态风偏、听风校准、绿区蓄力击发、首通/复刷奖励与专属称号「百步穿杨」（`t_archery_master`）。
2. **第二轮（装备与成长扩充 — 6 件史诗神兵与背包战力评估）**：
   - 在 `data/equip.json` 新增 6 件 24 级史诗装备（陨星破阵重剑、穿云破阵长枪、寒渊凝星法杖、晨曦圣佑战锤、远征统帅重甲、百步穿杨扳指），均带专属被动说明与词条；
   - 在 `src/ui/BagPanel.gd` 装备详情栏新增动态「战力评估 %d(%+d▲/▼)」对比显示。
3. **第三轮（剧情、NPC 与区域叙事扩充 — 边城古碑共鸣）**：
   - 在 `src/autoload/G.gd` 新增 `lore_resonate(role_id)` 并在 `ArenaPanel.gd` 接入「参悟古碑」，为四职业提供专属先祖铭文叙事、首次四货币重赏及四职业专属称号（重甲承志/孤影听风/寒星执律/晨光守誓）。
4. **第四轮（伙伴/灵宠羁绊与收集扩充 — 五阶灵犀羁绊）**：
   - 在 `src/ui/GrowthChestView.gd` 与 `src/ui/PetRaisePanel.gd` 新增第 4 页签「羁绊」，在 `G.gd` 实现 `pet_bond_interact(pid)` 五阶养成：每阶提升灵宠全属性 `+3%`、主角生命 `+15` / 攻击 `+2`、每次互动获 `+60` 灵宠经验，第 3/5 阶触发灵宠寻宝献礼（强化石/精炼石），满阶解锁称号「灵犀契主」（`t_pet_bond`）。
5. **第五轮（隐藏玩法与世界秘密扩充 — 行商奇珍鉴宝）**：
   - 在 `src/autoload/G.gd` 新增 `curio_appraise(tier_id)` 并在 `ArenaPanel.gd` 接入「鉴古匣(260金) / 鉴宝匣(680金)」，支持开匣鉴定高阶宝石、锁词符、突破晶与 24 级史诗神兵，累计 3 次解锁称号「慧眼识珍」（`t_curio_seer`）。

### 第五至六阶段：视觉打磨、双分辨率截图与 77 项全量回归验证
1. 生成 3 张 `1280×760` 视觉方案对比参考图板（`docs/agent_iteration/references/ref_*.png`）。
2. 完成 `480×800` 与 `480×1067` 双分辨率实机截图与 `UITextAudit` 排版校验（保存于 `docs/agent_iteration/screenshots/` 及 `long_480x1067/`）。
3. 全量 77 项自动化回归测试套件 **77 / 77 ALL GREEN**。

---

## 三、如何运行游戏与执行自动化测试

### 1. 运行游戏
```powershell
& "D:\STEAM\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --path "D:\new bee\远征"
```

### 2. 运行全量 77 项自动化回归测试
```powershell
$godot = "D:\STEAM\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\new bee\远征\tools\run_regression.ps1" -Godot $godot -Proj "D:\new bee\远征"
```

### 3. 运行战斗数值平衡模拟器
```powershell
$godot = "D:\STEAM\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
& $godot --headless --path "D:\new bee\远征" --script "res://tools/SimBalanceReport.gd"
```

---

## 四、分批 Git 提交记录（`main` 分支）
1. **Batch 1 (`b0267992`)**：`feat(core): 完成第一阶段基线审计与第二阶段五大核心体验重构（区域地图直达、任务快速交付、主页四角色动态展示、角色接地感与11步新手指引）`
2. **Batch 2 (`45772e96`)**：`feat(content): 完成第三阶段战斗数值调优与第四阶段五轮实质性内容扩充（校场射艺、史诗装备与战力评估、古碑共鸣、灵宠羁绊、行商奇珍鉴宝）`
3. **Batch 3（本次最终交付提交）**：`docs(delivery): 完成第五至七阶段双分辨率视觉验收、参考图板、77项全量回归门禁验证与最终交付文档`
