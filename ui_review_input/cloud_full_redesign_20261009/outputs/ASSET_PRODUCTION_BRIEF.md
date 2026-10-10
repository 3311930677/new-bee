# 《远征》UI 资产生产简报（灯下行箧）

> 方向已锁定：**深漆承载，旧铜立骨，纸签记事，灯火指路**（见 `UI_REDIRECTION_MASTER.md` B 节）。资产阶段不再探索风格。
> 组件与页面引用见 `MAIN_UI_REBUILD_BLUEPRINT.md`。尺寸单位：显示 = 480×800 逻辑像素；源 = 交付像素。

---

## 0. 全局交付规则（每项默认适用，表中只写例外）

1. **光向**：左上 45°；高光在左上边，暗部在右下。
2. **透明**：PNG-32，透明背景，四边不留杂色半透明像素。
3. **禁止烘焙**：任何中文、数字、名字、等级、价格、进度。品牌字标 BR-WORDMARK 是唯一例外。
4. **采样**：

   | 类别 | 源图 | 过滤 |
   |---|---|---|
   | 器物（按钮、匣盘、框、图标） | 3× | 线性 + mipmap（框体可关 mipmap） |
   | 世界像素（角色、地标、地图卷像素层） | 1× | 最近邻，整数倍显示 |
   | 文字 | — | 独立线性 |

5. **九宫格**：边距以源图像素给出；角件、铆钉、包角必须落在不可拉伸区。
6. **状态**：按下、禁用、选中、焦点优先用代码实现（调色、着色器去饱和、描边、缩放）。只有开关类图标和主按钮的按下态需要单独出图。
7. **命名**：`<ID>_<state>@3x.png`，例如 `UI-BTN-PRIMARY-9_pressed@3x.png`。
8. **颜色基准**：

   | 名称 | HEX |
   |---|---|
   | 夜漆 | `#17141A` |
   | 漆面 | `#221E26` |
   | 暗铜 | `#6E5434` |
   | 亮铜 | `#C29A5B` |
   | 朱漆 | `#6A2B1F` |
   | 灯金 | `#F0B95A` |
   | 纸签 | `#E8DCC0` |
   | 朱砂 | `#CF4A33` |
   | 玉青 | `#63B784` |
   | 霜蓝 | `#8DB3C7` |

---

## 1. 资产表

**来源**：复用 = 现有可直接用；重制 = 现有需重画；新增 = 没有现有资产。
**级别**：必需 / 增强 / 后续。
**批次**：B1 / B2 / B3（见 BLUEPRINT §19）。

### 1.1 品牌与场景

| ID | 名称 · 页面 · 组件 | 来源·级别·批次 | 解决的画面问题 | 显示→源 | 透明/拆层 | 九宫格/等比 | 变体 | 风险 | 临时方案 → 退出 |
|---|---|---|---|---|---|---|---|---|---|
| BR-WORDMARK | 铜漆书法字标“远征”· 标题/登记/加载 | 复用·必需·B1 | 11、13 仍是旧翅膀 Logo | 280×120 与 220×88 两档 → 现有源图 | 现有 | 等比 | — | 小尺寸笔画糊：需要 220 档的 1× 预览验收 | — |
| UI-RULE-BRONZE | 副标题铜线 · 标题/登记 | 复用·必需·B1 | — | 48×6 → 96×12（2×） | 透明 | 左右各 12 不可拉伸 | — | S01 长屏左侧缺失，待核实 | — |
| BG-HOME-EXT | 营帐夜空延展 · 营帐长屏 | 新增·必需·B1 | 1067 长屏顶部无内容 | 480×300 → 与营帐背景同像素密度 | 底部 40px 渐隐透明 | 不拉伸 | — | 与原图接缝 | 纵向渐变 `#121220`→原图顶色；B1 长屏验收前退出 |
| BG-LOAD-EXT | 加载插画延展 | 新增·后续·B3 | 长屏 cover 裁切过多时用 | 480×300 | 同上 | 不拉伸 | — | 插画源图尺寸未知 | cover 裁切 |
| CH-SHOW-{职业} | 角色展示精灵（营帐/养成/建角/出征人物步） | 新增·增强·B1 起（先破军） | 角色约 200px、存在感不足；不能非整数放大 | 显示约 240 高（3× 整数）→ 80×96 像素画布 ×6 帧 idle | 透明；身体与武器分层（可选）；脚底阴影单独一层 | 等比，整数倍 | idle 6 帧；可选“选中”1 帧 | 与地图精灵比例差异要有过渡；每个职业都要做 | 现有精灵整数倍 → 交付后营帐、养成、建角同步替换 |
| FX-STAGE-POOL | 灯池 · 角色台/图鉴/地区当前点 | 新增·必需·B1 | 建角页的平涂金色椭圆底座；角色悬空 | 200×48 → 600×144 | 透明，径向 | 等比（允许横向 0.8–1.2 缩放） | — | 过亮成为“光晕” | 着色器径向渐变（灯金 18%→0）→ 资产到位替换 |

