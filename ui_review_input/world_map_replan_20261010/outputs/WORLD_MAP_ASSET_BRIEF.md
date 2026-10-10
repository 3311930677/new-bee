# 远征 · 世界地图美术资产简报（配套 WORLD_MAP_REBUILD_PLAN.md）

## 1. 美术方向：“晴野枫城”——参考图1的画法 + 参考图2的构图

**参考图1提供背景画法**：明亮的16-bit JRPG像素绘画。
- 黄绿到翠绿的多层草地。
- 温暖沙色土路，波浪边。
- 深色描边的圆冠大树，点缀灌木、花丛、灰石、倒木。

**参考图2提供画面效果**：
- 画面四周被浓密枫树压住。
- 中间是一大片浅奶油色空地，用金黄草穗过渡到草地。
- 暖橙瓦顶建筑贴近空地，NPC站在空地边上，人物在画面中尺寸大、存在感强。

**与当前版本的区别**：浅色路可以保留，但必须改掉以下几点：
- 灰暗平涂的绿底；
- 直边色带；
- 空旷无物的草地。

### 地面
- **草地**：亮黄绿为主，配翠绿暗面和浅黄绿高光。草丛团块16–32px，偶有小白花、小黄花，不均匀撒点。树荫下压暗一档。
- **道路/空地**：野外用暖沙色，城镇广场用奶油色，均比草地亮。路面内部有低对比的浅斑、脚印、车辙，城镇可加淡鳞纹铺砖。
- **路缘（决定成败）**：草与土交界画成锯齿状、波浪状的草穗边，起伏±8–16px，夹零星草丛和小石。城镇空地外圈加一道金黄干草带（参考图2）。任何地方不允许出现直线色块边。

### 树与框景
- **树的画法**：
  - 圆冠树用3–4阶绿，左上亮、右下暗，深墨绿描边；
  - 枫树用粉红、朱红到暗紫红的色阶（参考图2），与主角的纯红披风拉开色相；
  - 针叶树少量点缀。
- **框景规则**：
  - 野外视口左右边缘由成片树冠覆盖，城镇四角由大枫树和屋檐压住；
  - 中心活动区只留低矮点缀，不放遮挡物。

### 光与角色统一
- **光照**：统一左上暖光。每个物件都有贴地的深绿或深棕椭圆接触影。
- **与角色统一**：主角和NPC是高饱和、深描边的像素角色，参考图1的场景同样是高饱和加描边，天然匹配，比上一版低饱和方案更合适。为保证人物跳出画面：
  - 角色站立区地面保持浅色、低纹理；
  - 浓重的枫红只放在画面边缘；
  - 角色脚下必须有接触影。
- **与“灯下行箧”UI统一**：明亮的地图上压深木色UI面板，层次清楚。路牌、灯、宝匣、驿亭等道具使用与UI同族的木、铜、麻绳材质。UI纹理不铺到地面。

### 像素尺度
- 场景像素颗粒应与角色接近，不要比角色更细碎。参考图1的草团和树叶约为2–3像素一簇。
- 相机1.15加最近邻采样可能出现粗细不均的像素。需在样板阶段实机检查，必要时改为整数倍渲染。

## 2. 资产清单（按资产族）

| 族 | 保留 | 修整 | 重绘/新增 |
|---|---|---|---|
| 地表 | 无（现有平涂底与直边色带全部替换） | — | 亮草地4种变体（普通/花草/树荫/干草）、野外沙土路、城镇奶油色压实地（含淡鳞纹铺砖）、残盐道石板、溪岸、溪水、潭水、芦苇湿地 |
| 过渡贴花 | — | — | 草穗路缘16件（直段/内弯/外弯/尽头）、金黄干草带8件、路面浅斑与脚印6件、小石与花丛10件、水岸8件 |
| 建筑 | 议事厅主体（03中的重檐中式风格） | 议事厅加台基、北向台阶、石灯，色彩提亮至新方案饱和度 | 城门改中式门楼（替换西式圆塔）；其余7座功能建筑每座三态，暖橙瓦与灰瓦两族，浅灰石墙；城墙段、后院民居屋顶6款 |
| 未落成 | — | — | ①残基+围栏+苫布料堆+名牌；②脚手架+半成木构；③落成。木料、瓦、石料、苫布做成通用散件 |
| 树与景观 | 现有枫树仅作配色参考 | — | 圆冠绿树3尺寸、枫树3尺寸×2色（粉红/朱红）、针叶树2款，均拆为树干/树冠两层；灌木4款、倒木、灰石组、花丛；石桥、踏石、石涵、驿亭、红叶残祠、断碑、北坡石阶、旧盐道木栅（开/闭）、界碑 |
| 道具/交互 | 路牌（02中的木路牌） | 提亮色彩，统一加接触影 | post、chime、cache、root、return_lamp、salt_marks各一版；长桌、铁砧、商摊货车、兵器架、拴马桩、马场围栏、兽栏围院；NPC头顶任务标记（只读现有任务状态） |

