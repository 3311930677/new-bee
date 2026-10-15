# 远征 UI 素材包 v3：生图需求

> 日期：2026-10-14
> 风格：乌漆底 + 旧金细边 + 少量朱红，以主页、设置两张定稿参考图为准。
> 共 8 张素材表、41 件。v1 的 31 件全部重画（id 不变，代码直接换皮），新增 10 件。

---

## 0. 怎么用

每张表生成时附三张图：

| 附图 | 作用 |
|---|---|
| `_review/ui_kit_v3/<表名>_guide_gpt.png` | 布局：品红底上每个灰块是一件素材，位置和比例照画 |
| `_review/ui_kit_v3/style_ref_home.png` | 风格：主页定稿（底栏、出征圆章、建筑名牌、货币条） |
| `_review/ui_kit_v3/style_ref_settings.png` | 风格：设置定稿（面板、组标题、开关、滑条、步进器） |

尺寸和九宫格切线看 `_review/ui_kit_v3/<表名>_guide_check.png`。

提示词 = 第 2 节通用前缀 + 第 4 节该表提示词。

原图存到 `D:\new-bee\outputs\ui_kit_v3_20261014\`，文件名用表名（如 `UI3-01_primary.png`）。保持 PNG 原图，不截图、不转 JPG。

---

## 1. 规范

- **像素密度 1:1**：1 美术像素 = 1 屏幕像素。第 3 节的尺寸就是游戏里的尺寸。
- **生图倍数**：布局图里的方块 = 美术尺寸 × 倍数（2 / 2.5 / 3，见表头）。颗粒不严格对网格也没关系，我会逐件还原到美术尺寸。
- **九宫格**：深灰区域是角块，所有装饰（包角、云纹、铆钉、宝石、图标座）都放这里；浅灰区域是中段，只能放能平铺的漆面和细边线。
- **背景**：纯品红 `#FF00FF`，素材内部不能用品红。
- **不画**：投影、外发光、柔光晕、文字、图标、人物。
- **同组同轮廓**：同一件的各状态（normal / pressed / disabled、开 / 关、5 档稀有度）外轮廓完全一致，只改颜色和光泽。

---

## 2. 通用前缀（每张都粘贴）

```text
Original 2D UI asset sheet for a portrait mobile RPG with an East-Asian frontier theme. Top-tier commercial mobile game quality.
Match the UI style of the two attached STYLE references (the game's home screen and settings screen) exactly: near-black lacquer (#1A1412) and dark lacquered wood as the main surface, thin aged-gold (#C9A45C) rims and fine gold inner lines, small cloud-scroll (ruyi) corner ornaments, tiny red-garnet rivets, vermilion (#9E2B25) used only as a small accent. Elegant and restrained, not chunky.
Follow the attached LAYOUT reference exactly: every grey box is one asset, drawn at that exact position and size; darker grey areas are decorated end caps / corners, light grey areas are plain stretchable middles that must contain only seamless lacquer texture and straight rim lines.
Rendering: fine-grain HD pixel art, crisp edges, consistent fine pixel size across the whole sheet; light from the upper left, lit top rims, darker bottom rims, small bright highlights on gold; subtle lacquer sheen and faint wood grain inside panels.
Background: flat pure #FF00FF magenta everywhere outside the boxes. Never use magenta inside any asset.
NO text, NO letters, NO numbers, NO icons or symbols, NO characters, NO cast shadows, NO outer glow, NO soft halo, NO tassels, NO jade pendants, NO dragons, NO 3D render look, NO photorealism, NO watermark.
```

---

## 3. 素材清单

尺寸单位：像素（美术 = 游戏）。九宫格顺序：左, 上, 右, 下。

