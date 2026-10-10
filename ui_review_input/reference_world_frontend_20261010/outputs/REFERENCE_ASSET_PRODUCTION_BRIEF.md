> 2026-10-11 落地更新：本文件保留设计历史；当前正式实现、坐标和像素规格以 `D:/new-bee/远征/docs/plans/2026-10-11-reference-delivery.md` 与 `assets/world/reference_complete_20261011/layout.json` 为准。已完成两图与加载、标题、登记三页接入，不再是未接入原型。

# 《远征》参考级资产制作简报

> 最新修订：城镇出口为一个独立路牌，不制作门楼。地图范围按内容与留白计算，当前约1200×2112为工作草案；主路约136宽、支路较窄。城镇布局及旧门楼描述以 [TOWN_NEIGHBORHOOD_PLAN.md](TOWN_NEIGHBORHOOD_PLAN.md) 和最新 IMAGE_PROMPTS_ALL.md 为准。访客簿作为独立点位保留原功能ID。

> 城镇最新构图与生产范围由 [TOWN_NEIGHBORHOOD_PLAN.md](TOWN_NEIGHBORHOOD_PLAN.md) 覆盖：左右建筑、连续草坪主路、北门出城，1104×1920为待定样板范围。原960宽与广场绕行表不作为当前制作坐标；正式数据尚未改动。野外方案保持原范围。地表、建筑、树与NPC分开制作，生成前先核对当前预检记录。

> 接入规格修订：以 [MAP_INTEGRATION_AUDIT.md](MAP_INTEGRATION_AUDIT.md) 为准。A1–A12 是局部景观候选，不可拉伸成全地图；相机 1.0 不再是定案，先比较 1.15 基准。2 倍母版、1 倍世界输出、分块延展和实际出图尺寸登记见该修订。现有 841×1870 样板未满足正式交付规格。

> 配套文件：MAP_REFERENCE_REBUILD_PLAN.md（尺寸、比例、坐标）、FRONTEND_REDESIGN_PLAN.md（前端页面）。
> 制作路线：手绘地表底图分块 + 分层透明散件。生图只用来做样板和底稿；所有交付资产都要经过像素整理、去边、定锚点和同屏验收。工具一次生成的结果不保证规格准确，规格以画面效果为准。

---

## 1. 通用技术规格

**比例基准**：主角显示高 72px，其余尺寸按地图方案第 3.1 节换算。

**像素密度**

- 最终 1 倍地图资产：1 输出像素 = 1 世界单位；2 倍工作母版：2 源像素 = 1 世界单位。相机倍率独立计算，不由母版倍率决定；建议先以 1.15 校准，详见接入修订。
- 细节按“簇”组织，不靠单像素噪点：叶团 6–12px，草叶宽 2–4px，石面块 4–8px。

**光源**：太阳在左上，约 10 点钟方向。

| 物件 | 接触影 |
|---|---|
| 树 | 椭圆，宽约为树冠宽的 0.8 倍，向右下偏 4–10px |
| 小物件 | 宽约为底宽的 1.1 倍 |
| 角色 | 34×12 |

接触影一律单独出图，交给引擎的阴影组合成，不画进散件本体。

**色彩**

- 不设总色数上限。
- 每个资产族使用同一套色阶（例如树叶：高光黄绿 → 中绿 → 橄榄 → 蓝绿暗部），外轮廓用同色系最深色，不用纯黑。
- 禁止荧光色。

**源图与交付流程**

1. 生图（大尺寸）。
2. 识别有效像素网格后，最近邻缩放到目标尺寸。
3. 按资产族合并色阶。
4. 在 Aseprite 里手工清边。
5. 导出 PNG。

透明散件在纯品红 #FF00FF 底上生成；不用绿底，避免和草色混淆。

**锚点**：除特别说明外，一律在底部中心，即物件的落地点。

---

## 2. 资产族清单

