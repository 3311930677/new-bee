# 《远征》地图与NPC · 资产重建制作说明（首轮样板）

方向与同屏规范见 `WORLD_ART_DIRECTION.md`。下文的「显示 px」都按 480 宽视口计；凡标「推荐」或「待验证」的数值都没有经过工程实测，由 Codex 接入时核对。

## 一、首轮样板（只做这 6 件，验收通过后再推广）

| 样板 | 为什么能代表后续资产 |
|---|---|
| S1 执事（文职 NPC） | 主线任务目标，以宽袖长袍和非武器道具为主。可以验证布料、手部、受控调色和「局部呼吸」待机；图志记录员、导师、马厩管理都可直接套用 |
| S2 巡界人（守卫 NPC） | 有甲胄、长兵器，轮廓超出头顶。可以验证武器不扭曲、长道具留白和描边；可推广到行脚旅人和其他武职 |
| S3 昭元城镇地表/道路段 | 首屏面积最大的问题。可以验证地表降噪、路缘过渡、平铺接缝和明度层级；城镇类地域都复用这套结构 |
| S4 枫林古道地表/土路段 + 枫树 + 岩石组 | 一次验证野外地表、地域标识植被、干冠分层遮挡和岩石压边；各野外地图的结构模板 |
| S5 城镇代表建筑一栋（边城木构屋／执事署，对应城中现有建筑位置之一） | 建立屋顶、立面、墙基、落影和 Y 排序锚点的规则；但须在「显示问题核实」之后再定是修还是重绘 |
| S6 路牌修整（交互物） | 成本最低，用来验证交互物与地表、人物之间的层级，以及接触影规范 |

主角不重做。只有当样板对比时，主角的描边色或光向明显成为统一障碍，才单列为可选依赖：只调描边色和阴影色，不改造型。

## 二、资产清单

**P0（首轮样板）**

| 资产/族 | 用途 | 当前问题 | 处置 | 源规格 | 最终显示 | 透明 | 平铺/分层 | 锚点 | 依赖 | 验收 |
|---|---|---|---|---|---|---|---|---|---|---|
| S1 执事待机 | 主线 NPC | 4 帧只有整体平移 1px，脚底浮动；每帧约 4100 色 | 重绘 | 512×128，4×128 横排 | ×0.64，约 82px 画布 | 二值 alpha | 单层 | 中心 x=64，脚底最低不透明行 y=123，四帧一致 | 显示倍率与采样核实 | 四帧外框底边都=123；色数 ≤48；与主角同屏时高约为主角的 0.85–0.95 倍 |
| S2 巡界人待机 | 城门守卫 | 同 S1；每帧约 3400 色 | 重绘 | 同 S1 | 同 S1 | 二值 | 单层 | 同 S1；矛尖可到 y≥4 | 同上 | 同上；矛杆四帧形状一致，偏移 ≤1px |
| S3 城镇地表/道路 | 底层地面 | 发软、高色数、细节均匀 | 重绘 | 推荐 48×48 瓦片 1:1：草底 4 变体、路面 4 变体、草↔路 16 块角点过渡（或 47 块 blob，由 Codex 按 TileSet terrain 定） | 1 格=48 显示 px（**待验证**相机缩放） | 不透明 | 平铺 | 无 | 过滤设为 Nearest | 3×3 平铺无接缝；整套色数 ≤20；灰度图中路与草差 ≥1 阶 |
| S3b 城镇地被散件 | 草簇、花丛、碎石 | 现为均匀撒点 | 重绘 | 24×24 / 48×48 | 1:1 | 二值 | 叠加散件，不烧进瓦片 | 底边中心 | S3 | 每屏花丛 ≤2 簇，草簇成团 |
| S4 枫林地表/土路 | 野外底层 | 无地域感，路读不清 | 重绘 | 同 S3 结构；另加落叶路缘过渡 | 同 S3 | 不透明 | 平铺 | 无 | 同 S3 | 同 S3；路缘落叶集中，路心安静 |
| S4b 枫树 | 地域标识与框景 | 缺失 | 新绘 | 推荐：树干底座 64×80，树冠 176×144（两张图） | 1:1；整树高约为主角的 2.5–3 倍 | 二值 | 干：Y 排序；冠：独立上层 | 干：树根中心；冠：与干对位的偏移量由 Codex 记录 | 冠是否遮挡淡出＝工程确认项 | 冠下主角可辨（淡出或摆位）；不改碰撞 |
| S4c 岩石组 | 弯道压边 | 缺失 | 新绘 | 小 24、中 40、大 64 宽，各 2 变体 | 1:1 | 二值 | 散件 | 底边中心 | — | 3–5 块成组，接触影贴地 |
| S5 城镇建筑 | 地点身份 | 半透明空壳、裁切（成因待核实） | 核实后修或重绘 | 推荐占地 4×3 格，图约 192×224 | 1:1 | 二值；落影另出一层 | 主体：Y 排序；落影：地表上一层 | 正立面墙基中点 | 显示问题核实 | 实心、完整屋顶、墙基贴地；与塔楼同屏不违和 |
| S6 路牌 | 交互物 | 基本达标 | 修整 | 沿用现源 | 沿用 | 二值 | 单层 | 底座中心 | — | 描边改为暗色同色相，接触影合规 |