### 1.2 共享控件

| ID | 名称 · 组件 | 来源·级别·批次 | 解决的问题 | 显示→源 | 拆层 | 九宫格（源 px） | 文字安全区（显示） | 变体 | 临时方案 → 退出 |
|---|---|---|---|---|---|---|---|---|---|
| UI-BTN-PRIMARY-9 | 朱漆主行动 · A-PRIMARY / CMD 主键 | 新增·必需·B1 | 主行动与返回等重；StyleBox 平涂廉价 | 高 56（标题页 64），宽 200–456 → 源 240×168 | 面 / 双色铜边 / 两端铜钉三层合一，交付单图 | L48 R48 T30 B30；铜钉在左右 48 内 | 内缩：左右 24、上下 10 | default / pressed / disabled | StyleBoxFlat：朱漆 + 2px 亮铜边，B1 验收前退出 |
| UI-BTN-HERO-9 | 继续旅程 · A-PRIMARY-HERO | 新增·必需·B1 | 营帐横幅过度装饰（罗盘、宝石、缎带） | 400×72 → 1200×216 | 面 + 左侧 40×40 印记槽（印记单独 ICN-JOURNEY） | L180 R72 T36 B36（左侧印记区不可拉伸） | 文字区 x+64…x+340 | default / pressed / disabled | 用 UI-BTN-PRIMARY-9 代替 → B1 验收前退出 |
| UI-TRAY-LIP | 匣盘箱沿 · TRAY | 新增·必需·B1 | 纸板外框、刻度尺边 | 480×6 → 1440×18 | 亮铜沿 + 下方 1px 影 | 横向三段：左右各 36 不可拉伸 | — | — | 2px 亮铜 ColorRect → B1 退出 |
| UI-TRAY-CORNER | 匣盘铜包角 | 新增·必需·B1 | 同上 | 12×12 → 36×36 | 单层；右角为水平镜像 | 等比 | — | — | 不显示 |
| UI-TRAY-FILL | 匣盘面（可选纹理） | 新增·增强·B2 | 平涂面略单薄 | 平铺 64×64 → 192×192 | 不透明 | 平铺 | — | 纹理变噪点 | 纯色夜漆 |
| UI-CELL-9 | 物品格 · ITEM-CELL | 新增·必需·B2 | 米色瓦片配 24px 小图标；稀有度难辨 | 84×92 / 70×80 / 52×56 → 源 120×120 | 漆面底 + 左上铜角；稀有度内线由代码着色（单独一张白色内线层） | L18 R18 T18 B18 | 图标区居中 48 | default（选中、禁用由代码实现） | StyleBoxFlat → B2 退出 |
| UI-CELL-L | 大物品框 · E-ART / I-ART | 新增·必需·B2 | 装备页无物品形象 | 96×96 → 288×288 | 框 + 内衬暗槽两层 | 等比 | — | — | UI-CELL-9 放大 |
| UI-AVATAR-RING | 头像铜圈 · ID-PLATE | 新增·必需·B1 | 现头像是罗盘占位，圈形不统一 | 56×56 → 168×168 | 圈 + 内部遮罩图 | 等比 | default / pressed（代码） | — | 2px 亮铜圆 |
| UI-MAPFRAME-9 | 地图框 · MAP-FRAME | 复用（V1）·必需 | — | — | — | 现有 | — | — | — |
| UI-ART-FRAME-9 | 插画画框 · 出征/介绍 | 新增·必需·B3 | 插画边缘生硬，或被纸板包住 | 448×224 → 源 240×240 | 只有框，中央透明 | L/R/T/B 各 36；四角包角在内 | — | — | 1px 亮铜 + 内阴影 |
| UI-SHOWCASE-9 | 图鉴展示台 | 新增·必需·B3 | 剪影被放在平涂深蓝框里 | 448×284 → 源 300×300 | 背板（深漆 + 微弱纹理）+ 框 + 底座阴影三层 | 各 48 | — | — | UI-ART-FRAME-9 + 灯池 |
| UI-CMD-ATK | 战斗攻击主键面 | 新增·必需·B3 | 四个等大指令 | 152×116 → 456×348 | 面 + 铜边；图标单独 | 等比（固定尺寸） | default / pressed / disabled | — | UI-BTN-PRIMARY-9 |
| UI-JOY-BASE/KNOB | 摇杆 | 复用（V1）·必需 | — | — | — | — | — | — | — |

