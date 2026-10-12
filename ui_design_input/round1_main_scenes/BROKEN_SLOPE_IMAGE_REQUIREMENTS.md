# 断碑坡（broken_slope）样板地图：生图需求文档

> 项目：`D:\new-bee\远征`（Godot 4.7，480×800 竖屏，Nearest 过滤）
> 阶段：第一阶段产出。本文档只做规划，没有修改任何项目文件，也没有生成任何素材。
> 目标：用一整套模块化像素素材重做 broken_slope，做成成熟商业 2D 像素 RPG 的野外地图。样板通过后，同一套方法复制到其余 16 张标准尺寸地图。

---

## 0. 本文档怎么用

1. 先读第 1、2 节，理解要做成什么样。
2. 第 3 节是统一规范，所有素材共用。
3. 第 5 节按编号逐项生成。每项都有完整字段表和可直接粘贴的英文提示词。
4. 第 6 节是生成顺序和交付命名。把原始 PNG 发给我，不要截图、不要转 JPG。
5. 第 7 节是你自己的验收清单，发给我之前过一遍可以省掉返工。

每次生成的提示词 = `通用前缀（3.7）` + `对应视角块（3.6，素材提示词里写的 [VIEW-G] 或 [VIEW-O]）` + `该素材的提示词` + `精灵表后缀（3.8，仅精灵表需要）` + `克制块 [CALM]（3.10）`。生成时附上风格参考图 `_review/bs00_v2_pixelized_256x384_x4.png`。

---

## 1. 要解决的问题

### 1.1 现状（来自项目文件和运行截图）

- `image/main_world/broken_slope_ground_v4.png` 为 960×1248，共 346,153 种颜色，是柔和的照片质感绘画，不是像素画。
- 运行截图里整张图是"灰绿 + 土黄"两种色调的斑块混合，没有清晰路沿、没有高差、没有地标，缩小后认不出这是什么地方。
- 叠在上面的装饰是 48px 通用小图，随机缩放 0.85–1.18 后随机撒点。路牌、摊位、箱子、狼的像素颗粒大小各不相同。
- 现有路网（`flat_routes`）、刷怪点、任务点、出口是好的，新美术要完全贴合它们。

### 1.2 你提出的核心要求

> 地图不再是两个粗糙色调拼凑，要真的有"远征世界"的感觉，要有成熟游戏像素风格 2D 地图的感觉。

我把它拆成下面 8 条设计原则。后面每一份素材需求都围绕这几条写。

| # | 原则 | 具体做法 |
|---|---|---|
| 1 | 材质多样，不是两种色调 | 地表至少 6 种材质：草、枯草、裸土、碎石、苔地、落叶地，加土路和石铺路两种路面。材质之间用不规则的"像素边缘斑块"过渡，不用渐变 |
| 2 | 地形有高差 | 北崖、中段石坎、南侧沟壑，把一整块平地切成"沟 → 营地 → 中坡 → 碑林 → 崖门"几个台阶 |
| 3 | 有一眼能认出来的地标 | 中坡东侧的巨型断碑、北端的碑窟石门。缩到 25% 的缩略图也要认得出 |
| 4 | 路是会讲故事的 | 路面从南到北逐渐变化：踏实土路 → 车辙和泥洼 → 营地踩实地 → 碑林区的旧石铺路 → 崖门前的台阶。路沿有深色土边和覆盖的草叶 |
| 5 | 旅人留下的痕迹 | 营火、翻倒的盐车、车辙、兽迹、系绳木桩、巡逻路标、断桥。不画人物，只画人经过的证据 |
| 6 | 分区有冷暖变化 | 南入口暖（锈红枫叶过渡）→ 营地暖光 → 中坡橄榄绿 → 碑林偏冷偏苔 → 崖门冷暗。整图色温有走向，但每个区域内部不超过一个主色调 |
| 7 | 疏密有节奏 | 每屏 2–4 棵大树、4–8 丛灌木，至少 35% 是安静的草地和路面。树在两侧成林，在怪物空地处向内收出缺口 |
| 8 | 像素统一 | 全图只有一种像素尺寸（1 美术像素 = 1 世界像素）。不再有 0.055 倍缩小的怪物或 0.085 倍缩小的路牌这种混用 |

---

## 2. 样板地图方案：broken_slope 断碑坡

### 2.1 为什么选它

- 960×1248 标准尺寸的野外图，背景 1:1 绘制，没有被程序层盖住。
- 功能齐全：5 个刷怪点、1 个可选 Boss、营地交易点、修桥任务、追踪任务、南北两个出口。
- 主题鲜明：从枫林古道走向远古界碑带，最容易做出"远征"的味道。
- `docs/plans/2026-10-05-map-background-review-and-plan.md` 已经把它定为第一张样板。
- 做通以后，其余 16 张标准尺寸地图可以复用同一套流程。lorin_wilds 和 maple_road 是另一条管线，不在这一轮。

### 2.2 世界观

古代边境的界碑带。界碑本来用来"报声"，现在已经失声。这是一条商旅和巡卫北上的必经坡地：旧路、倒伏的界碑、车辙、营火痕迹、修补过的木桥，北面崖壁里是通向失声碑窟的石门。

整体氛围是边境远征的苍凉和荒废，不是童话森林，也不是废土。

### 2.3 色彩与光照

| 色组 | 色值（参考） |
|---|---|
| 草 | #3e4a35 #52603f #6b7a4c #879461 #a3ad78 |
| 枯草高光 | #b9b394 #cec8a5 |
| 土路 | #5e4b37 #7a6247 #98805d #b7a079 #cfbd95 |
| 石 | #2f3438 #474e52 #646b6c #868b86 #a9aca2 |
| 苔 | #4f6a3a #6f8a45 |
| 地衣 | #c9c07a |
| 锈红（枫叶、旗布） | #8a3b2a #b5583a #d98a4f |
| 溪水 | #2b4a52 #3f6a70 #6c9a96 #b8d0c4 |
| 火光 | #d98a4f #f0b45c #ffe29a |
| 描边、暗部 | #23302e #1f2422 |

- 色值是参考，整体色相和明度要落在这个范围里，不需要逐色精确。后期我会统一量化到项目色板。
- 光源在左上，午后柔和斜光。物体右下是冷暗面，树根和石底有接触暗部。
- 不要纯黑、不要纯白、不要霓虹高饱和绿。

### 2.4 分区设计

坐标是世界像素（0,0 在左上角，地图 960×1248），与 `data/main_world_maps.json` 一致。

| 区 | y 范围 | 主色调 | 内容 |
|---|---|---|---|
| Z7 崖门 | 0–170 | 冷暗灰蓝 | 北崖横贯，碑窟石门（出口 480,96），台阶，两侧残碑 |
| Z6 碑林 | 170–540 | 偏冷偏苔 | 倒伏碑群，苔石，路面换成旧石铺路。两侧怪物空地 (160,405)、(790,420) |
| Z5 石坎 | 540–575 | 中性灰绿 | 低矮干砌石坎，只在 x 360–470 留坡道口（所有环路都在 415,560 汇合） |
| Z4 中坡 | 575–870 | 橄榄绿 | 东环岛中心约 (560,790) 立巨型断碑；西环岛是泥洼和兽迹。怪物空地 (200,710)、(760,760)、(335,860) |
| Z3 营地 | 870–960 | 暖 | 营地广场 (475,930)，营火暖光。迷失之兽巢穴在西南 (140,880) |
| Z2 沟壑 | 970–1015 | 冷湿 | 横贯浅沟，主石桥 x 430–530，西木桥 (245,990)、东木桥 (710,990)（修桥任务，损坏和修复两种状态） |
| Z1 南入口 | 1015–1248 | 暖，锈红枫叶 | 出生点 (480,1040)，出口 (480,1152)，枫叶过渡，路标 |

两侧密林边界厚 60–120px，在怪物空地处收出缺口。

### 2.5 道路

完全沿用现有 `flat_routes`，不改路网：

- 主干宽 88：(480,1152) → (480,1040) → (475,930) → (525,735) → (415,560) → (505,330) → (480,185) → (480,96)
- 西环路宽 62：(475,930) → (355,980) → (255,950) → (295,820) → (410,755) → (525,735)
- 东环路宽 60：(475,930) → (600,900) → (655,785) → (590,655) → (415,560)
- 北环路宽 60：(505,330) → (330,375) → (290,500) → (415,560)

道路材质分段：y > 330 用土路材质，y < 330 逐渐换成旧石铺路，约在 y 330–400 之间有一段碎裂的过渡。

### 2.6 新增结构（需要你确认）

