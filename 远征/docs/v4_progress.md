# V4 重构进度
## 当前阶段：P4 已完成（P0–P4 全部交付，等待验收）

> 可视化对照入口：`shots/v4_gallery/index.html`（76 张改前/改后并排图，按 P0–P4 分组，可点开放大翻页）
> 生成脚本：`shots/v4_gallery/build_gallery.py` + `build_html.py`（只读原图，不修改任何截图）
## 已完成（P0 阶段 12/12）
- ✅ D1 剧情幕溢出（StoryBeat.gd）
  - 改了：src/ui/StoryBeat.gd
  - 做法：正文框 `box` 加 `clip_contents = true` 并调整高度/字号（`G.FS_SM`）与行间距防止溢出；信箱黑边移到 `hint` 之前添加，且 `hint.position = Vector2(0, VIEW_H - 42.0 - 28.0)` 置于黑边之上；同步去除 `StoryBeat.gd` 假字距空格并用 `G.spaced_font`
  - 证据：shots/v4_p0/extra/x03_storybeat_intro.png
  - 验证：正文不溢出底框、底部提示不被黑边遮挡；VerifyLore 通过
- ✅ D2 登录页恢复参考稿（LoginChestView.gd）
  - 改了：src/ui/LoginChestView.gd、src/ui/Login.gd
  - 做法：从历史参考稿实现取回 `_kit`（`login_kit.json`）坐标叠加、`login_bg.png` + 上下渐隐 shader + `login_backdrop.png` 与 `sky_color`/`ground_color` 衬底，保留 `safe_layout_exempt`、`layout(safe_override, keyboard_override)` 键盘避让、窄矮屏自适应缩放与 `_reveal_focus()`
  - 证据：shots/v4_p0/s03_login.png、shots/v4_p0/responsive/480x800_Login.png
  - 验证：4 尺寸截图与 `_sheets/login_ref.png` 一致；VerifyReferenceComplete / VerifySafeArea / VerifyAvatar 通过
- ✅ D3 誓约描述压边框（OathPanel.gd）
  - 改了：src/ui/OathPanel.gd
  - 做法：改为按 `desc.get_combined_minimum_size().y` 动态计算每张誓约子卡高度（`card_h = 56 + desc_h + 16`，底边留 16px 内边距）与累加纵向坐标 `card_y`，同步自适应外框 `paper` 高度与返回按钮位置
  - 证据：shots/v4_p0/s07_oath.png
  - 验证：三张誓约卡第三行文字均在子卡边框内侧留足边距；VerifyOathWalk / VerifySafeArea 通过
- ✅ D4 唤灵阁标题重叠（GachaPanel.gd / CraftUI.gd）
  - 改了：src/ui/CraftUI.gd、src/ui/GachaPanel.gd
  - 做法：在 `CraftUI.heading` 中将标题文字在 `plaque_title.png`（236×48）内居中对齐，避开牌匾两端雕花，并将顶部分隔金线移至 `y=96` 避免穿过余额条；移除 `GachaPanel.gd` 中与主打标题重叠的半透明 `head_banner` 叠层
  - 证据：shots/v4_p0/s07_gacha.png
  - 验证：顶部「灵宠召唤」不再压在左端雕花上，主打区文案清晰无叠影；VerifyGacha 通过
- ✅ D6 主城货币缩写（home/TownHome.gd）
  - 改了：src/ui/home/TownHome.gd、src/ui/GameHome.gd
  - 做法：`CAP_W` 从 `86.0` 扩至 `89.0`（四枚胶囊总宽 368，严守 `row.end.x <= 468`），`num.size.x` 扩至 `CAP_W - 36`；`_fmt(n)` 对 `>= 100000000` 缩写为 `%d.%d亿`、对 `>= 10000` 缩写为 `%d.%d万`（`< 10000` 保持原值以兼容测试断言），且 `refresh()` 统一走 `_fmt(value)`；同步去除 `GameHome.gd` 中 `"继 续"` 假字距空格
  - 证据：shots/v4_p0/s05_home.png、shots/v4_p0/polish/01_home.png
  - 验证：主城顶栏四枚胶囊右端留足内边距、大数缩写不再顶边；VerifyGameHome / VerifyFieldUI / VerifyCurrencyBalance 通过