| 表 | 倍数 | 素材 | 尺寸 | 九宫格 | 用在哪 |
|---|---|---|---|---|---|
| UI3-01 | 2 | hero_normal / pressed / disabled | 304×72 | 40,18,40,18 | 开始游戏、确认强化等全屏唯一主按钮 |
| UI3-02 | 2 | btn_normal / pressed / disabled | 128×48 | 16,12,16,12 | 次级按钮 |
| UI3-02 | 2 | tab_normal / tab_selected | 144×44 | 16,12,16,12 | 页签（常规 / 旅人 / 存档） |
| UI3-02 | 2 | pill（新） | 128×44 | 44,10,20,10 | 返回、说明（左端圆形图标座） |
| UI3-02 | 2 | btn_round | 56×56 | — | 小图标按钮 |
| UI3-03 | 2 | panel_iron | 256×256 | 48,48,48,48 | 设置分组面板、弹窗 |
| UI3-03 | 2 | card_paper | 256×192 | 32,32,32,32 | 羊皮纸说明卡、教学弹窗 |
| UI3-03 | 2 | group_header（新） | 240×48 | 56,0,36,0 | 组标题牌（左端圆形图标章） |
| UI3-04 | 2 | plaque_title | 352×64 | 80,0,80,0 | 页面标题 |
| UI3-04 | 2 | plaque_small | 192×40 | 40,0,40,0 | 角色名牌、小标签 |
| UI3-04 | 2 | building_tag（新） | 160×40 | 44,0,24,0 | 主页建筑名牌（左端图标圆章） |
| UI3-04 | 2 | divider | 240×20 | 48,0,48,0 | 分隔线、标题两侧饰线 |
| UI3-05 | 2 | toggle_off / toggle_on（新） | 80×36 | — | 开关 |
| UI3-05 | 2 | slider_track（新） | 240×12 | 12,0,12,0 | 滑条轨道 |
| UI3-05 | 2 | slider_fill（新） | 232×6 | — | 滑条填充 |
| UI3-05 | 2 | slider_knob（新） | 28×28 | — | 滑块 |
| UI3-05 | 2 | stepper（新） | 160×40 | 40,0,40,0 | 战斗倍速 `< ×1 >` |
| UI3-06 | 3 | slot_common / uncommon / rare / epic / legend | 64×64 | — | 装备、道具格 |
| UI3-06 | 3 | slot_empty / slot_selected | 64×64 | — | 空格、选中态 |
| UI3-07 | 2.5 | nav_base | 480×88 | 64,0,64,0 | 主页底栏 |
| UI3-07 | 2.5 | nav_socket / nav_socket_selected | 80×80 | — | 底栏图标座 |
| UI3-07 | 2.5 | rail_socket / rail_socket_selected | 56×60 | — | 主页右上背包、小聚 |
| UI3-07 | 2.5 | sortie_medal（新） | 112×112 | — | 出征圆章 |
| UI3-08 | 2.5 | bar_frame | 200×20 | 20,0,20,0 | 经验条、血条外框 |
| UI3-08 | 2.5 | bar_fill_exp / bar_fill_hp | 184×8 | — | 条填充 |
| UI3-08 | 2.5 | currency_capsule | 144×36 | 40,0,20,0 | 货币条（左端币槽） |
| UI3-08 | 2.5 | quest_slip | 256×72 | 40,20,24,20 | 主页任务条 |

---

## 4. 各表提示词（接在通用前缀后面）

### UI3-01 主按钮（3 件，倍数 2）

整套 UI 的气质由它决定，先生成这张，定稿后再做其余。

```text
Sheet UI3-01, scale 2. Three copies of the SAME primary action button, stacked top to bottom, identical outline:
1) normal: a black-lacquer frame with a thin aged-gold double rim; inside, a deep vermilion lacquer plate with a soft warm sheen along the top; small gold cloud-scroll ornaments on both short ends, each with one tiny red-garnet rivet; the long middle is plain lacquer with only the straight gold rim lines.
2) pressed: same button pushed in: vermilion one shade darker, top sheen replaced by a dark inner line.
3) disabled: same button with the plate turned dull dark grey-brown, gold rims dimmed, no sheen.
```

### UI3-02 按钮、页签、胶囊（7 件，倍数 2）

```text
Sheet UI3-02, scale 2. Top row: a secondary button in three states with identical outline: normal (black lacquer plate, thin aged-gold rim, tiny gold corner ticks), pressed (pushed in, darker, dark inner top line), disabled (dull grey lacquer, dim rim).
Bottom row, left to right:
- a tab in two states with identical outline: normal (flat black lacquer, dim gold outline), selected (vermilion lacquer fill with a bright gold rim and two tiny gold diamond ornaments near the ends);
- a pill button: rounded capsule of black lacquer with a thin gold rim; its left end is a raised round gold-ringed socket (empty centre, for an icon); plain middle for text;
- a round icon button: black lacquer disc with a thin gold ring and four tiny gold ticks, empty centre.
```

### UI3-03 面板与组标题（3 件，倍数 2）

```text
Sheet UI3-03, scale 2. Top left: a large panel: near-black lacquer surface with faint wood grain and a subtle inner shadow, framed by a thin aged-gold rim and a second fine gold inner line; each corner has a small gold cloud-scroll bracket with one tiny red-garnet rivet; edges between corners are plain straight lines.
Top right: a parchment card: cream aged parchment with darker worn edges, a thin brown ink border and small gold corner tacks; plain parchment middle.
Bottom: a group header plaque: horizontal black lacquer plaque with a gold rim; its left end is a large round gold-ringed seal (empty centre, for an icon) slightly overlapping the plaque; its right end is a gold swallowtail point; plain middle for a title.
```

