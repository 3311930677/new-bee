# 背景细化与建筑样板（2026-10-01）

用户追加：主角不急于重绘，其余自主调整，背景不要过于粗糙。

## 主城v5

Use case: style-transfer. Asset type: runtime ground-only background for a Chinese fantasy mobile RPG. Image 1 is the EDIT TARGET, the currently used town ground; image 2 is STYLE REFERENCE ONLY, a game recording, ignore all its people/buildings/UI/phone overlay. Refine image 1 to be finely crafted and smoother, less coarse. Preserve its portrait aspect, exactly the center north-south path location and overall width, both open grass sides and full map coverage. Replace enormous boulders with much smaller evenly fitted rounded paving stones: about 6 stones across the EXISTING same-width path, stone widths 15-22 output pixels, light sage/gray color, shallow fine joints and very restrained shadows. Stone outlines must feel delicate, no black outlines, no chunky raised rock highlights. Grass should be continuous calm green, with subtle fine 1px pixel-art transitions between just 3 nearby colors, a few fine blades at the road edges, no angular block mosaic, no square dither or scattered bright speckles; avoid flat crude blankness as well. Preserve a few tiny elegant tufts, reduce their dark outlines. Match the reference's gentle readable classic mobile RPG ground with carefully rounded paving rather than exaggerated 8-bit chunky blocks. Crisp fine pixel clusters at native resolution, no oversized pixelation, no 3D bevel, no painterly brush smears or photographic grass. Top-down shallow 3/4 RPG ground, no perspective gradient. Do not add any buildings, people, props, labels, letters, UI, text, borders or watermark.

## 战斗地表v2

Use case: precise-object-edit. Edit this runtime RPG combat ground background to look more finely finished and less crude. Keep the portrait canvas, subdued light sage-green palette, flat overhead ground, and complete absence of characters/buildings/UI. Remove two thirds of the paving-stone clusters and break their artificial evenly spaced grid rhythm. The few remaining paving groups should have smaller, delicately rounded stones, almost no dark contour, only neighboring light sage-gray tones and shallow joints, no chunky coarse stair-step borders. Grass should have understated fine crafted pixel-art tonal variation in broad clean fields, no granular noise, no large dither squares, no mushy photographic or watercolor texture, no lighting vignette or glowing gradient. Leave an especially calm broad center for combat sprites. It should read like a refined classic Chinese mobile pixel-RPG field, with sufficient fine detail to feel finished rather than an empty colored placeholder. No roads, tracks, horizons, props, text, border or watermark. Preserve aspect ratio.

## 锻造铺v2

Use case: style-transfer. Image 1 is the EDIT TARGET: the existing forge building sprite; image 2 is STYLE REFERENCE ONLY, ignore its people/UI/phone overlays. Refine the forge into the reference's classic Chinese mobile RPG style, retaining the existing single building's identity: red-brown tiled roof, brown timber walls, stone chimney on the right, open working forge area with anvil and restrained orange furnace glow. Keep the same shallow 3/4 viewpoint facing down-right, door and base location, full building visible and similar wide silhouette, but simplify the overcrowded tiny barrels, hanging ornaments and micro-carvings into a few readable, well-crafted forms. Use moderate 16-bit sprite detail with small crisp pixel clusters, soft muted warm wood and clay roof tones, subtle 3-tone materials, no exaggerated gold edge highlights and no oversaturated orange glow. Fine craftsmanship, not coarse giant pixel blocks and not a photoreal/painterly 3D rendering. The entrance needs to be clear and the silhouette easy to read at approximately 190px wide in a game. Keep a modest continuous stone base, no landscape ground or cast shadow beyond that base. Output exactly one isolated building centered with transparent background and a small even transparent margin. No NPCs, letters, signs with text, watermarks, frame or UI. Preserve real alpha transparency.

## 接入与验收

### 主城草地v6迭代

