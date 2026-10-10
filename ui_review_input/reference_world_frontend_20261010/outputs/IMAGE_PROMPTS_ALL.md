# 《远征》全套生图提示词（地图 / 素材 / 建筑 / 角色 / 前端）

> 2026-10-11 已正式接入：左右各式建筑、中央自然主路、路牌出口、独立树木；城镇1200×2112、野外960×2112，相机1.15，主角0.65。运行地表为2倍密度分块，纹理像素0.5世界单位。最新交付见 `D:/new-bee/远征/docs/plans/2026-10-11-reference-delivery.md`。

> 接入规格修订：以 [MAP_INTEGRATION_AUDIT.md](MAP_INTEGRATION_AUDIT.md) 为准。A1–A12 是局部景观候选，不可拉伸成全地图；相机 1.0 不再是定案，先比较 1.15 基准。2 倍母版与2倍密度运行地表、分块延展和实际出图尺寸登记见该修订。现有 841×1870 样板未满足正式交付规格。

> 配套：MAP_REFERENCE_REBUILD_PLAN.md（空间与坐标）、FRONTEND_REDESIGN_PLAN.md（页面布局）、REFERENCE_ASSET_PRODUCTION_BRIEF.md（规格与验收）。
> 目标观感：成熟商业手游的俯视地图——自然、可信、安静的地面，饱满有体积的植被，物件成组贴地，人能“走进去”。
> 唯一不改的是现有主角（红发、红披风、暗甲）：不生成主角替代品，只把他的立绘作为比例参考图附上。其余地图、建筑、NPC、前端都可以重做。

---

## 0. 使用方法

1. **拼接**：每条提示词 = `风格块` + `正文`。复制时把 `{MAP}`、`{PROP}`、`{BLD}`、`{CHAR}`、`{ART}`、`{UIKIT}` 替换为第 1 节对应的英文风格块；负面词统一用 `{NEG}`（支持负面词的工具填入 negative prompt，不支持的工具把 `Avoid: ...` 接在提示词末尾）。
2. **尺寸**：A1–A12 逻辑校准框 480×1067，请求 960×2134 工作母版，不是 960 宽世界全图。G 背景同规格。生产地表按接入修订的核心块及重叠带制作。每次记录实际输出尺寸，规格不符先登记为原始候选，不直接拉伸上线。
3. **一致性**：先从 A1 和 A10 里各选定 1 张最好的图，把它们作为后续所有地图和散件条目的风格参考图（style reference / image prompt）一起附上。仅在工具支持时固定种子；当前 Codex 内置生图工具没有种子参数，实际以相同风格块、参考图和逐张检查保持一致，不宣称已固定种子。NPC 条目必须附现有主角立绘。
4. **用途**：A 组全屏图是效果底稿，用来描改地表和确定构图，不直接上线。实际进游戏的树、石、建筑、交互物，按 C–F 组请求原生透明背景，检查 alpha、完整轮廓与脚底锚点后单独接入；原始生成图保留。
5. **顺序**：先核对街区坐标、出口、建筑轮廓、门前区、NPC与任务物件，跑通可达性与交互选择 → 地表与自然路缘 → 单体建筑与独立树木 → NPC → 同屏实际行走验收 → 前端与其余资产。未经位置校准，不批量生成占地未知的房屋。

6. **二维风格优先**：A1、A10 首次出图只附用户原始森林参考，不附此前被否定的成图。地图采用参考图的二维俯视投影，不出现天空、地平线或消失点；体积由手绘像素色块表达。前端可用叙事构图，但保持同一像素绘画语言，不加入电影镜头、写实材质或预渲染光照要求。样板只作候选，未经同屏与人工验收不批量铺开。
7. **负面词按用途过滤**：G5 是 UI 部件，移除负面词里的 UI、frame、border；F 组及 G1/G2 允许正文指定角色，只排除额外角色。正文明确要求的物件、框体和角色优先于通用负面词。
8. **背景与透明度**：当前生产优先原生透明 alpha；不得把棋盘格、深色渐变或带色光晕当作透明。仅当工具无法输出透明时另行约定纯色底，并保留原图、检查残边与锚点。不得靠后期缩小或像素化掩盖风格偏差。

---

## 1. 风格块（只写一次，拼接用）