### UI3-04 标题牌、名牌、分隔线（4 件，倍数 2）

```text
Sheet UI3-04, scale 2. Top: a wide page-title plaque: black lacquer with a thin gold rim, gold cloud-scroll end caps on both short sides, plain centre for text.
Bottom row, left to right:
- a small name plaque in the same style with simpler end caps;
- a building name tag: slim black lacquer tag with a gold rim; left end is a round gold-ringed medallion (empty centre, for an icon); right end is a small gold arrow-like point; plain middle for a short name;
- a thin divider: a fine gold line with a small ruyi cloud ornament at each end, plain middle.
```

### UI3-05 开关、滑条、步进器（6 件，倍数 2）

```text
Sheet UI3-05, scale 2.
Top row: a toggle switch in two states with identical outline: off (dark iron-grey lacquer track, thin dim gold rim, round brass knob on the LEFT); on (warm amber-gold lacquer track, bright gold rim, round brass knob on the RIGHT). Knob position must clearly differ.
Middle row: a slider track (thin recessed black channel with a fine gold rim and small gold end caps, plain middle) and a slider fill the size of the channel interior (warm orange-gold with a lighter top pixel row).
Bottom row: a slider knob (round brass knob with a gold ring and a tiny cross-star engraving, no text) and a stepper (black lacquer bar with a gold rim; both short ends are square gold-framed buttons with empty centres; plain middle for a value).
```

### UI3-06 稀有度格子（7 件，倍数 3）

```text
Sheet UI3-06, scale 3. Seven square item slots with IDENTICAL outline and inner recess (dark recessed lacquer square inside a thin beveled frame, empty centre). Top row, five rarity tiers, only the frame colour and a tiny corner gem change: common (dull grey-bronze), uncommon (jade green), rare (deep blue), epic (violet), legend (bright aged gold with tiny cloud-scroll corner flourishes and an amber gem). Bottom row: empty slot (dim frame, faint dashed inner edge) and selected slot (bright gold frame with four small inward corner ticks).
```

### UI3-07 底栏、图标座、出征圆章（6 件，倍数 2.5）

```text
Sheet UI3-07, scale 2.5.
Top: a full-width bottom navigation base: a slab of near-black lacquered wood with faint grain, a thin bright gold rim along the top edge and a fine gold inner line; both short ends have gold cloud-scroll corner caps with one tiny red-garnet rivet; plain repeating middle. No large red areas.
Bottom row, left to right:
- a round navigation socket in two states with identical outline: normal (dark recessed lacquer disc with a thin gold ring), selected (same with a brighter gold ring and a soft warm lit top edge);
- a smaller side socket in two states (normal / selected) in the same style;
- a large sortie medallion: round, raised, layered gold frame with a thin outer ring of small ruyi notches, a deep vermilion lacquer inner disc with a soft warm sheen, empty centre for an icon. It is the most prominent asset on the sheet.
All sockets and the medallion have empty centres.
```

### UI3-08 条、货币、任务条（5 件，倍数 2.5）

```text
Sheet UI3-08, scale 2.5.
Top: a thin bar frame: recessed black channel with a fine gold rim and small gold end caps, plain middle.
Middle row: two fills the size of the channel interior: experience (teal-jade with a lighter top pixel row) and health (crimson with a lighter top pixel row).
Bottom row: a currency capsule (black lacquer pill with a thin gold rim; left end is a round recessed socket for a coin icon; plain middle for numbers) and a quest slip (cream parchment strip on a thin black lacquer backing with a gold rim; left end has a small vermilion seal disc; plain middle for two lines of text).
```

---

## 5. 交付前自查

1. 背景是纯品红，素材内部没有品红。
2. 每件都在布局图对应位置，比例一致，没有被裁掉或粘连。
3. 装饰全部在深灰角块里，中段可以平铺。
4. 同组素材外轮廓一致；开关的开 / 关滑块位置明显不同。
5. 没有文字、图标、人物、投影、外发光。
6. 金边细，不是粗铁框；朱红只用在主按钮、选中页签、出征圆章和印章上。

## 6. 接入流程（我这边做）

```bash
python -I tools/restore_ui_kit.py D:/new-bee/outputs/ui_kit_v3_20261014 _review/ui_kit_v3/ui_kit_spec.json _review/ui_kit_restored_v3
```

还原后先看 `preview.png` 和 `report.json`（长宽比误差、色数），确认没问题再替换 `远征/assets/ui/kit_20261013/`，旧素材先备份。之后接入标题、主页、设置，跑 480×800 和 480×1067 实机截图对比。