石坎（Z5）和沟壑（Z2）会新增碰撞，改变可走区域。刷怪点、出口、任务点的位置都已经避开，不受影响。如果你不想新增碰撞，我会把它们当作纯装饰处理，素材需求不变。

### 2.7 分层结构

| 层 | z | 内容 | Godot 实现 | 生图 |
|---|---|---|---|---|
| L0 地表 | -20 | 6 种地表材质 + 2 种路面，由道路遮罩合成 | 256px 无缝材质 + 遮罩（遮罩由 `flat_routes` 生成，边缘按像素对齐、带不规则锯齿），加载时烘焙缓存 | 是（BS-G01） |
| L1 地表贴花 | -15 | 材质斑块、草丛、花、碎石、车辙、裂纹、路沿草叶、落叶 | 独立精灵，按规则散布 | 是（BS-G02、BS-G03） |
| L2 地形结构 | Y 排序 + 碰撞 | 北崖、石门、石坎、沟壑、桥 | 模块化精灵 + 多边形或矩形碰撞 | 是（BS-L02、L03、L04） |
| L3 物件 | Y 排序 + 碰撞 | 树、灌木、石、断碑、营地、任务道具 | 独立精灵，原点在底部中心，碰撞只覆盖树干或基座 | 是（BS-T01~T03、R01、L01、C01、Q01） |
| L4 前景 | 8 | 边缘树冠、垂枝、底部草叶 | 独立精灵，玩家走到下方时半透明 | 是（BS-F01） |
| L5 特效 | 9 | 落叶、尘点、萤火、雾带 | GPUParticles2D + 小精灵 | 是（BS-E01） |
| 小地图 | UI | 由 L0–L2 烘焙后缩小、色阶化 | 代码 | 否 |

**为什么地表不用 48px TileSet：** 这张图的道路是自由折线，宽 60–88，不对齐格子。用 TileSet 铺会变成阶梯状。2026-10-05 的文档已经批评过这种"梯子形"。所以地表用"重复材质 + 遮罩"，其余层全部模块化。我不会用一张巨图覆盖整张地图。

---

## 3. 统一规范（所有素材共用）

### 3.1 像素密度

| 项目 | 数值 |
|---|---|
| 地图素材 | 1 美术像素 = 1 世界像素，Godot 里 scale 必须是 1 |
| 屏幕呈现 | 镜头 1.15 倍，屏幕上每个美术像素约占 1.15 个屏幕像素 |
| 角色基准 | 128px 帧，可见身高 109–111px（实测），在 broken_slope 缩放 0.54 后约 60 世界像素高 |
| 逻辑格 | 48 世界像素（只用于碰撞和布局，不用于美术拼块） |

### 3.2 物件尺寸基准（单位：美术像素 = 世界像素）

| 物件 | 尺寸 | 相对角色 |
|---|---|---|
| 大树 | 宽 150–200，高 190–240 | 约 3.5 倍 |
| 中树 / 枯树 / 枫树 | 宽 90–150，高 150–190 | 约 2.5–3 倍 |
| 灌木 | 36–72 | 0.6–1.2 倍 |
| 石 | 小 12–24 / 中 32–56 / 巨石 72–110 | |
| 巨型断碑 | 约 160×190（含基座） | 约 3 倍 |
| 门洞 | 宽至少 104，高至少 96 | 至少 1.6 倍 |
| 主路 / 环路 | 宽 88 / 60–62 | |

### 3.3 像素画规则

- 全图只有一种像素尺寸。同一张图里不能出现大小不同的像素块。
- 最小细节团块 2×2。孤立的单个像素只用于高光和火星。
- 硬边，无抗锯齿，无渐变喷枪，无随机噪点抖动。
- 选择性描边：用该材质自己最暗的一阶颜色，不用纯黑。
- 每个素材不超过 24 色，整张地图合计约 40 色。
- 投影：素材里不画地面投影，Godot 里统一生成。树根、石底的接触暗部可以画。
- 透明：只允许 0 或 255，不允许半透明边缘（雾带例外，只允许两档）。

### 3.4 画布规则

GPT 生成的图不是严格的像素网格，所以我们约定：**每个美术像素在生成图里画成 4×4 的方块**。生成画布固定三种：

| 代号 | 生成画布 | 对应美术像素网格 |
|---|---|---|
| C-S | 1024×1024 | 256×256 |
| C-W | 1536×1024 | 384×256 |
| C-T | 1024×1536 | 256×384 |

后文所有尺寸都是**美术像素**，生成时整体放大 4 倍。精灵表里每件之间至少留 16 美术像素（64 生成像素）的空白。

### 3.5 我在第三阶段会做的处理（你不需要做）

检测像素网格 → 按网格中心采样到目标尺寸 → 量化到统一色板 → alpha 二值化 → 无缝材质修接缝 → 逐项检查尺寸、色数和透明边缘。素材做得越接近上面的规则，损失越小。

### 3.6 视角锁定（第一张样张的教训，所有素材必须遵守）

第一张 BS-00 样张的问题是：它是一幅"斜着往下望的风景插画"，不是游戏地图的切片。具体表现：

- 台地和崖壁把侧面立面大面积画了出来（右侧坡台有整面崖壁），地形有了"高度"，整个镜头看起来是倾斜的。
- 桥画成了从侧面看的拱桥，桥洞和水是侧视，水里还有小瀑布。
- 森林连成一整片带远近关系的树冠，像从高处斜望出去。
- 断碑同时画了正面和侧面，成了 2.5D 方块。

游戏里的实际情况是：镜头固定，地面是一块平面，所有东西同一比例，"高度"靠 Y 排序和独立结构精灵表达。所以美术必须是**扁平的地图切片**。视角只允许两种：

| 代号 | 用于 | 定义 |
|---|---|---|
| **V-G** | 地面、材质、路、水沟、贴花 | 正交投影，镜头严格垂直向下 90°，像地图或卫星瓦片。地面是一整块完全平的平面：没有地平线、没有透视、没有远近缩放。**高度不在这类图里画**：不画崖壁立面、不画台地侧面、不画瀑布、不画桥洞 |
| **V-O** | 树、石、碑、建筑、营地、崖壁、桥、道具 | 正交投影，所有物件使用**同一个固定镜头角度**：只画物体的**正面**和一小条**顶面**（经典 16 位 RPG 野外地图的画法）。**永远不画左侧面或右侧面**。竖线绝对垂直，横线绝对水平，不汇聚，不因位置不同而变形。物件立在底部基线上 |

共同禁止：透视汇聚、远小近大、景深虚化、空气雾化、暗角、倾斜镜头、等距或 2.5D 方块、画出物体左右侧面、整幅"风景插画"式构图。

高度怎么表达：

- 地面图里没有高度。
- 高差只通过独立的结构精灵表达（石坎、北崖、石门），而且只画正立面，由游戏用 Y 排序叠到地面上。
- 水沟按平面画：水面和两岸只露顶面，不画岸壁立面。桥只画桥面和护栏顶面，不画桥洞。
- 树：树冠是一团圆形叶簇（从略高处看到的顶面），树干短短地露在下面，不画树的侧视。
- 碑、石、建筑：正面 + 一小条顶面，不画侧面。

**每次生成都要粘贴对应的视角块**（各素材的"视角"字段和提示词里的 [VIEW-G] / [VIEW-O] 会指明用哪个）：

```text
[VIEW-G]
CAMERA: strictly orthographic, looking straight DOWN at exactly 90 degrees, like a flat 2D game map
tile or a satellite tile. The ground is ONE perfectly flat plane. There is NO horizon, NO perspective,
NO vanishing point, NO depth shrinking, NO tilt, NO aerial landscape-illustration look, NO depth of
field, NO haze, NO vignette. Nothing is shown from the side: no cliff faces, no vertical walls,
no waterfalls, no raised terraces, no bridge arches. Height differences are NOT drawn at all.
Every point of the image has exactly the same scale.
```

```text
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
```

### 3.7 通用前缀（每次生成都粘贴）

