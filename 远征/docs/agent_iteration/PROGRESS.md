# 《远征》长程开发实时进度表（PROGRESS）

- **当前阶段**：第七阶段（全量 77 项回归测试全绿、双分辨率截图验收与最终 Git 交付）
- **整体完成度**：**100%（全部七个阶段与五轮内容扩充均已完成并验证）**

## 阶段完成清单

- [x] **第一阶段：工程审计、基线和长程计划**
  - [x] Git 状态、分支与代理环境检查
  - [x] 工程目录、Autoload、场景树、存档格式与 77 项测试门禁梳理
  - [x] 基线截图采集（`docs/agent_iteration/screenshots/baseline/`）
  - [x] 建立 `docs/agent_iteration/` 全套规划与记录文档

- [x] **第二阶段：修复最严重的核心体验问题（Tasks A–E）**
  - [x] **任务 A（地图探索与连通）**：`RegionChestMap.gd` 已探索区域驿车直达、当前/目标徽记、未解锁准入提示 + `MapScene.gd` 出口路牌 BFS 任务方向指引
  - [x] **任务 B（任务系统与 NPC 体验）**：`QuestPanel.gd` 目标地图追踪导航 + 日常委托/简单差事「信使速交」
  - [x] **任务 C（主页四角色动态展示）**：`TownHome.gd` 动态绑定 `G.selected_role`、四职业精灵/朝向预览、角色铭牌与 `CreateRoleChestView.gd` 易职重选模式
  - [x] **任务 D（人物行走接地感）**：`MapScene.gd`、`CityScene.gd`、`TownHome.gd` 脚底双层接触阴影与步态重心相位同步
  - [x] **任务 E（完整新手教程）**：`TutorialService.gd` + `TutorialOverlay.gd` 11 步剧情融合式引导、跳过/重温/断点恢复与完成奖励
  - [x] **Git Batch 1 提交并推送**：`b0267992`

- [x] **第三阶段：战斗、技能、数值与成长重构**
  - [x] 编写 `tools/SimBalanceReport.gd` 执行 115,200 场四职业全阶段战斗模拟
  - [x] 优化 `MonsterAI.gd` 蓄力重击阶段化伤害上限与 `SkillSystem.gd` 四职业平衡
  - [x] 输出 `docs/agent_iteration/test_results/balance_sim.json` 与 `BALANCE_REPORT.md`

- [x] **第四阶段：五轮真正有内容的玩法扩充**
  - [x] **第一轮（探索与射艺小游戏）**：`data/archery.json` + `src/ui/ArcheryPanel.gd` 接入演武场 + 称号「百步穿杨」
  - [x] **第二轮（史诗装备与战力评估）**：`data/equip.json` 新增 6 件 24 级史诗神兵 + `BagPanel.gd` 动态战力评估对比
  - [x] **第三轮（边城古碑共鸣叙事）**：`G.lore_resonate` 四职业先祖铭文参悟 + 四货币首通赏 + 四职业专属称号
  - [x] **第四轮（灵宠五阶灵犀羁绊）**：`GrowthChestView.gd` 第 4 页签「羁绊」+ `G.pet_bond_interact` 五阶属性/主角加成/寻宝赠礼 + 称号「灵犀契主」
  - [x] **第五轮（行商奇珍鉴宝）**：`G.curio_appraise` 鉴古匣/鉴宝匣开匣鉴定 + 史诗神兵保底 + 称号「慧眼识珍」
  - [x] **Git Batch 2 提交并推送**：`45772e96`

- [x] **第五至七阶段：视觉升级、全量自动化测试、双分辨率截图验收与最终交付**
  - [x] 生成 3 张视觉设计参考图板（`docs/agent_iteration/references/ref_*.png`）
  - [x] 采集 `480×800` 与 `480×1067` 双分辨率实机截图并完成视觉检查
  - [x] 全量 77 项自动化回归测试套件 `ALL GREEN`（77 / 77 通过）
  - [x] 完成 `QA_REPORT.md`、`FINAL_DELIVERY.md`、`ART_DIRECTION.md`、`ASSET_LICENSES.md`、`DESIGN_DECISIONS.md`
  - [x] **Git Batch 3 最终提交并推送至 `origin/main`**
