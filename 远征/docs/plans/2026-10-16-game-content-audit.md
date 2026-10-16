# 《远征》游戏内容审查报告

- **审查日期**：2026-10-16
- **审查对象**：`D:\new bee\远征`（Godot 4.7.2 / Compatibility / 480×800 竖屏 / JSON 表驱动）
- **代码基线**：`b53c40ac`（源码 `src/` 共 168 个 `.gd`，`data/*.json` 共 52 份，`tools/` 回归相关文件 298 个）
- **截图与文字基线**：`shots/rounds/Version_3.10_{before,after}_{title,home,city,battle,forge,rare_ceremony}.{png,text.json}`（6 核心场景 290 个文字节点；全量 `Version_*_after_*.text.json` 60 份共 2,222 个文字节点）
- **审查身份与边界**：资深技术美术 + 数值策划 + 工程审查员。商业美术笔触与构图交由独立美术复审；本报告聚焦文档一致性、实现层规范、数据数值闭环、视觉风格自洽、资源体积与测试体系。

---

## 0. 一句话结论

**《远征》核心循环、数值克制与测试管线已达可上线工程水准，但「文档即真相源」与「全局统一规范」在执行层失守——`G.FS_*` 字号阶梯被 48 处字面量绕过（21 处低于 `FS_XS=15` 下限，最低 11px，属历史已修项回退），`G.gd:88` 注释与 4 份文档滞留旧阶梯，360 MB 资源中含 22.5 MB 零引用字体/快照与 38 个构建日志，此刻修统一收敛层与 CI 门禁比加新功能更紧迫。**

---

## 1. 优点

### A1. [数据数值层] 主线难度阶梯跨档单调递增，试炼反刷规则直接写进数据
- **结论**：14 张主线图在 `data/campaign_difficulty.json:3-130` 中分为三档，普通怪 `hp×/atk×/def×` 与首领 `boss_hp×/boss_def×` 跨档严格单调递增；副本反刷机制由结构化字段驱动而非靠文档口头约束。
- **证据**：`data/dungeon_trials.json:5,16,26` 中 `stele_cavern`（需 `s10`）、`tidal_gate`（需 `s19`）、`rift_mine_vault`（需 `s25`，`no_potions: true`）均内置分步 `steps`（`listen`/`align`/`escort`/`defeat`）与 `reward`，并明文约束“再挑战只练习，不发首通物、金币或经验”。

| 难度档 | 普通怪 `hp× / atk× / def×` | 首领 `boss_hp× / boss_atk× / boss_def×` | 覆盖图数 | 地图 ID（`data/campaign_difficulty.json:3-130`） |
|---|---|---|---|---|
| 一档 | `1.16 / 1.30 / 1.00` | `1.22 / 1.45 / 1.00` | 4 张 | `old_salt_road` `shenyuan_port` `tideflat` `tidal_gate` |
| 二档 | `1.22 / 1.50 / 1.02` | `1.40 / 1.85(矿库1.60) / 1.05` | 6 张 | `red_sand_route` `frost_post` `rift_mine_road` `rift_mine_vault` `frost_boardwalk` `frost_pass` |
| 三档 | `1.28 / 1.70 / 1.04` | `1.55 / 2.20 / 1.08` | 4 张 | `abyss_ring` `stele_entry` `stele_resonance` `stele_core` |

### A2. [文档一致性] 核心数据表内置“防脱节说明”，主动隔离展示字符串与执行参数
- **结论**：关键表通过顶层 `comment` 与 `*_note` 明确规定代码读取的唯一参数源，防止策划注释与代码实现脱节。
- **证据**：
  - `data/growth.json:5` 的 `exp_formula_note` 明文标注：`"lv*100 + 2*pow(5, 0.1*lv)。此字符串只是给人看的说明；实际计算读下面的 exp.type 与 exp 参数，代码不执行表里的字符串。"`
  - `data/drops.json:3,20-24` 说明 `equip` 仅声明档位允许掉出的稀有度（`normal:[1,2]`、`elite:[2,3]`、`boss:[2,3]`），具体掉落概率由 `data/equip.json:845-855`（`0.12/0.35/1.0`）与 `data/equip.json:171-207` 的 `drop_weight`（`60/25/12/3/0`）联动结算，且剧情/传世装在 `data/equip.json:396,793` 显式设 `random_drop: false`。