| 族 | 用途 | 显示规格 | 透明 | 分层 / 锚点 / 碰撞 | 复用 | 验收 |
|---|---|---|---|---|---|---|
| G1 地表分块 | 整图地面 | 野外 480×528 共 8 块；城镇 480×480 共 8 块 | 不透明 | 最底层；整张地图画完后再切块；同时交付 1/4 尺寸的行走遮罩 | 只用于本图 | 拼接后看不出接缝；符合地图方案第 2.3 节第 1、2 条；遮罩与路面视觉吻合，误差 ≤8px |
| G1k 材质套件 | 绘制地表用的笔刷与填充 | 草地 3 层 128² 可平铺；土路 128²；路缘笔刷；草舌印章 6 个 | — | 只在绘制阶段使用 | 所有后续地图 | 平铺 3×3 后看不到重复 |
| G2 地表贴花 | 落叶、碎石、车辙、脚印、平放的花 | 8–48px | 透明 | 贴花层，无碰撞 | 高 | 低对比，不比路面更吵 |
| G3 树 | 阔叶大树/中树、针叶树、枫树（绿/橙/红）、幼树 | 见尺寸表；3 种剪影 × 季节色 | 透明 | 拆成**树干底部**（Y 排序，带椭圆碰撞）和**树冠**（上覆层，可渐隐）两片；锚点为树干根部中心 | 高；镜像只限对称树型 | 灰度下树冠能读出受光、中间、暗部三块；根部被草压住 |
| G4 灌木 | 林缘填充、框景 | 40–72 宽，4 种剪影 | 透明 | Y 排序；可带小碰撞 | 高 | 体积感和接触影齐全 |
| G5 草花 | 草簇、蕨、白/黄/橙花组 | 16–40 | 透明 | 贴花层；另做 2 个高草前景版（盖住脚部） | 高 | 3–5 个成组放置，不均匀撒点 |
| G6 岩石/倒木 | 景观收边、地标 | 岩石 24–64，3 种加苔藓版；倒木 104×40；树桩 40 | 透明 | Y 排序，带碰撞 | 中 | 贴地，底部有接触影 |
| G7 水/桥 | 溪流、岸、桥 | 溪面和岸边画进地表；水面高光 3 帧 64×16 贴花；桥 96×140，两态 | 桥透明 | 桥面在水面之上；水面碰撞、桥面可走 | 低 | 受损版和修好版剪影一致，只有楔、绳不同 |
| G8 建筑 | 9 座设施加门楼、城墙、栅栏、井、货摊、夜桌、古枫 | 见地图方案第 3.1 节；占地底面对齐 48 格 | 透明 | 主体走 Y 排序；屋檐、门楼顶拆到上覆层；锚点为占地底边中心；门洞位置要标注 | 城墙、栅栏可复用 | 门洞与主角同屏比例合格；落成/待建两态占地一致 |
| G8u 待建工地 | 未落成设施 | 与对应建筑占地一致 | 透明 | 地基石框、竹脚手架、苫布料堆、告示木牌（名字由 UI 显示） | 7 处共用一套部件 | 一眼能看出是工地，不像 UI 占位 |
| G9 交互物 | 风铃、石匣、草根、路牌、告示牌、承重点标记、桥楔、拒马（开/关）、路灯、驿亭、盐车、石凳、口述册桌 | 32–120 | 透明 | Y 排序；交互点在物件正前方 24–40px；另加一张描边高亮图 | 中 | 在同屏检查板上比例合格；高亮清楚但不刺眼 |
| G10 NPC | 9 名常驻 NPC | 高 64–76（孩童 52）；朝下站立，可选 2 帧待机 | 透明 | Y 排序；锚点在脚底；影子由引擎生成 | — | 与主角像素密度、头身比、光源一致；剪影可互相区分 |
| G11 前端 | 加载/标题/登记背景，以及 UI 物件 | 背景 480×1067（交付 960×2134）；UI 物件见前端方案第 7 节 | 背景不透明，UI 透明 | 9 宫格要标出切线 | — | 中间 480×800 的焦点完整；Logo 区背景安静 |

---

## 3. 母提示词