### 1.3 图标（ICN 系列，母提示词见 §2.8）

源图 3×，显示尺寸见表；线性 + mipmap；四边留白 10%。

| ID | 显示 | 页面·组件 | 来源·级别·批次 | 变体 |
|---|---|---|---|---|
| ICN-NAV-WORLD / BAG / GROW / CODEX | 32 | 营帐 N-TABBAR | 重制·必需·B1 | default |
| ICN-RAIL-EVENT / ARENA / SUMMON / EXCHANGE / REUNION | 28 | 营帐旅签架 | 重制·必需·B1 | default |
| ICN-SETTINGS / BACK / INFO / LOCK / DICE / BAG | 24 | 页头、通用 | 新增·必需·B1 | LOCK：开、关两张 |
| ICN-CUR-GOLD / TOKEN / SOUL / HONOR | 20 | RES-CHIP | 复用·必需（统一轮廓后重出） | — |
| ICN-JOURNEY | 40 | 继续旅程印记 | 新增·必需·B1 | — |
| ICN-GROW-EQUIP / TALENT / BOOK / PET / MOUNT / TITLE | 40 | 养成 GROW-ROW | 重制·必需·B2（替换六个金圈徽章） | — |
| ICN-HUD-CAMP / EXIT / QUEST / PARTNER / POTION / INTERACT | 24–28 | HUD | V1 复用，统一轮廓·必需·B2 | — |
| ICN-HUD-SPRINT / RIDE | 28 | HUD | 新增·必需·B2 | off / on 两张 |
| ICN-CMD-ATTACK / SKILL / ITEM / PARTNER / RETREAT | 32（攻击 40） | 战斗 | 重制·必需·B3（替换写实高光风格） | — |
| ICN-CMD-AUTO | 24 | 战斗 | 新增·必需·B3 | off / on |
| ICN-STATE-HEART / HEART-CRACK / ENERGY / STONE | 12–20 | 状态条、成本 | 部分复用·必需·B2 | — |

### 1.4 地图

| ID | 名称 | 来源·级别·批次 | 解决的问题 | 显示→源 | 透明/拆层 | 等比 | 风险 | 临时方案 → 退出 |
|---|---|---|---|---|---|---|---|---|
| MAP-REGION-ART | 地区地图卷 | 新增·必需·B3 | 09 页是方格纸加矩形按钮，没有地理 | 视口 480×528；整图 960×1056 → 1×像素层（最近邻） | 分层：①纸底（可 2× 平滑）②地形像素层 ③路线层（实线、虚线分开）④雾层 MAP-FOG | 不拉伸，只平移 | 地点坐标必须与现有拓扑一致，需工程提供地点表 | 纸签色底 + 淡墨山水纹 + 地标 → 正式图到位后移除 |
| MAP-LMK-{地点} | 地点地标 | 新增·必需·B3 | 节点没有辨识度 | 显示 48×48 → 源 24×24 像素，整数 2× 显示 | 透明；去饱和由代码实现 | 整数倍 | — | 通用城、林、窟、坡四种通用图标 |
| MAP-FOG | 未探索雾 | 新增·增强·B3 | 未解锁区域只靠灰色表达 | 同地图层 | 半透明 | — | — | 不显示 |

