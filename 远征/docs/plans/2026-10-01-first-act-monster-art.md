# P08-E7 第一幕怪物画风与同源接入（2026-10-01）

关联总方案S0/S2/S4/S7。上一包4949134已完成霜关；本包覆盖六种常见怪、失路兽、影狼，共8张重绘；失声碑灵保留原图并登记裁切。主角重绘后置，背景细腻方向不变。

## 实施规则

主城原幽灵贴图与mon_zombie僵尸名称不符，改为僵尸本体；地图、战斗、图鉴从同一MonsterArt登记来源取图。原PNG保留，原生Atlas按真实alpha轮廓裁切，统一硬边和脚底。原怪物ID/数值/AI/掉落/位置/碰撞/追逐与历练编队规则均不改变。主城僵尸显示高度从118降到76，常规地图沿用已配置62/70等显示高度；主世界普通怪战斗目标高84，其他表现目标沿用原78，首领128，宽度上限防横体怪撑满小屏。固定脚底代替原0.42高偏移；不存在登记的素材走旧逻辑。仅美术字段可改主世界表，故事/技能/经济/存档结构不变。

## 新ID与完整生成提示词

### mon_zombie_reference_v2

参考：D:\new bee\远征\image\main_world\npc_frost_guard_idle_reference_v2.png

Create ONE complete full-body freestanding enemy sprite for a classic Chinese fantasy 2D RPG. Refined crisp pixel painting with small cloth/fur/wood/metal details and a dark-edged silhouette, same restrained detail density and camera as the single character in the style reference, not an illustration with smooth airbrushing and not huge chunky pixel blocks. Standing combat-ready three-quarter view facing toward the lower LEFT, mildly top-down game camera, whole body and all feet/paws/tools visible, stable bottom foot baseline. Character fills a compact square sprite area with transparent padding and room for the whole silhouette. Real alpha transparency outside the sprite. NO painted ground, shadows, background, text, symbols resembling writing, grid, UI, border, frames, multiple poses or extra characters. No photorealistic or 3D render. Avoid blood and gore.

Use the supplied character sheet ONLY as a pixel-painting/camera reference; create exactly one new enemy, no sheet. A shambling ancient undead wanderer, pale grey-green intact skin, clouded eyes, worn faded indigo Chinese cloth tunic and dark loose trousers, frayed sash, weathered shoes, sparse dark hair. Stooped but clearly humanoid, both hands held loosely forward. No floating ghost body, no spectral dress, no glowing aura, no horror gore, no coffin or scenery.

### mon_wolf_reference_v2

参考：D:\new bee\远征\image\generated_101_200\ready\map\mon_wolf.png；D:\new bee\远征\image\main_world\npc_frost_guard_idle_reference_v2.png

Create ONE complete full-body freestanding enemy sprite for a classic Chinese fantasy 2D RPG. Refined crisp pixel painting with small cloth/fur/wood/metal details and a dark-edged silhouette, same restrained detail density and camera as the single character in the style reference, not an illustration with smooth airbrushing and not huge chunky pixel blocks. Standing combat-ready three-quarter view facing toward the lower LEFT, mildly top-down game camera, whole body and all feet/paws/tools visible, stable bottom foot baseline. Character fills a compact square sprite area with transparent padding and room for the whole silhouette. Real alpha transparency outside the sprite. NO painted ground, shadows, background, text, symbols resembling writing, grid, UI, border, frames, multiple poses or extra characters. No photorealistic or 3D render. Avoid blood and gore.

Image 1 defines the existing grey-brown wild wolf species; image 2 is pixel-painting style only, not clothing to copy. Preserve a recognizably ordinary quadruped forest wolf, lean grey-brown fur, alert ears, amber eyes, subtle bared teeth, four grounded paws, tail kept close inside silhouette. Fine fur clusters and readable anatomy, no horns, armor, magic effects or extra heads.

### mon_spider_reference_v2

参考：D:\new bee\远征\image\generated_362_xajh\ready\monster\mon_spider.png；D:\new bee\远征\image\main_world\npc_frost_guard_idle_reference_v2.png