### A3. [数据数值层] 养成上限、跑商摩擦与四币职责隔离清晰克制
- **结论**：装备强化、角色成长与跑商经济参数透明，无暗改系数，四种货币产销回路互不串味。
- **证据**：
  - `data/equip.json:3,359-365`：仅 6 槽位，强化上限 20 级、每级 `+10%`、`guaranteed_target: 3`（+3 前必成）、失败不掉级且每次失败累加 `+15%` 保底补偿（`failure_rate_bonus: 0.15`），与 `src/ui/EquipChestView.gd:208` 文案 `"失败不掉级"` 一致。
  - `data/economy.json:3-7`：`carry_limit: 28` 限制跑商单趟容量，`buy_markup_pct: 110` / `sell_bid_pct: 88` 形成固定 22% 价差摩擦。
  - `data/currencies.json:3-16`：`gold`（主世界流通）、`expedition`（界碑历练）、`soul`（灵宠养成）、`honor`（演武挑战）逐项定义 `scope`、`source`、`use`。

### A4. [实现层] `UIReadability.gd` 提供渲染级可读性兜底，实测 2,222 个文字节点零裁切
- **结论**：`src/ui/UIReadability.gd:4-16` 用统一规则在渲染层兜住了文字采样、小字号装饰字降级与描边收敛。
- **证据**：
  - `src/ui/UIReadability.gd:7` 强制文字控件 `node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR`，对冲了 `project.godot:47` 全局默认最近邻过滤（`default_texture_filter=0`）引起的细笔画断裂（见 `docs/plans/2026-10-05-ui-font-readability-and-feedback.md:11`）。
  - `src/ui/UIReadability.gd:12-15` 在 `px < 24` 时自动将 `G.font_display` / `G.font_art` 降级为 `G.font_bold` / `G.font_reg` 并将 `outline_size > 1` 压至 `1`，而在 `city` 36px 标题「昭元边城」中保留 `MaShanZheng-Regular.ttf` 书法字体。
  - **实测验证与漏调后果**：`Version_3.10_after_*.text.json`（6 场景 290 节点）及全库 60 份 `Version_*_after_*.text.json`（2,222 节点）中 `rect_height < height` 裁切数为 **0 处**。但**一旦某处新建文字节点漏调 `UIReadability.apply_to()`，F-01 中的 11–14px 小字将直接继承 `project.godot:47` 最近邻过滤并叠加粗描边，瞬间从“字号偏小”恶化为“笔画粘连不可读”**。

### A5. [测试体系] 回归脚本与 `.text.json` 文字审计管线密度极高
- **结论**：项目具备细粒度功能回归与可程序化断言 UI 渲染结果的导出管线。
- **证据**：`tools/` 下共有 **298 个** `Verify*`/`regression` 相关文件（98 个 `.gd` + 91 个 `.tscn` 及辅助脚本），`shots/rounds/` 自动导出 `text_nodes[].{path,font,size,text,rect_height,height}`，为字号收敛与防裁切提供了直接机器判据。

---

## 2. 缺点

### F-01【严重】[实现层] `G.FS_*` 字号阶梯被 48 处字面量与动态参数绕过，21 处低于最小档且属修复回退
- **结论**：`src/autoload/G.gd:89-94` 定义最小档 `FS_XS := 15`，但源码（排除 `src/preview/`）有 **48 处**硬编码字号调用（其中 **21 处单值字面量 + 2 处三元分支低于 15px，最低 11px**），且 `G.gd` 工厂动态传入了阶梯外的 `20/26/36px`；对照 `docs/plans/2026-10-02-gap-audit-vs-target.md:238`“硬编码字号扫描零命中”，属**已修复项回退**。
- **证据**：字面量频次（排除 `preview/`）为 `12px×11, 16px×9, 13px×5, 14px×5, 22px×4, 15px×3, 11px×2, 17px×2, 18px×2, 19/20/21/24/26px×1`；`Version_3.10_after_*.text.json` 6 场景 290 节点中 5 场景含 12–14px，且含工厂动态算出的 `20/26/36px`：

