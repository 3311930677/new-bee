# 远征 UI 素材包：生图需求

> 日期：2026-10-13
> 目标：用一套统一的像素 UI 素材，替换现在代码画的纯色框体，把主菜单、主页、养成、装备、地图入口提到商业手游质感。
> 共 7 张素材表、31 件素材。每张表一次生成。

---

## 0. 怎么用

每张表生成时附上三张图：

| 附图 | 作用 |
|---|---|
| `_review/ui_kit/<表名>_guide_gpt.png` | 布局参考：品红底上的灰色方块就是每件素材的位置和比例 |
| `_review/ui_kit/style_ref_title_bg.png` | 风格参考：游戏标题背景，定色调和画工 |
| `_review/ui_kit/style_ref_character_x4.png` | 像素参考：主角放大图，只参考画工，颗粒以本文 1.1 为准 |

核对尺寸用 `_review/ui_kit/<表名>_guide_check.png`，上面标了每件的编号、美术尺寸、游戏尺寸和九宫格切线。

提示词 = **通用前缀（第 2 节）** + **该表的提示词（第 4 节）**。

原始 PNG 放到 `outputs/ui_kit_20261013/`，文件名用表名，比如 `UI-01_hero_button.png`。不要截图，不要转 JPG。

---

## 1. 规范

### 1.1 像素密度

- 游戏里 UI 按 **1 美术像素 = 1 屏幕像素** 绘制，和地图颗粒一致（2026-10-13 由 1:2 改为 1:1）。
- 每件素材都有固定的美术尺寸（见第 3 节表格）。
- 布局图里每件方块 = 美术尺寸 × 放大倍数（每张表的倍数写在表头）。生成时请让一个美术像素占一个 `倍数×倍数` 的方块。
- GPT 做不到严格网格也没关系，我会按规范逐件切出、按网格还原、量化颜色。但颗粒越接近规范，还原损失越小。

### 1.2 九宫格

框体、按钮、标题牌在游戏里会被拉伸到不同宽度，所以分成两部分：

- **角块（布局图里较深的灰色区域）**：放所有装饰，包角、雕花、铆钉、宝石。游戏里保持原样不拉伸。
- **中段（浅灰色区域）**：只放能重复的简单纹理和边框线，**不要放任何装饰图案**，否则拉伸后会变形。

### 1.3 透明与背景

- 背景必须是纯品红 `#FF00FF`，或真实透明。
- 素材本身**不能使用品红色**。
- 不画投影、外发光、柔光晕。立体感只靠素材内部的受光面和暗面。

### 1.4 状态一致

同一件素材的不同状态（normal / pressed / disabled，稀有度 5 档）**外轮廓必须完全一致**，只改颜色、凹陷和光泽。

---

## 2. 通用前缀（每张都粘贴）

```text
Original 2D pixel art UI kit for a portrait mobile fantasy expedition RPG with an East-Asian frontier theme (bronze, red lacquer, aged wood, parchment, jade). Commercial mobile RPG quality.
Match the pixel-art craft, palette and lighting of the attached STYLE references (the game's title background and the hero sprite enlarged). Follow the attached LAYOUT reference exactly: every grey box is one asset, drawn at exactly that position and that size; darker grey areas inside a box are the decorated end caps / corners, light grey areas are plain stretchable middles.
Pixel art rules: one uniform pixel size across the whole sheet (each art pixel drawn as a solid square block of the scale stated below), hard pixel edges, no anti-aliasing, no blur, no gradients, no airbrush, limited palette, dark 1-pixel outlines in deep brown or near-black (never pure black).
Materials: dark forged iron with warm bronze-gold trim, deep red lacquer, aged dark wood, cream parchment. Light from the upper-left: lit top edges, darker bottom edges, small bright pixel highlights on metal.
Background: flat pure #FF00FF magenta everywhere outside the boxes. Never use magenta inside any asset.
NO text, NO letters, NO numbers, NO icons or symbols inside buttons, NO characters, NO cast shadows, NO outer glow, NO soft halo, NO 3D render look, NO photorealism, NO watermark.
```