**{MAP} 地图全屏**
> Two-dimensional hand-drawn pixel art for a playable overhead JRPG map matching the forest reference. Fixed orthographic game projection: north up, south-facing facades seen straight on, vertical posts and horizontal east-west edges. Roofs visible from above. Same-sized objects retain their size everywhere, no horizon or vanishing point. Fine single working pixels and tiny 2-pixel clusters matching the existing hero; never enlarge 4–8-pixel mosaic blocks. Fine single working pixels and tiny 2-pixel clusters matching the existing hero; never enlarge 4–8-pixel mosaic blocks. Fine single working pixels and tiny 2-pixel clusters matching the existing hero; never enlarge 4–8-pixel mosaic blocks. Fine single working pixels and tiny 2-pixel clusters matching the existing hero; never enlarge 4–8-pixel mosaic blocks. Fine single working pixels and tiny 2-pixel clusters matching the existing hero; never enlarge 4–8-pixel mosaic blocks. Fine single working pixels and tiny 2-pixel clusters matching the existing hero; never enlarge 4–8-pixel mosaic blocks. Deliberate pixel color clusters, upper-left daylight, short lower-right contact shadows. Natural layered grass, quiet ochre paths with irregular grass-tongue edges, clustered foliage with lit tops and cool green undersides. Varied plant group sizes and spacing, sparse grouped flowers and generous connected walking space. Painted volume and rich natural colors, not flat cutouts. One local view, not a compressed entire region.

**{PROP} 散件表**
> Two-dimensional hand-drawn pixel game sprites matching the forest reference. Fixed overhead orthographic projection, down-facing fronts, horizontal east-west axes and vertical posts, no rotated isometric bases. Deliberate color clusters, upper-left light, same-hue dark edges, restrained material detail. Complete uncropped objects separated by margins, genuinely transparent alpha background, no baked checkerboard or colored backdrop, no cast shadow or surrounding ground. Contact bases visible for bottom-center anchors. Requested working artwork is 2x the listed logical sizes; pixel count and world size differ.

**{BLD} 建筑单体**
> Single two-dimensional hand-drawn pixel building sprite for an overhead JRPG. South-facing facade straight on, horizontal eaves and front steps, vertical posts, roof seen from above. Symmetrical fixed game projection matching the actor, no receding side facade or rotated isometric base. Frontier timber construction, grey clay roof, cream plaster, fieldstone base, restrained red accents. Painted color ramps, clean pixel clusters; simplified tiles and wood grain subordinate to silhouette. Upper-left light. Complete uncropped roof and steps, bottom-center doorway, genuinely transparent alpha background, no baked checkerboard or colored backdrop, no cast shadow or surroundings. A 72-world-unit actor fits an 88-unit-high door. Request a 2x working master, not a larger in-game building.

**{CHAR} 角色**
> One original down-facing NPC sprite for a two-dimensional overhead JRPG. Match the existing hero reference's pixel density, projection, approximately 3.3-head proportions and upper-left light. Adult visible height 72 world units, request 144 working pixels; child uses the stated smaller ratio. Natural muted frontier fantasy clothes, one accent, readable silhouette, same-hue dark edge. Feet anchored bottom center. genuinely transparent alpha background, no baked checkerboard or colored backdrop, no shadow or writing. Attached hero is scale and painting reference only: do not redraw, replace or include that hero.

**{ART} 前端插画**
> Two-dimensional hand-drawn pixel frontend background using the map's painted color clusters, foliage palette, upper-left light and restrained materials. Fixed elevated game-style composition, no cinematic receding street, horizon or vanishing point. Logical canvas 480x1067, requested master 960x2134. Key content fits central 480x800 crop, quiet top and bottom extensions. No generated hero: reserve actor space for overlaying the existing game sprite. Horizontal building facades, vertical posts, discrete painted color ramps for wood, brass and paper.

**{UIKIT} UI 部件**
> Two-dimensional pixel UI sprites in a warm lantern-lit frontier travel theme: dark red-brown lacquer, restrained brass corners, cream paper and vermilion accents. Straight-on front view, consistent logical pixel grid, requested 2x master. Nine-slice friendly plain center and edge stretches, decorations at corners and ends. Complete separate elements on genuinely transparent alpha background, no baked checkerboard or colored backdrop. No text or letters; live labels and semantic states are separate overlays.

**{NEG} 负面词**
> text, letters, numbers, UI, HUD, watermark, signature, frame, border, grid lines, isometric diamond tiles, neon or fluorescent colors, oversaturated green, camouflage blotches, random noise speckles, dithering noise, repeated stamp pattern, objects evenly spaced in rows, hard straight edge between grass and road, floating objects without contact, blurry, painterly smudge, 3D render, photo, mixed pixel sizes, heavy pure-black outlines, extra characters

---

## A. 地图效果底稿（9:20 竖屏，无人物）