| 违规来源 | 文件:行号 | 字号（px） | 涉及控件与实测分布 |
|---|---|---|---|
| 11px 字面量 | `src/explore/MapScene.gd:1112`、`src/ui/QuestPanel.gd:215` | **11px**（2 处） | 玩家头顶名签 `_player_name_l`、委托标签 `who_label` |
| 12px 字面量与三元 | `src/battle/BattleScene.gd:2472,2537`、`src/battle/BattleChestView.gd:369,406`、`src/explore/MapScene.gd:1276,4749,4883`、`src/ui/JournalUI.gd:300`、`src/ui/RegionChestMap.gd:210,244`、`src/city/CityScene.gd:3138` | **12px**（9 处单值 + 2 处 `12 if ... else 14`） | 战斗单位名、战斗副标题、跟随标签、交互提示、怪物等级、手记标记、区域边签、城务 NPC 名签 |
| 13–14px 字面量 | `src/ui/LoginChestView.gd:144`、`src/ui/QuestPanel.gd:61`、`src/ui/RareGearCeremony.gd:195`、`src/ui/ShopPanel.gd:130,246,270`、`src/ui/BagPanel.gd:324`、`src/ui/CollectionChestView.gd:143`、`src/ui/FlowChestUI.gd:27`、`src/ui/GrowthPanel.gd:210` | **13–14px**（10 处） | 登录、委托、稀有仪式词条、商店返回/买卖、背包出售、图鉴领奖、输入框、养成摘要 |
| 工厂动态 + `.text.json` | `src/autoload/G.gd:6062`；`shots/rounds/Version_3.10_after_{battle,forge,home,rare_ceremony,city,title}.text.json` | **12–14 / 20 / 26 / 36px** | `battle`(56节点,最小12)、`forge`(72,最小12,含20)、`home`(59,最小12,含26)、`rare_ceremony`(79,最小12,含20)、`city`(11,最小14,含36)、`title`(13,最小13) |

- **量化影响**：源码 **48 处**绕过 `G.FS_*`（23 处含 `<15px`，最低 **11px**）；6 场景 **290 个**文字节点实测出现 `{12,13,14,15,17,18,20,22,24,26,36}` 共 **11 种**字号（仅 4 种在 `G.FS_*` 内），11–17px 七档连号挤在 6px 区间内。

### F-02【严重】[文档一致性] `G.FS_*` 常量值与紧邻注释及 4 份规范文档自相矛盾
- **结论**：`src/autoload/G.gd:88` 紧邻注释与 4 份文档仍写旧阶梯 `13/16/18/22/30/56`，与 `G.gd:89-94` 实际常量 `15/17/18/24/28/56` 冲突，破坏「文档即真相源」。**应以代码现行常量 `15/17/18/24/28/56` 为准，回改 `G.gd:88` 注释与 4 份文档。**
- **证据**：

| 对照项 | 文件:行号 | 记载值（XS/SM/MD/LG/BIG/HERO） | 偏差（对比代码常量） |
|---|---|---|---|
| 代码常量定义 | `src/autoload/G.gd:89-94` | **`15 / 17 / 18 / 24 / 28 / 56`** | 基准真值（与 `docs/plans/2026-10-03-ui-polish-plan.md:23` 一致） |
| 常量紧邻注释 | `src/autoload/G.gd:88` | `13 / 16 / 18 / 22 / 30 / 56` | 4 档不符（XS `-2px`, SM `-1px`, LG `-2px`, BIG `+2px`） |
| 规范与设计文档 | `docs/开发规范.md:107`、`docs/2026-09-15-玩法设计与开发路径.md:18`、`docs/2026-09-17-开发交接.md:190`、`docs/plans/2026-09-28-style-spec.md:64` | `13 / 16 / 18 / 22 / 30 / 56` | **4 份**核心文档滞留旧值 |

- **量化影响**：**1 处**代码注释 + **4 份**核心文档与实际常量错位最高 **2px**，直接诱发后续代码继续写入 `13px`（5 处）与 `16px`（9 处）旧档字面量。

### F-03【严重】[实现层] 名签体系分裂为三套实现与四档字号，P01 已验收修复被回退
- **结论**：玩家、城务 NPC、战斗单位与野外怪物的名签散落在 3 个场景脚本中各自构建，字号横跨 `11/12/14/17px`，且 `docs/plans/2026-09-28-style-spec.md:70-71,162` 已勾选完成的“名签字号收进 `G.FS_*`（16）”被回退。
- **证据**：

| 名签语义节点 | 文件:行号 | 历史验收承诺 | 现行代码实现与字号 |
|---|---|---|---|
| 玩家头顶名签 | `src/explore/MapScene.gd:1112` | `style-spec.md:70,162` 收进 `G.FS_SM` | `_player_name_l.add_theme_font_size_override("font_size", 11)`（回退至 **11px**） |
| 城务 NPC 名签 | `src/city/CityScene.gd:3135-3138` | `:3135` 注释写“字号收进六档（P01 样板 §5）” | `:3138` 写 `_name_l.add_theme_font_size_override("font_size", 12 if embedded else 14)`（**12/14px**，注释与代码直接相悖） |
| 战斗单位名签 | `src/battle/BattleScene.gd:2472,2537,2540` | 同级单位名统一字号 | `:2472,:2537` 写死 **12px**，`:2540` 分支又覆写为 `G.FS_SM`（**17px**） |
| 野外怪物名签 | `src/explore/MapScene.gd:4802,4883` | `:4802` 注释写 `FS_SM 16 + 描边` | `:4883` `level_l` 硬编码 **12px** |