---

## 3. 素材清单

美术尺寸单位是美术像素；1:1 规范下游戏尺寸 = 美术尺寸，九宫格边距同为屏幕像素。

| 表 | 倍数 | 素材 | 美术尺寸 | 游戏尺寸 | 九宫格（左,上,右,下） | 用在哪 |
|---|---|---|---|---|---|---|
| UI-01 | 2 | hero_normal / pressed / disabled | 304×72 | 304×72 | 32,16,32,16 | 开始游戏、继续旅程、出征、确认强化 |
| UI-02 | 2 | btn_normal / pressed / disabled | 128×48 | 128×48 | 16,12,16,12 | 次级按钮 |
| UI-02 | 2 | tab_normal / tab_selected | 144×44 | 144×44 | 16,12,16,12 | 页签 |
| UI-02 | 2 | btn_round | 56×56 | 56×56 | — | 返回、设置、小图标按钮 |
| UI-03 | 2 | panel_iron | 256×256 | 256×256 | 48,48,48,48 | 大面板、弹窗 |
| UI-03 | 2 | card_paper | 256×192 | 256×192 | 32,32,32,32 | 信息卡、说明卡 |
| UI-04 | 2 | plaque_title | 352×64 | 352×64 | 80,0,80,0 | 页面标题牌 |
| UI-04 | 2 | plaque_small | 192×40 | 192×40 | 40,0,40,0 | 角色名牌、小标签 |
| UI-04 | 2 | divider | 240×20 | 240×20 | 48,0,48,0 | 分隔线 |
| UI-05 | 3 | slot_common / uncommon / rare / epic / legend | 64×64 | 64×64 | — | 装备、道具格（5 档稀有度） |
| UI-05 | 3 | slot_empty / slot_selected | 64×64 | 64×64 | — | 空格、选中态 |
| UI-06 | 2.5 | nav_base | 480×88 | 480×88 | 64,0,64,0 | 底部导航底座 |
| UI-06 | 2.5 | nav_socket / nav_socket_selected | 80×80 | 80×80 | — | 导航图标座 |
| UI-06 | 2.5 | rail_socket / rail_socket_selected | 56×60 | 56×60 | — | 主页右侧入口座 |
| UI-07 | 2.5 | bar_frame | 200×20 | 200×20 | 20,0,20,0 | 经验条、血条外框 |
| UI-07 | 2.5 | bar_fill_exp / bar_fill_hp | 184×8 | 184×8 | — | 条的填充 |
| UI-07 | 2.5 | currency_capsule | 144×36 | 144×36 | 20,0,20,0 | 货币胶囊 |
| UI-07 | 2.5 | quest_slip | 256×72 | 256×72 | 32,20,32,20 | 主页任务卡 |

---

## 4. 各表提示词（接在通用前缀后面）

### UI-01 主按钮（3 件，倍数 2）

最重要的一张，整套 UI 的气质由它决定。

```text
Sheet UI-01, scale 2 (each art pixel = 2x2 block). Three copies of the SAME large primary action button, stacked top to bottom, identical outline:
1) normal: a deep red lacquer plate set in a forged dark-iron frame with a raised bronze-gold rim; ornate gold end caps on both short sides (cloud-scroll or ruyi motif) with a small jade or amber gem; a thin bright highlight line along the top edge; the long middle is plain lacquer with a very subtle grain.
2) pressed: same button pushed in: lacquer one shade darker, top highlight replaced by a dark inner line, gem dimmer.
3) disabled: same button desaturated to grey-brown iron, no gem shine.
```

### UI-02 次级按钮与页签（6 件，倍数 2）