**A1 野外·林门草甸（参考级主样板）**
> {MAP} A quiet ochre dirt road enters from the bottom center and bends in a gentle S-curve toward the top, 120–160 logical units wide within this local 480-unit-wide view, its edges worn and irregular, with faint footprints and wheel ruts. At the bottom two large broadleaf trees frame the road like a natural gate. Left middle: a sunny open meadow with a fallen mossy log, a cluster of white and yellow wildflowers, scattered tuft groups, and a narrow trampled footpath leading to a lone young maple with an old wind chime hanging from a branch. Right: forest edge with grouped round bushes of three sizes, a medium oak, one conifer and two mossy grey rocks. Top edge: the road continues through a green forest opening; the stream and bridge belong to A2 and must not be compressed into this meadow. Summer greens, almost no red leaves. No characters.

**A2 野外·溪谷古桥（受损）**
> {MAP} A clear shallow stream crosses the frame slightly diagonally from upper-left to lower-right through the middle third, sparkling water with gentle light ripples, natural banks of pebbles, reeds, mossy stones and overhanging grass, no hard straight banks. An old timber bridge runs north-south across the center, weathered planks, a cosmetic missing wedge near the edge with continuous walkable central decking, loose sagging ropes, a small faded cloth warning strip tied to a post, stone piers on both banks. The dirt road approaches from the bottom and continues from the north bridgehead upward. Willows and oaks on both banks, a few young maples beginning to turn orange on the north side. No characters.

**A3 野外·溪谷古桥（修好，用 A2 局部重绘）**
> Same image, inpaint only the bridge: the missing wedge is replaced by a fresh pale wooden wedge, the ropes are retied tight with neat knots, the warning cloth removed, nothing else changes.

**A4 野外·驿亭岔口（旧盐道封闭）**
> {MAP} A forest crossroads: the main dirt road runs from the bottom center up to the upper-left; a slightly narrower branch leaves eastward to the right edge. Beside the junction on the right, a small open wooden roadside pavilion with a grey tile roof, a bench and a hanging lantern; near it a two-wheeled salt cart loaded with tied sacks. Across the east branch near the right edge, a wooden cross-barricade with rope and a short carved stone road marker, blocking the way. On the left, a low mossy rocky rise with an old stone box half hidden in ferns, reached by a faint trampled footpath. Mixed green trees with a few orange maples. No characters.

**A5 驿亭岔口（开放，用 A4 局部重绘）**
> Same image, inpaint only the barricade: it is pushed aside onto the roadside grass and partly dismantled, the east road is clear, nothing else changes.

**A6 野外·枫岭林窟**
> {MAP} A maple grove clearing in early autumn: about half the trees are orange, crimson and amber maples mixed with green oaks, fallen red leaves gathered along road edges and under trees (not covering the road). The dirt road winds through from bottom to top. In the clearing, an old moss-covered stone lantern stands beside the road as a landmark, with a few red leaves on its roof. Left forest edge: ferns, a root cluster and a small patch of wild herbs. Right: dense thicket of bushes and fallen branches. Warm dappled light patches on the ground. No characters.

**A7 野外·北坡石阶出口**
> {MAP} The dirt road reaches the top of the forest and turns into old uneven stone steps climbing northward out of the frame, flanked by large maples and conifers. Beside the steps, an ancient broken stone stele, cracked in half and leaning, covered in moss and ivy, marking the way to a hillside beyond. Grass grows between the steps. Upper area slightly cooler and shadowed to suggest elevation. No characters.

**A8 城镇·出城路牌（抵达点）**
> {MAP} Local view at the northern town exit: one small wooden directional signpost stands beside the central natural ochre road, not in its walking corridor. The road continues north through open grass toward the forest route. No gatehouse, arch, wall or barrier. The town street width is roughly120–144 logical units, not enlarged with the map canvas. Varied left and right buildings begin farther down the road, with gentle vertical staggering and clear south-facing doors. Only a few independent trees on outer verges, sparse small plant groups and generous quiet grass. Keep the sign's destination text as a runtime overlay. No characters. Avoid: {NEG}

**A9 城镇·门内街**
> {MAP} Local overhead view of a quiet gently winding ochre street in grass. On the left, a granary in its approved280x200-world-unit lot; on the right, a forge in its own280x200 lot, staggered downward slightly. Fronts and steps horizontal, posts vertical, roofs seen from above. Short88-unit worn access paths reach the separate door forecourts; small side clearings reserve NPC conversation spaces off the main road and away from doors. Sparse crates and troughs stay inside the asset bounds. One small shrub group as an accent, generous empty grass, no evenly scattered flowers. The central144-unit route remains continuous through both frame edges. No characters. Avoid: {NEG}