- **量化影响**：同一“头顶名签”语义跨 **3 个文件**存在 **4 种字号**（11/12/14/17px，极差 **6px**），玩家无法通过名签视觉权重分辨主角、NPC 与敌方优先级。

### F-04【中】[资源层] `assets/` 360 MB 中含 22.5 MB 零引用字体/历史快照及 38 个构建垃圾文件
- **结论**：`assets/` 共 **360 MB**（`world` 171 MB / `ui` 115 MB / `fonts` 60 MB / `audio` 8.1 MB / `source` 3.6 MB / `role` 3.4 MB），含 1 个零引用字体（6.0 MB）、2 个零引用历史快照目录（16.5 MB）及 **38 个**构建日志。
- **证据**：

| 资源/目录路径 | 体积 / 数量 | `grep -rl` 引用文件数 | 核查结论 |
|---|---|---|---|
| `assets/fonts/ZCOOLXiaoWei-Regular.ttf` | **6.0 MB** | **0 个**（跨 `src/`） | **纯闲置可删**（其余 5 字体在用：`NotoSerifCJKsc-SemiBold.otf` 23.6 MB [2 文件]、`NotoSansSC-Bold.otf` 8.3 MB [2 文件]、`NotoSansSC-Regular.otf` 8.1 MB [1 文件]、`ZCOOLQingKeHuangYou-Regular.ttf` 7.9 MB [1 文件声明，经 `G.font_display` 在 `CityScene.gd:2715,2728`/`RouteScene.gd:567` 实调]、`MaShanZheng-Regular.ttf` 5.6 MB [4 文件]） |
| `assets/world/reference_playable_20261010/`、`reference_rebuild_20261010/` | **16.4 MB** + **0.1 MB** | **0 个**（跨 `src/`+`data/`+`scenes/`） | **废弃批次可删**（注：`reference_complete_20261011` 84.4 MB 有 5 文件引用、`natural_ground_20261011` 45.0 MB 与 `maps_rebuild_20261015` 12.0 MB 被 `data/main_world_maps.json` 引用，均在用） |
| `assets/world/{reference_complete_20261011,natural_ground_20261011}/*.{log,stdout,stderr}` | **38 个文件** | **0 个** | 构建垃圾（前者 30 个、后者 8 个），混在资源目录内 |

- **量化影响**：**22.5 MB** 零引用资源 + **38 个**构建垃圾文件白占包体；此外 `NotoSerifCJKsc-SemiBold.otf` 单文件 **23.6 MB**（占字体总重 39.7%）未做子集化。

### F-05【中】[数据数值层] 数据表 `version` 覆盖率仅 75%，稀有度五档错位且二档首领有 1 处攻击倒挂
- **结论**：52 份 `data/*.json` 中有 **13 份缺失 `version`**；`equip.json` 与 `G.gd`、`RareGearCeremony.gd` 的稀有度命名错位一档导致实机同屏文案矛盾；`campaign_difficulty.json` 二档存在 1 处未声明的 `boss_atk` 下跌。
- **证据**：

| 问题项 | 文件:行号 | 数据与代码冲突详情 |
|---|---|---|
| 13 份表缺 `version` | `data/{arena,camp_gathering,fishing,frost_city_art,mentor_curriculum,monster_art,story_quests}.json`（7 份对象表）+ `data/{combos,monsters,pets,roles,skills,traits}.json`（6 份根数组表） | 52 份 JSON 中 **13 份**无 `version` 字段，无法走统一表迁移校验 |
| 稀有度命名错位 | `data/equip.json:171-207` vs `src/autoload/G.gd:45-50` vs `src/ui/RareGearCeremony.gd:94,142,204` | `equip.json` 为 `1普通/2精良/3稀有/4史诗/5传世`；`G.gd:45` 注释写“稀有度四档”却定义 5 键（缺“精良”、多“传说”）；`RareGearCeremony.gd:94,204` 对 `rarity==4` 硬编码“**传说**宝具·现世”与“**传说**印鉴”，`:142` 却调 `G.equip_rarity_name(4)` 显示“**史诗**”（见 `Version_3.10_after_rare_ceremony.png`） |
| 二档首领倍率非单调 | `data/campaign_difficulty.json:72` | 二档其余 5 图 `boss_atk` 均为 `1.85`，唯独 `rift_mine_vault` 为 `1.60`（低 **0.25**），表内无注释说明 |

- **量化影响**：**25%**（13/52）数据表缺版本号；`rarity == 4` 的 **10 件**装备在仪式界面 100% 出现“顶栏/印章写传说、副标题写史诗”的同屏穿帮。