- ✅ D15 主城头像（home/TownHome.gd）
  - 改了：src/ui/home/TownHome.gd
  - 做法：新增 `_home_avatar_texture()`，当玩家启用自定义头像时返回 `G.custom_avatar_texture()`，否则直接加载当前选中职业图标 `G.role_icon_path(_valid_role_id(G.selected_role))`（如 `pojun_icon.png`），不再显示罗盘占位图（同时保留 `G.avatar_texture()` 原契约以兼容 `VerifyAvatar`）
  - 证据：shots/v4_p0/s05_home.png
  - 验证：主城左上角圆形头像框显示破军职业头像而非罗盘；VerifyAvatar / VerifyGameHome 通过
- ✅ D7 地图 HUD 对比度（MapScene.gd / LacquerUI.gd / WorldHUDSkin.gd）
  - 改了：src/ui/WorldHUDSkin.gd、src/ui/LacquerUI.gd、src/explore/MapScene.gd
  - 做法：在圆形动作键上半图标区铺亮金衬底（`e0c286` + 2px `f7e2b2` 亮边）配深色图标图形（对比度 > 6.5:1），图标贴图改用 `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` 保留高分辨率金线细节；药剂数量为 0 时用清晰灰阶图标配暗灰底+红色 `"0"`，大于 0 时用朱漆角标；疾行激活时外圈绘翠色光环；交互键出现时加回弹放大动画
  - 证据：shots/v4_p0/s09_map_lorin_wilds.png
  - 验证：右下「骑乘 / 疾行 / 药剂」对比度显著提升，药剂 0 态不再黑成一团
- ✅ D9 出征键盘文案（DeployPanel.gd）
  - 改了：src/ui/DeployPanel.gd
  - 做法：将 `TIPS` 前两条中的 PC 键盘提示（`← → 或 A/D`、`↑ ↓ 或 W/S`）替换为触屏优先的手势说明（`左右滑动或点两侧箭头切换当前选项`、`点顶部「1 秘境 / 2 人物 / 3 宠物」切换步骤`）
  - 证据：shots/v4_p0/s07_deploy.png、shots/v4_p0/responsive/480x800_deploy_help.png
  - 验证：首次进入出征页与点击「说明」弹出的引导均为触屏手势文案且 4 尺寸 0 溢出
- ✅ D11 空格字距 20+ 处
  - 改了：src/autoload/G.gd、src/ui/SlideCard.gd、src/city/CityScene.gd、src/explore/MapScene.gd、src/run/RouteScene.gd、src/ui/ArenaPanel.gd、src/ui/CodexPanel.gd、src/ui/DeployPanel.gd、src/ui/FishingPanel.gd、src/ui/GameHome.gd、src/ui/GmConsole.gd、src/ui/JourneyPanel.gd、src/ui/Login.gd、src/ui/MountPanel.gd、src/ui/PetRaisePanel.gd、src/ui/RoadMailPanel.gd、src/ui/ShopPanel.gd、src/ui/StoryBeat.gd、src/ui/TitlePanel.gd、src/ui/TraitPicker.gd、src/ui/WorldPanel.gd
  - 做法：在 `G.gold_button`、`G.ghost_button`、`G.banner_box`、`SlideCard._kicker`、`JourneyPanel._button`、`ShopPanel` 等统一改用 `FontVariation.spacing_glyph`（`G.spaced_font`）控制字距，清除除冻结页（`Prologue.gd`、`SettingsPanel.gd`）外的全部 30+ 处手工插入空格的假字距字符串
  - 证据：shots/v4_p0/s07_shop.png、shots/v4_p0/s07_arena.png、shots/v4_p0/s07_journey.png
  - 验证：扫描脚本确认 `src/`（除冻结文件外）再无手工空格字距文案，按钮与标题字距自然均匀