```text
[STYLE PREFIX]
Original 2D pixel art game asset for a flat 2D top-down fantasy expedition RPG field map (mobile, portrait).
The camera is locked by the VIEW block that follows; never deviate from it.
Professional, mature JRPG field-map craft: clean hand-placed pixel clusters, ONE uniform pixel size
across the whole image (every art pixel drawn as a 4x4 block), hard pixel edges, no anti-aliasing,
limited palette (max 24 colors), selective dark outlines in deep green/brown (never pure black).
Light from the upper-left, soft late-afternoon light, cool shadowed lower-right sides.
Muted, weathered palette: sage and olive greens, ochre packed dirt, cool blue-grey stone,
small rust-red accents. Frontier expedition mood: old roads, weathered stone, traces of travelers.
Original design, not imitating any existing game.
NO text, NO UI, NO people, NO creatures, NO watermark, NO photorealism, NO painterly brush strokes,
NO blur, NO airbrush gradients, NO random noise dithering, NO glow, NO cast shadows on the ground,
NO perspective, NO 3D look, NO isometric, NO landscape illustration, NO depth of field, NO vignette,
NO magenta (#FF00FF) used inside the artwork.
```

### 3.8 精灵表后缀（所有精灵表都附加）

```text
[SHEET SUFFIX]
Isolated assets on a fully transparent background (if transparency is unavailable: a flat pure #FF00FF
background with no gradients and no shadows). Every asset separated by at least 64 px of empty space,
arranged in a neat grid, all drawn at the SAME pixel scale, each asset complete and uncropped.
Output as PNG, exact canvas size as specified.
```

### 3.9 参考图使用

- `ui_review_input/reference_world_frontend_20261010/reference/01_target_forest.jpg` 是你给的目标参考。
- 用于传达两件事：**像素工艺水平**（成团的叶簇、三层明度的草地、干净的路沿、自然的接地暗部）和**镜头角度**（平地、树冠是一团圆形加短树干、没有崖壁和透视）。第一张样张之所以偏成斜视风景画，一个原因是没有给它这类"平地切片"的视觉参考。
- **不要**复制它的色彩（我们的色调更克制）、构图和角色。
- 在 BS-00 样张生成时可以附上这张图，并写一句：`Match the pixel craft level AND the flat top-down camera angle of the attached reference (flat ground, round-canopy trees with short trunks, no cliffs, no perspective), but use the muted palette described and a different composition. Do not copy the character.`
- 样张通过后，后续所有素材都附上 BS-00 样张作为风格参考。

### 3.10 BS-00 第二版评审结论（2026-10-12）

第二版样张通过，作为**镜头角度和像素工艺**的锚点，BS-00 不再重抽。实测和目测结果：

| 项 | 结果 |
|---|---|
| 视角 | 通过。地面是平面，没有崖壁、台地、瀑布；桥是平桥面，只见桥面和护栏顶；水沟是平面带；树是"圆形树冠 + 短树干"，每棵独立；碑和石只有正面和顶面 |
| 远征感 | 通过。断碑、倒伏碑段、车辙、裸土斑块、枯树都到位，已经不是"两种色调拼凑" |
| 饱和度 | 偏高。平均饱和度 0.52，比 2.3 的克制色板更鲜。按 40 色量化后的版本更接近目标 |
| 安静区域 | 不足。8×8 区块中只有 15.7% 是平静的，目标是至少 35%。小花、红叶、草簇在全图均匀撒满 |
| 像素网格 | 不是真网格（17.2 万色，95.9% 的横向像素段长度为 1）。和第一版一样，入库前必须重新像素化 |

处理方式：

1. 风格参考改用量化版：`_review/bs00_v2_pixelized_256x384_x4.png`（原图按 4 倍降采样、量化到 40 色、再放大回原尺寸）。后续生成时附上它，而不是原图。
2. 安静区域不足不需要靠重抽样张解决。正式地图的地面由材质、斑块、贴花按密度规则拼出来，疏密由我在 Godot 里控制。但单项素材本身也要克制，所以**下面这段加到每一次生成的提示词末尾**：

```text
[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
```

---

## 4. 素材总览与生成次数

| 编号 | 内容 | 画布 | 次数 |
|---|---|---|---|
| BS-00 | 风格定调样张（只参考，不导入） | 1024×1536 | 1 |
| BS-G01 | 地表无缝材质（草、土路、碎石、苔石路） | C-S | 4 |
| BS-G02 | 地表贴花（路沿草叶、车辙、裂纹等） | C-W | 2 |
| BS-G03 | 地表材质斑块（打破两色调的关键） | C-W | 3 |
| BS-T01 | 大型阔叶树（每张一棵） | C-S | 5 |
| BS-T02 | 中型树：阔叶 ×2、枯树 ×2 | C-W | 2 |
| BS-T03 | 灌木与蕨类 | C-W | 2 |
| BS-R01 | 岩石 | C-W | 2 |
| BS-L01 | 断碑与界碑 | C-S + C-W | 2 |
| BS-L02 | 北崖与碑窟石门 | C-W | 3 |
| BS-L03 | 沟壑与桥 | C-W | 2 |
| BS-L04 | 石坎 | C-W | 1 |
| BS-C01 | 营地 | C-W | 1 |
| BS-Q01 | 任务与交互道具 | C-W | 1 |
| BS-F01 | 前景层 | C-W | 3 |
| BS-E01 | 特效小精灵 | C-W | 1 |
| 合计 | | | 35 |

---

## 5. 逐项需求

### BS-00 风格定调样张

| 字段 | 内容 |
|---|---|
| 用途 | 确定色彩、光照、细节密度和"远征感"，作为后续所有素材的风格参考。**不导入游戏** |
| 尺寸 | 生成 1024×1536（对应 256×384 美术像素） |
| 比例 | 2:3 竖图 |
| 像素规范 | 每个美术像素 4×4 方块；全图一种像素尺寸；约 40 色 |
| 视角 | 严格按 3.6 锁定：地面 V-G，直立物件 V-O。整图是一块扁平的正交地图切片，不是风景插画 |
| 构图 | 一条赭色土路从下往上弯曲，宽度约为画面宽度的 1/3（对应 88 世界像素）。**全部在同一块平地上，没有台地、没有崖壁、没有高差**。路右侧平地上立一块斜向断裂的巨型界碑（带石砌基座，只画正面 + 顶面）；路左侧是倒伏的碑段和一棵枯树；下三分之一横贯一条平面的浅沟（从正上方看，只见水面和两岸），平桥面处路穿过；两侧是疏密相间的树，**每棵树独立可数**，不连成一整片树冠海 |
| 颜色 | 按 2.3 的色板。南端点缀少量锈红枫叶 |
| 光照 | 左上午后斜光；沟里更暗；碑的断面受光最亮 |
| 材质 | 草地 3 个明度层，靠草簇表现；路沿有 2px 深色土边，草叶盖到路面；路面中间被走得更亮，有车辙；碑石有风化裂纹、苔、暗淡赭金色刻痕 |
| 必须保留 | 道路区域干净、可读；至少 35% 是安静的草地；有一处明显的材质过渡（草 → 裸土或苔地） |
| 禁止 | 人物、怪物、UI、文字、投影、发光符文、两色调斑块感 |
| 与角色匹配 | **样张不作为尺寸基准。** 一张 256×384 美术像素的画布装不下 220px 的大树、88px 的路和整座桥，所以样张里的物件必然偏小，这是正常的。样张只用来定风格，物件的真实尺寸以 3.2 和各单项素材为准。不要画出人物 |
| Godot 使用方式 | 不导入 |
| Tile 还是背景图 | 都不是，仅风格参考 |

```text
[STYLE PREFIX]
[VIEW-G]
[VIEW-O]
SCENE: a flat 2D game-map tile section (like a cropped screenshot of a classic 16-bit top-down
RPG field map), NOT a landscape illustration. Canvas 1024x1536 (256x384 art pixels).
The whole ground is ONE flat plane: no cliffs, no raised terraces, no vertical rock walls,
no waterfalls, no height differences anywhere.
A worn ochre dirt road, one third of the image width, curves from the bottom to the top.
Right of the road, on the same flat ground, stands ONE giant ancient boundary stele, snapped
diagonally in half, on a cut-stone plinth (front face and thin top face only, no side faces),
moss on the shoulders, faded ochre-gold rune carvings (no glow). Left of the road: toppled stele
fragments, one dead tree (short trunk, bare branches, front view), grass clumps, a patch of bare
earth and a patch of mossy ground blending into the meadow with ragged hard-pixel edges.
Across the lower third runs a narrow shallow stream gully drawn as a flat strip seen from straight
above (only the water surface and the grassy-stone banks, no bank walls), crossed by a flat-decked
stone bridge seen from directly above (deck and parapet tops only, no arch, no bridge opening)
where the road passes. Trees are separate individual round-canopy trees (canopy mass with a short
trunk below) scattered in loose groups on both sides with gaps of open meadow between them, never
a continuous forest-roof. Grass has three value layers built from tuft clusters; the road has a crisp
dark dirt lip with grass blades overhanging it, a paler worn center and cart ruts. At least 35% of the
image is calm open ground. A few rust-red maple leaves near the bottom edge.
```