### F-06【中】[视觉层] 像素精灵与矢量 UI 同屏混用，全局默认最近邻过滤迫使 130 处散落覆写
- **结论**：`project.godot:47` 将全局默认纹理过滤设为最近邻（`default_texture_filter=0`），而 `forge`/`home`/`rare_ceremony` 采用圆角渐变矢量绘制风 UI，导致像素内容与平滑 UI 采样冲突。
- **证据**：

| 场景/配置 | 文件:行号 | 冲突表现 |
|---|---|---|
| 全局默认最近邻 | `project.godot:47` | `textures/canvas_textures/default_texture_filter=0`（按工程全局设置而非按资产用途分层） |
| 逐节点打补丁覆写 | `src/battle/BattleScene.gd:473`、`src/city/CityScene.gd:456`、`src/ui/home/TownHome.gd:23` | 全项目散落 **130 处** `.texture_filter = ...` 手工赋值，代码注释直言 `# 项目默认 nearest，放大必须改线性` |
| 同屏细腻度割裂 | `shots/rounds/Version_3.10_after_battle.png` | 点阵像素角色与怪物站在平滑渐变圆角 HUD 面板上方，点阵密度与抗锯齿标准不统一 |

- **量化影响**：全代码库被迫维护 **130 处** `texture_filter` 覆写，任何漏写处即出现矢量贴图锯齿或像素贴图模糊。

### F-07【中】[实现层] UI 尺寸按 `480×800` 硬编码，`content_scale_factor` 为 0 处且跨分辨率零验证
- **结论**：全项目无字号/布局缩放系数（`content_scale_factor` 0 次命中），大量面板按 `480×800` 绝对坐标硬算，未做多分辨率与长屏安全区验证。
- **证据**：

| 检查项 | 文件:行号 | 实测证据 |
|---|---|---|
| 视口与缩放配置 | `project.godot:27-34`、`src/` 全量 `.gd` | 锁死 `480×800` + `keep_width`，`grep -rn "content_scale_factor" src/` 为 **0 处** |
| 绝对像素硬编码 | `src/ui/RareGearCeremony.gd:41,65,75,150,169`、`src/battle/BattleChestView.gd:406` | 直接写死 `size = Vector2(480, 800)`、`position = Vector2(40, 264)` 等绝对像素 |
| 截图分辨率矩阵 | `shots/rounds/Version_3.10_*.png` | 全部截图恒定为 `480×800` 单一分辨率，`docs/plans/2026-09-28-ui-art-review.md:26` 指出的长屏遮挡风险仍未补测 |

- **量化影响**：主流手机长屏比（`540×960` 16:9、`720×1600` 20:9）实机截图与自动断言覆盖率为 **0%**（0 张）。

### F-08【轻】[视觉层] `home` 主角立绘为西式 JRPG 少年，与其余五景中式行旅母题割裂
- **结论**：核心 6 场景中 5 景视觉母题高度统一为中式边城行旅风，唯独 `home` 中央角色立绘采用西式奇幻肩甲与现代 JRPG 少年造型，风格不自洽。
- **证据**：

| 场景截图 | 文件路径 | 主视觉母题对照 |
|---|---|---|
| 其余 5 核心场景 | `shots/rounds/Version_3.10_after_{title,city,battle,forge,rare_ceremony}.png` | 中式城楼、毛笔字标「远征 / 昭元边城」、朱砂印章「传说印鉴」、中式器物「赤霄玄龙古剑」 |
| 营地主页立绘 | `shots/rounds/Version_3.10_after_home.png`（引自 `src/ui/CampChestView.gd:173`） | 中式城门夜景前站立西式重甲红披风少年，与下方「【破军】· 昭元边城」铭牌调性割裂 |

- **量化影响**：6 张核心验收截图中 **1 张**（占主界面中心约 `220×240px` 视觉焦点区）偏离中式行旅母题。

### F-09【轻】[测试体系] 4 个核心脚本单文件膨胀至 2,854–7,199 行，且回归套件缺字号/资源静态门禁
- **结论**：核心状态与场景脚本体量严重超标，且 `tools/` 298 个回归文件中缺少对 `G.FS_*` 字号与 `assets/` 垃圾文件的静态门禁，导致历史已修缺陷回退。
- **证据**：