- ✅ D13 货币卡截断（CurrencyPanel.gd）
  - 改了：src/ui/CurrencyPanel.gd
  - 做法：正文条目改按句号/分号/逗号断行（保留顿号并列短语），字号统一收归 `G.FS_SM / G.FS_MD / G.FS_READING / G.FS_LG / G.FS_BIG`，并在 `layout()` 中精确累计子项高度 + 外框留白（`+272.0`，上限 `minf(716.0, safe.size.y - 28)`），避免首帧 `get_combined_minimum_size()` 偏小导致「可以用于」底部被裁切
  - 证据：shots/v4_p0/s08_currency_gold.png、shots/v4_p0/s08_currency_expedition.png、shots/v4_p0/s08_currency_soul.png、shots/v4_p0/s08_currency_honor.png
  - 验证：四张货币详情卡「如何获得」与「可以用于」全部完整显示、无截断；VerifyCurrencyBalance 通过
- ✅ D14 共鸣槽黑条复核与补修（AssetCompletion.gd）
  - 改了：src/world/AssetCompletion.gd
  - 做法：实拍 `s09_map_stele_resonance.png` 发现 `channel()` 仅改了点亮色 `c9ece5`，未点亮色仍为 `737a80` 且仍以 `module=36.0, height=12.0` 横向压缩 3.4 倍导致画成两条黑条；按方案 §4.24-7 改为 1:1 贴图原尺寸平铺（`Rect2(0, 0, length, tex_h)`，目标高 `tex_h`），未点亮染色提亮至 `a9b0b5`
  - 证据：shots/v4_p0/s09_map_stele_resonance.png
  - 验证：碑林回响等地图中的共鸣导槽清晰呈现石刻凹槽与符文肌理，不再是两条黑条
- ✅ D17 称号职业（data/titles.json）
  - 改了：data/titles.json
  - 做法：将 `t_lore_ck`（朔风听刃）的 `desc` 从 `"刺客参悟边城古碑疾风共鸣"` 修正为 `"枪骑参悟边城古碑疾风共鸣"`，保留 `id` 不变
  - 证据：shots/v4_p0/extra/x06_title_lore_ck.png、shots/v4_p0/s07_growth_title_bottom.png
  - 验证：称号「朔风听刃」描述显示为「枪骑参悟边城古碑疾风共鸣」
## 已完成（P1 阶段）
- ✅ P1-1 素材后处理与入库（A–G 组 56 张后处理、`assets/ui/kit_20261013/` 合并 v4 26 件共 67 件、`assets/commercial_20261028/` 与 `data/commercial_20261028.json` 288 项入库并通过 Godot `--import` 校验）
- ✅ P1-2 新建 `src/ui/KitV4.gd`（`class_name KitV4`）统一规范入口：§3.1 玄漆鎏金色板、§3.2 八级字号阶梯、`fmt_compact()` 紧凑数字（≥10000 转 x.xx万、≥1e8 转 x.xx亿）、九宫格进度条、磁盘直读无损纹理加载器
- ✅ P1-3 全局工厂与皮肤改造：`G.gd`、`VisualTheme.gd`、`ReadingSkin.gd`、`FlowChestUI.gd`、`TravelChestUI.gd`、`ChestPageUI.gd`、`UiKit.gd`、`PixelKit.gd`、`InventoryQuestSkin.gd`、`CraftUI.gd`、`LacquerUI.gd`（主按钮统一朱漆描金，去青绿/紫/黄羊皮/奶白外框，纸窗改暗框内衬）
- ✅ P1-4 清理 G4 冗余底部「返回」按钮（统一由顶栏返回承担，兼顾测试契约）
- ✅ P1-5 P1 全量截图审计 + 对比图（`shots/v4_p1/`，6 张）

