# 潮痕滩（tideflat）样板地图：生图需求文档

> 项目：`D:\new-bee\远征`（Godot 4.7，480×800 竖屏，Nearest 过滤）
> 日期：2026-10-12
> 背景：真实运行普查发现 11 张地图的地面图（`*_ground_v4.png`）是开发用的灰盒（网格 + 彩色路线条），潮痕滩是玩家遇到的第一张、也是任务最多的一张（20 个任务点），选它做新样板。
> 做法（已确认）：**地面 = 一整张手绘图**；会挡路、要 Y 排序遮挡的物件 = 独立精灵 + 碰撞。

---

## 0. 怎么用

1. 生成地面（第 3 节）时，同时附上两张图：
   - 布局参考：`_review/tideflat/tideflat_guide_gpt.png`（色块图，决定"东西画在哪"）
   - 风格参考：`_review/tideflat/style_ref_old_salt_road.png`（游戏里已有的旧盐道地面，决定"画成什么样"）
2. 核对位置用 `_review/tideflat/tideflat_guide_annotated.png`（带出生点、出口、怪物、Boss、任务点标注，960×1248 = 游戏世界像素）。
3. 原始 PNG 直接放进 `outputs/tideflat_assets_20261012/`，不要截图、不要转 JPG。

---

## 1. 这张图要变成什么样

**世界观**：沉渊港东侧的退潮滩涂。潮水每天两次漫过，退下后露出湿沙、潮池、盐壳和搁浅的漂木。北端是古老的退潮水闸石堤，堤中间的闸门通向"退潮水闸"（剧情 s18 后开放）。东边是开阔的海，西边连回沉渊港的栈道。

**氛围**：海边的开阔、潮湿、略带冷意；退潮后的寂静。和旧盐道同一个世界、同一种画工，但更湿、更冷、更亮。

**色彩**（参考，整体落在这个范围即可）：

| 色组 | 色值 |
|---|---|
| 湿沙（主体） | #8d8a72 #a3a084 #b9b597 #cfc9a8 |
| 干沙 / 沙丘 | #c9b98e #dccb9c #e8dcb5 |
| 潮池 / 浅水 | #2f5a5c #3f7472 #5f9590 #9cc3bb |
| 深海 | #1f3d4a #2a5160 #3a6b78 |
| 浪花 / 盐壳 | #d9e2d6 #eef0e6 |
| 海草 / 滩草 | #4f6447 #6b7d55 #8b9866 |
| 湿木 / 漂木 | #3e3429 #5a4a38 #7d6a50 |
| 堤石 | #4a4f52 #646a6b #858a86 #a7aaa2 |

光源在左上，柔和的阴天海边光。不要霓虹蓝绿，不要纯黑纯白。

---

## 2. 布局（坐标 = 游戏世界像素，地图 960×1248）

| 区 | 位置 | 内容 |
|---|---|---|
| 北堤 | y 0–140 | 横贯的古石水闸堤，**中间 x 420–540 是闸门豁口**（出口 north_gate 在 (480,96)）。堤上有石块、铁环、海藻痕 |
| 东海 | x 860–960 全高 | 开阔的深海，x 836–860 是浪花带。**整条是碰撞区** |
| 西口 | (90,700) | 通往沉渊港的栈道入口（出口 west_port），地面接一段木板栈道 |
| 出生点 | (165,700) | 栈道下来的第一片空地，保持干净 |
| 主路 | 宽 92 | (90,700)→(165,700)→(245,720)→(320,730)→(480,650)→(510,470)→(455,270)→(480,185)→(480,96) |
| 南支路 | 宽 80 | (480,650)→(455,850)→(480,1060) |
| 西北环 | 宽 62 | (245,720)→(305,585)→(425,565)→(510,470) |
| 西南环 | 宽 60 | (320,730)→(295,830)→(350,900)→(455,850) |
| 潮池 ×5 | 见布局图 | 最大的一个在 (300,495)，是钓鱼点"潮池浅滩"(310,560) 的水面 |
| 盐壳滩 | 中心 (270,1000) | 迷失之兽同级的可选 Boss"盐鳞王"的巢穴，一大片发白的盐壳硬地 |
| 南沙丘 | y 1170–1248 | 干沙和滩草，地图南缘 |
| 西侧滩草 | (60,440)、(70,1080) | 两片滩草地，做西边的自然边界 |