| 超大脚本 / 缺失门禁 | 文件:行号 | 规模与影响证据 |
|---|---|---|
| 全局单例与主世界脚本 | `src/autoload/G.gd:1-7199`、`src/explore/MapScene.gd:1-6082` | 单文件分别达 **7,199 行**（291.5 KB）与 **6,082 行**，`G.gd` 较此前 5,800+ 行又增长 **1,390+ 行** |
| 主城与战斗场景脚本 | `src/city/CityScene.gd:1-3287`、`src/battle/BattleScene.gd:1-2854` | 单文件分别达 **3,287 行**与 **2,854 行**，UI 布局、名签绘制与业务逻辑混写 |
| 回归门禁盲区 | `tools/Verify*.gd`（98 个脚本） | 未包含 `add_theme_font_size_override` 字面量扫描与 `.text.json` `<15px` 断言，放行了 F-01/F-03 回退 |

- **量化影响**：前 **4 个** `.gd` 文件合计 **19,422 行**；静态 lint 门禁覆盖数为 **0 个**，导致字号规范已发生至少 **2 次**回退。

---

## 3. 改进方向

### P0 — 可立即止血（1 个批次内闭环）
| 编号 | 动作 | 验收方式（可直接执行的命令 / 可数指标） |
|---|---|---|
| P0-1 | **清零硬编码字号并收敛动态字号**：将 `src/`（排除 `src/preview/`）48 处 `add_theme_font_size_override("font_size", <字面量>)` 全部改为 `G.FS_*`（含 `<15px` 的 23 处归位至 `G.FS_XS`/`G.FS_SM`），并修正 `G.gd:6062` 等产出 `20/26/36px` 的动态工厂。 | ① `grep -rn 'add_theme_font_size_override("[^"]*", *[0-9]' src/ --include=*.gd \| grep -v /preview/ \| wc -l` 输出 `0`；② 复采 `Version_3.10_after_*.text.json` 后实测字号集合 `⊆ {15, 17, 18, 24, 28, 56}` |
| P0-2 | **对齐字号真相源**：以代码常量 `15/17/18/24/28/56`（`G.gd:89-94`）为准，同步修改 `G.gd:88` 注释及 `docs/开发规范.md:107` 等 4 份文档。 | `grep -rn "13/16/18/22/30/56" src/ docs/ --exclude="*audit*.md" \| wc -l` 输出 `0` |
| P0-3 | **清理零引用资产与构建日志**：删除 `assets/fonts/ZCOOLXiaoWei-Regular.ttf`（6.0 MB）、`assets/world/reference_playable_20261010/`（16.4 MB）、`assets/world/reference_rebuild_20261010/`（0.1 MB），并移除 `assets/world/` 下 38 个 `*.log/*.stdout/*.stderr`。 | ① `grep -rn "ZCOOLXiaoWei" src/ \| wc -l` 输出 `0` 且 `du -sh assets/fonts/` `≤ 54M`；② `find assets -name "*.log" -o -name "*.stdout" -o -name "*.stderr" \| wc -l` 输出 `0` |
| P0-4 | **修复稀有度同屏穿帮**：对齐 `RareGearCeremony.gd:94,142,204`、`G.gd:45-50` 与 `data/equip.json:171-207` 的五档命名（`rarity==4` 统一显示「史诗」或统一升为 `rarity==5`）。 | 重新导出 `Version_3.10_after_rare_ceremony.text.json`，断言顶栏标题、印章与副标题稀有度词根 100% 一致 |

### P1 — 需设计决策（结构性收敛）
| 编号 | 动作 | 决策与落地说明 |
|---|---|---|
| P1-1 | **收敛名签单一工厂**：在 `G.gd` 提供唯一 `make_nameplate(kind)` 工厂，字号锁死 `G.FS_XS`（15px），敌我/主次层级仅用底板不透明度（玩家 `0.91` / NPC `0.82` / 怪物无底板描边）区分。 | 彻底消除 F-03 中 `MapScene`、`CityScene`、`BattleScene` 的三套名签实现与 `11/12/14/17px` 四档分裂。 |
| P1-2 | **按用途分层设置纹理过滤**：世界地表/精灵根节点统一设 `TEXTURE_FILTER_NEAREST`，UI CanvasLayer 根节点统一设 `TEXTURE_FILTER_LINEAR`，裁撤 UI 脚本内散落的 `.texture_filter` 手工赋值。 | 解决 F-06 像素与矢量同屏过滤冲突，并消除漏调 `UIReadability.apply_to()` 时的糊字隐患。 |
| P1-3 | **补齐多分辨率截图矩阵与安全区断言**：在 `ShotRunner` 增加 `540×960` 与 `720×1600` 采样，自动断言底部按钮与顶部 HUD 不越界、不重叠。 | 将 F-07 的跨分辨率风险从“零验证”纳入自动化回归。 |
| P1-4 | **统一 `home` 立绘母题与明确二档矿库首领倍率**：将 `home` 主角立绘统一为中式行旅风（或同步调整其余场景调性），并确认 `data/campaign_difficulty.json:72` 的 `rift_mine_vault.boss_atk: 1.60` 是否回调至 `1.85` 或补注释说明。 | 解决 F-08 视觉母题割裂与 F-05 难度表隐性特例。 |

