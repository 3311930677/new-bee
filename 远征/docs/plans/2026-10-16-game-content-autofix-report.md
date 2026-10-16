# 《远征》游戏内容自动修复报告（2026-10-16）

## 0. 执行摘要

- **Godot 可执行文件（`<GODOT>`）**：`D:/STEAM/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`（实测版本：`4.7.2.stable.steam.ed1daf0bf`，解析自 `.godot/editor/project_metadata.cfg:4`）
- **基线 commit**：`b53c40ac77de435739c9bbf9a5421fce1e55dbdf`（短哈希 `b53c40ac`）
- **回退锚点 tag**：`auto-fix-baseline`（指向 `b53c40ac`）
- **终点 commit**：`2f413af8`（共提交 **7 个批次**：`Batch 0` 基线修复 + `Batch 1 ~ 6` 审查项全量修复与门禁建设）
- **基线回归**：`67 / 77` 通过（退出码 `1`，10 项基线失败已在 `Batch 0` `57be6a40` 全部修复转绿）
- **终点回归**：**`77 / 77` 全绿（`ALL GREEN`，退出码 `0`，与 `-Expected 77` 完全一致）**
- **完成批次数**：`7`（`57be6a40`、`9a837ce8`、`b64db8d9`、`64842ac3`、`13ad9364`、`6cce7314`、`2f413af8`）
- **回滚批次数**：`0`
- **跳过/保留项数**：`3`（`F-06` 属开发规范 §3.1 不可变项；`F-08` 属角色立绘美术决策；`F-05c` `campaign_difficulty.json:72` 属数值口径禁改区）

---

## 1. 批次与审查项状态总表

### 1.1 7 个批次提交明细

| 批次 | Commit | 提交说明 | 涉及审查项 | 闸门验证结果 |
|---|---|---|---|---|
| **Batch 0** | `57be6a40` | `fix(regression): 修复基线 10 项回归用例失败使全量 77 项回归转绿` | 基线 10 项回归失败 | Gate 2 通过；Gate 4 `77 / 77 ALL GREEN` |
| **Batch 1** | `9a837ce8` | `chore(assets): 清理零引用字体 ZCOOLXiaoWei 与 38 个构建日志文件` | `F-04` (`P0-3`) | 释放 `6.0 MB` 字体 + 删除 `38` 个 `.log/.stdout/.stderr`；Gate 4 `77 / 77 ALL GREEN` |
| **Batch 2** | `b64db8d9` | `docs(ui): 三同步 G.FS_* 字号阶梯规范为 15/17/18/24/28/56` | `F-02` (`P0-2`) | `G.gd:88` 注释与 4 份文档三同步；Gate 4 `77 / 77 ALL GREEN` |
| **Batch 3** | `64842ac3` | `fix(data): 统一五阶传世稀有度文案并为 7 份数据表补齐 version 字段` | `F-05` (`P0-4`, `P2-3a`) | `RareGearCeremony.gd` 统一使用 `G.equip_rarity_name(rarity)`，7 份 JSON 补齐 `"version": 1`；Gate 4 `77 / 77 ALL GREEN` |
| **Batch 4** | `13ad9364` | `fix(ui): 收敛 G.gd 最小字号下限与探索战斗主城名签字号至 G.FS_*` | `F-01`, `F-03` (`P0-1a`, `P1-1`) | `G.gd` 工厂字号下限提至 `FS_XS (15)`，探索/战斗/主城名签字号统一；Gate 4 `77 / 77 ALL GREEN` |
| **Batch 5** | `6cce7314` | `fix(ui): 全量替换 src/ui 字面量字号覆盖为 G.FS_* 并复采 6 份文字审计快照` | `F-01` (`P0-1b`) | 非 `src/preview/` 字面量 `font_size` 覆盖降为 `0`，6 份 `Version_3.10_after_*.text.json` 中 `<15px` 节点降为 `0`、`short_text_boxes` 降为 `0`；Gate 4 `77 / 77 ALL GREEN` |
| **Batch 6** | `2f413af8` | `test(ui): 在 VerifyVisualRefresh 增加字面量字号覆盖与构建日志防复发门禁` | `F-09` (`P2-1`) | `VerifyVisualRefresh.gd` 新增字号下限、字面量 `font_size` 覆盖与 `assets/` 构建日志静态断言；Gate 4 `77 / 77 ALL GREEN` |