Use case: precise-object-edit. Image 1 is EDIT TARGET, a town ground map; image 2 is supporting STYLE REFERENCE ONLY for the fine quiet grass texture. Change ONLY the grass texture in image 1 to the quieter grass handling of image 2. Keep image 1's middle stone path exactly, all stones and path width/position/geometry unchanged, keep the tiny isolated grass tufts where they are. Remove 90 percent of the small yellow-green square flecks and angular mottled grass texture patches from image 1. Replace the grass surrounding the road with broad continuous muted green fields and only extremely subtle finely shaped tonal clusters, much smoother and calmer, delicately crafted fine 1px transitions. This is a finished classic mobile-RPG ground, not a blurry photograph or crude flat color. No oversized pixel blocks, harsh checker dither, grain, speckle, thick contours or brush smears. Preserve canvas dimensions/aspect and avoid any added paving groups from image 2. No people/buildings/text/UI.

### 锻造铺透明边界迭代

Refine ONLY transparency and lighting of this existing isolated forge sprite. Preserve the building geometry, roof, chimney, door, tools, composition and pixel detail exactly. Completely REMOVE the large soft halo, dark background gradient and ambient orange glow surrounding the building. All pixels outside the stone base and building silhouette must be fully transparent with alpha 0; not dark translucent color. Building walls, roof, chimney and stone base must be solid opaque alpha 255 with crisp hard sprite boundaries. Keep orange glow confined to INSIDE the furnace opening, and small lamp windows only, no bloom spreading onto the ground or background. No soft shadow under/outside the base. Reduce the excessively shiny yellow edges to muted tan wood and stone highlight tones, without changing geometry. Output true RGBA transparent background, no backdrop or checkerboard burned into image. No characters, text or UI.

已接入 `lorin_wilds_reference_v6.png`、`classic_floor_reference_v2.png`、`city_forge_reference_v2.png`。主城v5仍有偏密草色碎斑，作为候选保留；v6单独减草地纹理，石路保持浅色细边。森林战斗地表减少人工等距石圈，增加低对比细草层次。锻造铺重绘并修正透明边界，运行时按原宽度等比显示；保留建筑身份、原碰撞/交互位置与商店功能。其他已有贴图建筑的落地影透明度由0.30降到0.20，减少黑色大底盘。

主世界NPC显示比例由0.72调整为0.64，并保持脚底原点；原呼吸四帧与互动逻辑保留。名牌改硬边无软投影，儿童保持较低名牌位置。**主角图片/动画和本轮之前的显示比例完全不改**。

实际样板又发现下方旅人的头顶名牌会盖到主角身体；名牌避让现在同时保护主角名牌和身体轮廓，位置移开后正常恢复。专项测试覆盖下方压身隐藏与侧面走近显示，保留NPC实体和交互。

首轮41项回归中40项通过，`VerifyMainWorld`发现成人NPC名牌下移后与主角名牌相交，被原有避让规则隐藏。成人名牌恢复原安全高度后，主世界/城镇/UI布局三项复验 **3/3 ALL GREEN**。同目录截图清单列出全部41个测试的最近通过日志，**没有宣称修复后重新跑过第二轮全量回归**。引擎退出时资源诊断issue43仍存在。

[六张双尺寸实际截图](../../shots/style_refine_20261001/README.md)已目视检查；正式玩家存档SHA256保持 `C5D29EE55C033619C4F5232D55A6C4F186D40ADD556DB61EE0D776B9FDA2660C`。截图是隔离档构图，战斗暂停，不是新一轮主线通关证据。资产、主角保留哈希、截图与测试日志清单见同目录 `acceptance.json`。

本批只替换昭元地表、森林对阵地表及一座锻造铺建筑。其他建筑、普通怪、港口/第三幕素材与后续场景仍需继续统一；主角重绘按用户要求暂缓。地表的铺石粒度仍可继续校准，当前先解决强高光、密碎斑和粗描边，不把候选缩放或一次生成当作整套美术验收。