### P2 — 长期工程演进
| 编号 | 动作 |
|---|---|
| P2-1 | **将字号、资源与 `.text.json` 断言接入 CI 门禁**：在 `tools/` 新增 `VerifyUIStandards.gd`，自动断言“0 处硬编码字号”“0 个 `<15px` 渲染文字节点”“0 处 `rect_height < height` 裁切”“0 个 `assets/` 构建日志”，阻断 F-01/F-03 再次回退。 |
| P2-2 | **字体子集化与资源体积预算**：对 `NotoSerifCJKsc-SemiBold.otf`（23.6 MB）按项目字符集提取子集（预计缩减 15+ MB），并禁止带日期的历史快照目录直接合入 `assets/` 主干。 |
| P2-3 | **补齐 13 份数据表 `version` 与拆分超大脚本**：为 7 份无版本对象表补 `"version": 1`，将 6 份根数组表纳入版本清单；按职责（存档/经济/UI工厂）拆分 7,199 行的 `G.gd` 与 6,082 行的 `MapScene.gd`。 |

---

## 4. 数据证据附录

```bash
cd "D:/new bee/远征"

# 1. 代码规模与单文件体量异常（Check E）
find src -name "*.gd" | wc -l
# 实测：168（src/ui: 90, src/world: 33, src/explore: 20, src/combat: 7, src/preview: 5, src/run: 4, src/autoload: 3, src/battle: 3, src/city: 1, src/main: 1, src/save: 1）
wc -l src/autoload/G.gd src/explore/MapScene.gd src/city/CityScene.gd src/battle/BattleScene.gd
# 实测：G.gd 7199 行 / MapScene.gd 6082 行 / CityScene.gd 3287 行 / BattleScene.gd 2854 行
ls tools/ | grep -ic "verify\|regression"
# 实测：298

# 2. 字号违规与频次分布（Check A）
sed -n '88,94p' src/autoload/G.gd
# 实测：第 88 行注释写 13/16/18/22/30/56，第 89-94 行常量为 FS_XS=15, FS_SM=17, FS_MD=18, FS_LG=24, FS_BIG=28, FS_HERO=56
grep -rn 'add_theme_font_size_override("[^"]*", *[0-9]' src/ --include=*.gd | grep -v /preview/ | wc -l
# 实测：48（44 处纯数字字面量 + 4 处三元表达式）
grep -rn 'add_theme_font_size_override("[^"]*", *\([0-9]\|1[0-4]\)\(,\|)\)' src/ --include=*.gd | grep -v /preview/ | wc -l
# 实测：21（另有 CityScene.gd:3138 与 RegionChestMap.gd:244 两处 `12 if ... else 14` 三元表达式）
grep -rn 'add_theme_font_size_override("[^"]*", *[0-9]' src/ --include=*.gd | grep -v /preview/ | grep -oP 'add_theme_font_size_override\("[^"]*", *\K[0-9]+' | sort -n | uniq -c
# 实测（排除 preview）：12×11, 16×9, 13×5, 14×5, 22×4, 15×3, 11×2, 17×2, 18×2, 19×1, 20×1, 21×1, 24×1, 26×1（含 preview 全量为 54 个数字匹配）
grep -rn "13/16/18/22/30/56" docs/ --exclude="*audit*.md" | wc -l
# 实测：4 份文档命中（docs/2026-09-15-玩法设计与开发路径.md:18, docs/2026-09-17-开发交接.md:190, docs/开发规范.md:107, docs/plans/2026-09-28-style-spec.md:64）

# 3. 实机 .text.json 渲染字号与裁切核查（Check A & D）
python -c "
import json, glob
for p in sorted(glob.glob('shots/rounds/Version_3.10_after_*.text.json')):
    d = json.load(open(p, encoding='utf-8')); tn = d['text_nodes']
    clip = [n for n in tn if n.get('rect_height', 0) < n.get('height', 0)]
    print(p.split('_after_')[1][:-10], len(tn), sorted({n['size'] for n in tn}), 'clipped=', len(clip))"
# 实测：6 场景 290 节点，字号集合 {12,13,14,15,17,18,20,22,24,26,36}，clipped=0（全库 60 份 after 共 2222 节点，clipped=0）

# 4. 资源体积、字体引用与构建垃圾（Check B）
du -sh assets/ assets/*/ | sort -hr
# 实测：assets/ 360M（world 171M, ui 115M, fonts 60M, audio 8.1M, source 3.6M, role 3.4M）
for f in assets/fonts/*.otf assets/fonts/*.ttf; do
  b=$(basename "$f")
  printf "%-40s %6.1f MB refs=%s\n" "$b" "$(stat -c%s "$f" | awk '{print $1/1048576}')" "$(grep -rl "$b" src/ --include=*.gd | wc -l)"
done
# 实测：NotoSerifCJKsc-SemiBold.otf 23.6MB refs=2 | NotoSansSC-Bold.otf 8.3MB refs=2 | NotoSansSC-Regular.otf 8.1MB refs=1
#       ZCOOLQingKeHuangYou-Regular.ttf 7.9MB refs=1（经 G.font_display 在 CityScene/RouteScene 实调）
#       ZCOOLXiaoWei-Regular.ttf 6.0MB refs=0（完全闲置） | MaShanZheng-Regular.ttf 5.6MB refs=4
find assets -name "*.log" -o -name "*.stdout" -o -name "*.stderr" | wc -l
# 实测：38（reference_complete_20261011 下 30 个，natural_ground_20261011 下 8 个）

# 5. 跨分辨率缩放与纹理过滤（Check D）
grep -rn "content_scale_factor" src/ --include=*.gd | wc -l
# 实测：0
grep -rn "texture_filter" src/ --include=*.gd | wc -l
# 实测：130
```