```text
Sheet UI-02, scale 2. Top row: a secondary button in three states with identical outline: normal (dark iron plate with a thin bronze rim and small corner rivets), pressed (pushed in, darker, dark inner top line), disabled (grey, no shine). Bottom row: a tab in two states with identical outline: normal (flat dark iron, dim bronze underline), selected (warm bronze-gold rim, lit top edge, a small gold notch at the bottom centre); and one round icon button (circular dark iron disc with a bronze ring and four tiny rivets, empty centre).
```

### UI-03 面板（2 件，倍数 2）

```text
Sheet UI-03, scale 2. Left: a large dark forged-iron panel frame with heavy bronze-gold corner brackets (ornate L-shaped corners with a rivet and a tiny gem), straight plain edges between the corners, dark recessed inner area with a faint brushed-metal texture. Right: a parchment card: cream aged parchment with darker worn edges, a thin brown ink border and small bronze corner tacks; plain parchment middle.
```

### UI-04 标题牌与分隔线（3 件，倍数 2）

```text
Sheet UI-04, scale 2. Top: a wide page-title plaque: dark lacquered wood with a bronze-gold frame, ornate swallowtail end caps with cloud scrolls on both short sides, plain flat centre for text. Bottom left: a small name plaque in the same style, simpler end caps. Bottom right: a thin horizontal divider: a bronze line with a small diamond ornament at each end, plain middle.
```

### UI-05 稀有度格子（7 件，倍数 3）

```text
Sheet UI-05, scale 3. Seven square item slots with IDENTICAL outline and inner recess (dark recessed square inside a beveled frame, empty centre). Top row, five rarity tiers, only the frame metal and a small corner gem change: common (plain grey iron), uncommon (iron with green jade trim and gem), rare (iron with blue sapphire trim and gem), epic (bronze with violet amethyst trim and gem), legend (bright gold with amber gem and tiny engraved corner flourishes). Bottom row: empty slot (dim iron, dashed inner edge) and selected slot (warm gold rim with small corner arrow ticks pointing inward).
```

### UI-06 导航底座（5 件，倍数 2.5）

```text
Sheet UI-06, scale 2.5. Top: a full-width bottom navigation base: a thick slab of dark lacquered wood framed in forged iron with a bronze-gold top rim, ornate end caps on both short sides, plain repeating middle. Bottom row: a round navigation icon socket in two states with identical outline (normal: dark recessed iron ring; selected: same ring with a warm gold rim and lit top), and a smaller side-rail icon socket in two states (normal / selected) in the same style. All sockets have empty centres.
```

### UI-07 条、货币、任务卡（5 件，倍数 2.5）

```text
Sheet UI-07, scale 2.5. Top: a thin bar frame: dark iron channel with bronze end caps, plain middle. Middle row: two bar fills the size of the channel interior: experience fill (teal-jade with a lighter top pixel row) and health fill (crimson with a lighter top pixel row). Bottom row: a currency capsule (dark iron pill with bronze rim, a round socket on the left end for a coin icon, plain middle for numbers) and a quest slip (a small parchment note pinned on a dark iron backing with a red wax seal on the left end, plain middle for two lines of text).
```

---

## 5. 交付前自查

1. 画布 1536×1024，背景是纯品红或真透明，素材内部没有品红。
2. 每件都在布局图对应的方块位置，大小比例一致，没有被裁掉。
3. 装饰全部在角块（深灰区域）里，中段是可以拉伸的简单纹理。
4. 同一件素材的不同状态、5 档稀有度，外轮廓完全一致。
5. 没有文字、图标、角色、投影、外发光。
6. 像素颗粒统一，边缘硬，没有模糊和渐变。

## 6. 我这边接入时会做的事

- 按 `ui_kit_spec.json` 逐件切出，还原到美术尺寸（= 游戏尺寸），量化颜色，抠底，二值化透明。
- 检查同组素材的轮廓是否一致，九宫格中段能否无缝拉伸。
- 写成 Godot 的九宫格样式，替换 `PixelKit` 里代码画的框体，依次接入主菜单、主页、养成、装备、地图入口。
- 每页在游戏里实际截图，前后对比。