**道路的画法**：潮痕滩的"路"不是土路，是**被反复踩实的湿沙小径**，颜色比周围湿沙略暗、略平整，边缘有少量贝壳碎和脚印，可以有一两处木板或踏石。路面必须清楚可读，但不要画成黄土路。

**必须保持空旷的地方**（游戏会在这里放怪物、任务物件、交互标签）：

- 4 个怪物点 (550,525)、(600,655)、(330,900)、(610,945) 周围约 40px
- Boss 点 (270,1000) 周围约 56px
- 出生点、两个出口
- 路面本身

这些地方地面可以有纹理，但不能画石头、木桩、船、网之类的立体物件。

---

## 3. TF-G01 地面整图（核心，1 张）

| 字段 | 内容 |
|---|---|
| 用途 | 潮痕滩的完整地面，替换灰盒 `tideflat_ground_v4.png` |
| 尺寸 | 生成 **1024×1536**（竖版）。地图区域是 y 102–1433；上下两条是延伸带，后期裁掉 |
| 后期 | 裁出 1024×1331 → 缩到 960×1248（×0.9375），游戏里 1:1 绘制 |
| 像素规范 | 和风格参考图同一种画工：细致的像素风，统一颗粒，硬边，无模糊 |
| 视角 | 严格垂直俯视的平面地图（见下方视角块）。北堤只画顶面和一条很窄的正立面 |
| 构图 | 严格按布局参考图的位置：路、潮池、盐壳、海、北堤、豁口。**不要复制色块的颜色和平涂效果** |
| 必须保留 | 路面清楚；第 2 节的空旷区域没有立体物件；东海边界和北堤豁口位置准确 |
| 禁止 | 人物、怪物、文字、UI、船、树、高大立体物件（这些另做精灵）、网格线、透视 |
| 与角色匹配 | 角色约 60px 高、路宽 92。贝壳、小石子 4–12px，潮池 70–190px 宽 |
| Godot 用法 | 替换 `background`，TextureRect 1:1，z -20；海和北堤用 `block_rects` 加碰撞 |
| 类型 | 背景整图（只含地面） |

```text
Original 2D pixel art game background for a flat top-down fantasy expedition RPG field map (mobile, portrait), canvas 1024x1536.
Match the pixel-art craft, detail density and painting quality of the attached STYLE reference (an existing map from the same game). Follow the attached LAYOUT reference exactly for WHERE things are, but do NOT copy its flat colours or blocky shapes: it is only a colour-coded plan.
Layout legend: brown bands = paths, sand colour = wet tidal sand, teal ovals = shallow tide pools, white ovals = salt crust, olive = beach grass and dunes, dark blue strip on the right = open sea, thin pale strip = surf line, grey bands at the top = ancient stone sluice embankment, black square in its gap = the sluice gateway.

SCENE: a tidal flat at low tide beside a harbour. Wet, slightly glossy sand with subtle ripple marks and tide lines, scattered shells, small pebbles and strands of seaweed. Shallow tide pools with clear teal water, wet dark rims and a few small stones. A large patch of cracked white salt crust in the lower-left. Paths are compacted trails of darker, smoother wet sand with faint footprints and shell bits at the edges (not dirt roads), clearly readable. On the right, the open sea with gentle surf foam along the shore. Across the top, an old weathered stone sluice embankment with iron rings and seaweed stains, with a gap in the middle where the path enters a dark gateway. Dry sand and beach grass along the bottom edge and two grassy patches on the left edge. On the left at mid-height the path ends at the start of a wooden boardwalk.

CAMERA: strictly orthographic, looking straight down at 90 degrees, like a flat 2D game map. The ground is one flat plane. No horizon, no perspective, no depth shrinking, no tilt, no haze. The embankment shows only its top surface and a very thin front face.
Muted, cool, overcast seaside palette: grey-olive wet sand, teal pools, slate-blue sea, off-white salt. Light from the upper-left.
NO text, NO UI, NO people, NO creatures, NO boats, NO trees, NO tall objects, NO grid lines, NO watermark, NO photorealism, NO blur, NO glow. Keep the open areas calm, with fine detail in small clusters rather than spread evenly.
```