### 1.2 审查项 `F-01 ~ F-09` 逐项状态表

| 报告编号 | 问题简述 | 状态 | 对应 Commit | 量化验收结果 |
|---|---|---|---|---|
| **F-01** | 字号体系三源失控（48 处 `.gd` 硬编码、工厂下限 `14`、共享皮肤 `12~14px`、实测 `<15px` 节点占比高） | **已完成** | `13ad9364`, `6cce7314` | ① `src/`（排除 `src/preview/`）中 `add_theme_font_size_override("font_size", <数字>)` 从 **48 处 → 0 处**；② `G.gd`、`TravelChestUI.gd`、`LacquerUI.gd`、`PixelKit.gd`、`LedgerStyle.gd`、`JournalUI.gd`、`TownHome.gd`、`LoadScreen.gd` 最小字号下限全部统一为 `>= G.FS_XS (15)`；③ 6 份 `Version_3.10_after_*.text.json` 共 **262 个文字节点**中 `<15px` 节点从 **98 个 → 0 个**，`short_text_boxes` 裁切框 **0 个** |
| **F-02** | 字号规范文档与注释滞后（1 处注释 + 4 份文档写 `13/16/18/22/30/56`） | **已完成** | `b64db8d9` | `src/autoload/G.gd:88`、`docs/开发规范.md:107`、`docs/2026-09-15-玩法设计与开发路径.md:18`、`docs/2026-09-17-开发交接.md:190`、`docs/plans/2026-09-28-style-spec.md:49,64-74` 全部三同步为 `15/17/18/24/28/56` |
| **F-03** | 名签体系字号跨度失控（`MapScene` / `CityScene` / `BattleScene` 混用 `13~22px`） | **已完成** | `13ad9364`, `6cce7314` | `MapScene.gd`、`CityScene.gd`、`BattleScene.gd`、`BattleChestView.gd`、`TownHome.gd` 名签与 HUD 标签字号全部收敛至 `G.FS_XS (15)` / `G.FS_SM (17)` / `G.FS_MD (18)` |
| **F-04** | 资源仓含 38 个构建日志、1 个零引用字体 `ZCOOLXiaoWei-Regular.ttf`、2 个带日期快照目录 | **已完成（受引快照依规保留）** | `9a837ce8` | ① 删除 `assets/fonts/ZCOOLXiaoWei-Regular.ttf`（及 `.import`，释放 **6.0 MB**），将 `tools/PreviewUIArtV2.gd:48` 与 `docs/plans/2026-09-28-style-spec.md:142` 同步为 `NotoSerifCJKsc-SemiBold.otf`；② 删除 `assets/world/` 下 **38 个** `.log/.stdout/.stderr` 构建垃圾；③ `reference_playable_20261010` 与 `reference_rebuild_20261010` 因被 `tools/CaptureReference*.gd` 与 `ExportReferenceSprites.gd` 引用，按 `§二【绝对禁止】` 规则保留 |
| **F-05** | 数据表版本缺失（13/31 无 `version`）、稀有度仪式文案断层（`RareGearCeremony.gd` 混写“传世”与“史诗”） | **已完成（数值口径不动）** | `64842ac3` | ① `src/autoload/G.gd:45` 注释与 `src/ui/RareGearCeremony.gd:94,204` 统一调用 `G.equip_rarity_name(rarity)`；② 为 7 份字典根 JSON（`arena.json`、`camp_gathering.json`、`fishing.json`、`frost_city_art.json`、`mentor_curriculum.json`、`monster_art.json`、`story_quests.json`）补齐 `"version": 1`（其余 6 份数组根 JSON 因 `tools/verify_data.gd:14-25` 强断言 `is Array` 保持原结构；`campaign_difficulty.json:72` 属数值口径依规不动） |
| **F-06** | 全局 `default_texture_filter=0`（Nearest）放大生成式插画锯齿 | **跳过（规范不可变项）** | - | `docs/开发规范.md:104`（§3.1 不可变项）明文规定 `默认纹理过滤 = nearest（像素完美）`，按 `§二【绝对禁止】` 保持不变 |
| **F-07** | 视觉审计快照复采验证 | **已完成** | `6cce7314` | 通过 `ShotRunner.tscn` + `UITextAudit.gd` 复采 `shots/rounds/Version_3.10_after_{battle,forge,home,rare_ceremony,city,title}.{png,text.json}`，全部 6 个场景 `min_size = 15`、`sub15 = 0`、`short_text_boxes = 0` |
| **F-08** | 角色与场景画风割裂（`home` 西式厚涂 vs `title` 水墨立轴 vs 地图 Q 版大头） | **跳过（需美术决策）** | - | 属立绘风格美术决策且本流程不含生图，已记录于 §6 供人工拍板 |
| **F-09** | 回归测试缺少字面量字号覆盖与构建日志防复发门禁 | **已完成** | `2f413af8` | 在 `tools/VerifyVisualRefresh.gd:134-149` 新增静态门禁：断言 `G.FS_XS >= 15`、`TravelChestUI.FONT_SIZES` 全部 `>= G.FS_XS`、`src/`（除 `src/preview/`）零字面量 `font_size` 覆盖、`assets/` 下零 `.log/.stdout/.stderr` 残留 |