**P1（样板通过后）**：塔楼修整（降饱和、补墙基影、量化调色）；木栅、货箱、灯柱道具组（2–4 件成组，灯柱是唯一用灯金的地方）；孩童和铁匠修整（锁脚底、局部呼吸、量化到 ≤48 色；孩童可见高 75–85 源 px）；城中另外三栋建筑；野外灌木与倒木；统一接触影的三种尺寸（推荐 32×10、48×14、64×18）。
**P2**：图志记录员、兽栏照料、导师、马厩管理、行脚旅人（以 S1/S2 为模板）；其他地域按复用规则推广；环境动效（旗幡、落叶，每屏 ≤2 处）；敌人（如野狼）按同屏规范对齐，另立范围。霜关 NPC 使用独立帧区域和注册规则，不套用本接口。

## 三、NPC 制作规范

- **身份辨识**：执事＝宽袖长袍、发冠、簿册；巡界人＝短甲、红头巾、长矛；工匠＝皮围裙、锤、粗臂；孩童＝短褂、背小包、头身比更大。人物之间的差异（体型、年龄、胡须）保留，不同 NPC 的主色要错开。
- **帧条一致性**：同一条内身高、宽度、朝向（正面略偏左 3/4）、光源（左上）完全一致；四帧下半身像素逐一相同。只允许：胸肩与头 1px 起伏，衣摆、头巾、发梢 1–2px 摆动，眨眼最多 1 帧。禁止整体平移、换脸、变装，手指和武器形变 >1px 也不行。
- **尺寸**：成人可见高 106–116 源 px（×0.64 ≈ 68–74 显示 px）；孩童 75–85 源 px；壮汉体型靠宽度体现，可见高度不超过成人上限。
- **像素**：最小细节簇 2 源 px（显示约 1.3px）；描边 2 源 px，用 selout；五官最少 2×2；全身 ≤48 色，不用渐变噪点。

## 四、场景资产族与拼接

- **资产族**：① 可平铺地表（底色变体）② 道路过渡（角点或 blob）③ 地被散件（草簇、花、落叶、碎石）④ 遮挡物（建筑、树干、岩石，走 Y 排序）⑤ 上层遮挡（树冠、屋檐，独立层）⑥ 交互物（路牌、宝箱、告示牌）⑦ 光影（接触影、建筑落影单独成层）。NPC、名牌、任务箭头、UI 文字一律不烧进底图。
- **主世界如果继续用整张底图**：底图只画地表和道路（不含任何建筑、树、人物）；绘制前由 Codex 从当前地图导出同比例的「碰撞/出口/交互点」参照层，路中线、路宽都按参照层画；整图切块时块间留 48px 重叠，接缝用地被散件压住；建筑和树一律作为散件放在上面，遮挡边界取散件墙基线，不靠底图画墙。
- **其他地域复用公式**：每个地域 = 1 套地表色带（≤20 色）+ 1 种标志植被或岩体 + 1 种屋顶/墙材 + 1 种点缀色。网格、描边、光向、明度分区、人物比例全部不变。旧港口图只能作为背景参考，其色带**待验证**。

## 五、母提示词