---

## 4. 物件精灵（立体、会挡路或需要遮挡的东西）

画法和断碑坡素材一致：**正面 + 一小条顶面，永不画左右侧面**；品红 #FF00FF 或透明底；每件之间留空。尺寸是游戏世界像素（我后期统一缩放）。

| 编号 | 内容 | 目标尺寸 | 用途 |
|---|---|---|---|
| TF-P01 | 搁浅的旧渔船（倾斜躺在沙上）×1、小划艇 ×1 | 170×90 / 90×50 | 地标，放东南沙地，带碰撞 |
| TF-P02 | 漂木：大段 ×2、小段 ×3 | 60–120 宽 | 漂木任务（driftwood）的视觉，带碰撞 |
| TF-P03 | 潮位标尺木桩 ×2、断木桩群 ×3、系船柱 ×2 | 24×64 / 40×40 | 原 TideflatGround 程序画的标尺换成精灵 |
| TF-P04 | 渔网晾架 ×1、捕蟹笼 ×2、货箱（潮印货物）×1、木桶 ×2 | 90×70 / 30 / 48 / 28 | 任务点 tide_cargo (410,700) 周边 |
| TF-P05 | 礁石：大 ×2、中 ×4、小 ×4（带藤壶和海藻） | 100 / 44 / 18 | 散布与边界 |
| TF-P06 | 滩草丛 ×4、海蓬子（红紫色小肉质草）×3 | 24–48 | 点缀 |
| TF-P07 | 西口木栈道起点段 ×1（栈道 + 两根桩） | 140×96 | 出口 west_port (90,700) |
| TF-P08 | 潮池水面动画 4 帧（只有高光和涟漪变化）、浪花 4 帧（可横向拼接 160 宽） | 160×60 / 160×24 | 让水活起来 |

### 精灵通用提示词

每张都用这段开头，再接具体内容：

```text
Original 2D pixel art sprite sheet for a flat top-down fantasy expedition RPG field map, matching the pixel-art craft of the attached STYLE reference.
Classic 16-bit RPG overworld sprite convention: one fixed camera angle for every object, show only the FRONT face and a thin TOP face, never a left or right side face, no perspective, vertical edges vertical. Each object stands on a flat baseline.
Muted, cool, overcast seaside palette. Light from the upper-left.
Isolated assets on a flat pure #FF00FF background (no gradients, no shadows on the background), every asset separated by at least 64 px of empty space, all at the same pixel scale, each complete and uncropped. No cast shadows on the ground, only a small dark contact area at the base.
NO text, NO UI, NO people, NO creatures, NO watermark, NO blur, NO glow.
```

| 编号 | 接在后面的内容 |
|---|---|
| TF-P01 | `An old wooden fishing boat beached on its side on wet sand, weathered planks, a broken mast stub, seaweed on the hull; and a small rowing boat upside down.` |
| TF-P02 | `Driftwood: 2 large bleached tree trunks with roots, 3 small driftwood pieces, barnacles and seaweed.` |
| TF-P03 | `2 tide-gauge posts with painted level marks (no numbers, no text), 3 clusters of broken wooden piles, 2 iron-capped mooring bollards.` |
| TF-P04 | `A wooden net-drying rack with a fishing net, 2 crab pots, 1 sealed cargo crate with a wax tide seal, 2 small barrels.` |
| TF-P05 | `Coastal rocks with barnacles and seaweed: 2 large, 4 medium, 4 small.` |
| TF-P06 | `4 clumps of coastal beach grass, 3 clumps of red-purple glasswort (samphire).` |
| TF-P07 | `The landward end of a wooden harbour boardwalk: weathered planks on two posts, ending on wet sand.` |
| TF-P08 | `Top row: a shallow tide pool water surface in 4 animation frames (identical outline, only highlights and ripples change). Bottom row: a horizontally tileable surf foam strip in 4 animation frames.` |