**规格**
- 世界像素1:1绘制。
- 地面按480×416分块，每图2×3块，分底层和道路/空地层；路缘与点缀放在独立贴花层，可旋转、翻转复用。
- 建筑与树的锚点取正面基线中点，y排序以基线为准；阴影为独立精灵。
- 树冠、屋檐单独拆层，玩家进入遮挡区时淡出到约45%。
- 建筑占地宽≤200、高≤260，约为主角（统一缩放0.60后约76px）的3–3.5倍；门与招牌在建筑下半部。
- 框景树大量复用，靠尺寸、色变体和翻转避免重复。

## 3. 生图提示词

**母提示词**
> top-down 3/4 view 16-bit SNES-style JRPG map, bright saturated pixel art, lush yellow-green grass with darker green clumps, small white and yellow flowers, warm light sand dirt path with wavy organic edges and jagged grass fringe, round deciduous trees with dark outlines and 3-4 tone shading, bushes, grey rocks, fallen logs, consistent sunlight from top-left, dark soft contact shadows under every object, dense trees framing the left and right edges, open clean walkable space in the center, Chinese frontier setting, no characters, no UI, no text, 480x800 portrait

| 样板 | 差异 |
|---|---|
| T2 城镇广场 | 奶油色空地+金黄草缘+四角枫树+暖橙瓦建筑（参考图2） |
| F2 枫溪石桥 | 沙土主路+溪、潭、石桥+两侧林墙（参考图1） |
| 建筑三态 | 白底散件排版 |
| 野外散件 | 白底散件排版，树冠拆层 |

**P1 城镇首轮样板T2**
> [母提示词] + plaza of a small Chinese frontier town, large open cream-colored packed-earth clearing with faint scale-pattern paving in the center, ringed by a band of golden dry grass fading into bright green grass; a wavy pale dirt street enters from top and bottom; upper-left a granary under construction (ruined stone foundation, rope fence, tarp-covered timber pile, small wooden name board), upper-right a blacksmith house with warm orange tiled roof, light grey stone walls, open-air anvil and chimney smoke; lower-left a large pink-red maple tree shading a long wooden table with a brass lantern; lower-right a fenced animal pen with a small shed; merchant cart with cloth canopy at the plaza edge; dense pink-red and crimson maple trees with purple shading crowding the four corners like a frame

**P2 野外首轮样板F2**
> [母提示词] + forest valley trail, wide warm sand dirt road running vertically with wavy grass-fringed edges, crossing a narrow clear blue stream over an old arched stone bridge with pillars at both ends; to the left the stream has a shallow ford with stepping stones and a thin sandy side path, a dead tree with a tiny wind chime; to the right the stream feeds a small round pond ringed by reeds with a thin path around it; a moss-covered milestone at a fork near the top; continuous wall of round green trees and a few orange-red maples along both edges, bushes, flowers and rocks under the trees

**P3 建筑三态（锻造铺示例，其他建筑换主体描述）**
> [母提示词，改为 white background asset sheet，去掉 framing/480x800] + one Chinese frontier blacksmith building in three construction states left to right: (1) broken stone foundation, rope-and-stake fence, tarp-covered timber and tile stacks, small wooden sign; (2) bamboo scaffolding around a half-built timber frame, partial roof; (3) finished building with warm orange tiled roof, light grey stone walls, wooden frame, open front forge, anvil outside, chimney; same footprint for all states, front door facing viewer, separate ground shadow

**P4 野外散件**
> [母提示词，改为 white background asset sheet] + round deciduous trees in three sizes, pink-red maple and crimson maple trees in three sizes, two pine trees, each with separate trunk layer and canopy layer; bushes; grey rock clusters; fallen log; flower patches; wavy grass-fringe edge decals for sand paths (straight, inner curve, outer curve, end cap); golden dry-grass border strips; stepping stones; small stone culvert; old wooden road barricade closed and open with a cart wheel; broken stone stele; stone steps going uphill

## 4. 首轮样板范围

- **城镇T2**（中心(480,640)）：直接对标参考图2。
  - 检验：奶油色空地、枫树框景、建筑与NPC贴近空地的效果；仓廪三态与锻造铺同屏。
- **野外F2**（中心(480,700)）：直接对标参考图1。
  - 检验：波浪沙路、林墙框景，以及修桥任务点、浅滩、小潭是否让原来的“8”字结构消失。
- **入画测试**：两处都放入主角、岩龟、1名NPC或1只野狼。
- **通过标准**：与两张参考图并排，画法与密度相当，且人物不被背景吞没。**两张样板通过前，不量产其余地块、建筑和NPC。**

## 5. 工程能力需求

| 能力 | 收益 | 成本 |
|---|---|---|
| 分块手绘地面+路缘贴花层，替代野外着色器混色 | 实现参考图1的有机路缘，去掉直边色带 | 中：分块精灵+贴花节点；flat_routes只作导航参考 |
| 树冠/屋檐遮挡淡出 | 实现密集框景而不挡交互 | 低：区域检测加透明度调整 |
| 统一接触影精灵 | 物件和人物贴地 | 低 |
| NPC头顶任务标记 | 实现参考图2的“接任务”提示，只读现有状态 | 低 |
| 轻量环境动效：水面2–3帧、少量落叶粒子、炊烟 | 场景活起来 | 低 |
| 两图统一角色缩放 | 跨图尺度一致 | 中：需重核碰撞与名牌偏移 |

不需要换引擎、做3D或做动态光照。
