# V1 内置imagegen完整提示词

全部使用内置工具，未使用CLI/API密钥。原始输出保留于Codex生成目录；选中图已复制入项目并接入运行时。

## 主城地表初稿（v3，候选）

输入：原草地图为编辑目标，参考录屏042帧仅提供风格。

Edit target: image 1 is the existing ground-only map asset for an RPG. Image 2 is a STYLE REFERENCE ONLY, a phone recording of a classic low resolution Chinese fantasy mobile pixel RPG; exclude its UI, people and buildings. Redraw image 1 into coherent early mobile-game pixel art matching image 2's quiet large color clusters, muted grassy green palette, modest 3-4 tone shading and clean pixel edges. Retain image 1's straight-ish continuous north-south middle walking path, its position and width, the broad empty buildable grass on both sides, and full map coverage. Make the path pale green-gray irregular rounded cobblestones, with chunky subdued shapes and soft stepwise pixel shadows; grass mostly calm olive/light-green clusters and only a very few tiny tufts. Original visual interpretation, not a copy of the reference tiles. True low resolution pixel art, uniformly chunky 2-4px pixel blocks at this asset's output size, no subpixel/antialiasing, no fine stipple/noise, no dramatic highlights, no painterly gradients. Flat overhead ground seen in a 3/4 RPG camera. No buildings, characters, props, shadows of people, labels, text, UI, borders or watermarks. Ground texture should remain visually quiet behind sprites. Preserve full portrait canvas and path continuity from top to bottom. This is a runtime ground bitmap, not a game screenshot or mockup.

## 主城地表迭代（v4，接入）

输入：v3候选，修改粒度并保持主街几何。

Refine ONLY the visual granularity of this ground-only pixel RPG map. Keep the north-south path's overall POSITION, WIDTH and continuity unchanged. Keep the muted grass-green and pale green-gray stone palette, the low-noise ground and no buildings/people/UI. The current output has enormous one-stone-wide path boulders and enormous angular grass patches. Instead draw a finely structured classic 16-bit mobile-RPG field: path made of 4-6 small rounded stones across its same width, each cobble about 12-20 pixels wide at the output asset scale, staggered, moderate outline/shadow, restrained 3 tones. Grass has smooth large calm fields broken by smaller soft-edged pixel clusters, avoid checkerboards and large angular camouflage blotches. Use sharply controlled 1-2px edge steps at output resolution rather than oversized 8px voxel blocks. A few small grass tufts, no flowers or busy stippling. The art should look like an original classic Chinese mobile fantasy RPG ground layer, not an 8-bit landscape or an illustration. Flat overhead ground, no perspective depth gradient. Preserve full portrait canvas aspect ratio. No text, border, entities, buildings or UI.

项目路径：image/main_world/lorin_wilds_reference_v4.png。

## 战斗地表初稿（未选用）

Create a runtime BACKGROUND bitmap for a classic 16-bit Chinese mobile fantasy RPG combat scene, portrait 3:5 composition. The entire image is an unobstructed flat grassy stone ground plane seen from above in an RPG 3/4 camera. Muted gray-green / moss green / pale sage palette, quiet broad fields with occasional faint groups of small rounded flagstones; crisp 1-2px pixel edge steps and restrained 3-4 shading tones. The background must be visually calm behind small character sprites. Ground pattern is consistent across the whole canvas; NO horizon, scenery, perspective vanishing point, buildings, trees, paths, roads, rail tracks, bushes, boulders, actors, shadows of actors, UI, text, borders or watermarks. No stipple/noise, no camouflage blotches, no painterly gradients or elaborate lighting. Fine but deliberately arranged pixel clusters rather than millions of textured pixels. Original early mobile-RPG art, inviting natural flat ground; a clean combat arena without any arena border.

## 战斗地表减噪（接入）

输入：战斗地表初稿。

Change ONLY the texture density of this background. Remove at least 95 percent of all scattered dark speckles, light speckles, mottled patches and grass tuft textures. The result MUST be predominantly FLAT QUIET light sage/olive green (#a8b97a) occupying almost the entire canvas, with a subtle repeating pattern of low-contrast rounded paving shapes (each shape 24-32 output pixels wide, only 1-2 neighboring green shades). The ground should read like the clean green terrain in an early Chinese mobile pixel RPG, not a textured lawn photograph and not camouflage. Leave a very broad clean middle area for combat sprites. Do not add gradients, vignette, light direction, road, buildings, actors, text or UI. Preserve exact portrait dimensions. Minimal decorative pixels, no granular noise. Large uniform color fields are required; sharp pixel steps on the few shallow stone outlines.

项目路径：image/main_world/classic_floor_reference_v1.png。

## 用户追加：背景细化、主角暂缓

主城v5、战斗v2与锻造铺v2的完整提示词见同目录 `2026-10-01-reference-style-refinement.md`，保留版本化图片和原资产，不以改变主角素材适配背景。
