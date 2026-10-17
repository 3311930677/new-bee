# 《远征》长程自主开发与商业品质升级 — 最终交付说明（FINAL_DELIVERY）

## 1. 最终工程所在目录和版本
- **工程根目录**：`D:\new bee\远征`（Git 仓库根目录：`D:\new bee`，当前分支：`main`）
- **Godot 引擎版本**：`Godot Engine v4.7.2.stable.steam.ed1daf0bf`
- **可执行文件路径**：`D:\STEAM\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`
- **基准视口分辨率**：`480×800`（支持 `480×1067` 全面屏长屏自适应，`canvas_items` + `expand`，Nearest 像素采样）

---

## 2. 运行 Godot 项目与快速开发验收入口的方法
### 2.1 正常启动游戏
```powershell
& "D:\STEAM\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --path "D:\new bee\远征"
```

### 2.2 快速开发验收入口（不污染真实存档的独立场景预览与截图工具）
项目内置 `res://tools/ShotRunner.tscn`（自动将存档重定向至 `res://tools/_logs/save_shot_runner.json`，绝不污染玩家真实存档 `user://save.json`），支持一键直达任意新增玩法或界面：
```powershell
$godot = "D:\STEAM\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
# 预览主页（可指定 --role=zs / ck / fs / fz）
& $godot --path "D:\new bee\远征" "res://tools/ShotRunner.tscn" -- --scene=home --role=ck --frames=120
# 预览第一轮扩充：校场射艺小游戏
& $godot --path "D:\new bee\远征" "res://tools/ShotRunner.tscn" -- --scene=archery --frames=120
# 预览第二轮扩充：史诗装备与动态战力评估
& $godot --path "D:\new bee\远征" "res://tools/ShotRunner.tscn" -- --scene=bag --frames=120
# 预览第三 & 五轮扩充：边城古碑共鸣与行商奇珍鉴宝
& $godot --path "D:\new bee\远征" "res://tools/ShotRunner.tscn" -- --scene=arena_curio --frames=120
# 预览第四轮扩充：灵宠养成「羁绊」页签
& $godot --path "D:\new bee\远征" "res://tools/ShotRunner.tscn" -- --scene=pet_bond --frames=120
```

### 2.3 运行全量 77 项自动化回归测试套件
```powershell
$godot = "D:\STEAM\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\new bee\远征\tools\run_regression.ps1" -Godot $godot -Proj "D:\new bee\远征"
```

---

## 3. 已完成的所有主要功能
1. **Task A — 地图探索、出口路牌指引与世界行路图直达**（`src/ui/RegionChestMap.gd`、`src/explore/MapScene.gd`）：
   - 世界行路图区分「当前所在」「已探索可直达」「未探索/未解锁」状态，标注主线/支线目标徽记，支持点击「乘驿车前往」一键跨区直达已探索区域；
   - 野外地图出口路牌通过主世界连通图 BFS 最短路径算法，动态高亮显示通往当前追踪任务目标的「✦ 任务方向」指引。
2. **Task B — 任务追踪导航与边塞信使速交**（`src/ui/QuestPanel.gd`、`src/autoload/G.gd`）：
   - 对达成完成条件的日常委托与简单交付差事提供「交付 / 信使速交」快捷结算按钮，并提供「行路图」按钮一键定位目标区域。
3. **Task C — 主页四角色动态展示与易职重选系统**（`src/ui/TownHome.gd`、`src/ui/CreateRoleChestView.gd`、`src/ui/CreateRole.gd`）：
   - 主页城门舞台角色完全由 `G.selected_role` 驱动（破军 `zs` / 穿杨 `ck` / 霜语 `fs` / 晨星 `fz`），配备职业铭牌、点击切换五向姿态及顶栏「易职」按钮；
   - 选角页支持老存档「易职重选」模式（切换职业时完整保留等级、主线进度、钱包与装备背包，返回主页立即刷新）。
4. **Task D — 人物行走接地感与像素接触阴影**（`src/explore/MapScene.gd`、`src/city/CityScene.gd`、`src/ui/TownHome.gd`）：
   - 为主角统一挂载双层像素接触阴影（`FootShadowOuter` + `FootShadowCore`），严格对齐脚底基线，移动时随步态相位同步呼吸缩放与重心起伏。
5. **Task E — 11 步剧情融合式新手引导**（`src/world/TutorialService.gd`、`src/ui/TutorialOverlay.gd`）：
   - 融合「初抵昭元边城·执事闻叔指引」叙事的 11 步交互式引导，覆盖角色认识、移动探索、NPC 对话、任务追踪、基础战斗、战斗奖励、装备穿戴、角色成长、地图切换、返回边城与后续远征目标说明，支持跳过、断点续引、重温与完成奖励。
6. **Phase 3 — 战斗体验与四职业数值平衡重构**（`src/combat/MonsterAI.gd`、`src/combat/SkillSystem.gd`、`tools/SimBalanceReport.gd`）：
   - 引入敌人蓄力重击阶段化单次伤害预算上限（普通 42% / 精英 48% / 首领 55% MaxHP），强化四职业特色被动，完成 115,200 场模拟验证。