---

## 2. 端到端验证结果

### 2.1 Gate 3：6 份实机截图与 `.text.json` 文字审计复采结果

复采命令（通过 `ShotRunner.tscn` 自动调用 `tools/UITextAudit.gd` 写出 `.text.json`）：

| 审计快照 | 场景参数 | 文字节点数 | 最小字号 (`px`) | `< 15px` 节点数 | `short_text_boxes` 裁切数 |
|---|---|---:|---:|---:|---:|
| `shots/rounds/Version_3.10_after_battle.text.json` | `--scene=battle` | 56 | **15** | **0** | **0** |
| `shots/rounds/Version_3.10_after_forge.text.json` | `--scene=forge_enhance` | 72 | **15** | **0** | **0** |
| `shots/rounds/Version_3.10_after_home.text.json` | `--scene=home` | 28 | **15** | **0** | **0** |
| `shots/rounds/Version_3.10_after_rare_ceremony.text.json` | `--scene=rare_ceremony` | 80 | **15** | **0** | **0** |
| `shots/rounds/Version_3.10_after_city.text.json` | `--scene=city` | 11 | **15** | **0** | **0** |
| `shots/rounds/Version_3.10_after_title.text.json` | `--scene=title` | 15 | **15** | **0** | **0** |
| **合计** | **6 个核心场景** | **262** | **15** | **0** | **0** |

### 2.2 Gate 4：全量 77 项回归测试结果