**场景母提示词（SCENE_MASTER）**
```
Game asset for a top-down 3/4 view pixel-art RPG (portrait mobile, ancient frontier-town travel fantasy). Hand-placed pixel art, crisp hard pixels, no anti-aliasing blur, no gradients, no noise texture, no photo texture. Top-left key light, soft warm shadows to the lower-right. Natural regional colors, mid-low saturation and limited palette (about 16–24 colors for the whole sheet), detail clusters 2–3 pixels, ground contrast lower than characters. Orthographic 3/4 view: building fronts face the camera, roofs visible; no vanishing-point perspective, no isometric 2:1. Flat solid #FF00FF background for anything that is not a full tile. No text, no letters, no UI, no icons, no arrows, no watermark, no signature, no characters, no frame border.
```

**NPC 母提示词（NPC_MASTER）**
```
Pixel-art NPC idle animation sprite sheet for a top-down 3/4 view mobile RPG, chibi-leaning proportions (about 3 heads tall), same rendering style as a crisp detailed hero sprite. Exactly 4 frames in one horizontal row, equal square cells, the same single character in every frame: identical face, outfit, colors, size, and facing (front, slightly turned 3/4 to the left). Feet planted at exactly the same baseline in all frames; lower body pixel-identical across frames; only subtle breathing (chest/shoulders/head move 1 pixel) and 1–2 pixel cloth sway. Top-left light. Limited palette (max ~48 colors), 2-pixel clusters for small details, dark colored outline (not pure black), no gradients, no blur, no glow. Flat solid #FF00FF background, no ground, no cast shadow, no text, no UI, no name tag, no watermark, no extra characters or props outside the cell.
```

## 六、差异表（所有资产统一套用对应母提示词）

| 资产 | 母提示词 | 差异内容（追加到母提示词后） |
|---|---|---|
| S1 执事 | NPC | 见完整提示词 P1 |
| S2 巡界人 | NPC | 见完整提示词 P2 |
| 孩童（P1） | NPC | child about 7 years, short brown tunic with red sash, small satchel, topknot with red ribbon, bigger head ratio, cheerful; same height in all frames |
| 铁匠（P1） | NPC | burly old smith, white beard, leather apron, bare muscular arms, sledgehammer on right shoulder; hammer shape identical in all frames |
| 图志/导师/马厩/兽栏/旅人（P2） | NPC | 只替换服装与道具：卷轴笔匣／长杖素袍／缰绳草帽／饲料桶皮手套／宽檐帽行囊，主色彼此错开 |
| S3 城镇地表 | SCENE | 见完整提示词 P3 |
| S4 枫林地表 | SCENE | same tile layout as town set; forest floor grass in muted olive-green with ochre patches, packed reddish-brown dirt trail, edge transition with scattered maple leaves (vermilion, ochre) concentrated along trail edges, trail center clean |
| S4b 枫树 + S4c 岩石 | SCENE | 见完整提示词 P4 |
| S5 城镇建筑 | SCENE | single frontier town house, rammed-earth walls, dark wood frame, blue-grey clay tile roof with upturned eaves, stone foundation, one wooden door and one lattice window facing camera, empty signboard frame (no writing), footprint about 4×3 tiles, separate soft shadow on the lower-right as a second sprite |
| 塔楼修整（P1） | — | 不生图；对现有塔楼做降饱和、调色量化和补墙基影 |
| 木栅/货箱/灯柱（P1） | SCENE | weathered fence segments (straight, corner, end), 2 crates, 1 barrel, 1 lantern post with warm gold lamp as the only bright accent |

## 七、首轮完整生图提示词（4 条）

**P1 · 执事待机帧条**
```
[NPC_MASTER 全文] Character: elderly town steward of a frontier city, kindly round face, grey hair in a small topknot under a black official cap, short grey beard, wide-sleeved layered robe in rust-brown and ochre with a cream inner collar and a deep red sash, holding a thin bound ledger against the chest with the left arm, right hand resting on the belly. Calm, dignified, slightly plump. Idle: frame 1 neutral, frame 2 chest and head up 1 pixel, frame 3 neutral, frame 4 sleeves sway 1 pixel; feet and robe hem fixed. 4 frames, layout 4×1, equal cells.
```

**P2 · 巡界人待机帧条**
```
[NPC_MASTER 全文] Character: frontier patrol guard, sturdy adult man, short black beard, red cloth headband with trailing tails, brown leather lamellar vest over a dark red tunic, small iron shoulder plates, bracers, boots, holding a long spear upright in the right hand with the spearhead above the head, left hand on belt. Alert stance, feet shoulder-width. Idle: chest rises 1 pixel on frames 2 and 4, headband tails sway 1–2 pixels; spear shaft completely straight with the same length in every frame, hands do not change shape, feet fixed. 4 frames, layout 4×1, equal cells, spear fully inside each cell.
```