**A10 城镇·中央广场（城镇主样板）**
> {MAP} One local view of a frontier town's central grassland street, gently winding north through open grass with subtle irregular worn ochre edges. Varied buildings occupy the left and right lots, all fronts facing south. The council hall is one larger building on the left, not a block across the route; on the right a smaller working facility is staggered vertically so silhouettes are not mirrored. A short worn footpath reaches each clear doorway forecourt. Keep the northward street visibly continuous beyond this view toward the town gate. Sparse independent bushes and one tree in a reserved open side patch, never a dense forest wall. No central rectangular paved board, no courtyard-only dead end, no buildings, NPCs or trunks on the main walking corridor. This is an assembled composition reference; runtime buildings and plants will be separate assets. No characters. Avoid: {NEG}

**A11 城镇·南坊（图志阁 / 祭坛 / 兽栏）**
> {MAP} Local view of the southern town street continuing through grass: archive on the left, beast pen and open altar in separate staggered lots on the right, never an altar placed across the road. Every door or altar step has a short side approach. Reserve NPC standing clearings beside, not directly in front of, the entrances. Sparse outer-verge vegetation and varied facility silhouettes, ample open walking space, no enclosing paper-board courtyard or dense tree wall. No characters. Avoid: {NEG}

**A12 城镇·南城根荒院（敌人活动区）**
> {MAP} An abandoned overgrown yard along the inner side of the south town wall: long wild grass, nettles, broken roof tiles, a collapsed shed, an overturned cart, cracked flagstones half swallowed by weeds, a dead tree. Two gaps in a low broken stone wall at the top lead back into town. Slightly desaturated and cooler than the rest of town but still daylight, clearly a different, dangerous zone. No characters.

**A13 全图概念·枫林古道（可选，只用于确认布局）**
> {MAP} Full overhead map of a long forest road region, portrait 9:20, from bottom to top: a tree-framed entrance, an open meadow with a side path to a lone maple, a stream crossed by an old timber bridge, a crossroads with a roadside pavilion and an eastward branch blocked by a barricade, a red maple grove clearing with a stone lantern, and old stone steps leading out at the top. Greens at the bottom gradually turn to autumn reds toward the top. No characters.

**A14 全图概念·昭元边城（可选，只用于确认布局）**
> {MAP} Full spatial concept overview only, fit the canvas around approved building plots and comfortable outer grass margins rather than forcing a fixed region size. One continuous gently winding ochre road runs between varied left and right facilities and ends at a small roadside direction sign leading north to the forest route. No gatehouse, enclosed wall or architectural exit. Left lots: stable, granary, larger council hall, archive. Right lots: patrol hall, forge, beast pen and altar. Vertically stagger the facilities and add short narrower doorway approaches. Keep main road roughly120–144 world units regardless of canvas width. Trees stand independently in sparse outer or inter-building clearings; no dense tree walls. Preserve all entrance and NPC standing spaces. No characters. Avoid: {NEG}

---

## B. 地表材质套件（1:1，正俯视，可平铺）

**B1 草地三层（各生成一次，替换括号内文字）**
> Seamless tileable top-down ground texture, polished HD pixel art, one consistent pixel size, natural grass made of small clustered blade groups, [sunlit yellow-green / mid green / cool blue-green shaded] tone, subtle variation, no flowers, no objects, no visible repeat, no camouflage blotches. Avoid: {NEG}

**B2 土路填充**
> Seamless tileable top-down texture of a calm packed ochre dirt road, polished HD pixel art, very low contrast, a few tiny pebbles, faint footprints and soft wheel-rut hints, quiet surface, no noise speckles. Avoid: {NEG}

**B3 路缘过渡带**
> Horizontal strip texture, polished HD pixel art top-down, showing a natural transition from packed ochre dirt (bottom half) into grass (top half): irregular worn edge, grass tongues reaching into the dirt, small isolated tufts, a few pebbles, a thin darker compressed soil line, no straight edges, left and right ends seamless. Avoid: {NEG}

**B4 城镇石板铺地**
> Seamless tileable top-down texture of worn irregular grey-ochre flagstones of mixed sizes, rounded worn corners, thin grass and moss in the cracks, a few chipped stones, calm and low contrast, polished HD pixel art. Avoid: {NEG}

**B5 荒院地面**
> Seamless tileable top-down texture of an abandoned yard: dry patchy earth, scattered broken roof tile shards, sparse weeds, slightly desaturated, polished HD pixel art. Avoid: {NEG}

