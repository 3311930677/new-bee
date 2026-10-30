# 远征 · 商业化画面重构 P0 阶段验收报告

- **执行日期**：2026-10-30
- **对应方案**：`远征/docs/2026-10-28-商业化画面重构方案.md`（仅执行 **P0 阶段**，共 12 项确定缺陷）
- **进度记录**：`远征/docs/v4_progress.md`
- **新素材状态说明**：**素材已到位、尚未入库**。`D:/new bee/outputs/commercial_20261028/` 下 A–G 七组共 56 张已交付（其中 A 组文件名为 `UI4-01_topbar.png` … `UI4-06_meters.png`，其余组为 `B-01.png`、`C-01.png` 等）。按交接要求，P0 阶段全部为纯代码修复，未对新图片做后处理或入库；`远征/assets/commercial_20261028/`、`远征/data/commercial_20261028.json` 与 `assets/ui/kit_20261013/` 的 v4 合并均留待 P1 阶段执行。

---

## 一、P0 12 项缺陷逐项修复清单与截图证据

| 编号 | 缺陷名称 | 状态 | 修改文件 | 修复方案摘要 | 改后实拍截图 | 改前\|改后并排对比图 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **D1** | 剧情幕正文溢出、提示被黑边盖住 | ✅ 已修复 | `src/ui/StoryBeat.gd` | 1. 底框 `stage_card` 上移至 `(32, 434)`、高扩为 `290`；正文容器 `box` 设于 `(64, 524)`、尺寸 `352×176`、开启 `clip_contents = true`，行间距 `separation = 6`，台词字号统一为 `G.FS_SM`（`AUTOWRAP_WORD_SMART`），确保 6 行台词完整落于底框金角内侧。<br>2. 将上下信箱黑边（`y=0` 与 `y=VIEW_H-42=758`）移至 `hint` 之前 `add_child`，并将 `hint.position` 设为 `Vector2(0, VIEW_H - 42.0 - 28.0)`（`y=730`），置于下黑边正上方。<br>3. 清除副标题与跳过按钮的手工空格，改用 `G.spaced_font`。 | `shots/v4_p0/extra/x03_storybeat_intro.png`<br>`shots/v4_p0/extra/x03_storybeat_outro.png` | `shots/v4_p0/compare/cmp_D1_storybeat_intro.png`<br>`shots/v4_p0/compare/cmp_D1_storybeat_outro.png` |
| **D2** | 登录页被回退成表单 | ✅ 已修复 | `src/ui/LoginChestView.gd`<br>`src/ui/Login.gd` | 从 `148c7d3a^`（`0566a808`）取回参考稿实现：加载 `res://assets/ui/login_20261014/` 下 `login_kit.json` 坐标表、`login_backdrop.png` 全屏氛围底、`login_bg.png` 卷轴主舞台（含上下 `64px` 渐隐 shader）与 `sky_color` / `ground_color` 延伸色块、朱漆金框主按钮、黑底金边次按钮与圆形罗盘头像框 `AvatarDisc`；同时完整保留当前版的 `safe_layout_exempt`、`layout(safe_override, keyboard_override)` 软键盘避让、`320×640` / `480×640` 窄矮屏等比缩放与 `_reveal_focus()`。 | `shots/v4_p0/s03_login.png`<br>`shots/v4_p0/responsive/320x640_Login.png`<br>`shots/v4_p0/responsive/480x800_Login.png` | `shots/v4_p0/compare/cmp_D2_login.png` |
| **D3** | 誓约描述压在卡片边框上 | ✅ 已修复 | `src/ui/OathPanel.gd` | 将原先固定 `140px` 步进、固定 `132px` 子卡高度改为：`card_h = 146.0`（纵向步进 `154.0`），`desc.custom_minimum_size = Vector2(384, 78)` 配合 `AUTOWRAP_WORD_SMART`（不提前锁死未换行 `size`），使三张誓约子卡的第三行奖励描述距离子卡下边框均留足 `12px+` 内边距，同时动态调整 `paper` 总高与返回按钮坐标。 | `shots/v4_p0/s07_oath.png`<br>`shots/v4_p0/responsive/480x800_oath.png` | `shots/v4_p0/compare/cmp_D3_oath.png` |
| **D4** | 唤灵阁标题与装饰重叠 | ✅ 已修复 | `src/ui/CraftUI.gd`<br>`src/ui/GachaPanel.gd` | 1. 在 `CraftUI.heading` 中将标题 Label 在 `plaque_title.png`（`236×48`，位于 `(24, 18)`）内设为居中对齐（`HORIZONTAL_ALIGNMENT_CENTER`），使「灵宠召唤」避开牌匾左端雕花包角；将顶部分隔金线移至 `y=96`，避免穿过右上货币条。<br>2. 移除 `GachaPanel.gd` 主打卡左上角半透明 `head_banner`（`plaque_title.png` `modulate.a=0.45`）叠层，消除与「本期主打 / 幼龙·烬」的脏叠影。 | `shots/v4_p0/s07_gacha.png` | `shots/v4_p0/compare/cmp_D4_gacha.png` |
| **D6** | 主城货币顶边、无缩写 | ✅ 已修复 | `src/ui/home/TownHome.gd` | 1. `CAP_W` 从 `86.0` 扩至 `89.0`（四枚胶囊总宽 `368`，`row.end.x = 468 <= 468`），数字区宽度扩至 `CAP_W - 36`。<br>2. `_fmt(n)` 对 `>= 100000000` 格式化为 `"%d.%d亿"`、对 `>= 10000` 格式化为 `"%d.%d万"`（如 `128400` → `"12.8万"`），`< 10000` 保持原数字以兼容既有测试断言；`refresh()` 统一调用 `_fmt(value)`。 | `shots/v4_p0/s05_home.png`<br>`shots/v4_p0/polish/01_home.png` | `shots/v4_p0/compare/cmp_D6_D15_home.png` |
| **D7** | 地图 HUD 图标对比度不足 | ✅ 已修复 | `src/ui/WorldHUDSkin.gd`<br>`src/ui/LacquerUI.gd`<br>`src/explore/MapScene.gd` | 1. 在 `WorldHUDSkin.ring` 圆形动作键上半图标区（`y < size.y - 19`）绘制暖亮金衬底（`Color("e0c286")` + 2px `Color("f7e2b2")` 亮边），与深褐图标形成 `> 6.5:1` 对比度；`ActionIcon` 改用 `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` 保留高分辨率金线细节。<br>2. `set_count(0)` 改为清晰灰阶图标 + 深色角标底配醒目红字 `"0"`（`Color("ff6452")`），`> 0` 时用朱漆红角标（`Color("c83e2b")`）。<br>3. 疾行激活态外圈增绘翠玉光环；交互键浮现时加入 `TRANS_BACK` 回弹放大动效。 | `shots/v4_p0/s09_map_lorin_wilds.png` | `shots/v4_p0/compare/cmp_D7_map_hud.png` |
| **D9** | 出征说明写的是键盘操作 | ✅ 已修复 | `src/ui/DeployPanel.gd` | 将 `TIPS` 中的 PC 键盘文案（`← → 或 A/D`、`↑ ↓ 或 W/S`）全面替换为触屏手势优先文案：<br>• `"左右滑动或点两侧箭头切换当前选项"`<br>• `"点顶部「1 秘境 / 2 人物 / 3 宠物」切换步骤"` | `shots/v4_p0/s07_deploy.png`<br>`shots/v4_p0/responsive/480x800_deploy_help.png` | `shots/v4_p0/compare/cmp_D9_deploy.png` |
| **D11** | 用空格假装字距（20+ 处） | ✅ 已修复 | `src/autoload/G.gd`<br>`src/ui/SlideCard.gd`<br>`src/city/CityScene.gd`<br>`src/explore/MapScene.gd`<br>`src/run/RouteScene.gd`<br>`src/ui/ArenaPanel.gd`<br>`src/ui/CodexPanel.gd`<br>`src/ui/DeployPanel.gd`<br>`src/ui/FishingPanel.gd`<br>`src/ui/GameHome.gd`<br>`src/ui/GmConsole.gd`<br>`src/ui/JourneyPanel.gd`<br>`src/ui/Login.gd`<br>`src/ui/MountPanel.gd`<br>`src/ui/PetRaisePanel.gd`<br>`src/ui/RoadMailPanel.gd`<br>`src/ui/ShopPanel.gd`<br>`src/ui/StoryBeat.gd`<br>`src/ui/TitlePanel.gd`<br>`src/ui/TraitPicker.gd`<br>`src/ui/WorldPanel.gd` | 1. 在 `G.gold_button`、`G.ghost_button`、`G.banner_box`、`SlideCard._kicker`、`JourneyPanel._button`、`ShopPanel` 等统一通过 `FontVariation.spacing_glyph`（`G.spaced_font`）设置字距。<br>2. 全库扫描并清除除冻结页面（`Prologue.gd`、`SettingsPanel.gd`）外的全部 30+ 处手工插入空格的中文字符串（如 `"出 征"` → `"出征"`、`"物 资 铺"` → `"物资铺"`、`"开 始 切 磋"` → `"开始切磋"`、`"已 领 取"` → `"已领取"` 等）。 | `shots/v4_p0/s07_shop.png`<br>`shots/v4_p0/s07_arena.png`<br>`shots/v4_p0/s07_journey.png` | `shots/v4_p0/compare/cmp_D11_shop.png`<br>`shots/v4_p0/compare/cmp_D11_arena.png`<br>`shots/v4_p0/compare/cmp_D11_journey.png` |
| **D13** | 货币卡底部被截断 | ✅ 已修复 | `src/ui/CurrencyPanel.gd` | 1. 将 `source` 与 `use` 的拆行分隔符改为按 `"，"`、`"；"` 断行（保留 `"、"` 并列短词在同一行），使条目紧凑易读。<br>2. 将硬编码字号全部收归 `G.FS_SM / G.FS_MD / G.FS_READING / G.FS_LG / G.FS_BIG` 常量。<br>3. 在 `layout()` 中精确累加内部子控件高度并预留 `+272.0` 外框空间（上限 `minf(716.0, safe.size.y - 28)`），彻底解决「可以用于」段落底部被裁切的问题。 | `shots/v4_p0/s08_currency_gold.png`<br>`shots/v4_p0/s08_currency_expedition.png`<br>`shots/v4_p0/s08_currency_soul.png`<br>`shots/v4_p0/s08_currency_honor.png` | `shots/v4_p0/compare/cmp_D13_currency_gold.png`<br>`shots/v4_p0/compare/cmp_D13_currency_expedition.png`<br>`shots/v4_p0/compare/cmp_D13_currency_soul.png`<br>`shots/v4_p0/compare/cmp_D13_currency_honor.png` |
| **D14** | 共鸣槽画成两条黑条 | ✅ 复核并补修 | `src/world/AssetCompletion.gd` | 实拍 `s09_map_stele_resonance.png` 复核发现：原代码虽将激活态染色改成了 `c9ece5`，但未激活态仍为 `737a80`，且仍按 `module := 36.0, height := 12.0` 将 `124×19` 的 `rune_channel.png` 横向压缩 3.4 倍，导致实拍仍是两条黑条。按方案 §4.24-7 改为 1:1 贴图原尺寸平铺（`Rect2(0, 0, length, tex_h)`，目标高 `tex_h`），未点亮染色提亮至 `Color("a9b0b5")`。 | `shots/v4_p0/s09_map_stele_resonance.png` | `shots/v4_p0/compare/cmp_D14_stele_resonance.png` |
| **D15** | 主城头像显示罗盘 | ✅ 已修复 | `src/ui/home/TownHome.gd` | 在 `TownHome.gd` 新增 `_home_avatar_texture()`：当玩家开启自定义头像时返回 `G.custom_avatar_texture()`，否则直接加载当前所选职业头像 `G.role_icon_path(_valid_role_id(G.selected_role))`（如破军 `pojun_icon.png`），不再显示罗盘占位图；同时保持 `G.avatar_texture()` 原契约不变以兼容 `VerifyAvatar`。 | `shots/v4_p0/s05_home.png` | `shots/v4_p0/compare/cmp_D6_D15_home.png` |
| **D17** | 称号职业写错 | ✅ 已修复 | `data/titles.json` | 将 `t_lore_ck`（朔风听刃）的 `desc` 从 `"刺客参悟边城古碑疾风共鸣"` 改为 `"枪骑参悟边城古碑疾风共鸣"`，保持 `id: "t_lore_ck"` 不变。 | `shots/v4_p0/extra/x06_title_lore_ck.png`<br>`shots/v4_p0/s07_growth_title_bottom.png` | `shots/v4_p0/compare/cmp_D17_title_lore_ck.png` |