Create ONE complete full-body freestanding enemy sprite for a classic Chinese fantasy 2D RPG. Refined crisp pixel painting with small cloth/fur/wood/metal details and a dark-edged silhouette, same restrained detail density and camera as the single character in the style reference, not an illustration with smooth airbrushing and not huge chunky pixel blocks. Standing combat-ready three-quarter view facing toward the lower LEFT, mildly top-down game camera, whole body and all feet/paws/tools visible, stable bottom foot baseline. Character fills a compact square sprite area with transparent padding and room for the whole silhouette. Real alpha transparency outside the sprite. NO painted ground, shadows, background, text, symbols resembling writing, grid, UI, border, frames, multiple poses or extra characters. No photorealistic or 3D render. Avoid blood and gore.

Image 1 defines the existing forest poison spider species; image 2 is style only. One moss-green/brown woodland spider, exactly eight articulated legs, dark chitin abdomen with restrained green patches, tiny jade venom marks at mandibles. Readable compact silhouette and small detailed chitin plates, all eight leg tips visible. No giant transparent webs, glowing halo, extra limbs or human features.

### mon_treant_reference_v2

参考：D:\new bee\远征\image\generated_362_xajh\ready\monster\mon_treant.png；D:\new bee\远征\image\main_world\npc_frost_guard_idle_reference_v2.png

Create ONE complete full-body freestanding enemy sprite for a classic Chinese fantasy 2D RPG. Refined crisp pixel painting with small cloth/fur/wood/metal details and a dark-edged silhouette, same restrained detail density and camera as the single character in the style reference, not an illustration with smooth airbrushing and not huge chunky pixel blocks. Standing combat-ready three-quarter view facing toward the lower LEFT, mildly top-down game camera, whole body and all feet/paws/tools visible, stable bottom foot baseline. Character fills a compact square sprite area with transparent padding and room for the whole silhouette. Real alpha transparency outside the sprite. NO painted ground, shadows, background, text, symbols resembling writing, grid, UI, border, frames, multiple poses or extra characters. No photorealistic or 3D render. Avoid blood and gore.

Image 1 defines the existing treant; image 2 is style only. One ancient forest tree creature with weathered warm brown bark body, two branch arms, two root-like grounded legs, sparse muted olive leaves close to the crown, a pair of dim amber eyes and a gnarled expressive face in the trunk. Fine bark fissures, small moss patches, compact branches contained near the body. No floating forest landscape, giant sprawling canopy or surrounding trees.

### mon_skeleton_reference_v2

参考：D:\new bee\远征\image\generated_101_200\ready\map\mon_skeleton.png；D:\new bee\远征\image\main_world\npc_frost_guard_idle_reference_v2.png

Create ONE complete full-body freestanding enemy sprite for a classic Chinese fantasy 2D RPG. Refined crisp pixel painting with small cloth/fur/wood/metal details and a dark-edged silhouette, same restrained detail density and camera as the single character in the style reference, not an illustration with smooth airbrushing and not huge chunky pixel blocks. Standing combat-ready three-quarter view facing toward the lower LEFT, mildly top-down game camera, whole body and all feet/paws/tools visible, stable bottom foot baseline. Character fills a compact square sprite area with transparent padding and room for the whole silhouette. Real alpha transparency outside the sprite. NO painted ground, shadows, background, text, symbols resembling writing, grid, UI, border, frames, multiple poses or extra characters. No photorealistic or 3D render. Avoid blood and gore.

Image 1 defines the existing skeleton soldier; image 2 is style only. One old skeleton soldier with worn dull iron helmet, sparse weathered brown leather/iron armor, visible intact ivory-grey skull and bony hands, a small round battered shield and short rusty sword held close. Two grounded feet with worn boots/leg guards. Crisp small bone and metal details, no gore, no huge shield that hides the whole figure.

### mon_goblin_reference_v2

参考：D:\new bee\远征\image\generated_101_200\ready\map\mon_goblin.png；D:\new bee\远征\image\main_world\npc_frost_guard_idle_reference_v2.png