**B6 溪面与岸**
> Top-down pixel art texture strip of a clear shallow stream flowing horizontally: transparent teal water showing pebbles on the bottom, soft light ripples, natural banks on both sides with pebbles, wet darker soil, reeds and overhanging grass, left and right ends seamless, polished HD pixel art. Avoid: {NEG}

---

## C. 植被与自然散件（1:1，{PROP}）

**C1 阔叶大树**
> {PROP} Three large broadleaf oak-like trees with different silhouettes (round, wide asymmetric, tall oval), full canopies of distinct leaf clumps in summer green, bright upper-left clumps, deep blue-green underside, sturdy brown trunks with visible roots flaring at the base. Avoid: {NEG}

**C2 中树与幼树**
> {PROP} Two medium broadleaf trees and three young saplings of different heights, summer green, same leaf-clump style, slender trunks with small root flares. Avoid: {NEG}

**C3 枫树（三季色）**
> {PROP} Three maple trees with the same silhouette family in three color states: mostly green with a few orange clumps; half orange and amber; full crimson and red, with deeper wine-red shadows. Elegant canopies made of leaf clumps, dark brown trunks with root flares. Avoid: {NEG}

**C4 针叶树**
> {PROP} Three conifer pine/fir trees of different heights, layered drooping branch tiers, deep cool greens with lit tips on the upper-left, brown trunks visible at the bottom. Avoid: {NEG}

**C5 灌木**
> {PROP} Six bushes of different sizes and shapes (small round, wide low, tall clumpy, berry bush with small red berries, flowering bush with white blossoms, wild rose with pink flowers), clear volume, lit upper-left. Avoid: {NEG}

**C6 草簇与蕨**
> {PROP} Twelve small ground plants: short grass tufts, tall grass tufts, a clover patch, two fern clumps, reeds, wild herbs, a small sprout, dandelions; each tiny but readable, natural greens. Avoid: {NEG}

**C7 花丛**
> {PROP} Eight small wildflower clusters: white daisies, yellow buttercups, orange marigold-like flowers, small blue flowers, a mixed patch, low ground flowers, two tall-stem clusters; each grouped with a little foliage. Avoid: {NEG}

**C8 岩石**
> {PROP} Eight rocks: three single grey stones of different sizes, two moss-covered boulders, one group of three rocks, a flat stepping stone, a small rock with grass growing around it; rounded natural shapes, soft lichen tones. Avoid: {NEG}

**C9 倒木 / 树桩 / 树根**
> {PROP} A long fallen mossy log with a small sprout, a short broken log, two tree stumps (one with mushrooms), an exposed root cluster, a pile of fallen branches. Avoid: {NEG}

**C10 地表贴花**
> {PROP} Small flat ground decals viewed from above: scattered fallen leaves (green, orange, red sets), pebble groups, a muddy footprint trail piece, a wheel-rut segment, a small puddle, twig clusters, clover patches; all very flat and low contrast. Avoid: {NEG}

**C11 水边散件**
> {PROP} Waterside props: three reed clumps, cattails, a group of wet pebbles, two half-submerged mossy rocks, lily pads with one small flower, a small wooden stake. Avoid: {NEG}

**C12 古枫地标与夜桌**
> {PROP} One huge ancient maple tree, much larger than normal trees, thick gnarled trunk with large roots, broad canopy mostly green with warm orange clumps; plus a long rustic wooden table with two benches and a small oil lantern on it, shown separately. Avoid: {NEG}

---

## D. 建筑（4:3 或 1:1，{BLD}）

周边房屋必须同时服从 [TOWN_NEIGHBORHOOD_PLAN.md](TOWN_NEIGHBORHOOD_PLAN.md) 的街区轮廓，而不是各自独立决定尺寸。完整图框包括屋檐、台阶、附属物；工作母版是该图框的2倍，另留品红边距。门高与主角统一，禁止把议事厅缩小复制成普通房屋。当前尺寸是候选；新素材超出轮廓时先更新街区并重跑间距、入口与通行检查。A8–A12 只表现这些地块的局部视口，不把整个街区塞到一张手机画面。

| 条目 | 设施 | 候选可见轮廓（世界单位） |
|---|---|---|
| D1 | 出城路牌 | 约60×64；独立物件 |
| D3 | 议事厅 | 420×259 |
| D4 | 图志阁 | 280×220 |
| D5 | 兽栏 | 280×210 |
| D6 | 巡界厅 | 280×210 |
| D7 | 仓廪 | 280×200 |
| D8 | 马厩 | 280×200 |
| D9 | 祭坛 | 240×180 |
| D10 | 锻造铺 | 280×200 |