---

## 5. 交付前自查

1. 地面图是 1024×1536 PNG；位置和布局参考图一致（路、潮池、盐壳、北堤豁口、东海）。
2. 地面图里没有船、树、高大物件；怪物点、Boss 点、出生点、出口附近是平地。
3. 地面颜色是灰橄榄湿沙 + 青色潮池，不是黄土；路是踩实的湿沙小径，清楚可读。
4. 俯视平面，没有地平线、透视、雾。
5. 精灵只有正面 + 顶面，品红底干净，每件之间有空。

**常见补救句**

| 问题 | 加在提示词末尾 |
|---|---|
| 位置跑偏 | `Place every element exactly where the layout reference shows it. Do not move the paths, pools, sea edge or the gap in the embankment.` |
| 照抄色块平涂 | `The layout reference is only a plan. Paint real wet sand, water and stone textures; never flat colour shapes.` |
| 路画成黄土路 | `Paths are compacted wet-sand trails, only slightly darker and smoother than the surrounding sand. Not dirt roads.` |
| 出现透视或斜视 | `This is a flat 2D game map seen straight from above. No perspective, no horizon, no depth.` |
| 画面太满 | `Keep large calm areas of plain wet sand. Fine details only in small occasional clusters.` |

---

## 6. 我这边接入时会做的事

- 裁切、缩放到 960×1248，检查路面和 `flat_routes` 是否对齐（偏差超过 16px 我会反馈）。
- 关掉潮痕滩的程序叠加层（TideflatGround 的圆形水池和标尺），关掉随机散件和重复的道具层。
- 新增 `block_rects`：北堤两段 + 东海。
- 放置精灵和碰撞，替换道具贴图；小地图改为由地面图生成。
- 在 Godot 里真实运行截图，和改造前逐视角对比，按 100 分制评分。

## 7. 2026-10-12 生图前坐标复核

- 已读取当前完整地图配置及 `MapScene.gd`、`TideflatGround.gd`、`SecondaryMapEnhancer.gd`、`ReturnJourneyProps.gd`。地图为 20×26 格，每格 48px；四条 `flat_routes`、出生点、两个出口、4 个怪物点、Boss 和 20 个实体坐标与第 2 节一致。
- 北堤实体两段的准确范围以设计文件为准：`[0,0,410,140]` 与 `[550,0,410,140]`，可走开口为 x=410–550；x=420–540 是开口内的视觉闸口。东海碰撞建议为 `[860,0,100,1248]`，浪花带 x=836–860 在其西侧。当前游戏配置尚没有这些 `block_rects`，属于后续接入改动。
- 北侧进入本图的到达点 `(480,200)` 同样需要保持可走、无立体遮挡。
- GPT 参考图已按统一比例 1024/960 绘制；地图实际绘制区域为 `(0,102,1024,1433)`，采用右/下边界不包含的裁切约定，裁出 1024×1331。顶部 102 行、底部 103 行全部为单一地面色，没有首尾像素拉长。整数像素舍入最多产生不足 1px 的边界误差，不会造成约 13% 的压扁。
- 现有标注版的黄色点是 20 个实体点。道路直接从当前配置读取；潮池、盐壳、北堤、东海属于 `tideflat_design.json` 的新美术布局，不是程序水池坐标的复制。旧程序水池原有 6 个，接入新图应关闭。
- 接入还需检查 SecondaryFloorDepth（含沙地纹理）、SecondarySceneryLayer（7 个潮滩装饰）、随机散件与任务完成后的 ReturnJourneyProps；任务状态道具需保留功能并避免重复绘制。
- 此轮只生成参考图和素材，不改游戏代码。透明精灵保留真实 alpha；TF-P08 按 4 列×2 行交付源图，动画一致性仍需单独核对。实际调用提示词保存在输出目录 `generation_prompts.json`。