> 同样的 3.6 视角块已经内嵌在上面的提示词里，粘贴时把 `[VIEW-G]`、`[VIEW-O]` 两行替换成 3.6 里对应的完整文字。

---

### BS-G01 地表无缝材质（4 张，每张单独生成）

| 字段 | 内容 |
|---|---|
| 用途 | L0 地表的基础材质 |
| 尺寸 | 每张 C-S：生成 1024×1024，处理成 256×256 |
| 比例 | 1:1 |
| 像素规范 | **必须无缝**，上下、左右都能接上。每张不超过 8 色 |
| 视角 | V-G 锁定（见 3.6）：严格垂直向下的正交俯视，地面完全平面 |
| 构图 | 均匀分布，没有视觉中心、没有单个大物体 |
| 颜色 | a：草色组；b：土路色组；c：石色组 + 土路色组；d：石色组 + 苔色组 |
| 光照 | 只有很轻的左上光感，没有方向性投影 |
| 材质 | a 草地：成簇草丛，3 个明度层。b 土路：压实的土，少量小石子，中间略亮。c 碎石地：灰蓝碎石混合泥土。d 苔石铺路：旧石板，缝隙里有苔 |
| 必须保留 | 四边完整无缝；可以重复平铺 |
| 禁止 | 噪点颗粒、明显的重复图案、单个大物体、阴影、花、叶子 |
| 与角色匹配 | 草簇 6–14px，石子 4–12px，铺路石板每块约 28–40px |
| Godot 使用方式 | 重复材质（repeat），配合道路遮罩合成地面 |
| Tile 还是背景图 | 重复材质贴图，不是 TileSet，也不是背景图 |

```text
[STYLE PREFIX]
[VIEW-G]
Seamless tileable top-down ground texture, canvas 1024x1024 (256x256 art pixels), wraps perfectly on
all four edges, no focal point, no large objects, max 8 colors. Even distribution.
Variant (a): short meadow grass of sage/olive greens built from small tuft clusters in three value layers.
```

其余三张把最后一句替换为：

- b：`Variant (b): packed ochre dirt road surface, slightly lighter in the center, sparse tiny pebbles, faint wear marks.`
- c：`Variant (c): blue-grey gravel and broken stone chips mixed with dirt.`
- d：`Variant (d): old flagstone pavement, each slab about 28-40 art pixels, cracks between slabs filled with moss.`

---

### BS-G02 地表贴花精灵表（2 张）

| 字段 | 内容 |
|---|---|
| 用途 | L1 层。清晰路沿，加路面细节，打破地面单调 |
| 尺寸 | 每张 C-W：生成 1536×1024，对应 384×256 美术像素 |
| 比例 | 3:2 |
| 像素规范 | 每张不超过 20 色，同一像素尺度 |
| 视角 | V-G 锁定（见 3.6）：严格垂直向下的正交俯视，地面完全平面 |
| 构图 | 网格排列，每件之间留空至少 16 美术像素 |
| 颜色 | 草、土、石、锈红色组 |
| 光照 | 左上 |
| 材质与内容 | **G02-A（路面细节）**：路沿草叶条，横向 3 段 + 竖向 3 段，每段约 64×16，一侧边缘平直，用来贴着路沿放；车辙 2 段，64×20，可横向连续拼接；泥洼 2 个，32–64；地面裂纹 3 条；裸露树根 2 段；脚印贴花 2 组。**G02-B（草地细节）**：草丛 6 个（宽 12–32）；野花 4 种（宽 8–16）；碎石子群 5 组；落叶堆 3 堆（其中 1 堆锈红）；高草 2 丛 |
| 必须保留 | 路沿草叶条一侧边缘平直；车辙两端能接上 |
| 禁止 | 投影、半透明、人物、文字 |
| 与角色匹配 | 最大的草丛不超过角色膝盖高度（约 16px） |
| Godot 使用方式 | 独立精灵，沿 `flat_routes` 路沿和空地按规则散布，不做随机缩放 |
| Tile 还是背景图 | 独立精灵 |

```text
[STYLE PREFIX]
[VIEW-G]
Sprite sheet G02-A of small road-surface decals for a pixel RPG field map, canvas 1536x1024
(384x256 art pixels): grass edge strips that overhang a dirt road (3 horizontal, 3 vertical,
each about 64x16 art pixels, one long edge perfectly straight), 2 cart-rut segments (64x20,
horizontally repeatable), 2 mud puddles, 3 ground cracks, 2 exposed root segments,
2 sets of boot/animal tracks pressed into dirt. Very small, crisp, all the same pixel scale.
[SHEET SUFFIX]
```

```text
[STYLE PREFIX]
[VIEW-G]
Sprite sheet G02-B of small meadow decals for a pixel RPG field map, canvas 1536x1024
(384x256 art pixels): 6 grass tufts (12-32 art pixels wide), 4 kinds of tiny wildflower clusters
(8-16 wide), 5 pebble groups, 3 fallen-leaf piles (one rust red), 2 tall grass clumps.
Very small, crisp, all the same pixel scale.
[SHEET SUFFIX]
```

---

### BS-G03 地表材质斑块（3 张）——打破"两种色调"的关键

| 字段 | 内容 |
|---|---|
| 用途 | L1 层。在草地上铺出不同材质的自然斑块（裸土、枯草、苔地、碎石、落叶地、湿土），做出过渡，让地表读起来像真实地貌 |
| 尺寸 | 每张 C-W：生成 1536×1024，对应 384×256。每张 6 块，每块 96–128 美术像素，3 列 × 2 行 |
| 比例 | 3:2 |
| 像素规范 | 每块不超过 10 色；斑块边缘是**不规则的硬像素锯齿边**，不是渐变，也不是圆形 |
| 视角 | V-G 锁定（见 3.6）：严格垂直向下的正交俯视，地面完全平面 |
| 构图 | 每块是一个形状各异的有机斑块，外部完全透明。形状不重复，不能是圆或椭圆 |
| 颜色 | G03-A：裸土 ×3（土路色组偏暗）+ 枯草 ×3（枯草高光色组）。G03-B：苔地 ×3（苔色组）+ 碎石地 ×3（石色组）。G03-C：落叶地 ×3（含锈红）+ 深色湿土 ×3 |
| 光照 | 很轻，只有表面细节的左上光感 |
| 材质 | 每块内部有 2–3 个明度层，靠团簇表现，不是噪点。边缘有 1–2px 过渡像素，部分延伸成小碎片，像是植被生长到这里才停止 |
| 必须保留 | 外部透明；每块边缘不贴着画布边 |
| 禁止 | 圆形、椭圆形、规则几何形、渐变过渡、噪点、阴影 |
| 与角色匹配 | 一块斑块大约是 1.5–2 个角色身高 |
| Godot 使用方式 | 独立精灵，随机选取，按分区设计（Z1–Z7）散布。每个区域选不同的斑块组合，形成各区的地貌特征 |
| Tile 还是背景图 | 独立精灵（地表覆盖层） |

```text
[STYLE PREFIX]
[VIEW-G]
Sprite sheet G03-A of organic ground-material patches for a pixel RPG field map, canvas 1536x1024
(384x256 art pixels), 3 columns x 2 rows, each patch 96-128 art pixels wide with a ragged, irregular
HARD-PIXEL edge (never a circle or ellipse), transparent outside, no two shapes alike:
3 patches of bare ochre earth with small pebbles, and 3 patches of dry yellow-olive straw grass.
Each patch has two to three value layers built from clusters, no noise.
[SHEET SUFFIX]
```

G03-B 把内容替换为 `3 patches of mossy ground (green moss with a few stones), and 3 patches of gravel and broken stone chips`；G03-C 替换为 `3 patches of fallen-leaf litter (one with rust-red leaves), and 3 patches of dark damp soil with a few tiny wet pebbles`。

---

### BS-T01 大型阔叶树（5 张，每张一棵）