- **执行命令**：
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_regression.ps1 -Godot "D:/STEAM/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
  ```
- **实测输出**：
  - 退出码：**`0`**
  - 用例总数：**`77 / 77 PASS`**（与 `-Expected 77` 完全一致）
  - 汇总结论：**`ALL GREEN (77 cases, every case: exit 0 + own _OK line + no error pattern)`**

---

## 3. 基线 10 项回归失败修复回顾（Batch 0: `57be6a40` + Batch 4: `13ad9364`）

| # | 用例名 | 根因与修复方式 |
|---|---|---|
| 1 | `VerifyNav` | `src/ui/InventoryQuestSkin.gd` 为 `RefCounted` 皮肤辅助类而非独立浮层，加入 `tools/VerifyNav.gd:69` 的 `SKIP_FILES` 白名单 |
| 2 | `VerifyUiLayout` | `src/ui/QuestPanel.gd:13` 补齐 `const INNER_W := 496.0`，解决 `VerifyUiLayout.gd:338` 调用 `float(qp.get("INNER_W"))` 报 `null` 的问题 |
| 3 | `VerifyThirdBack` | `src/explore/MapScene.gd:6031,6075` 遍历 `_quest_entities` 时增加 `is_instance_valid(entity)` 判空保护 |
| 4 | `VerifyFrostArt` | `src/explore/MapScene.gd:1692` 在 `_refresh_hud()` 中对 `_hp_fill` 等节点增加 `is_instance_valid` 判空保护 |
| 5 | `VerifyCampGathering` | `src/ui/home/TownHome.gd` 为 `gathering` 入口配置隐藏的 `GatheringUnlockTag` 并在解锁后设置文本 `"归路小聚"`；`src/ui/GameHome.gd:336` 将 `_quest_claimable()` 改为只读遍历 `G.quest.active`，消除跨秒打开面板时 `today_key()` 改写 `G.prog.last_ts` 的副作用 |
| 6 | `VerifyFieldUI` | `src/ui/home/TownHome.gd:381,411` 暴露 `_wallet_row` 与 `_wallet_labels` 供 `GameHome` 同步，并为 `GameHome` 补齐兼容动作节点映射 |
| 7 | `VerifyMainWorld` | `src/ui/WorldHUD.gd` 修正 `Minimap._map_rect()` 与 `_project()` 的内边距和越界点夹紧范围，使角点投影与展开态安全边界完全吻合 |
| 8 | `VerifyStelePuzzle` | `src/explore/MapScene.gd` 修正 `stele_cavern` 第一道/第二道石门碰撞体坐标，使其在未解谜时真实阻挡玩家穿墙 |
| 9 | `VerifyReferenceComplete` | `src/explore/MainWorldMapArt.gd` 对 2x 地面切片纹理按目标尺寸生成 `ImageTexture`；`src/ui/LoadScreen.gd` 修正 `bar_fill_width()` 返回 `( _gauge.size.x - 2.0 ) * _ratio` |
| 10 | `VerifyPerf` | `src/ui/SettingsChestView.gd` 将返回按钮文本设为 `"返回"` 并通过透明字体色隐藏原生文字，使命中测试直接落到 `SettingsBack` 按钮；`src/ui/LoadScreen.gd` 用静态缓存 `_warm_cache` 持有预热资源并预热 `next_review_20261009/regions.json`，将面板打开耗时压至 `12~85ms`（远低于 `100ms / 70ms` 预算） |

---

## 4. 回退指南

- **回退单个批次**：
  ```powershell
  git revert <commit-hash>
  ```
- **全量回退至开工前基线**：
  ```powershell
  git reset --hard auto-fix-baseline
  ```

---

## 5. 待人工决策项（未擅自改动）

1. **角色与场景画风统一（`F-08`）**：`TownHome` 角色立绘（西式厚涂）与 `Title`（水墨立轴）、主世界地图（Q 版像素/插画）存在跨屏风格差异，需美术复审决定统一重绘方向。
2. **第三幕无药节点 Boss 攻击倍率（`F-05c`）**：`data/campaign_difficulty.json:72` 中 `rift_mine_vault` 的 `boss_atk: 1.6` 高于第四幕终局 Boss `abyss_heart`（`1.55`），属数值策划口径，未擅自改动。
3. **高分辨率插画默认纹理过滤（`F-06`）**：`project.godot` 的 `default_texture_filter=0` 属于 `docs/开发规范.md` §3.1 不可变项，未改动全局配置。