每栋生成落成版；未落成用 D12。实测样板中议事厅需约 420×259 世界单位才能满足约 88 高的门洞，420 宽是候选比例，不直接改全城建筑间距。按完整有效轮廓统一缩放，不能分别拉长门洞或挤压屋顶。其他建筑按批准的世界宽高制作。

**D1 出城路牌**
> {PROP} One small rustic wooden signpost with one or two blank directional boards on a single upright pole, weathered warm timber, understated carved edges, complete root/base contact. Logical visible height about64 world units and width about60, requested2x object artwork plus clear transparent margin. Placeable beside a road, not an arch or a barrier. No buildings, walls, printed words or text; destination is a live label. Avoid: {NEG}

**D2 设施院落栅栏（按需）**
> {PROP} Optional small yard fence modules only: timber rail straight, corner and open gate pieces, a low paddock fence and short low stone edge. These belong inside individual stable or facility plots, never enclose the town or block the main road or exit sign. Avoid: {NEG}

**D3 议事厅（hall）**
> {BLD} The council hall: the largest building in town, single-storey on a raised stone platform with wide steps, red-lacquered pillars, carved wooden lattice windows, a grand grey tile roof with upturned eaves, a wooden plaque frame above the door (blank), two potted pines at the steps. Avoid: {NEG}

**D4 图志阁（archive）**
> {BLD} An archive and map hall: a two-storey timber pavilion with a small balcony, paper lattice windows, scroll racks and map rolls visible through an open side, a small bookcase by the door, ink-blue accent cloth. Avoid: {NEG}

**D5 兽栏（kennel）**
> {BLD} A beast pen and barn: a wooden barn with a thatched-and-tile roof, a fenced front yard with straw, feeding troughs, a water bucket, small kennel boxes, a pen gate at the bottom. Avoid: {NEG}

**D6 巡界厅（barracks）**
> {BLD} A frontier patrol hall: solid stone-and-timber building with dark red banners, weapon racks of spears beside the door, a drum, a small training yard with two wooden practice dummies at the front. Avoid: {NEG}

**D7 仓廪（storehouse）**
> {BLD} A granary storehouse raised on short stone stilts, heavy timber walls, a steep tile roof, a wide door with a ramp, sacks and grain baskets stacked by the entrance, a hand cart. Avoid: {NEG}

**D8 边城马厩（stable）**
> {BLD} A frontier stable: long low timber building with open stalls, hay bales, saddles hanging on a rail, a water trough, a small fenced paddock attached on one side. Avoid: {NEG}

**D9 祭坛（shrine）**
> {BLD} An open-air altar terrace: a square stone platform with three low steps at the front, a bronze incense burner in the center, a low stone altar table with offerings, two tall vertical cloth banners, two old pines at the back corners. No enclosed building. Avoid: {NEG}

**D10 锻造铺（forge）**
> {BLD} A blacksmith forge: open-fronted workshop with a glowing furnace, a tall stone chimney with light smoke, an anvil and quench trough in the front yard, tool racks, a pile of iron bars and charcoal sacks. Avoid: {NEG}

**D11 驿亭与盐车**
> {PROP} A small open wooden roadside pavilion with four posts, a grey tile roof, a bench and a hanging lantern; separately a two-wheeled wooden cart loaded with tied salt sacks. Avoid: {NEG}

**D12 待建工地部件**
> {PROP} Construction site parts for an unbuilt building lot: a rectangular stone foundation frame, a bamboo scaffolding section with rope lashings, a tarp-covered timber pile, a stack of grey roof tiles, a pile of stones, a wooden sawhorse, and a blank wooden notice board on a post. Avoid: {NEG}

**D13 城镇生活散件**
> {PROP} Town props: wooden crates, barrels, a stone well with a wooden crank, a lantern post, potted plants, a laundry pole with cloth, a market cart stall with goods and a canopy, a stone bench, a small shrine lamp. Avoid: {NEG}

---

## E. 交互物（{PROP}，每件都需要另做一张描边高亮图）

**E1 野外交互物**
> {PROP} Field quest objects: a small old bronze wind chime with a faded ribbon; an old carved stone box half covered in moss; a clump of wild grass roots pulled from the soil; a wooden direction signpost with two blank arrow boards; a short wooden marker post with a cloth strip for a bridge pier; a fresh pale wooden bridge wedge; a moss-covered stone lantern; a wooden cross-barricade in closed state and the same barricade pushed aside; a cracked ancient stone stele. Avoid: {NEG}

**E2 城镇交互物**
> {PROP} Town quest objects: a stone bench with a lantern post; a small reading table with three stacked bound books and an inkstone; a wooden notice board with blank paper sheets pinned on it; a small oil lantern on a table stand; a carved wooden low stool. Avoid: {NEG}