### 场景母提示词 S0（所有场景条目前缀）

> Original top-down 3/4 view JRPG pixel art, clean hand-placed pixel clusters, crisp edges with no blur or soft anti-aliasing, bright natural daylight from upper-left, short soft contact shadows falling to lower-right, rich natural greens (yellow-green lit grass, mid green, olive, cool blue-green shade under canopies), quiet warm ochre dirt road with irregular worn edges where grass tongues and small tufts invade the path, trees with full layered canopies (bright leaf clumps on top-left, deep shaded underside), visible trunks rooted into grass, grouped bushes, grass tufts, small white and yellow flower clusters, mossy grey rocks, deliberate negative space and a clear scale gradient from large trees to tiny tufts, cohesive believable space. No text, no UI, no watermark, no grid lines, no neon colors, no noisy dithering, no repeated stamp patterns, no camouflage blotches.

### 角色母提示词 C0（NPC）

> Single full-body character sprite for a top-down 3/4 RPG, facing down-front, standing, pixel art with the same pixel density, proportions (about 3.3 heads tall) and upper-left lighting as the attached hero reference image, East-Asian frontier-town fantasy clothing with muted natural dyes and one accent color, dark same-hue outline (not pure black), plain flat #FF00FF background, no shadow, no text.

C0 必须附上现有主角的立绘图作为参考，只用于对齐比例和像素密度。不能生成主角的变体，也不能换掉主角。

### 差异表（S0/C0 前缀 + 下列差异）

| 条目 | 前缀 | 差异内容 | 画幅 |
|---|---|---|---|
| 野外·林门草甸 | S0 | 见完整提示词 P1 | 竖屏 9:20 |
| 野外·溪谷古桥 | S0 | shallow clear stream crossing diagonally, reed and pebble banks, old timber bridge with one missing wedge, loose ropes, small cloth warning strip | 竖屏 |
| 野外·驿亭岔口 | S0 | crossroads with small wooden roadside pavilion, salt cart with sacks, wooden barricade and carved stone marker blocking the east branch | 竖屏 |
| 野外·枫岭林窟 | S0 | half the trees turning orange and crimson maple, fallen red leaves along road edges, old stone lantern in a clearing | 竖屏 |
| 城镇·广场 | S0 | 见完整提示词 P2 | 竖屏 9:20 |
| 城镇·待建工地 | S0 | single building lot on #FF00FF: stone foundation frame, bamboo scaffolding, tarp-covered timber and roof tiles, blank wooden notice board | 方形 |
| 建筑单体 | S0 | one south-facing building only, isolated on #FF00FF, door clearly visible, footprint flat on ground, no surroundings | 方形 |
| 散件表 | S0 | prop sheet on #FF00FF, items spaced apart, each with no shadow: [列出物件] | 方形 |
| NPC | C0 | [身份 + 服饰 + 道具]，例如 steward: elderly town steward, grey topknot, dark blue robe, scroll in hand | 方形 |
| 加载背景 | S0 | 改为 high oblique illustration：P1 的森林路面朝北 S 形伸入林中，远处有红枫，上部 1/3 是树冠间的亮色天光；现有主角背影约占画高 1/9，背着行箧、提着灯走在路上；上部安静，留出 Logo 位置 | 竖屏 9:20 |
| 手记背景（备用） | — | 同 P4 的木桌，行箧换成摊开的空白手记 | 竖屏 |

---

## 4. 关键样板完整提示词（4 条）

### P1 · 野外参考级样板：枫林古道“林门—草甸”