---

## 2. 生成提示词（10 组）

通用前缀（每条都附加）：

> Game UI asset for a Chinese ancient-city travel fantasy pixel RPG "远征". Art direction: "lantern-lit travel chest" — dark lacquered wood (#17141A), aged bronze (#6E5434 / #C29A5B) only on structural edges and corners, paper slips (#E8DCC0), vermilion lacquer (#6A2B1F) for the single primary action, warm lantern gold (#F0B95A) as the only accent. Light from top-left. Clean, restrained, crafted; no wings, no gems, no compass roses, no glow halos, no random wood-grain noise. Transparent background. No text, no numbers, no letters, no watermark.

### 2.1 UI-BTN-PRIMARY-9 / UI-BTN-HERO-9（朱漆主行动）

- **用途**：每页唯一主行动；营帐“继续旅程”宽版。
- **提示词**：
  > A horizontal button plate made of deep vermilion lacquer (#6A2B1F), flat face with very subtle vertical lacquer depth (max 6% luminance change), 4-pixel chamfered corners, a two-tone bronze frame (outer 1px dark bronze #6E5434, inner 1px light bronze #C29A5B, top inner edge highlighted at 30%), one small round bronze rivet centered on the left and right ends. Front orthographic view, perfectly symmetric. Deliver three states: default; pressed (face 12% darker, top highlight removed); disabled (face replaced by dark lacquer #221E26, bronze desaturated 50%). Variant HERO: wider 400:72 ratio with an empty square recessed seal slot on the left (40×40 at display scale), no emblem inside.
- **尺寸**：PRIMARY 源 240×168（九宫格 L48 R48 T30 B30）；HERO 源 1200×216。
- **避免**：渐变发光、宝石、卷轴、文字、阴影投到背景。
- **验收**：拉伸到 456×56 与 200×56 时，铆钉不变形；灰度下三态可区分。

### 2.2 UI-TRAY-LIP / UI-TRAY-CORNER / UI-TRAY-FILL（匣盘）

- **用途**：所有页面的承载匣盘，替换方格纸板与刻度尺边。
- **提示词**：
  > A long horizontal bronze rim strip for the top edge of a dark lacquered chest drawer: 2px light bronze lip with a 1px shadow line underneath, slightly worn at regular intervals but no ornament. Separate piece: a small square bronze corner cap (L-shaped, 12×12 at display scale) with one tiny rivet, for the top-left corner (mirror for right). Optional seamless tile: dark lacquer surface #17141A with extremely subtle brush-lacquer texture, tileable, no visible pattern repetition.
- **尺寸**：LIP 源 1440×18（左右各 36 不可拉伸）；CORNER 源 36×36；FILL 源 192×192 平铺。
- **避免**：雕花、云纹、铆钉阵列、刻度。
- **验收**：480 宽平铺无接缝；放大 100% 看不出平铺的重复周期。

### 2.3 FX-STAGE-POOL（灯池）

- **用途**：角色、标本、当前地点脚下的光与影。
- **提示词**：
  > A soft elliptical warm lantern light pool seen on the ground from a 3/4 top-down view, color #F0B95A fading to fully transparent at the edges, with a smaller darker contact shadow ellipse in the center for character feet. Two separate layers: light pool, contact shadow.
- **尺寸**：源 600×144（显示 200×48）。
- **避免**：实心边缘、星光、光线条纹。
- **验收**：叠在营帐夜景与深漆面上，都不出现明显的圆盘边缘。

### 2.4 CH-SHOW-破军（角色展示精灵，其他职业按差异表）

- **用途**：营帐、养成、建角的角色台。
- **提示词**：
  > Pixel art character showcase sprite, same style and palette family as the existing in-game hero: a heavy-armored greatsword warrior "破军" with dark steel plate armor with gold trim, red cape, spiky brown hair, holding a huge greatsword diagonally in a ready stance, 3/4 front view facing right. Canvas 80×96 pixels, crisp 1-pixel outline in dark brown, limited palette (≤24 colors), light from top-left. Idle animation 6 frames: subtle breathing, cape sway, sword tip still. Transparent background, feet on bottom row minus 4 pixels, centered horizontally.
- **差异表**：

  | 职业 | 武器与特征 |
  |---|---|
  | 枪 | 长枪、轻甲 |
  | 法 | 法杖、长袍 |
  | 锤 | 圣锤、厚甲 |

  具体职业形象以现有精灵为准，**不改设定**。
- **尺寸**：80×96 像素/帧，横排 6 帧（480×96）；显示 3× 整数倍。
- **避免**：抗锯齿半透明边、写实光影、改变服装设定。
- **验收**：3× 显示时像素网格整齐；与地图精灵并排时能认出是同一角色。

### 2.5 BG-HOME-EXT（营帐夜空延展）

- **用途**：营帐长屏顶部的 267px 延展。
- **提示词**：
  > Pixel art night sky extension strip to sit above an existing camp-at-night background: deep indigo to blue-black gradient with sparse thin clouds catching faint warm city light at the bottom, a few small stars only near the top, no moon. Must blend seamlessly into the existing background's top edge colors (sample them). 480×300 at the same pixel density as the source background; bottom 40 pixels fade to transparent.
- **避免**：亮月、银河、流星、高饱和紫。
- **验收**：1067 长屏原尺寸截图看不出接缝。

### 2.6 MAP-REGION-ART（地区地图卷）

- **用途**：地区行路图主体。
- **提示词**：
  > A top-down illustrated regional travel map in pixel-art style, painted on aged paper: rolling hills, a maple forest road, a broken-stele slope, a cliff cave, and a walled frontier town, connected by a dirt road network. Muted earthy palette (paper #E8DCC0 base, ink-brown terrain lines, desaturated greens and ochres), small pixel trees and mountains, no labels. Leave clear flat ground spots at each location for separate landmark icons. Deliver layers: paper base, terrain pixel layer, solid road layer, dashed trial-route layer, fog-of-war layer.
- **尺寸**：960×1056；地形层 1× 像素、最近邻。地点坐标按工程提供的拓扑表摆放（昭元边城—枫林古道—断碑坡—失声碑窟 的连线关系必须一致）。
- **避免**：文字地名、指南针玫瑰、3D 透视、照片质感。
- **验收**：拓扑与现有一致；节点周围 104px 内无高对比细节，节点清晰可读。

### 2.7 MAP-LMK 系列（地点地标）

- **用途**：地区图节点。
- **母提示词**：
  > Pixel art landmark icon, 24×24 pixels, 3/4 top-down, 1-pixel dark outline, ≤8 colors, light from top-left, transparent background, consistent with the region map palette.
- **差异表**：

  | ID | 内容 |
  |---|---|
  | MAP-LMK-TOWN | 城门与城墙一段，红旗 |
  | MAP-LMK-FOREST | 三棵红枫与古道 |
  | MAP-LMK-SLOPE | 断裂石碑 |
  | MAP-LMK-CAVE | 崖壁洞口与碑 |
  | MAP-LMK-TRIAL | 界碑（历练用） |

- **验收**：2× 显示时在地图卷上可一眼区分；去饱和后仍能辨认。

### 2.8 ICN 系列（UI 图标母提示词 + 差异表）

- **母提示词**：
  > A single game UI icon in a consistent set: hard silhouette object, centered, occupying 80% of the canvas with 10% padding, 3/4 view, light from top-left, 1-pixel (at display scale) dark outline #1A1410, at most 5 tonal steps plus one local color, pixel-adjacent crisp edges (not blurry, not photo), no background disc, no glow, no sparkle. Export at 3× display size.
- **差异表**：

  | ID | 主体 | 固有色 |
  |---|---|---|
  | ICN-NAV-WORLD | 卷起的行路图 | 纸 |
  | ICN-NAV-BAG | 皮扣行囊 | 褐 |
  | ICN-NAV-GROW | 发芽的铜盆幼苗 | 玉青 |
  | ICN-NAV-CODEX | 线装册 | 朱漆封面 |
  | ICN-RAIL-EVENT | 灯笼 | 灯金 |
  | ICN-RAIL-ARENA | 交叉双剑 | 钢 |
  | ICN-RAIL-SUMMON | 符牌与光点 | 霜蓝 |
  | ICN-RAIL-EXCHANGE | 秤 | 铜 |
  | ICN-RAIL-REUNION | 两只酒盏 | 暖褐 |
  | ICN-JOURNEY | 行旅印章（路牌 + 山） | 朱漆 |
  | ICN-GROW-EQUIP | 剑与甲片 | 钢 |
  | ICN-GROW-TALENT | 星点枝 | 灯金 |
  | ICN-GROW-BOOK | 技能书 | 霜蓝 |
  | ICN-GROW-PET | 爪印 | 暖褐 |
  | ICN-GROW-MOUNT | 马首 | 赭 |
  | ICN-GROW-TITLE | 冠 | 灯金 |
  | ICN-HUD-CAMP | 帐篷 | 帐褐 |
  | ICN-HUD-EXIT | 门旗 | 朱砂 |
  | ICN-HUD-QUEST | 卷轴 | 纸 |
  | ICN-HUD-SPRINT（off/on） | 靴：off 为暗填轮廓，on 为填色加 3 条动势线 | 灯金 |
  | ICN-HUD-RIDE（off/on） | 马鞍，同上规则 | 赭 |
  | ICN-CMD-ATTACK | 斜举长剑 | 钢 |
  | ICN-CMD-SKILL | 打开的书加光纹 | 霜蓝 |
  | ICN-CMD-ITEM | 药瓶 | 药红 |
  | ICN-CMD-PARTNER | 爪印 | 暖褐 |
  | ICN-CMD-RETREAT | 折旗 | 朱砂 |
  | ICN-CMD-AUTO（off/on） | 齿轮 / 齿轮加环形箭头 | 灯金 |
  | ICN-SETTINGS | 铜齿轮 | 铜 |
  | ICN-BACK | 回折箭头 | 纸白 |
  | ICN-INFO | 圆中“i”形刻痕（图形，不是字母） | 纸白 |
  | ICN-LOCK | 铜锁开/关 | 铜 |
  | ICN-DICE | 骰子 | 象牙 |

- **验收**：一屏并排 24 个图标的灰度截图里，轮廓粗细、留白、光向一致；24px 显示时可辨认。

### 2.9 UI-CELL-9 / UI-CELL-L（物品格）

- **用途**：背包、装备槽、图鉴缩略。
- **提示词**：
  > A square inventory cell frame: dark lacquer recessed well #221E26 with a 1px dark bronze outer edge, a small bronze L-shaped corner piece on the top-left only, and a separate thin white inner-line layer (to be tinted by rarity in code). Large variant: same design with a deeper inner bevel for a 96×96 item showcase.
- **尺寸**：CELL 源 120×120（九宫格各 18）；L 源 288×288 等比。
- **避免**：稀有度色烘焙、宝石角、发光。
- **验收**：五种稀有度着色后都可辨；选中的 2px 灯金框由代码叠加时与铜角不冲突。

### 2.10 UI-CMD-ATK + 战斗指令盘（战斗）

- **用途**：战斗攻击主键与指令匣盘。
- **提示词**：
  > A large square-ish primary battle command plate (ratio 152:116) in vermilion lacquer with two-tone bronze frame and 4px chamfer, an empty recessed area in the upper 60% for an icon, and a clean band in the lower 40% for a live text label. States: default, pressed, disabled. Matching dark lacquer tray strip for the command area uses UI-TRAY assets — do not create a different frame family.
- **尺寸**：源 456×348。
- **避免**：火焰、剑光、能量环。
- **验收**：与 UI-BTN-PRIMARY 并排时属于同一套器物。

---

## 3. 交付与验收流程

1. 每组资产先交 1× 显示尺寸的预览拼板，由美术总监在 480×800 原尺寸截图中验收。
2. 九宫格资产附“拉伸到最小、最大尺寸”的测试图。
3. 像素资产附 2×/3× 整数倍显示的测试图。
4. 不接受整屏合成图作为可用资产。合成效果图只能作为沟通附件，必须同时交付拆层源文件。
5. 每批资产与 BLUEPRINT §19 的批次对应；某批资产未交付时，按表中“临时方案”实施，并在退出条件满足时替换。