| 字段 | 内容 |
|---|---|
| 用途 | L3 层的主要体量，以及两侧密林边界 |
| 尺寸 | 每张 C-S：生成 1024×1024，对应 256×256。树占画布约 80%：宽 150–200，高 190–240 |
| 比例 | 1:1 |
| 像素规范 | 不超过 24 色；叶簇是成团的像素块，不是逐片叶子 |
| 视角 | V-O 锁定（见 3.6）：只画正面 + 一小条顶面，永不画左右侧面，无透视，所有物件同一角度；能看到树冠顶面、树干正面，树根略显 |
| 构图 | 一棵完整独立的树，居中，树干底部在画布下方 1/8 处。5 张各取不同的剪影（A 圆润，B 偏宽，C 偏高，D 一侧树冠缺一块，E 锈红枫树） |
| 颜色 | A–D 草、苔、石色组（灰绿，不是嫩绿）；E 用锈红色组 |
| 光照 | 树冠左上最亮，右下是冷色暗面；树干根部有接触暗部 |
| 材质 | 叶簇团块有 3 个明度层；树皮竖向纹理；根部有少量苔 |
| 必须保留 | 树干底部完整可见，用来确定原点和碰撞；树冠外轮廓不要贴画布边 |
| 禁止 | 地面投影、草地底座、半透明的叶子边缘、果实、人物 |
| 与角色匹配 | 大树约 220px 高，约 3.5 倍角色身高 |
| Godot 使用方式 | 独立精灵，原点在树干底部中心。碰撞是树干处半径 10–14 的圆，树冠可以遮挡角色（Y 排序） |
| Tile 还是背景图 | 独立精灵 |

```text
[STYLE PREFIX]
[VIEW-O]
One single large broadleaf tree, canvas 1024x1024 (256x256 art pixels), the tree fills about 80% of
the canvas (about 180 art pixels wide, 220 tall). Full rounded canopy built from clustered leaf clumps
in three value layers, sage-to-olive greens, cool shadowed lower-right side, lit upper-left,
a sturdy trunk with root flare, slight moss on the bark, contact darkening at the base.
Transparent background.
Variant A: round, symmetrical canopy.
```

其余 4 张把最后一行替换为：

- B：`Variant B: wider canopy, slightly lopsided, thicker trunk.`
- C：`Variant C: taller, narrower canopy, two visible trunk roots.`
- D：`Variant D: a chunk of the canopy missing on one side where a branch broke, exposing darker inner leaves.`
- E：`Variant E: a rust-red maple tree, same size, orange and rust-red leaf clumps with a few green ones.`

---

### BS-T02 中型树精灵表（2 张）

| 字段 | 内容 |
|---|---|
| 用途 | L3 层。填充密林中层，调节节奏，在碑林、崖门区域提供枯树 |
| 尺寸 | 每张 C-W：生成 1536×1024，对应 384×256。每张 2 棵 |
| 比例 | 3:2 |
| 内容 | **T02-A**：中型阔叶树 ×2，宽 110–140、高 150–190。**T02-B**：枯树 ×2，宽 90–130、高 150–190，枝条扭曲，无叶 |
| 像素规范 | 不超过 24 色 |
| 视角 | V-O 锁定（见 3.6）：只画正面 + 一小条顶面，永不画左右侧面，无透视，所有物件同一角度 |
| 构图 | 2 棵并排，树根在同一条水平线上，间距至少 16 美术像素 |
| 颜色 | T02-A 草、苔色组；T02-B 土路暗色 + 石色组 + 少量苔 |
| 光照 | 左上受光，右下冷暗 |
| 材质 | 叶簇团块；枯树树皮龟裂，枝条尖端细 |
| 必须保留 | 树干底部完整；枯树的树洞和折断处可见 |
| 禁止 | 地面投影、半透明边缘、鸟、人物 |
| 与角色匹配 | 中树 150–190px，约 2.5–3 倍角色身高 |
| Godot 使用方式 | 独立精灵，原点在底部中心，碰撞同 BS-T01 |
| Tile 还是背景图 | 独立精灵 |

```text
[STYLE PREFIX]
[VIEW-O]
Sprite sheet T02-A: 2 medium broadleaf trees (110-140 art pixels wide, 150-190 tall) standing on the
same baseline, clustered leaf clumps, sage-to-olive greens, lit upper-left, visible trunks with root
flare and contact darkening at the base.
[SHEET SUFFIX]
```

```text
[STYLE PREFIX]
[VIEW-O]
Sprite sheet T02-B: 2 bare weathered dead trees (90-130 art pixels wide, 150-190 tall), twisted
branches with fine tips, cracked bark, a hollow in one trunk, tiny moss patches, standing on the same
baseline, lit upper-left.
[SHEET SUFFIX]
```

---

### BS-T03 灌木与蕨类精灵表（2 张）

| 字段 | 内容 |
|---|---|
| 用途 | L3 层。树下与路边的中低层植被 |
| 尺寸 | 每张 C-W。每张 5 件，每件 36–72 美术像素，两行 |
| 内容 | **T03-A**：圆灌木 ×4（其中 1 个带锈红叶）+ 荆棘丛 ×1。**T03-B**：蕨类 ×3 + 高草丛 ×2 |
| 像素规范 | 每张不超过 20 色 |
| 视角 | V-O 锁定（见 3.6）：只画正面 + 一小条顶面，永不画左右侧面，无透视，所有物件同一角度 |
| 颜色 | 草、苔色组；锈红色组只用在 1 个灌木上 |
| 光照 | 左上受光 |
| 材质 | 叶簇团块；蕨类是放射状的羽叶 |
| 必须保留 | 底部轮廓清晰 |
| 禁止 | 地面投影、花、果实、半透明边缘 |
| 与角色匹配 | 灌木 0.6–1.2 倍角色身高 |
| Godot 使用方式 | 独立精灵。高度超过 48 的灌木加小碰撞，其余不加 |
| Tile 还是背景图 | 独立精灵 |

```text
[STYLE PREFIX]
[VIEW-O]
Sprite sheet T03-A: 4 round shrubs (36-72 art pixels, one with rust-red leaves) and 1 bramble thicket,
clustered leaf clumps, lit upper-left, two rows, same pixel scale.
[SHEET SUFFIX]
```

```text
[STYLE PREFIX]
[VIEW-O]
Sprite sheet T03-B: 3 ferns with radiating fronds and 2 tall grass clumps, 36-72 art pixels,
lit upper-left, two rows, same pixel scale.
[SHEET SUFFIX]
```

---

### BS-R01 岩石精灵表（2 张）

| 字段 | 内容 |
|---|---|
| 用途 | L3 层。路边石、怪物空地的点缀、巨石 |
| 尺寸 | 每张 C-W。**R01-A**：小石 ×4（12–24）+ 中石 ×5（32–56），共 9 件。**R01-B**：巨石 ×3（72–110），两件在上一行、一件在下一行 |
| 像素规范 | 每张不超过 16 色 |
| 视角 | V-O 锁定（见 3.6）：只画正面 + 一小条顶面，永不画左右侧面，无透视，所有物件同一角度 |
| 颜色 | 石色组，带苔色组和地衣色点缀 |
| 光照 | 顶面最亮，右下冷暗 |
| 材质 | 风化的棱角、裂纹、苔、地衣 |
| 必须保留 | 底部轮廓清晰 |
| 禁止 | 地面投影、宝石、矿脉发光、半透明 |
| 与角色匹配 | 中石约到角色小腿到膝盖，巨石约 1.2–1.8 倍角色身高 |
| Godot 使用方式 | 独立精灵。中石以上加椭圆碰撞 |
| Tile 还是背景图 | 独立精灵 |

```text
[STYLE PREFIX]
[VIEW-O]
Sprite sheet R01-A of weathered rocks: 4 small stones (12-24 art pixels) and 5 medium rocks
(32-56 art pixels), cool blue-grey stone with moss and pale lichen patches, angular cracked forms,
lit top faces.
[SHEET SUFFIX]
```

```text
[STYLE PREFIX]
[VIEW-O]
Sprite sheet R01-B of 3 large boulders (72-110 art pixels), two in the upper row, one in the lower
row, blue-grey stone, deep cracks, moss on top and in crevices, lichen patches, lit top faces.
[SHEET SUFFIX]
```

---

### BS-L01 断碑与界碑（2 张，地图身份核心）

| 字段 | 内容 |
|---|---|
| 用途 | 地标。巨型断碑立在中坡东侧；其余散布在碑林和碑道 |
| 尺寸 | **L01-A**：C-S，单件巨型断碑，约 160×190（含基座）。**L01-B**：C-W，倒伏碑段 ×3（长 60–100）、中型残碑 ×2（约 40×80）、路碑或石堆路标 ×3（约 24×40） |
| 像素规范 | 每张不超过 20 色 |
| 视角 | V-O 锁定（见 3.6）：只画正面 + 一小条顶面，永不画左右侧面，无透视，所有物件同一角度 |
| 构图 | L01-A：碑斜向断裂，上半截向一侧偏斜但仍立着，基座是切割整齐的石砌平台，前沿平直。L01-B：第一行 3 段倒伏碑，第二行 2 座残碑和 3 个小路标 |
| 颜色 | 石色组为主，苔色点缀；刻痕用暗淡赭金色 #98805d–#b7a079，不发光 |
| 光照 | 左上受光，断面最亮；右下冷暗 |
| 材质 | 风化裂纹、苔藓、深刻的古代符纹带（只有图案，没有可读文字） |
| 必须保留 | 每座碑底边完整；巨型断碑基座前沿平直 |
| 禁止 | 发光符文、可读文字、投影、人物 |
| 与角色匹配 | 巨型断碑约 190px 高，约 3 倍角色身高 |
| Godot 使用方式 | 独立精灵，原点在基座底部中心。矩形碰撞只覆盖基座，上半截碑身可以遮挡角色 |
| Tile 还是背景图 | 独立精灵 |