---

## 4. 五轮扩充对应的实际内容与进入方法

| 轮次 | 玩法主题 | 核心文件 | 如何进入与体验该玩法 |
| :---: | :--- | :--- | :--- |
| **第 1 轮** | **校场射艺（风偏与蓄力射箭小游戏）** | `data/archery.json`<br>`src/ui/ArcheryPanel.gd`<br>`src/ui/ArenaPanel.gd` | 主页点击「竞技场（演武场）」→ 点击底部左侧 **「校场射艺」** 按钮 → 选择「初试百步 / 疾风劲草 / 飞星穿杨」三档难度，点「听风校准」微调准星，按住「按住蓄力射箭」在绿区（72%–88%）松手射箭；达标获强化石/精炼石/荣誉，满 42 环解锁称号 **【百步穿杨】**。 |
| **第 2 轮** | **6 件史诗神兵与动态战力评估** | `data/equip.json`<br>`src/ui/BagPanel.gd` | 主页点击右上角 **「背包」** → 选中任意武器/护甲/饰品 → 详情面板顶部副标题实时显示 **「战力评估 %d(%+d▲/▼)」**，史诗神兵（如陨星破阵重剑、穿云破阵长枪、寒渊凝星法杖、晨曦圣佑战锤等）额外展示专属被动词条。 |
| **第 3 轮** | **边城古碑共鸣（四职业先祖叙事）** | `src/autoload/G.gd`<br>`src/ui/ArenaPanel.gd`<br>`data/titles.json` | 主页点击「竞技场（演武场）」→ 点击底部右侧 **「古碑鉴宝」** → 点击 **「参悟古碑」** 即可激活当前职业先祖碑文共鸣，首次参悟获金币/远征币/魂晶/荣誉四货币重赏并解锁当前职业专属称号（重甲承志/孤影听风/寒星执律/晨光守誓）。 |
| **第 4 轮** | **灵宠五阶灵犀羁绊与寻宝献礼** | `src/ui/GrowthChestView.gd`<br>`src/ui/PetRaisePanel.gd`<br>`src/autoload/G.gd` | 主页点击底部「养成」→ 选择「灵宠养成」→ 切换到第 4 页签 **「羁绊」** → 点击 **「羁绊互动」** 消耗宠物粮与金币提升羁绊阶数（最高 5 阶）：每阶灵宠全属性 `+3%`、主角生命 `+15`/攻击 `+2`，第 3/5 阶额外获赠寻宝强化石/精炼石，满 5 阶解锁称号 **【灵犀契主】**。 |
| **第 5 轮** | **行商奇珍鉴宝（蒙尘古匣开匣）** | `src/autoload/G.gd`<br>`src/ui/ArenaPanel.gd`<br>`data/titles.json` | 主页点击「竞技场（演武场）」→ 点击底部右侧 **「古碑鉴宝」** → 点击 **「鉴古匣(260金)」** 或 **「鉴宝匣(680金)」** 开启蒙尘古匣，随机鉴定出高阶宝石、精炼石、锁词符、突破晶或 24 级史诗神兵；累计鉴宝 3 次解锁称号 **【慧眼识珍】**。 |

---

## 5. 专项功能测试与验收步骤