Create ONE complete full-body freestanding enemy sprite for a classic Chinese fantasy 2D RPG. Refined crisp pixel painting with small cloth/fur/wood/metal details and a dark-edged silhouette, same restrained detail density and camera as the single character in the style reference, not an illustration with smooth airbrushing and not huge chunky pixel blocks. Standing combat-ready three-quarter view facing toward the lower LEFT, mildly top-down game camera, whole body and all feet/paws/tools visible, stable bottom foot baseline. Character fills a compact square sprite area with transparent padding and room for the whole silhouette. Real alpha transparency outside the sprite. NO painted ground, shadows, background, text, symbols resembling writing, grid, UI, border, frames, multiple poses or extra characters. No photorealistic or 3D render. Avoid blood and gore.

Image 1 defines the existing goblin raider; image 2 is style only. One small stocky green goblin raider with pointed ears, crooked determined face, worn brown hooded leather vest and belt, a tightly strapped small travel sack, dark footwraps, a compact sling and stone pouch held close. He uses ranged attacks, so no oversized sword or axe. Recognizably the same mischievous forest raider species, fine seams and leather wear, no modern objects or oversized props.

### mon_lost_beast_reference_v2

参考：D:\new bee\远征\image\main_world\mon_lost_beast.png；D:\new bee\远征\image\main_world\npc_frost_guard_idle_reference_v2.png

Create ONE complete full-body freestanding enemy sprite for a classic Chinese fantasy 2D RPG. Refined crisp pixel painting with small cloth/fur/wood/metal details and a dark-edged silhouette, same restrained detail density and camera as the single character in the style reference, not an illustration with smooth airbrushing and not huge chunky pixel blocks. Standing combat-ready three-quarter view facing toward the lower LEFT, mildly top-down game camera, whole body and all feet/paws/tools visible, stable bottom foot baseline. Character fills a compact square sprite area with transparent padding and room for the whole silhouette. Real alpha transparency outside the sprite. NO painted ground, shadows, background, text, symbols resembling writing, grid, UI, border, frames, multiple poses or extra characters. No photorealistic or 3D render. Avoid blood and gore.

Image 1 defines the unique Lost Beast boss; image 2 is pixel-painting style only. Redraw that same distinctive grey-brown shaggy quadruped with moss patches, broken turquoise-veined stone horns, an old wooden courier pack frame tied across its back, a small weathered bronze bell on the neck strap, weary pale eyes and broad heavy grounded paws. Preserve every identity cue and rough travelling-animal silhouette, but use refined crisp pixel textures instead of smooth flat comic illustration. Keep pack/stone horns compact within silhouette; no writing on the pack or bell, no huge light effects.

### mon_shadow_wolf_reference_v2

参考：D:\new bee\远征\image\main_world\mon_shadow_wolf.png；D:\new bee\远征\image\main_world\npc_frost_guard_idle_reference_v2.png

Create ONE complete full-body freestanding enemy sprite for a classic Chinese fantasy 2D RPG. Refined crisp pixel painting with small cloth/fur/wood/metal details and a dark-edged silhouette, same restrained detail density and camera as the single character in the style reference, not an illustration with smooth airbrushing and not huge chunky pixel blocks. Standing combat-ready three-quarter view facing toward the lower LEFT, mildly top-down game camera, whole body and all feet/paws/tools visible, stable bottom foot baseline. Character fills a compact square sprite area with transparent padding and room for the whole silhouette. Real alpha transparency outside the sprite. NO painted ground, shadows, background, text, symbols resembling writing, grid, UI, border, frames, multiple poses or extra characters. No photorealistic or 3D render. Avoid blood and gore.

Image 1 defines the Shadow Wolf summoned by the Lost Beast; image 2 is pixel-painting style only. Redraw the same dark indigo/purple quadruped shadow wolf with pointed ears, small cyan eyes, narrow turquoise fissures across the back and restrained purple wisps close to paws/tail. Fine crisp fur clusters and pixel-edged wisps instead of smooth painterly smoke. Four paws grounded and readable, same three-quarter left-facing wolf anatomy, a few small broken dark-stone plates close to shoulders, no giant smoke island, halo or background.