```text
[STYLE PREFIX]
[VIEW-O]
ONE giant ancient boundary stele snapped diagonally in half, the upper half leaning but still standing,
on a cut-stone plinth with a straight front edge, about 160 art pixels wide and 190 tall in total,
weathered blue-grey stone, moss on the shoulders, carved rune bands in dull ochre-gold (pure pattern,
no readable text, no glow). Canvas 1024x1024 (256x256 art pixels). Transparent background.
```

```text
[STYLE PREFIX]
[VIEW-O]
Sprite sheet L01-B of ancient boundary markers: top row 3 toppled stele segments lying on the ground
(60-100 art pixels long); bottom row 2 medium broken steles (about 40x80) and 3 small wayside
markers / cairns (about 24x40). Weathered blue-grey stone, moss, faint ochre-gold carvings, lit upper-left.
[SHEET SUFFIX]
```

---

### BS-L02 北崖与碑窟石门（3 张）

| 字段 | 内容 |
|---|---|
| 用途 | Z7 崖门。地图北端的边界和出口，对应出口 (480,96)。三块横向拼接：左崖 320 + 石门 320 + 右崖 320 = 960 |
| 尺寸 | **L02-A**：C-W，石门主件 320×170。**L02-B**：C-W，崖壁正面 ×2 变体，各 320×110，上下排列。**L02-C**：C-W，崖顶边缘 ×2 变体（320×60，上下排列）+ 左右端头 ×2（48×170，并排放在右侧） |
| 像素规范 | 每张不超过 20 色 |
| 视角 | V-O 锁定（见 3.6）：崖壁只画正面立面，崖顶露一小条顶面，不画侧面，无透视 |
| 构图 | L02-A：崖壁里凿出的古石拱门，两侧各立一块碑，门前 3 级宽台阶，门洞内部是暗色（无光）。L02-B：分层岩壁，左右边缘能无缝横向拼接。L02-C：崖顶长着草和裸露的树根，下沿有垂下的根须 |
| 颜色 | 石色组偏冷；门洞内部 #1f2422 到 #2f3438；崖顶草 #3e4a35 |
| 光照 | 崖壁整体在阴影里，顶部边缘受光 |
| 材质 | 分层岩壁，裂缝、苔、水渍；门框带浅浮雕符纹 |
| 必须保留 | 门洞宽至少 104、高至少 96；台阶区域可以走上去；L02-B 左右两边的岩层接缝位置一致 |
| 禁止 | 门内透出光、可读文字、投影、人物 |
| 与角色匹配 | 门洞高约 1.6 倍角色身高以上 |
| Godot 使用方式 | 模块化结构精灵。崖壁用多边形碰撞，门洞处留出通行口，对接现有出口触发区 |
| Tile 还是背景图 | 模块化结构精灵，不是整图 |

```text
[STYLE PREFIX]
[VIEW-O]
Pixel RPG map north-edge landmark. An ancient stone archway carved into a layered rock cliff,
320 art pixels wide and 170 tall, flanked by two worn steles, three wide stone steps in front,
a dark empty doorway at least 104 art pixels wide and 96 tall (no light inside), shallow relief carvings
on the door frame, grass and roots on the cliff top. Cool shadowed stone with a lit top rim.
Canvas 1536x1024 (384x256 art pixels). Transparent background.
```

```text
[STYLE PREFIX]
[VIEW-O]
Sprite sheet L02-B: 2 straight layered rock cliff-face strips, each 320x110 art pixels, stacked
vertically, whose left and right edges tile horizontally with identical rock-layer seams. Cracks, moss,
water stains, cool shadowed stone.
[SHEET SUFFIX]
```

```text
[STYLE PREFIX]
[VIEW-O]
Sprite sheet L02-C: 2 cliff-top rim strips (320x60 art pixels, stacked vertically, horizontally tileable)
with grass overhang, exposed roots and hanging root tendrils; plus 2 cliff end caps (48x170) side by
side on the right.
[SHEET SUFFIX]
```

---

### BS-L03 沟壑与桥（2 张，需要你确认是否新增碰撞）

| 字段 | 内容 |
|---|---|
| 用途 | Z2 沟壑，y 约 970–1015。把"修桥"任务做成画面里能看见的东西 |
| 尺寸 | **L03-A**：C-W，沟壑段 ×2（320×80，上下排列，可横向拼接）。**L03-B**：C-W，第一行：主石桥（平桥面，不是拱桥） 136×112 + 木桥（损坏）72×104 + 木桥（修复）72×104；第二行：沟壑端头 ×2（96×80） |
| 像素规范 | 每张不超过 20 色 |
| 视角 | V-G 锁定（见 3.6）：垂直向下的平面图。水沟只露水面和两岸顶面，桥只露桥面和护栏顶面，不画岸壁立面、桥洞、瀑布 |
| 构图 | 沟壑是浅岩石沟，里面有细流和湿石头，两岸有岩石边。主石桥是旧石拱桥，桥面宽至少 96，对着宽 88 的主路。木桥桥面宽约 56，对着宽 60 的环路。**损坏与修复两个状态的外轮廓和桥墩位置必须完全一致**，损坏版是断板加松垂的绳子，修复版是新木板、绑紧的绳子和新木桩 |
| 颜色 | 溪水色组 + 石色组；木头用土路色组；修复版木板略亮 |
| 光照 | 沟里比地面暗两阶 |
| 材质 | 湿润的岩石、苔、木板纹理、粗绳 |
| 必须保留 | 两种木桥状态轮廓一致；桥面中心线垂直 |
| 禁止 | 大面积水体、瀑布、人物、投影 |
| 与角色匹配 | 桥面宽度容纳角色（约 40px 宽）有余 |
| Godot 使用方式 | 模块化精灵。沟壑加碰撞，桥面留出通行口。木桥状态跟随修桥任务旗标切换 |
| Tile 还是背景图 | 模块化结构精灵 |

```text
[STYLE PREFIX]
[VIEW-G]
Sprite sheet L03-A: 2 horizontally tileable shallow rocky gully segments, each 320x80 art pixels,
stacked vertically, with a thin trickle of water at the bottom, wet stones, rocky banks on both edges.
Cooler and darker than normal ground.
[SHEET SUFFIX]
```

```text
[STYLE PREFIX]
[VIEW-G]
Sprite sheet L03-B: top row: 1 old flat-decked stone bridge seen from directly above (parapet tops only, NO arch, NO side view) (136x112 art pixels, deck at least 96 wide),
and the SAME small plank bridge (72x104, deck about 56 wide) in two states: broken (snapped planks,
slack rope) and repaired (fresh planks, tied rope, new posts), identical outline and post positions.
Bottom row: 2 gully end caps (96x80). Wet rock, moss, rope, wood grain.
[SHEET SUFFIX]
```

---

### BS-L04 石坎（1 张，需要你确认是否新增碰撞）

| 字段 | 内容 |
|---|---|
| 用途 | Z5，y 约 540–575。做出"坡"的高差，坡道口在 x 360–470 |
| 尺寸 | C-W。直段 ×2（320×56，上下排列，可横向拼接）；坡道开口件 ×1（128×72）；端头 ×2（64×56） |
| 像素规范 | 不超过 16 色 |
| 视角 | V-O 锁定（见 3.6）：上沿露一小条顶面，正面是石块（正面高度不超过 16 美术像素） |
| 构图 | 低矮干砌石坎，上沿长草，正面露出石块；坡道开口处是土路斜坡，两侧有收口石 |
| 颜色 | 石色组 + 草色组 |
| 光照 | 上沿受光，石坎正面稍暗 |
| 材质 | 干砌石块，缝隙有苔和草 |
| 必须保留 | 直段左右边缘能接上；坡道开口宽度至少 96 |
| 禁止 | 投影、人物、文字 |
| 与角色匹配 | 石坎高度约到角色腰部 |
| Godot 使用方式 | 模块化精灵。直段加碰撞，坡道口可通行 |
| Tile 还是背景图 | 模块化结构精灵 |