---

## F. 角色（1:1，{CHAR}，必须附主角立绘作为参考）

| # | ID | 正文（接在 {CHAR} 后） |
|---|---|---|
| F1 | npc_steward 闻叔·执事 | An elderly town steward, grey hair in a neat topknot, short grey beard, dark indigo long robe with a plain sash, holding a bound ledger, calm and kind. |
| F2 | npc_guard 老赵·城门卫 | A middle-aged gate guard, weathered face with stubble, brown tunic under a leather-and-iron lamellar vest, red cloth headband, spear held upright. |
| F3 | npc_scribe 青姨·图志阁掌事 | A middle-aged woman archivist, hair in a bun with a wooden pin, teal-green robe, map scrolls tucked under one arm, composed and wise. |
| F4 | npc_keeper 阿豆·兽栏伙计 | A cheerful young stable hand, round face, short messy hair, brown apron, rolled-up sleeves, carrying a feed bucket. |
| F5 | npc_smith 石头·铁匠 | A stocky young blacksmith, cropped hair, soot smudges, thick leather apron, bare strong forearms, hammer resting on his shoulder. |
| F6 | npc_mentor 岳教头·巡界导师 | A tall veteran instructor, upright posture, dark red and black patrol uniform with one armored shoulder guard, sword at the hip, arms crossed. |
| F7 | npc_stablemaster 马伯·马厩管事 | An old horse keeper with a straw hat, brown vest over a pale shirt, coiled whip at the belt, holding a grooming brush. |
| F8 | npc_warden 云游·行脚商人 | A traveling peddler with a wide bamboo hat, layered ochre travel cloak, a tall wooden backpack frame loaded with small goods, a walking staff. |
| F9 | npc_child 小满·城中孩童 | A small child, noticeably shorter (about 0.7 of an adult), hair in two buns, simple light-yellow outfit, holding a little paper pinwheel, playful. |
| F10 | 野狼（敌人，保留种类） | A grey wild wolf in a prowling stance, facing down-front, body length about 1.2 times the hero's height, lean and natural (not oversized or monstrous), layered fur with lit upper-left. |
| F11 | 其他敌人（模板） | A [按配置的敌人种类填写] enemy creature, facing down-front, size relative to the hero: [按体型填写], readable silhouette, natural colors matching the forest. |

主角本身不生成。如果需要统一像素密度，只对现有主角立绘做离线缩放和清边。

---

## G. 前端（9:20，{ART} / {UIKIT}）

**G1 加载背景·林口晨光**
> {ART} One local overhead forest composition: quiet dirt path winds north between green tree groups and a few red leaf accents at the upper edge. Same object scale throughout, no sky or horizon. Calm sunlit canopy clearing in upper third for logo. Empty actor staging area centered in lower third, 90 logical units tall, for existing hero sprite overlay; do not paint a hero. Separate small travel case and lantern beside the path. Bottom 15% calm ground for live progress. No text, logo, characters or baked-in interface. Avoid: {NEG}

**G2 标题背景·沿路启程**
> {ART} Elevated overhead frontier town street composition. A quiet ochre road through natural grass leads toward the forest. A small rustic wooden direction sign stands off the road near the visual focus; no gatehouse, arch or enclosing wall. Varied south-facing buildings sit on both sides, with horizontal facades and roofs visible from above. Leave an empty actor area on the road for the existing hero sprite. Sparse outer trees and natural grass groups, not crowded. A lamp and travel case can sit beside a building entrance. Calm upper canopy or pale sky-colored painted field for the logo, calm lower ground for live buttons. No text, logo or characters. Avoid: {NEG}

**G3 登记背景·行箧文牒**
> {ART} Top-down painted composition on a flat warm wooden tabletop lit by an oil lantern in the upper-left corner. In the center an opened dark red-brown lacquered travel case with brass corners and leather straps, the inner lid showing part of an old hand-drawn map. Resting over it, a large completely blank cream travel document with slightly curled edges, evenly lit, covering roughly x 6–94%, y 20–55% of the logical 480x1067 frame, with the blank form surface parallel to the image plane. Around the edges: a maple leaf, a brush and inkstone, a coiled rope, a cloth luggage tag tied to the handle. No writing anywhere, no characters. Avoid: {NEG}

**G4 手记背景（备用，范围确认后才用）**
> {ART} The same warm wooden table and lantern light, top-down, with an open leather-bound travel journal in the center, both pages blank and evenly lit, three cloth bookmark ribbons (red, teal, ochre) hanging from the top edge, a dried maple leaf and a small compass beside it. No writing. Avoid: {NEG}