**P3 · 昭元边城地表/道路瓦片表**
```
[SCENE_MASTER 全文] Seamless ground tileset sheet for a frontier town, square tiles on a strict grid with no gaps: row 1: 4 variants of short trimmed grass (muted sage-green, quiet, only small 2–3 pixel tufts, no flowers); row 2: 4 variants of packed pale-ochre earth road, very quiet center, faint cart ruts; rows 3–6: a 16-tile corner-based transition set between grass and road, the road edge has a 1-pixel darker seam and grass blades slightly overhanging the edge. Low contrast inside each tile (max 2 value steps), no repeated obvious motif, no stones larger than 3 pixels, no objects. Every tile must tile seamlessly with its neighbors.
```

**P4 · 枫树（干冠分离）+ 岩石组**
```
[SCENE_MASTER 全文] Sprite sheet on flat #FF00FF background, items separated by clear empty space: (A) two maple tree trunk bases with visible roots and the lower trunk only, rooted on a small patch of ground; (B) two matching separate maple canopies seen from 3/4 top view, clustered leaf masses in vermilion-red, warm ochre and a little deep green, darker underside, top-left highlight, irregular but readable silhouette, no individual floating leaves; (C) a set of grey-brown weathered rocks: two small, two medium, two large, flat bottoms sitting on the ground, moss on top-left. Canopy and trunk drawn so they can be stacked: canopy bottom-center aligns over trunk top-center. Hard alpha edges only.
```

注意：生图工具不能保证一次产出严格的像素规格，上面的提示词只决定风格；最终尺寸、网格和调色由导入前处理保证。

## 八、导入前检查（不满足的不接入）

1. 统一尺寸：用最近邻缩放到规定的源规格（NPC 512×128；瓦片 48×48），不得出现非整数采样造成的双线。
2. 调色：量化后 NPC ≤48 色、单套地表 ≤20 色；不允许出现 1 像素孤立噪点群。
3. Alpha：只有 0/255，品红背景去净，边缘不残留品红。
4. NPC：四帧外框底边都等于 y=123，中心 x 偏差 ≤1；下半身逐像素一致；脸、服装、武器长度的逐帧差异只在允许范围内。
5. 瓦片：3×3 自拼与过渡拼接无可见接缝；灰度化后路与草相差 ≥1 阶。
6. 全部资产中无文字、无 UI 图形、无水印。
7. 导入设置：纹理过滤 Nearest，关闭 mipmap 与有损压缩（具体设置由 Codex 按工程现状确认）。

## 九、Codex 执行顺序

| 步 | 内容 | 完成判据 |
|---|---|---|
| 0 基准 | 在 01、02 的同一位置和视角重新截图（480×800，另加 480×1067）；实测主角显示高度、1 格显示像素、NPC 倍率与采样方式 | 记录表给出实测值，替换本文所有「待验证」 |
| 1 排除显示问题 | 查城中四处半透明木构的 alpha、modulate、淡出、遮罩与层级；查地表过滤、mipmap、缩放和压缩 | 每处给出成因结论和修正后截图；建筑修复后若已完整、实心，就从「重绘」改为「修整」 |
| 2 接入样板 | S1–S6 通过导入前检查后，只在样板视口范围内替换；碰撞、出口和交互点不动 | 运行无报错；碰撞与交互回归（走通路、点路牌、和执事对话）全部正常 |
| 3 同视角比较 | 补拍 2–3 组前后对比：城（01 位置）、野（02 位置）、执事与主角同框近景 | 对照规范表逐项打勾：比例、色数、四帧脚底不动、灰度下人物和交互物最突出、每屏亮点 ≤3 组 |
| 4 修正 | 按对比结果只修样板，最多一轮；交 Cloud 用 `PROMPT_CLOUD_SAMPLE_REVIEW.md` 做限定验收 | Cloud 验收通过，或明确列出剩余问题 |
| 5 推广 | 验收通过后按 P1 → P2 和地域复用公式推广 | 每推广一族都补拍同视角截图并过同一张清单；**首轮没通过前，不批量重绘地图和 NPC** |