```text
[STYLE PREFIX]
[VIEW-O]
Sprite sheet of a low dry-stone terrace ledge: 2 horizontally tileable straight segments (320x56 art
pixels, stacked, grass overhanging the top, stone faces visible), 1 ramp opening (128x72) where a dirt
road climbs through with two finishing stones at the sides, 2 end caps (64x56). Lit top edge,
darker stone face, moss in the joints.
[SHEET SUFFIX]
```

---

### BS-C01 营地组件（1 张）

| 字段 | 内容 |
|---|---|
| 用途 | Z3 营地广场 (475,930)，同时替换现有那张高清缩小的交易摊位图 |
| 尺寸 | C-W。第一行：帐篷 112×96、交易摊位 120×110、营地旗杆 32×80。第二行：营火 4 帧动画（每帧 40×40，横向排列）、补给箱和桶 ×4（24–40）、木凳 ×1（48×24） |
| 像素规范 | 不超过 24 色 |
| 视角 | V-O 锁定（见 3.6）：只画正面 + 一小条顶面，永不画左右侧面，无透视，所有物件同一角度 |
| 颜色 | 土路色组 + 锈红（帐篷布、旗）；火焰用火光色组 |
| 光照 | 左上受光；营火周围有一圈暖色反光 |
| 材质 | 粗帆布、木桩、旧木箱、麻绳 |
| 必须保留 | 营火 4 帧的柴堆完全一致，只有火焰变化；摊位正面留空，可以放交互标签 |
| 禁止 | 人物、可读文字、投影 |
| 与角色匹配 | 帐篷约 1.6 倍角色身高 |
| Godot 使用方式 | 独立精灵。营火用 AnimatedSprite2D，帐篷和摊位加碰撞 |
| Tile 还是背景图 | 独立精灵 |

```text
[STYLE PREFIX]
[VIEW-O]
Sprite sheet of a small expedition roadside camp. Top row: 1 canvas tent (112x96 art pixels),
1 trader's stall with an awning and goods (120x110), 1 banner pole with a rust-red cloth (32x80).
Bottom row: a campfire in 4 animation frames (40x40 each, identical log pile, only the flames change),
4 supply crates and barrels (24-40), 1 log bench (48x24). Lit upper-left, warm firelight near the fire.
[SHEET SUFFIX]
```

---

### BS-Q01 任务与交互道具（1 张）

| 字段 | 内容 |
|---|---|
| 用途 | 统一像素密度，替换现在严重缩小的旧道具图（路牌原图 1254px 被画成 96px） |
| 尺寸 | C-W。第一行：盐车 96×80、路牌 40×72、巡逻路标桩 24×64、系绳木桩 32×56。第二行：宝箱（关）40×36、宝箱（开）40×36、兽迹贴花 40×24、断裂的车轮 40×40、插在地上的断矛 24×56 |
| 像素规范 | 不超过 24 色 |
| 视角 | V-O 锁定（见 3.6）：只画正面 + 一小条顶面，永不画左右侧面，无透视，所有物件同一角度 |
| 颜色 | 土路色组 + 石色组 + 少量锈红 |
| 光照 | 左上 |
| 材质 | 旧木、铁箍、麻绳、泥 |
| 必须保留 | 宝箱开、关两种状态的轮廓一致；路牌牌面空白 |
| 禁止 | 文字（牌面保持空白，文字由游戏生成）、人物、投影 |
| 与角色匹配 | 路牌约 1.2 倍角色身高 |
| Godot 使用方式 | 替换现有 entity 的贴图（`art` 字段对应：tracks、trade_stall、rope、salt_cart、post），不改交互逻辑 |
| Tile 还是背景图 | 独立精灵 |

```text
[STYLE PREFIX]
[VIEW-O]
Sprite sheet of interactive field props. Top row: a small two-wheeled salt cart (96x80 art pixels),
a wooden signpost with two BLANK arrow boards (40x72), a patrol marker post (24x64), a rope-tie post (32x56).
Bottom row: a treasure chest closed and open (40x36 each, identical outline), beast footprints pressed
into mud (ground decal, 40x24), a broken wagon wheel (40x40), a snapped spear stuck in the ground (24x56).
Aged wood, iron bands, rope, mud. No text.
[SHEET SUFFIX]
```

---

### BS-F01 前景层（3 张）

| 字段 | 内容 |
|---|---|
| 用途 | L4 层。画面边缘的景深，盖住地图边界 |
| 尺寸 | **F01-A**：C-W，角落树冠 ×1（320×220）。**F01-B**：C-W，侧边垂枝 ×2（200×112，上下排列）+ 底部前景草叶条 ×2（160×48，上下排列，放在右侧，可横向拼接）。**F01-C**：C-W，另一个角落树冠 ×1（320×220），形状与 A 不同 |
| 像素规范 | 不超过 20 色 |
| 视角 | V-O 锁定（见 3.6）：只画正面 + 一小条顶面，永不画左右侧面，无透视，所有物件同一角度 |
| 颜色 | 比场景同色组暗一阶 |
| 光照 | 整体偏暗，只有很弱的左上受光 |
| 材质 | 叶簇团块，叶尖下垂 |
| 必须保留 | 外侧边缘平直、贴住画布边缘；向内一侧是自然的叶片轮廓；草叶条左右可拼接 |
| 禁止 | 投影、半透明边缘、人物 |
| 与角色匹配 | 比场景整体大一些，因为离镜头更近 |
| Godot 使用方式 | z=8。玩家走进覆盖区域时整体变半透明。右上角用 F01-A，左上角用 F01-C，需要时可水平翻转 |
| Tile 还是背景图 | 独立精灵 |

```text
[STYLE PREFIX]
[VIEW-O]
A corner canopy overhang seen close to the camera, 320x220 art pixels, one value darker than the scene,
clustered leaf clumps with drooping leaf tips, outer top and side edges perfectly straight and flush
with the canvas edge, inner edge a natural leaf silhouette. Canvas 1536x1024 (384x256 art pixels).
Transparent background.
```

```text
[STYLE PREFIX]
[VIEW-O]
Sprite sheet F01-B of foreground framing foliage: 2 hanging branch clusters (200x112 art pixels,
stacked vertically) on the left, and 2 horizontally tileable foreground grass-blade strips
(160x48, stacked vertically) on the right. One value darker than the scene.
[SHEET SUFFIX]
```

F01-C 与 F01-A 提示词相同，在末尾加一句：`Make the silhouette different from the first: a denser canopy with one long hanging branch.`

---

### BS-E01 特效小精灵（1 张）

| 字段 | 内容 |
|---|---|
| 用途 | L5 层。让空气"活"起来，不抢眼 |
| 尺寸 | C-W。落叶 4 个旋转帧（6×6，绿色版和锈红版各一组，共 8 个）；尘点 2–3px ×4；萤火 2 帧（3px）；低雾带 1 条（320×48，只允许两档透明） |
| 像素规范 | 不超过 12 色 |
| 视角 | V-O 锁定（见 3.6）：只画正面 + 一小条顶面，永不画左右侧面，无透视，所有物件同一角度 |
| 颜色 | 叶：草色组、锈红色组。尘点：枯草高光。萤火：火光色组。雾：#868b86 与 #a9aca2 |
| 光照 | 无 |
| 必须保留 | 雾带只有两档透明度，左右两端渐淡并能无缝接上 |
| 禁止 | 辉光、发光、半透明的多档渐变（雾带除外） |
| 与角色匹配 | 落叶比角色手掌略小 |
| Godot 使用方式 | 作为 GPUParticles2D 的贴图，运动用代码实现；雾带用 Sprite2D 慢速横向滚动 |
| Tile 还是背景图 | 独立精灵 |

```text
[STYLE PREFIX]
[VIEW-O]
Sprite sheet of tiny ambient effect sprites: a falling leaf in 4 rotation frames at 6x6 art pixels
(a green set and a rust-red set), 4 tiny dust motes (2-3 px), a firefly in 2 frames (3 px),
and one horizontal low mist strip (320x48 art pixels) using only two transparency levels,
softly thinning at both ends and horizontally tileable.
[SHEET SUFFIX]
```

---

## 6. 生成顺序与交付命名

### 6.1 建议顺序