---

## 二、截图审计与交付物索引

1. **全量主审计截图（141 步）**：`远征/shots/v4_p0/`（由 `res://tools/CurrentVisualAudit.tscn` 生成，含 `audit_report.json`）
2. **多尺寸响应式审计截图（132 张，4 种分辨率：`320×640` / `480×640` / `480×800` / `480×1067`）**：`远征/shots/v4_p0/responsive/`（由 `res://tools/CurrentResponsiveAudit.tscn` 生成，`RESPONSIVE_CAPTURE_OK shots=132 overruns=0`）
3. **精修复核截图（199 项检查，0 失败）**：`远征/shots/v4_p0/polish/`（由 `res://tools/VerifyVisualPolish.tscn` 生成，`VISUAL_POLISH checks=199 failures=0`）
4. **专项补充实拍（剧情幕对峙/余韵、序章、称号朔风听刃选中态）**：`远征/shots/v4_p0/extra/`
5. **改前 | 改后并排对比图（共 17 张，覆盖全部 P0 修复项）**：`远征/shots/v4_p0/compare/`
   - `cmp_D1_storybeat_intro.png` / `cmp_D1_storybeat_outro.png`
   - `cmp_D2_login.png`
   - `cmp_D3_oath.png`
   - `cmp_D4_gacha.png`
   - `cmp_D6_D15_home.png`
   - `cmp_D7_map_hud.png`
   - `cmp_D9_deploy.png`
   - `cmp_D11_shop.png` / `cmp_D11_arena.png` / `cmp_D11_journey.png`
   - `cmp_D13_currency_gold.png` / `cmp_D13_currency_expedition.png` / `cmp_D13_currency_soul.png` / `cmp_D13_currency_honor.png`
   - `cmp_D14_stele_resonance.png`
   - `cmp_D17_title_lore_ck.png`

---

## 三、回归测试对比

| 阶段 | 用例总数 | 通过数 | 失败数 | 备注 |
| :--- | :--- | :--- | :--- | :--- |
| **开工前基线** | 78 | 78 | 0 | `VerifyPerf` 为已知偶发机器噪声，基线实跑通过 |
| **P0 完成后** | 78 | 78 | 0 | 无任何新增回归失败；`VerifyVisualPolish`（199 项）、`CurrentResponsiveAudit`（132 张，0 溢出）全部通过 |
