# 断碑坡（broken_slope）v3 重做：生图需求

> 日期：2026-10-12
> 原因：现有断碑坡背景是斜视透视画法（像 3D），拱门、碑、崖都画在背景里且没有碰撞，角色会穿过去。
> 做法：和潮痕滩一样。**地面 = 一张严格俯视的平面图**；碑、树、营地、木桥等立体物件 = 独立精灵 + 碰撞。
> 本轮只需要生成 **1 张地面图**。立体物件优先复用第一轮已生成的断碑坡素材（`outputs/broken_slope_assets_20261012/`），我负责切图、缩放、配碰撞。

---

## 1. 附图

生成时同时附上：

| 图 | 作用 |
|---|---|
| `_review/broken_slope_v3/broken_slope_guide_gpt.png` | 布局参考（纯色块，无文字），决定东西画在哪 |
| `_review/broken_slope_v3/style_ref_tideflat.png` | 风格参考：已验收的潮痕滩地面，决定画工和视角 |

核对位置用 `_review/broken_slope_v3/broken_slope_guide_annotated.png`（960×1248，标了出生点、出口、5 个怪物点、Boss、任务点）。

## 2. 布局图色块含义

| 色块 | 画成 |
|---|---|
| 橄榄绿底 | 林间坡地草地 |
| 棕色带 | 踩实的土路（主路宽 88，环路宽 60） |
| 灰色带（顶部） | 北崖：只画崖顶和一条很窄的正立面 |
| 黑色方块（顶部中间） | 碑窟石门的暗色门洞 |
| 深青色带（下部） | 横贯的浅沟：只见水面和两岸顶面。**三个缺口是渡口**（x≈245 / 480 / 710），画成平的踏石浅滩或碎石路面 |
| 灰色椭圆 | 风化的旧石板铺地（碑林前庭、中坡碑台、营地空地） |
| 浅蓝灰椭圆（左下） | 迷失之兽的巢穴：被践踏的秃土、抓痕、碎骨、倒伏的草 |

**必须留空**（不画石头、树、碑等立体物件）：5 个怪物点 (160,405) (790,420) (200,710) (760,760) (335,860)、Boss 点 (140,880)、出生点 (480,1040)、两个出口、路面本身。

## 3. BS3-G01 地面整图

| 字段 | 内容 |
|---|---|
| 尺寸 | 生成 **1024×1536**；地图区域 y 102–1433，上下两条延伸带会被裁掉 |
| 后期 | 裁 1024×1331 → 缩到 960×1248，游戏里 1:1 绘制 |
| 视角 | **严格垂直俯视的平面图**。没有地平线、没有透视、没有远近大小差、没有斜坡侧面。北崖只露顶面和极窄正立面 |
| 不画 | 树、碑、帐篷、桥、拱门立柱、人物、怪物、文字（这些都是独立精灵） |
| 与角色匹配 | 角色约 60px 高；草簇、小石 4–14px |
| 颜色 | 低饱和鼠尾草绿和橄榄绿、赭色土路、冷蓝灰石、南端少量锈红落叶 |

```text
Original 2D pixel art game background for a flat top-down fantasy expedition RPG field map (mobile, portrait), canvas 1024x1536.
Match the pixel-art craft, detail density, camera angle and painting quality of the attached STYLE reference (a finished map from the same game). Follow the attached LAYOUT reference exactly for WHERE things are, but do NOT copy its flat colours or blocky shapes: it is only a colour-coded plan.
Layout legend: olive = meadow ground on a forest slope, brown bands = packed dirt paths, grey bands at the top = the top of a rock cliff, black square in the cliff gap = a dark cavern doorway, dark teal strips = a shallow rocky stream gully crossing the map (the three gaps in it are flat stepping-stone fords), grey ovals = old weathered flagstone paving, pale blue-grey oval on the lower left = a trampled beast lair.

SCENE: a weathered frontier slope where ancient boundary stones once stood. Meadow grass in three value layers built from tuft clusters, patches of bare earth, moss and fallen leaves. Packed ochre dirt paths with a crisp dark edge, grass blades overhanging, a paler worn centre and faint cart ruts. Old cracked flagstone paving at the three grey ovals. Across the lower part, a narrow shallow stream drawn flat from straight above: clear water surface, wet stones, grassy banks (no bank walls), with three flat fords of stepping stones and gravel. At the top, the flat top of a rock cliff with grass and roots along its edge and a very thin front face, with a dark doorway in the middle where the path enters. On the lower left, a trampled lair: bare scuffed earth, claw marks, scattered small bones, flattened grass. A few rust-red fallen leaves near the bottom.

CAMERA: strictly orthographic, looking straight down at 90 degrees, like a flat 2D game map. The ground is one flat plane. No horizon, no perspective, no depth shrinking, no tilt, no slopes shown from the side, no haze.
Muted palette: dusty sage and olive greens, dull ochre dirt, cool blue-grey stone. Light from the upper-left.
NO trees, NO standing stones or steles, NO tents, NO bridges, NO pillars, NO people, NO creatures, NO text, NO UI, NO grid lines, NO watermark, NO photorealism, NO blur, NO glow. Keep the open areas calm, with fine detail in small clusters rather than spread evenly.
```

## 4. 立体物件（复用第一轮素材，无需重新生成）

| 用途 | 来源 | 碰撞 |
|---|---|---|
| 碑窟石门立面 | `bs_l02_a_gate.png` | 门两侧立柱 |
| 巨型断碑（中坡碑台） | `bs_l01_a_giant_stele.png` | 基座 |
| 倒伏碑段、残碑、路碑 | `bs_l01_b_markers.png` | 中型以上 |
| 大树 ×5、中树、枯树 | `bs_t01_*`、`bs_t02_*` | 树干 |
| 灌木、蕨类 | `bs_t03_*` | 不加 |
| 岩石、巨石 | `bs_r01_*` | 中型以上 |
| 营地（帐篷、营火 4 帧、箱桶） | `bs_c01_camp.png` | 帐篷 |
| 渡口木桥（损坏 / 修复两态） | `bs_l03_b_bridges.png` | 跟随修桥任务状态 |
| 路牌、巡逻桩、宝箱等 | `bs_q01_props.png` | 路牌 |

第一轮巨型断碑露了右侧面。如果切图后看着还是 2.5D，我会单独给它一条补生成提示词。

## 5. 自查

1. 地面图 1024×1536 PNG；路、沟、渡口、崖、门洞、石板、巢穴位置和布局图一致。
2. 地面里没有树、碑、帐篷、桥；怪物点、Boss 点、出生点、出口附近是平地。
3. 严格俯视，没有透视、地平线、侧面坡。
4. 颜色是低饱和灰绿和赭土，和潮痕滩是同一种画工。