| 批次 | 内容 | 目的 |
|---|---|---|
| P0 | BS-00 | 先确定风格。**满意以后再继续**，之后每次生成都附上 BS-00 作为风格参考 |
| P1 | BS-G01 ×4、BS-G03 ×3、BS-G02 ×2 | 地表是整张图的底子，先验证"没有两色调感" |
| P2 | BS-T01 ×5、BS-T02 ×2、BS-T03 ×2、BS-R01 ×2 | 自然物件 |
| P3 | BS-L01、BS-L02、BS-L03、BS-L04 | 地标与地形 |
| P4 | BS-C01、BS-Q01、BS-F01、BS-E01 | 营地、任务道具、前景与特效 |

每批做完可以先发给我。我先做一遍网格检测和量化，有问题当场反馈，不要等 35 张全部做完。

### 6.2 文件命名

放到同一个文件夹，原始 PNG，不要截图、不要压缩成 JPG：

```text
bs00_style_sample.png
bs_g01_a_grass.png        bs_g01_b_dirtroad.png     bs_g01_c_gravel.png      bs_g01_d_flagstone.png
bs_g02_a_roadside.png     bs_g02_b_meadow.png
bs_g03_a_earth_straw.png  bs_g03_b_moss_gravel.png  bs_g03_c_leaf_damp.png
bs_t01_a.png ... bs_t01_e_maple.png
bs_t02_a_broadleaf.png    bs_t02_b_dead.png
bs_t03_a_shrubs.png       bs_t03_b_ferns.png
bs_r01_a_small_medium.png bs_r01_b_boulders.png
bs_l01_a_giant_stele.png  bs_l01_b_markers.png
bs_l02_a_gate.png         bs_l02_b_cliff_face.png   bs_l02_c_cliff_rim.png
bs_l03_a_gully.png        bs_l03_b_bridges.png
bs_l04_terrace.png
bs_c01_camp.png
bs_q01_props.png
bs_f01_a_canopy.png       bs_f01_b_branches_grass.png   bs_f01_c_canopy.png
bs_e01_fx.png
```

### 6.3 摆放位置（第三阶段使用）

| 素材 | 在地图上的位置 |
|---|---|
| 北崖 / 石门 | 左崖 x 0–320 / 石门 x 320–640 / 右崖 x 640–960，底边约 y 170，出口 (480,96) 在门洞内 |
| 巨型断碑 | 东环岛中心，约 (560,790) |
| 石坎 | y 约 540–575，x 360–470 留坡道口 |
| 沟壑 | y 约 970–1015；主石桥 x 430–530；西木桥 (245,990)；东木桥 (710,990) |
| 营地 | 摊位 (475,930)；帐篷、营火、补给箱在周围 |
| 路牌 | 出生点附近 (480,1040) 侧边 |
| 巡逻路标 | (410,790) 和 (480,790) |
| 兽迹贴花 | (680,480)、(255,950)、(390,935)、(570,690) |
| 迷失之兽巢穴 | 西南 (140,880) 附近放碎石、骨头痕迹、拨开的灌木 |
| 怪物空地 | (160,405)、(790,420)、(200,710)、(760,760)、(335,860) 周围 60–100px 内不放大型物件 |
| 前景 | 左上角 F01-C，右上角 F01-A，侧边垂枝在中段两侧 |

---

## 7. 交付前自查清单

1. 画布尺寸正好是 1024×1024、1536×1024 或 1024×1536。
2. 保存为 PNG，而不是 JPG。
3. 背景是透明的；如果没有透明，是纯 #FF00FF，没有渐变、没有阴影。
4. 同一张图里像素块大小一致，没有出现一部分粗一部分细。
5. 没有人物、怪物、文字、UI、水印。
6. 边缘硬朗，没有柔化的半透明边。
7. 无缝材质四边接得上（把图拼成 2×2 看一眼）。
8. 精灵表里的每件素材完整、没被画布边裁掉，之间有空白。
9. 光源在左上，没有被画上地面投影。
10. 颜色整体是克制的灰绿和赭土，没有霓虹绿或大红。
11. **视角检查（最容易出问题）**，下面任何一条出现都要重做：
    - 地面有没有"远处小、近处大"的感觉？有没有地平线或雾？
    - 有没有崖壁立面、台地侧面、瀑布、桥洞？（地面图和水沟图里应该一个都没有）
    - 物件的左右侧面有没有被画出来？（碑、石、建筑只能有正面和顶面）
    - 树是不是"一团圆形树冠 + 短树干"？有没有画成侧视的大树，或连成一整片树冠海？
    - 竖线是否垂直、横线是否水平？物件在画面不同位置时角度一致吗？
    - 整体像不像"游戏截图的一块"，而不是"一幅斜着往下望的风景画"？
12. 想象人物（60px 高）站在图里，大小是否合理，且在画面各处大小一致。

### 常见失败与补救句

| 现象 | 加在提示词末尾的补救句 |
|---|---|
| 像素大小不一致 | `Every art pixel must be a perfectly uniform 4x4 block. No detail finer than one pixel block.` |
| 出现渐变、柔边 | `Hard pixel edges only. No anti-aliasing, no gradients, no soft shading, no blur.` |
| 颜色太饱和 | `Desaturate by 30 percent. Muted, weathered, dusty colors only.` |
| 出现地面投影 | `Do not draw any cast shadow on the ground. Only a small dark contact area at the very base.` |
| 草地像噪点 | `Build the grass from deliberate tuft clusters of 3 to 6 pixels, not scattered single noisy pixels.` |
| 背景不透明 | `Background must be completely transparent. If impossible, use flat solid #FF00FF.` |
| 构图太满 | `Leave at least 16 art pixels of empty space between every item and the canvas edge.` |
| 材质过渡像渐变 | `The transition between materials must be a ragged hard-edged pixel boundary with small isolated fragments, not a smooth blend.` |
| 画面像斜视风景画（有景深、透视） | `This is a flat 2D game-map tile, not a landscape painting. Orthographic camera, no perspective, no depth shrinking, no horizon, no atmospheric haze. Every object has the same scale everywhere in the image.` |
| 出现崖壁、台地、瀑布 | `Absolutely no cliffs, no vertical rock walls, no raised terraces, no waterfalls. The ground is one flat plane; show water only as a flat surface seen from straight above.` |
| 桥画成侧视拱桥 | `The bridge is a flat deck seen from directly above: only the deck and the tops of the parapet walls are visible. No arch, no bridge opening, no side view.` |
| 物件显示左右侧面（2.5D / 等距） | `Show only the front face and a thin top face of every object. Never draw the left or right side. No isometric, no 2.5D cube look.` |
| 树连成一片、像从高处俯瞰森林 | `Trees are separate individual objects with gaps of meadow between them. Each tree is a round canopy mass with a short visible trunk beneath. Not a continuous forest roof.` |
| 树画成侧视的高大树木 | `Draw each tree as a rounded canopy blob seen from slightly above with only a short trunk stub visible below it. The canopy is wider than the trunk is tall.` |

---

## 8. 本文档的边界（诚实说明）

- 没有运行游戏，所有项目结论来自读文件和量图：`project.godot`、`data/main_world_maps.json`、`src/explore/MapScene.gd`、角色序列帧的透明度包围盒、现有截图。
- 素材尺寸是按 4:1 的生成约定推算的。GPT 无法保证真正的像素网格，所以第三阶段的重新像素化是必须步骤，它会有一定损失，我会把每件的实际结果反馈给你。
- 第一张 BS-00 样张实测：1024×1536，共 144,159 种颜色；横向 96.3% 的相邻像素段长度只有 1；4 像素周期的网格信号很弱（只比平均高约 10%）。结论：看起来是像素风，但并没有真正的 4×4 网格，也远超 40 色的目标。样张只能当风格参考，不能直接当素材，真正的素材需要重新像素化、量化到统一色板后才能入库。
- 视角锁定（3.6）是对第一张样张"斜视风景画"问题的针对性修正。它能降低概率，不能保证每次都生成对，所以自查清单第 11 条要逐张检查。如果同一类素材连续两次视角仍然不对，请把错的那张发给我，我再调整提示词，而不是继续盲目重抽。
- 石坎（BS-L04）和沟壑（BS-L03）会改变可走区域，需要你确认。
- 没有确认的内容：lorin_wilds / maple_road 另一条管线的细节、`ReferenceTerrain` 是否被实例化、运行时是否会出现镜头抖动。后者要等第三阶段开启像素对齐后才能验证。
- 角色素材不在这一轮改动范围内。角色是 128px 高清缩小到 0.54，颗粒比地图细。建议在第四阶段评分时一起评估，是否需要开启 `snap_2d_transforms_to_pixel` 或调整镜头缩放。