| 关键指标 | 实测值 | 规范/目标值 | 状态判定 |
|---|---|---|---|
| `src/` `.gd` 脚本总数与最大单文件 | 168 个 / `G.gd` 7,199 行、`MapScene.gd` 6,082 行 | 模块职责单一 | 单文件体量超标（F-09） |
| `tools/` 回归与验证资产数 | 298 个 `Verify*` / `regression` 相关文件 | 核心玩法可回归 | 覆盖密度优秀（A5） |
| 字面量字号覆盖（排除 `src/preview/`） | 48 处（含 `<15px` 分支 23 处，最低 11px） | 0 处（全走 `G.FS_*`） | 严重违规且属回退（F-01） |
| 3.10 六场景实测文字节点与裁切 | 290 个节点，字号 11 种，裁切 0 处 | 字号 `⊆ {15,17,18,24,28,56}`，裁切 0 | 零裁切（A4），字号未收敛（F-01） |
| `assets/` 总体积与可清理无用项 | 360 MB（含 6.0 MB 零引用字体 + 16.5 MB 废弃快照 + 38 个日志） | 零闲置字体、零构建日志 | 22.5 MB + 38 文件可直删（F-04） |
| `data/*.json` 表总数与 `version` 覆盖 | 52 份表，39 份带 `version`（13 份缺失） | 100% 带 `version` | 75.0% 覆盖（F-05） |
| 跨分辨率缩放（`content_scale_factor`） | 0 处，截图仅 `480×800` 单一尺寸 | 覆盖长屏/异形屏矩阵 | 适配零验证（F-07） |

---

## 5. 审查范围声明

- **已覆盖**：`src/autoload/G.gd` 字号阶梯与注释、`src/` 全量 168 个脚本的字号字面量与动态字号工厂、`UIReadability.gd` 可读性兜底机制、`docs/` 与 `docs/plans/` 全部字号与名签规范对照、`shots/rounds/` 实机截图（3.10 六大场景）与全部 `.text.json` 文字节点渲染数据、`assets/` 各子目录体积/字体引用/历史快照引用/构建日志垃圾、`data/*.json` 52 份表的版本字段及 `growth`/`equip`/`drops`/`economy`/`currencies`/`campaign_difficulty`/`dungeon_trials` 交叉印证、纹理过滤策略与跨分辨率配置、`tools/` 回归脚本规模与大文件耦合度。
- **未覆盖 / 需独立专项**：
  - **战斗数值极限组合空间穷举**：已验证 `campaign_difficulty.json` 档位单调性，但 49 只怪物（`monsters.json`）× 4 职业（`roles.json`）× 20 技能（`skills.json`）× 44 词条（`traits.json`）的 DPS/TTK 极端组合需独立跑批数值仿真专项。
  - **商业美术主观质量复审**：笔触精度、构图张力、色彩艺术性按项目原则留给独立美术复审（本报告仅对像素/矢量过滤混用与中外母题不一致作出客观判定）。
  - **音频资产引用与响度审查**：`assets/audio/`（8.1 MB）未做逐条资源引用排查与 LUFS 响度一致性检测，需音频专项审查。