### 5.1 如何测试新手教程（Task E）
1. **游戏内手动体验**：进入主页 → 打开底部「设置」或触发 `GameHome._open_tutorial()` 呼出「新手指引」浮层 → 点击「前往体验」跳转到当前步骤对应面板/场景，或点击「下一步 / 上一步 / 跳过」验证 11 步引导状态流转与第 11 步完成奖励领取。
2. **自动化测试验证**：运行 `VerifyGameHome`（包含 Section M 新手指引 11 步全流程与持久化断言）：
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "D:\new bee\远征\tools\run_regression.ps1" -Godot "D:\STEAM\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" -Proj "D:\new bee\远征" -Only "VerifyGameHome" -Expected 1
   ```

### 5.2 如何测试四角色切换与主页动态展示（Task C）
1. **游戏内手动体验**：
   - 在主页城门舞台点击主角小人，观察朝向在「待机 → 朝南 → 朝西 → 朝东 → 朝北」五态间切换；
   - 点击顶栏昵称右侧的 **「易职」** 按钮进入角色重选界面，切换为「破军·战士 / 穿杨·枪骑 / 霜语·法师 / 晨星·牧师」任一职业并确认，返回主页即可看到城门前的小人精灵与下方职业铭牌立即同步更新。
2. **自动化测试验证**：运行 `VerifyGameHome`（Section L 遍历 `zs`/`ck`/`fs`/`fz` 四角色选角、主页精灵纹理、铭牌、存档保存与重载恢复）。

### 5.3 如何测试地图连通与任务速交（Task A & Task B）
1. **游戏内手动体验**：
   - 在主页点击「世界」打开「地区行路图」，点选已探索区域（如「枫林古道」），点击右下角 **「乘驿车前往」** 即可直接进入该主世界地图；
   - 在野外地图观察通往当前追踪任务目标的出口路牌，带有金色 `✦` 任务方向标识；
   - 打开「任务卷宗」，对已达成条件的委托点击 **「交付」** 即可直接远程结算奖励。
2. **自动化测试验证**：运行 `VerifyMainWorld,VerifyMapScene,VerifyNav,VerifyTransit,VerifyQuests`。

### 5.4 如何查看数值测试结果（Phase 3）
- **结构化 JSON 原始数据**：`D:\new bee\远征\docs\agent_iteration\test_results\balance_sim.json`
- **完整数值分析与调优报告**：`D:\new bee\远征\docs\agent_iteration\BALANCE_REPORT.md`

### 5.5 如何查看前后对比图片与参考图板（Phase 5 & Phase 6）
- **修改前基线截图（Before）**：`D:\new bee\远征\docs\agent_iteration\screenshots\before\`
- **修改后实机截图（After，`480×800`）**：`D:\new bee\远征\docs\agent_iteration\screenshots\after\`
- **修改后长屏自适应截图（After，`480×1067`）**：`D:\new bee\远征\docs\agent_iteration\screenshots\long_480x1067\`
- **左右同屏直观对比图（Comparisons）**：
  - **第二轮重点精修对比图（V2 Polish Comparisons）**：
    - `D:\new bee\远征\docs\agent_iteration\screenshots\comparisons\compare_v2_1_archery_minigame.png`（新增小游戏【校场射艺】截图 → 视觉参考图 → 实景靶场重构精修对比）
    - `D:\new bee\远征\docs\agent_iteration\screenshots\comparisons\compare_v2_2_curio_minigame.png`（新增小游戏【古碑鉴宝】截图 → 视觉参考图 → 双舞台实景重构精修对比）
    - `D:\new bee\远征\docs\agent_iteration\screenshots\comparisons\compare_v2_3_tutorial_flow.png`（11 步任务驱动新手教程：全流程自动切换对应页面 + 聚光灯挖空高亮对比）
    - `D:\new bee\远征\docs\agent_iteration\screenshots\comparisons\compare_v2_4_settings_reselect.png`（设置面板找回并置顶【重选角色 · 易职】双入口对比）
    - `D:\new bee\远征\docs\agent_iteration\screenshots\comparisons\compare_v2_5_home_heroes.png`（主页城门下方四职业专属守望立绘重构与 2x 局部特写对比）
  - **第一轮基础功能对比图**：
    - `D:\new bee\远征\docs\agent_iteration\screenshots\comparisons\compare_home_role_sync.png`
    - `D:\new bee\远征\docs\agent_iteration\screenshots\comparisons\compare_world_map_travel.png`
    - `D:\new bee\远征\docs\agent_iteration\screenshots\comparisons\compare_quest_quick_submit.png`
    - `D:\new bee\远征\docs\agent_iteration\screenshots\comparisons\compare_bag_epic_power.png`
- **视觉方案参考总览图板（References）**：
  - `D:\new bee\远征\docs\agent_iteration\references\ref_minigame_archery_v2.png`（校场射艺小游戏实景精修参考图）
  - `D:\new bee\远征\docs\agent_iteration\references\ref_minigame_curio_v2.png`（古碑共鸣与行商鉴宝双舞台精修参考图）
  - `D:\new bee\远征\docs\agent_iteration\references\ref_role_select_concepts.png`
  - `D:\new bee\远征\docs\agent_iteration\references\ref_world_map_hud_concepts.png`
  - `D:\new bee\远征\docs\agent_iteration\references\ref_archery_curio_concepts.png`

---

## 6. 关键 Git Commit 哈希清单（`main` 分支）
1. **`b0267992`**：`feat(core): 完成第一阶段基线审计与第二阶段五大核心体验重构（区域地图直达、任务快速交付、主页四角色动态展示、角色接地感与11步新手指引）`
2. **`45772e96`**：`feat(content): 完成第三阶段战斗数值调优与第四阶段五轮实质性内容扩充（校场射艺、史诗装备与战力评估、古碑共鸣、灵宠羁绊、行商奇珍鉴宝）`
3. **`f67372a3` / `cc0d7d94`（及第二轮精修归档提交）**：`feat(polish): 完成小游戏参考图驱动实景重构、全流程自动切页新手教程、设置置顶重选角色与四职业主页城门守望立绘精修`

---

## 7. 当前存在的已知问题与后续优化建议
1. **已知非阻塞引擎诊断（Issue #43）**：Godot 4.7.2 OpenGL Compatibility 渲染器在命令行进程退出时偶发输出 `1 RID allocations of type 'N5GLES37TextureE' were leaked at exit` 诊断日志，属于引擎已知退出清理顺序现象，不影响游戏运行帧率、内存或 77 项回归门禁判定。
2. **无法完成项目的阻塞项**：**无**（全部 7 个阶段、第二轮 4 项重点视觉与交互精修、双分辨率截图与 77/77 全量自动化测试均已 100% 完成）。