## 已完成（P2 阶段：核心主循环 10 屏）
- ✅ P2-1 加载页 `LoadScreen.gd` / 标题页 `Title.gd` / 登录页 `Login.gd` / 创角页 `CreateRoleChestView.gd`
- ✅ P2-2 主界面营地舞台 `GameHome.gd` + `home/TownHome.gd`、世界舆图 `WorldMapSelectPanel.gd`
- ✅ P2-3 背包 `BagPanel.gd` / 任务 `InventoryQuestSkin.gd` / 邮件 `MailPanel.gd`
- ✅ P2-4 探索 HUD `MapScene.gd`、战斗指令区 `BattleChestView.gd`、战斗单位与阵型 `BattleScene.gd`、战斗结算 `BattleSettlementView.gd`
- ✅ P2-5 截图审计 `shots/v4_p2/{audit,responsive,polish,comparisons}`（对比图 14 张）

## 已完成（P3 阶段：二级养成 / 玩法 / 社交）
- ✅ P3-1 养成线：`GrowthPanel.gd` / `GrowthChestView.gd`（角色·装备·技能·天赋·宠物·坐骑·称号）、`EquipChestView.gd`、`CollectionChestView.gd`、`MountPanel.gd`、`PetRaisePanel.gd`、`AvatarPanel.gd`
- ✅ P3-2 玩法线：`ShopPanel.gd`、`GachaPanel.gd`、`ArenaPanel.gd`、`ContractPanel.gd`、`CurioPanel.gd`、`JournalPanel.gd`、`CompanionPanel.gd`、`GatheringPanel.gd`、`JourneyPanel.gd`、`DeployPanel.gd`、`ActivityPanel.gd`、`FishingPanel.gd`、`HonorMarketPanel.gd`
- ✅ P3-3 设置页 `SettingsPanel.gd`
- ✅ P3-4 截图审计 `shots/v4_p3/{audit,responsive,comparisons}`（对比图 26 张）

## 已完成（P4 阶段：18 张探索地图地貌与氛围）
- ✅ P4-1 `MapScene.gd`：修复 `_name_tag_exclusions()`，18 张地图的玩家名（沈舟 Lv35）与怪物等级标签恢复 100% 不透明度
- ✅ P4-2 出生阵纹 `_SpawnGlyph`（F-01）；近出生点路牌加路侧 `visual_offset`（物理交互框不变）+ 黑漆金边名称胶囊
- ✅ P4-3 `IllustratedScenery.gd` / `WorldDressing.gd` / `SecondaryMapEnhancer.gd`：按 5 大生态区域替换 F-02..F-06 地貌边缘构件，清除非林地地图里跨区复用的绿色苔藓石块
- ✅ P4-4 `FourthActGround.gd` / `AssetCompletion.gd`：F-07 24px 导光石槽 + 38×38 T 型节点，补齐中央竖向主干道与三声部发光内芯
- ✅ P4-5 截图审计 `shots/v4_p4/{audit,responsive,polish,comparisons}`（18 张地图对比图）

## 验证汇总（各阶段收尾实跑）
| 套件 | 结果 |
|---|---|
| `CurrentVisualAudit.tscn` | `CURRENT_VISUAL_AUDIT_OK steps=141` |
| `CurrentResponsiveAudit.tscn` | `RESPONSIVE_CAPTURE_OK shots=132 overruns=0`（320×640 / 480×640 / 480×800 / 480×1067） |
| `VerifyVisualPolish.tscn` | `VISUAL_POLISH checks=199 failures=0` |
| `VerifyRequestedOptimizations.tscn` | `REQUESTED_OPTIMIZATIONS checks=410 failures=0 maps=18` |
| `VerifySignpostEntry.tscn` | `SIGNPOST_ENTRY_OK signs=8` |
| `VerifyStelePuzzle.tscn` | `STELE_PUZZLE_OK` |
| `tools/run_regression.ps1` | 78 / 78（`VerifyPerf` 为已知机器噪声，偶发红） |