> Original top-down 3/4 view JRPG pixel art game screen, portrait 9:20 composition for a 480×1067 mobile viewport, clean hand-placed pixel clusters, crisp edges, no blur. A quiet warm ochre dirt road enters from the bottom center and bends in a gentle S-curve toward the upper area, about 30% of the frame width, its edges irregular and worn, with grass tongues, small tufts and a few pebbles invading the borders; the road surface is calm with only faint footprints and wheel ruts. At the bottom, two large broadleaf trees frame the road like a natural gate, full layered canopies with bright yellow-green leaf clumps on the upper-left and deep blue-green shade underneath, thick trunks rooted into grass with soft contact shadows to the lower-right. On the left middle, an open sunny meadow with a fallen mossy log, a cluster of white and yellow flowers, a few grass tufts in small groups, and a narrow worn footpath leading to a lone young maple tree with a small old wind chime hanging from a branch. On the right, the forest edge with grouped round bushes of different sizes, a medium tree, a conifer and two mossy grey rocks. Near the top, a glimpse of a clear shallow stream with reed banks and the silhouette of an old timber bridge. Natural bright daylight from the upper-left, layered grass with lit patches and darker shade under trees, deliberate negative space, scale gradient from big trees to tiny tufts. No characters, no text, no UI, no watermark, no grid, no neon colors, no camouflage blotches, no repeating stamp pattern.

用途：作为地表整图和散件拆分的底稿（看画面效果，不直接上线）。树、灌木、岩石、倒木另按“散件表”在品红底上单独重生成。

### P2 · 城镇样板：昭元边城中央广场

> Original top-down 3/4 view JRPG pixel art game screen, portrait 9:20 composition for a 480×1067 mobile viewport, clean hand-placed pixel clusters, crisp edges, no blur. A frontier town plaza in East-Asian fantasy style. Upper-left: the south-facing facade of a council hall, one large single-storey timber building with grey tile roof, red-lacquered pillars, stone steps, wooden door clearly visible, door height about 1.2 times a person. Center: an irregular plaza of worn grey-ochre flagstones with grass growing in cracks and soft worn edges blending into packed earth; a stone well on the left. Right: a huge old maple tree with a full canopy (green with some warm orange clumps), its shade covering a long wooden table with benches and a small lantern. A street enters from the upper right between buildings. Lower-right edge: a building lot under construction with stone foundation frame, bamboo scaffolding and tarp-covered timber. Small planters, crates, a hanging lantern post. Bright morning light from the upper-left, soft contact shadows to the lower-right, warm but natural colors, calm ground and detailed volumes, believable inhabited space with negative space for walking. No characters, no text, no UI, no watermark, no grid, no neon colors.

用途：用来确定建筑比例、铺地质感、古枫和夜桌的样子，以及待建工地的读感。建筑另按“建筑单体”条目逐栋生成。

### P3 · 标题背景：门楼下的启程

> Original pixel art key illustration, high oblique three-quarter view, portrait 9:20 for a 480×1067 mobile title screen, clean pixel clusters, crisp edges. Inside a small East-Asian frontier town, a worn flagstone street with grass in the cracks converges toward a large timber-and-stone north gate tower with grey tile roofs; through the open gate passage a sunlit green forest road is visible, the brightest area of the image, placed in the vertical middle. The existing hero (attached reference: red hair, red cape, dark armor) stands small on the street seen from behind, about one ninth of the image height, facing the gate. Foreground right: a wooden lamp post with a hanging warm lantern and a small dark-lacquered travel case with brass corners. Side buildings with lanterns, crates and potted plants frame the street. Upper area above the gate roof: calm clear morning sky with soft clouds, kept quiet for a logo. Lower quarter: calm street surface, kept quiet for buttons. Morning light from the upper-left, natural foliage painted like the game map (layered canopies, grounded shadows). No text, no logo, no UI, no watermark, no neon.

### P4 · 登记背景：行箧文牒

> Original pixel art still life, top-down view, portrait 9:20 for a 480×1067 mobile screen, clean pixel clusters, crisp edges. A warm wooden table lit by an oil lantern in the upper-left corner, casting soft warm light and shadows to the lower-right. In the center, an opened dark red-brown lacquered travel case with brass corners and leather straps; its inner lid shows part of an old hand-drawn map; resting over the case, a large blank cream-colored travel document sheet with slightly curled edges and a faint paper texture, completely blank with no writing. Small details around the edges: a maple leaf, a brush and ink stone, a coiled rope, a cloth luggage tag tied to the case handle. The central blank document area occupies roughly x 6%–94%, y 20%–55% of the frame, and stays evenly lit for form overlay. No text, no characters, no seals with writing, no UI, no watermark, no neon.