**G5 UI 部件表**
> {UIKIT} A sheet of separate elements: a wide primary button plate in dark vermilion lacquer with aged brass corner caps (normal, pressed-darker, and greyed disabled versions); a cloth luggage tag button with a small brass eyelet and string; a cream paper document panel with slightly curled corners; a thin horizontal road-strip progress bar (left half packed warm earth, right half pale grass) with rounded ends; a small glowing hand lantern marker (lit and dim versions); a square portrait frame of dark wood with four small brass nails; a small diamond separator ornament; an eye icon open and closed; a round vermilion seal stamp with an abstract (non-letter) pattern. Avoid: {NEG}

---

## I. 首轮可接入制作提示词

P1 保持原野外512×768样板规格。P2 改为城镇主路的分块制作配方，须填入具体世界裁切区，不可直接调用一个未指定位置的全图提示词。P3/P4 独立分层。风格只用原始森林或通过验收的画面，布局图只指导坐标。此前 P2_PRODUCTION_PROMPT.txt 是历史实际调用，不代表最新配方。

**P1 草甸地表**
> {MAP} Ground-only meadow patch, logical extent 512x768 world units, requested working master 1024x1536 pixels, portrait 2:3. Calm mid-green grass with broad subtle sunlit transitions, sparse grouped blades and no flower dots. A quiet ochre path 132 logical units wide enters bottom at x256, bends to x280,y540 then x220,y300 and exits top at x260. Grass tongues soften edges. Narrow trampled branch from x240,y380 to left edge y330. Keep 70% of grass quiet. No trees, bushes, rocks, logs, buildings, characters, object shadows, bridges, rivers or quest props. Floor only. Avoid: {NEG}

**P2 城镇主路地表**
> {MAP} Ground-only production chunk of the town grassland street. Use an explicitly declared world crop derived from the current fit-to-content layout, not a fixed whole-map size. Core block dimensions and32-world-unit overlap come from the production manifest; request a2x working master of that crop including overlap. Keep the guide's centerline, main road roughly120–144 units and narrower short doorway paths. At the southern edge the road is not required to meet the frame: below the final facilities it gently bends, narrows, becomes overgrown and dissolves into grass; leave asymmetrical quiet grass and a few disconnected soft earth traces, never a rounded graphic end cap or straight stripe touching the bottom. Calm naturally layered grass, low-contrast ochre soil, irregular grass tongues and sparse short grass groups. No camouflage patches, evenly scattered flowers or pixel-noise carpet. Paint no buildings, gates, walls, foundations, trees, bushes, NPCs, signposts, quest props or object shadows. Input1 is painting style; input2 is geometry only. Never compress the whole region into this chunk. Avoid: {NEG}

**P3 基础散件**
> {PROP} Exactly four sprites in a two-column two-row sheet, requested canvas1024x1024. Top-left: complete green broadleaf tree with clustered canopy and visible trunk roots, logical visible height192 and width166. Top-right: rounded bush height48 width64. Bottom-left: mossy grey rock height44 width64. Bottom-right: short fallen mossy log with one sprout width110 height48. Each centered in its own quadrant with15% blank margin. Keep canopy distinct from lower trunk for separate canopy and trunk layers. No flowers or surrounding ground. No text, shadows or labels. Avoid: {NEG}

**P4 议事厅单体**
> {BLD} Complete single-storey council hall, logical visible bounding box approximately420x259, requested2x object artwork840x518 plus clear transparent margin; visible bounding box is not the whole source canvas. Symmetric front, broad horizontal eaves, horizontal stone steps, vertical restrained red columns, centered wooden door, cream plaster and grey roof with simplified tile rows. Door opening88 logical units high, large enough for a72-unit adult. Blank small signboard, no potted plants. Entire outline visible. No receding side facade, diagonal stairs or miniature architecture. Final width is a prototype candidate and must be checked against town spacing. Avoid: {NEG}

---

## H. 出图后最低检查（详见简报第 5 节）

| 检查项 | 要求 |
|---|---|
| 像素网格 | 统一，没有大小混杂的像素 |
| 品红底散件 | 无品红残边 |
| 光源与影子 | 受光面都在左上；接触影一律在引擎里加 |
| 同屏检查板 | 树约 2.3–2.8 倍人高；门约 1.2 倍人高；狼体长约 1.2 倍人高 |
| 色彩 | 转灰度后能读出三层明度；不出现荧光绿 |
| 前端 | 背景中间 480×800 焦点完整；Logo 区和按钮区安静 |