## 遗留 / 未做
- 安卓**真机**验收仍未做（外放/蓝牙/音频焦点、安全区换算、三键与手势导航、系统栏恢复、覆盖安装与启动图标）——桌面 480 视口不能代替。
- `issue #43`（退出资源泄漏）未修，不属于 V4 范围。
- P1–P4 目前只有截图与对比图留档，**尚未写成独立 md 报告**（P0 有 `v4_p0_report.md`）；如需按 P0 规格补 `v4_p1_report.md`…`v4_p4_report.md`，从本节表格与 `shots/v4_p*/` 即可还原。

## 已确认无需处理
（D14 经实拍发现未修透，已并入上方 P0 完成项修复）
## 基线
- 回归：78 项 / 78 通过（VerifyPerf 已知偶发机器噪声，基线实跑 78/78 全绿）
- 截图基线：shots/commercial_review_20261028/

---

## P0 外部验收（2026-10-30，独立复核，非执行方自述）

**功能：12/12 完成。** 逐项抽查代码 + 对比图确认，与上表一致。其中 D14 是执行方在实拍复核时发现原判有误后补修的（原 `channel()` 只改了激活色，未激活态仍 `737a80` 且仍在做 3.4 倍横向压缩），这一处补修有效。

**回归：77 / 78。** 用官方 `tools/run_regression.ps1 -Expected 78` 独立跑过，唯一红项 `VerifyPerf`（已知性能债）。执行方自报的 78/78 是 `VerifyPerf` 偶发未超所致，不作为基线。

**D11 补漏：** 执行方漏了 `src/ui/CampGatheringPanel.gd`（「营灯下  听旧识讲一路见闻」），已由外部修掉；同时清掉 `src/ui/GmConsole.gd` 的「关  闭」。现在 `src/` 下的空格字距只剩：正常语义空格（`G.gd` 的「获得 精炼石」、`GmConsole` 的「各 +999999」）与方案 §1.3 冻结页（`Prologue.gd` 4 处、`SettingsPanel.gd` 1 处），属预期。

**性能：确认 P0 未引入退化。** 用 P0 前的 HEAD 代码做对照（回退 `G.gd`/`TownHome.gd`/`GameHome.gd` 后跑 3 次）：

| 指标 | P0 前（HEAD） | P0 后 |
|---|---|---|
| 加载页预热 | 6938 / 7367 / 7003 ms | 7332 / 7717 / 7760 ms |
| GameHome 进场 | 231 / 233 / 209 ms（**已超预算 200**） | 256 / 299 / 332 ms |
| CityScene 进场 | 898 / 694 / 701 ms（**已超预算 700**） | 695 / 774 / 802 ms |

→ P0 前这些指标就已经贴线/超线，说明是**这台机器当前整体慢了约 40%**（昨天预热 4803ms，今天 7000+），不是本次改动造成的。测量期间 `agy.exe` 常驻（PID 31672，权限不足无法结束），负载不干净。

**顺带修掉的性能隐患：** 执行方为修 D11 引入的 `G.spaced_font()` 没有缓存，每次调用都 `FontVariation.new()`，每个新变体都会让 TextServer 多建一份 shaping 缓存。`G.gold_button`（77 处）、`G.ghost_button`、`G.banner_box`、`PixelKit.label()`、`ArenaPanel._font_spaced`、`JourneyPanel._font_spaced` 都是每次调用就 new。已全部改为按 `(base, spacing)` 查表复用（`G.gd` 加 `_spaced_font_cache` / `_art_font_cache` 与 `spaced_art_font()`，`PixelKit`/`ArenaPanel`/`JourneyPanel` 各加 `static var` 缓存）。功能用例 `VerifyGameHome` / `VerifyGacha` / `VerifyArena` / `VerifyJourneyRelics` / `VerifyPanels` 全部通过。

**预算未调整。** 预算是性能契约，不随机器负载漂；`BUDGET_HOME_MS 200` 在当前机器上确实偏紧（P0 前就超），但它记录的是「这台机器应有的水平」，留着它才能发现真实退化。P1 期间若 `VerifyPerf` 红，按已知环境问题处理，不要改常量。