---

## 5. 生成后必查项

| 项 | 方法 | 合格标准 |
|---|---|---|
| 轮廓 | 剪影填黑看 | 每种树、灌木、建筑的剪影都能互相区分 |
| 比例 | 放上同屏检查板 | 符合地图方案第 3.1 节；门、树、狼、宝箱逐一核对 |
| 像素网格 | 放大到 400% | 没有大小混杂的像素，没有半透明糊边 |
| 透明边 | 叠到亮草地和暗石地上各看一次 | 没有品红残边；外轮廓不发白，也不出现黑框 |
| 接缝 | 拼合全部地表块，并把遮罩叠在上面 | 看不到块边；路面和遮罩误差 ≤8px |
| 落点 | 锚点对齐脚底或根部 | 偏差 ≤2px；Y 排序遮挡正确 |
| 光源 | 所有物件并排放 | 受光面都在左上，影子都朝右下 |
| 同屏密度 | 按地图方案第 2.3 节第 4 条清点 | 留白 ≥35%，没有等距成列 |
| 色彩 | 转灰度，并与参考图并排 | 能读出三层明度；没有荧光色；暖绿基调一致 |
| 前端 | 分别按 480×800 和 1067 裁切 | 焦点完整；Logo 区、按钮区背景安静 |

---

## 6. 小批次实施与复审顺序

| 批次 | 内容 | 产出 | 复审门槛 |
|---|---|---|---|
| B0 定调 | P1、P2 各生成 3–4 张备选，选 1 张；定资产族色阶；做同屏检查板 | 样板图、色阶表、检查板 | 用户和美术总监确认基调与比例 |
| B1 野外样板 | 林门—草甸视口：地表 4 块、遮罩、大树 3、中树 2、灌木 4、草花 8、岩石/倒木 4、路牌、风铃孤枫、草根 | 实机截图 | 地图方案第 8 节通过条件 |
| B2 城镇样板 | 广场视口：地表 4 块、议事厅、古枫、夜桌、井、一处待建工地、闻叔与小满 | 实机截图 | 同上 |
| B3 前端（可与 B1 并行，前提是 B0 已定调） | P3、P4 和加载背景；按钮、文牒、行程条 | 三页实机截图 | 前端方案第 7 节 F4 |
| B4 野外补全 | 溪谷两态桥、驿亭岔口与拒马两态、枫岭、北坡、狼的比例修正 | 全图截图 | 可达性验证通过 |
| B5 城镇补全 | 其余 7 座设施（两态）、门楼、城墙、荒院、其余 7 名 NPC | 全图截图 | 可达性验证、旧档恢复测试 |

不允许跳过 B1、B2 的复审直接量产全部地图和 NPC。

---

## 7. 真实运行补拍清单（Codex 实施后，HUD 开/关 × 480×800 / 480×1067）

1. 野外出生：from_city 抵达，相机贴底。
2. 野外：主角走到大树后方，检查树干遮挡和树冠渐隐。
3. 野外：风铃小径终点、草根 b、和 M1/M2 同框的草甸。
4. 溪桥：受损态、修好态；4 个修桥交互点各一张。
5. 驿亭岔口：s12 前拒马加提示、s12 后通行；从旧盐道抵达。
6. 枫岭路灯、北坡出口；从断碑坡抵达。
7. 城镇：北门抵达、广场默认出生、夜桌任务各点、图志阁口述册、南城根荒院。
8. 城镇：待建设施与落成设施各一处，同屏检查门与主角的比例。
9. 旧存档：用 layout 4/3 时期的存档在城镇和野外各读一次，记录恢复后的坐标。
10. 加载页 0%、约 50%、100%；标题页常态/按下；登记页空态、错误态、键盘弹出、导入头像后。
