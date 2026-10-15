# 断碑坡素材生成提示词

方式：当前内置 image_gen；用户已同意无需指定 image2.5。参考：已通过的 BS-00 量化图。下列为 34 张选用原图的生成提示词。背景采用文档允许的品红底备选，输出实际情况见 QA_REPORT.md。

## bs_g01_a_grass.png

批次：P1

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
[VIEW-G]
CAMERA: strictly orthographic, looking straight DOWN at exactly 90 degrees, like a flat 2D game map
tile or a satellite tile. The ground is ONE perfectly flat plane. There is NO horizon, NO perspective,
NO vanishing point, NO depth shrinking, NO tilt, NO aerial landscape-illustration look, NO depth of
field, NO haze, NO vignette. Nothing is shown from the side: no cliff faces, no vertical walls,
no waterfalls, no raised terraces, no bridge arches. Height differences are NOT drawn at all.
Every point of the image has exactly the same scale.
Seamless tileable top-down ground texture, canvas 1024x1024 (256x256 art pixels), wraps perfectly on
all four edges, no focal point, no large objects, max 8 colors. Even distribution.
Variant (a): short meadow grass of sage/olive greens built from small tuft clusters in three value layers.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1024x1024 pixels, PNG.
CRITICAL TEXTURE CONTENT OVERRIDE: only very short meadow grass. Absolutely NO flowers, NO red leaves, NO stones, NO boulders, NO dirt patches, NO tall grass clumps. 65 percent plain sage-green areas, occasional low tiny 6-14 art pixel tuft clusters. Never dense scattered single-pixel noise. Use ONLY eight muted green colors. Reference objects must NOT appear. Exact SQUARE 1024x1024.
```

## bs_g01_b_dirtroad.png

批次：P1

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
[VIEW-G]
CAMERA: strictly orthographic, looking straight DOWN at exactly 90 degrees, like a flat 2D game map
tile or a satellite tile. The ground is ONE perfectly flat plane. There is NO horizon, NO perspective,
NO vanishing point, NO depth shrinking, NO tilt, NO aerial landscape-illustration look, NO depth of
field, NO haze, NO vignette. Nothing is shown from the side: no cliff faces, no vertical walls,
no waterfalls, no raised terraces, no bridge arches. Height differences are NOT drawn at all.
Every point of the image has exactly the same scale.
Seamless tileable top-down ground texture, canvas 1024x1024 (256x256 art pixels), wraps perfectly on
all four edges, no focal point, no large objects, max 8 colors. Even distribution.
Variant (b): packed ochre dirt road surface, slightly lighter in the center, sparse tiny pebbles, faint wear marks.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1024x1024 pixels, PNG.
Only packed earth texture; NO vegetation, flowers, red leaves, road borders or large rocks. Full-bleed square surface, not an illustration of a path.
```

## bs_g01_c_gravel.png

批次：P1

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
[VIEW-G]
CAMERA: strictly orthographic, looking straight DOWN at exactly 90 degrees, like a flat 2D game map
tile or a satellite tile. The ground is ONE perfectly flat plane. There is NO horizon, NO perspective,
NO vanishing point, NO depth shrinking, NO tilt, NO aerial landscape-illustration look, NO depth of
field, NO haze, NO vignette. Nothing is shown from the side: no cliff faces, no vertical walls,
no waterfalls, no raised terraces, no bridge arches. Height differences are NOT drawn at all.
Every point of the image has exactly the same scale.
Seamless tileable top-down ground texture, canvas 1024x1024 (256x256 art pixels), wraps perfectly on
all four edges, no focal point, no large objects, max 8 colors. Even distribution.
Variant (c): blue-grey gravel and broken stone chips mixed with dirt.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1024x1024 pixels, PNG.
Only gravel ground, no grass, no flowers, no red leaves, no isolated big boulders. Small stone chips seen straight down, no directional rock shadows.
```

## bs_g01_d_flagstone.png

批次：P1

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
[VIEW-G]
CAMERA: strictly orthographic, looking straight DOWN at exactly 90 degrees, like a flat 2D game map
tile or a satellite tile. The ground is ONE perfectly flat plane. There is NO horizon, NO perspective,
NO vanishing point, NO depth shrinking, NO tilt, NO aerial landscape-illustration look, NO depth of
field, NO haze, NO vignette. Nothing is shown from the side: no cliff faces, no vertical walls,
no waterfalls, no raised terraces, no bridge arches. Height differences are NOT drawn at all.
Every point of the image has exactly the same scale.
Seamless tileable top-down ground texture, canvas 1024x1024 (256x256 art pixels), wraps perfectly on
all four edges, no focal point, no large objects, max 8 colors. Even distribution.
Variant (d): old flagstone pavement, each slab about 28-40 art pixels, cracks between slabs filled with moss.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1024x1024 pixels, PNG.
ONLY a flat overhead paving texture. Moss in joints, no flowers, no red leaves, no standing objects. Same slab scale everywhere.
```

## bs_g03_a_earth_straw.png

批次：P1

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
[VIEW-G]
CAMERA: strictly orthographic, looking straight DOWN at exactly 90 degrees, like a flat 2D game map
tile or a satellite tile. The ground is ONE perfectly flat plane. There is NO horizon, NO perspective,
NO vanishing point, NO depth shrinking, NO tilt, NO aerial landscape-illustration look, NO depth of
field, NO haze, NO vignette. Nothing is shown from the side: no cliff faces, no vertical walls,
no waterfalls, no raised terraces, no bridge arches. Height differences are NOT drawn at all.
Every point of the image has exactly the same scale.
Sprite sheet G03-A of organic ground-material patches for a pixel RPG field map, canvas 1536x1024
(384x256 art pixels), 3 columns x 2 rows, each patch 96-128 art pixels wide with a ragged, irregular
HARD-PIXEL edge (never a circle or ellipse), transparent outside, no two shapes alike:
3 patches of bare ochre earth with small pebbles, and 3 patches of dry yellow-olive straw grass.
Each patch has two to three value layers built from clusters, no noise.
[SHEET SUFFIX]
Isolated assets on a fully transparent background (if transparency is unavailable: a flat pure #FF00FF
background with no gradients and no shadows). Every asset separated by at least 64 px of empty space,
arranged in a neat grid, all drawn at the SAME pixel scale, each asset complete and uncropped.
Output as PNG, exact canvas size as specified.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
CRITICAL: background SOLID PURE MAGENTA #FF00FF, not transparent in this version. Flat uniformly magenta empty space, no halos, no shadows, no vignette. Six islands with extremely crisp abrupt pixel boundaries; NO soft fringe, NO fading, NO gradient. Top three bare-earth, bottom three DRY STRAW GRASS: yellow-grey straw clusters, NO GREEN TUFTS, NO FLOWERS, NO LEAVES. Minimal details in calm 2-3 flat color regions. Pixel art, not photo texture.
```

## bs_g03_b_moss_gravel.png

批次：P1

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
[VIEW-G]
CAMERA: strictly orthographic, looking straight DOWN at exactly 90 degrees, like a flat 2D game map
tile or a satellite tile. The ground is ONE perfectly flat plane. There is NO horizon, NO perspective,
NO vanishing point, NO depth shrinking, NO tilt, NO aerial landscape-illustration look, NO depth of
field, NO haze, NO vignette. Nothing is shown from the side: no cliff faces, no vertical walls,
no waterfalls, no raised terraces, no bridge arches. Height differences are NOT drawn at all.
Every point of the image has exactly the same scale.
Sprite sheet G03-B of organic ground-material patches for a pixel RPG field map, canvas 1536x1024
(384x256 art pixels), 3 columns x 2 rows, each patch 96-128 art pixels wide with a ragged, irregular
HARD-PIXEL edge (never a circle or ellipse), transparent outside, no two shapes alike:
3 patches of mossy ground (green moss with a few stones), and 3 patches of gravel and broken stone chips.
Each patch has two to three value layers built from clusters, no noise.
[SHEET SUFFIX]
Isolated assets on a fully transparent background (if transparency is unavailable: a flat pure #FF00FF
background with no gradients and no shadows). Every asset separated by at least 64 px of empty space,
arranged in a neat grid, all drawn at the SAME pixel scale, each asset complete and uncropped.
Output as PNG, exact canvas size as specified.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Exactly six patches, top row three flat mossy ground areas, bottom row three gravel areas. NO FLOWERS, NO LEAVES, NO TALL GRASS. Small pebbles only. Flat map decals.
```

## bs_g03_c_leaf_damp.png

批次：P1

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
[VIEW-G]
CAMERA: strictly orthographic, looking straight DOWN at exactly 90 degrees, like a flat 2D game map
tile or a satellite tile. The ground is ONE perfectly flat plane. There is NO horizon, NO perspective,
NO vanishing point, NO depth shrinking, NO tilt, NO aerial landscape-illustration look, NO depth of
field, NO haze, NO vignette. Nothing is shown from the side: no cliff faces, no vertical walls,
no waterfalls, no raised terraces, no bridge arches. Height differences are NOT drawn at all.
Every point of the image has exactly the same scale.
Sprite sheet G03-C of organic ground-material patches for a pixel RPG field map, canvas 1536x1024
(384x256 art pixels), 3 columns x 2 rows, each patch 96-128 art pixels wide with a ragged, irregular
HARD-PIXEL edge (never a circle or ellipse), transparent outside, no two shapes alike:
3 patches of fallen-leaf litter (one with rust-red leaves), and 3 patches of dark damp soil with a few tiny wet pebbles.
Each patch has two to three value layers built from clusters, no noise.
[SHEET SUFFIX]
Isolated assets on a fully transparent background (if transparency is unavailable: a flat pure #FF00FF
background with no gradients and no shadows). Every asset separated by at least 64 px of empty space,
arranged in a neat grid, all drawn at the SAME pixel scale, each asset complete and uncropped.
Output as PNG, exact canvas size as specified.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Exactly six flat irregular patches. Top three dry fallen-leaf litter; only one rust-red. Bottom three dark damp soil, tiny wet pebbles only, no vegetation. No boulders, no trees, no tall grass, no flowers.
```

## bs_g02_a_roadside.png

批次：P1

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
[VIEW-G]
CAMERA: strictly orthographic, looking straight DOWN at exactly 90 degrees, like a flat 2D game map
tile or a satellite tile. The ground is ONE perfectly flat plane. There is NO horizon, NO perspective,
NO vanishing point, NO depth shrinking, NO tilt, NO aerial landscape-illustration look, NO depth of
field, NO haze, NO vignette. Nothing is shown from the side: no cliff faces, no vertical walls,
no waterfalls, no raised terraces, no bridge arches. Height differences are NOT drawn at all.
Every point of the image has exactly the same scale.
Sprite sheet G02-A of small road-surface decals for a pixel RPG field map, canvas 1536x1024
(384x256 art pixels): grass edge strips that overhang a dirt road (3 horizontal, 3 vertical,
each about 64x16 art pixels, one long edge perfectly straight), 2 cart-rut segments (64x20,
horizontally repeatable), 2 mud puddles, 3 ground cracks, 2 exposed root segments,
2 sets of boot/animal tracks pressed into dirt. Very small, crisp, all the same pixel scale.
[SHEET SUFFIX]
Isolated assets on a fully transparent background (if transparency is unavailable: a flat pure #FF00FF
background with no gradients and no shadows). Every asset separated by at least 64 px of empty space,
arranged in a neat grid, all drawn at the SAME pixel scale, each asset complete and uncropped.
Output as PNG, exact canvas size as specified.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Asset inventory mandatory: 6 edge strips, 2 cart-rut strips, 2 puddles, 3 cracks, 2 roots, 2 track groups = 17 distinct assets. Arrange compact rows with separate magenta gaps. Vertical strips must be tall vertical strips, not rotated horizontal. Only specified assets.
```

## bs_g02_b_meadow.png

批次：P1

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
[VIEW-G]
CAMERA: strictly orthographic, looking straight DOWN at exactly 90 degrees, like a flat 2D game map
tile or a satellite tile. The ground is ONE perfectly flat plane. There is NO horizon, NO perspective,
NO vanishing point, NO depth shrinking, NO tilt, NO aerial landscape-illustration look, NO depth of
field, NO haze, NO vignette. Nothing is shown from the side: no cliff faces, no vertical walls,
no waterfalls, no raised terraces, no bridge arches. Height differences are NOT drawn at all.
Every point of the image has exactly the same scale.
Sprite sheet G02-B of small meadow decals for a pixel RPG field map, canvas 1536x1024
(384x256 art pixels): 6 grass tufts (12-32 art pixels wide), 4 kinds of tiny wildflower clusters
(8-16 wide), 5 pebble groups, 3 fallen-leaf piles (one rust red), 2 tall grass clumps.
Very small, crisp, all the same pixel scale.
[SHEET SUFFIX]
Isolated assets on a fully transparent background (if transparency is unavailable: a flat pure #FF00FF
background with no gradients and no shadows). Every asset separated by at least 64 px of empty space,
arranged in a neat grid, all drawn at the SAME pixel scale, each asset complete and uncropped.
Output as PNG, exact canvas size as specified.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Exactly 20 separate tiny items: row 1 six grass tufts, row 2 four tiny flower clusters, row 3 five pebble groups, row 4 three leaf piles and two tall grass clumps. No dirt bases under assets, no giant objects, every asset small relative to canvas.
```

## bs_t01_a.png

批次：P2

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
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
One single large broadleaf tree, canvas 1024x1024 (256x256 art pixels), the tree fills about 80% of
the canvas (about 180 art pixels wide, 220 tall). Full rounded canopy built from clustered leaf clumps
in three value layers, sage-to-olive greens, cool shadowed lower-right side, lit upper-left,
a sturdy trunk with root flare, slight moss on the bark, contact darkening at the base.
Transparent background.
Variant A: round, symmetrical canopy.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1024x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Tree crown is a near circular canopy mass seen from slightly above, short trunk stub beneath only. No tall side-view tree. No ground base. Mature muted olive/sage palette. One tree only.
```

## bs_t01_b.png

批次：P2

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
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
One single large broadleaf tree, canvas 1024x1024 (256x256 art pixels), the tree fills about 80% of
the canvas (about 180 art pixels wide, 220 tall). Full rounded canopy built from clustered leaf clumps
in three value layers, sage-to-olive greens, cool shadowed lower-right side, lit upper-left,
a sturdy trunk with root flare, slight moss on the bark, contact darkening at the base.
Transparent background.
Variant B: wider canopy, slightly lopsided, thicker trunk.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1024x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Wide canopy, green only no rust-red leaf accents for this variant. Rounded crown seen slightly above, short thick trunk visible beneath. One separate tree, no ground platform.
```

## bs_t01_c.png

批次：P2

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
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
One single large broadleaf tree, canvas 1024x1024 (256x256 art pixels), the tree fills about 80% of
the canvas (about 180 art pixels wide, 220 tall). Full rounded canopy built from clustered leaf clumps
in three value layers, sage-to-olive greens, cool shadowed lower-right side, lit upper-left,
a sturdy trunk with root flare, slight moss on the bark, contact darkening at the base.
Transparent background.
Variant C: taller, narrower canopy, two visible trunk roots.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1024x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Narrower taller silhouette than the wide tree variant. Green only, no red leaves. Canopy occupies most tree height, only a short trunk beneath, two clear roots. Outer silhouette well inside canvas.
```

## bs_t01_d.png

批次：P2

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
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
One single large broadleaf tree, canvas 1024x1024 (256x256 art pixels), the tree fills about 80% of
the canvas (about 180 art pixels wide, 220 tall). Full rounded canopy built from clustered leaf clumps
in three value layers, sage-to-olive greens, cool shadowed lower-right side, lit upper-left,
a sturdy trunk with root flare, slight moss on the bark, contact darkening at the base.
Transparent background.
Variant D: a chunk of the canopy missing on one side where a branch broke, exposing darker inner leaves.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1024x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
A clearly visible wedge of canopy missing from the upper-right side, a broken branch stub in that notch. Mostly round green canopy, no red leaves. Short trunk below. No ground base.
```

## bs_t01_e_maple.png

批次：P2

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
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
One single large broadleaf tree, canvas 1024x1024 (256x256 art pixels), the tree fills about 80% of
the canvas (about 180 art pixels wide, 220 tall). Full rounded canopy built from clustered leaf clumps
in three value layers, sage-to-olive greens, cool shadowed lower-right side, lit upper-left,
a sturdy trunk with root flare, slight moss on the bark, contact darkening at the base.
Transparent background.
Variant E: a rust-red maple tree, same size, orange and rust-red leaf clumps with a few green ones.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1024x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Muted rusty-red autumn maple. NOT vivid bright orange, dusty copper red, dull ochre small highlights, dark brown cool shade. Round canopy mass plus short trunk, not side-view tall tree.
```

## bs_t02_a_broadleaf.png

批次：P2

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
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
Sprite sheet T02-A: 2 medium broadleaf trees (110-140 art pixels wide, 150-190 tall) standing on the
same baseline, clustered leaf clumps, sage-to-olive greens, lit upper-left, visible trunks with root
flare and contact darkening at the base.
[SHEET SUFFIX]
Isolated assets on a fully transparent background (if transparency is unavailable: a flat pure #FF00FF
background with no gradients and no shadows). Every asset separated by at least 64 px of empty space,
arranged in a neat grid, all drawn at the SAME pixel scale, each asset complete and uncropped.
Output as PNG, exact canvas size as specified.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Canvas 1536x1024. Exactly TWO separate medium trees side by side with distinct silhouettes, one round one slightly narrow. Roots aligned on same horizontal baseline, green canopies only, no rust-red leaves. Short visible trunks, no ground base.
```

## bs_t02_b_dead.png

批次：P2

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
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
Sprite sheet T02-B: 2 bare weathered dead trees (90-130 art pixels wide, 150-190 tall), twisted
branches with fine tips, cracked bark, a hollow in one trunk, tiny moss patches, standing on the same
baseline, lit upper-left.
[SHEET SUFFIX]
Isolated assets on a fully transparent background (if transparency is unavailable: a flat pure #FF00FF
background with no gradients and no shadows). Every asset separated by at least 64 px of empty space,
arranged in a neat grid, all drawn at the SAME pixel scale, each asset complete and uncropped.
Output as PNG, exact canvas size as specified.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Canvas 1536x1024. Exactly TWO dead trees, no leaves at all. One twisted hollow trunk, one broken branching silhouette. Thin bare branch tips fully inside canvas. No grass or ground base.
```

## bs_t03_a_shrubs.png

批次：P2

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
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
Sprite sheet T03-A: 4 round shrubs (36-72 art pixels, one with rust-red leaves) and 1 bramble thicket,
clustered leaf clumps, lit upper-left, two rows, same pixel scale.
[SHEET SUFFIX]
Isolated assets on a fully transparent background (if transparency is unavailable: a flat pure #FF00FF
background with no gradients and no shadows). Every asset separated by at least 64 px of empty space,
arranged in a neat grid, all drawn at the SAME pixel scale, each asset complete and uncropped.
Output as PNG, exact canvas size as specified.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Canvas 1536x1024. Exactly five objects, three above and two below: 4 round shrubs, one shrub rust-red; the fifth is tangled bramble. No flowers, fruit, tree trunks or ground pads. All silhouettes complete and separated.
```

## bs_t03_b_ferns.png

批次：P2

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
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
Sprite sheet T03-B: 3 ferns with radiating fronds and 2 tall grass clumps, 36-72 art pixels,
lit upper-left, two rows, same pixel scale.
[SHEET SUFFIX]
Isolated assets on a fully transparent background (if transparency is unavailable: a flat pure #FF00FF
background with no gradients and no shadows). Every asset separated by at least 64 px of empty space,
arranged in a neat grid, all drawn at the SAME pixel scale, each asset complete and uncropped.
Output as PNG, exact canvas size as specified.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Canvas 1536x1024. Exactly five isolated plants: three different radiating ferns in top row, two tall grass clumps below. No flowers, no red leaves, no dirt base. Same art-pixel scale, clear separate silhouettes.
```

## bs_r01_a_small_medium.png

批次：P2

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
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
Sprite sheet R01-A of weathered rocks: 4 small stones (12-24 art pixels) and 5 medium rocks
(32-56 art pixels), cool blue-grey stone with moss and pale lichen patches, angular cracked forms,
lit top faces.
[SHEET SUFFIX]
Isolated assets on a fully transparent background (if transparency is unavailable: a flat pure #FF00FF
background with no gradients and no shadows). Every asset separated by at least 64 px of empty space,
arranged in a neat grid, all drawn at the SAME pixel scale, each asset complete and uncropped.
Output as PNG, exact canvas size as specified.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Canvas 1536x1024. Exactly nine isolated rocks: four small stones above, five medium below. Grey-blue, not ochre. No ground pads, no ground shadows. Front and thin top only, no isometric side planes.
```

## bs_r01_b_boulders.png

批次：P2

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
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
Sprite sheet R01-B of 3 large boulders (72-110 art pixels), two in the upper row, one in the lower
row, blue-grey stone, deep cracks, moss on top and in crevices, lichen patches, lit top faces.
[SHEET SUFFIX]
Isolated assets on a fully transparent background (if transparency is unavailable: a flat pure #FF00FF
background with no gradients and no shadows). Every asset separated by at least 64 px of empty space,
arranged in a neat grid, all drawn at the SAME pixel scale, each asset complete and uncropped.
Output as PNG, exact canvas size as specified.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Canvas 1536x1024. Exactly 3 large boulders, two above one below. Broad low asymmetrical rock shapes, not vertical monoliths. Flat front and narrow top, no side view, no ground pad.
```

## bs_l01_a_giant_stele.png

批次：P3

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
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
ONE giant ancient boundary stele snapped diagonally in half, the upper half leaning but still standing,
on a cut-stone plinth with a straight front edge, about 160 art pixels wide and 190 tall in total,
weathered blue-grey stone, moss on the shoulders, carved rune bands in dull ochre-gold (pure pattern,
no readable text, no glow). Canvas 1024x1024 (256x256 art pixels). Transparent background.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1024x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
CRITICAL ORTHOGRAPHIC FRONT ELEVATION. Draw the broad stele face exactly parallel to image plane. NO VISIBLE SIDE FACES, not even a thin left-side bevel or right-side thickness stripe. Width including plinth 160 art pixels, height 190 art pixels: relatively broad stocky landmark, not tall narrow pillar. Center with generous margins. Plinth a broad rectangle front and one thin horizontal top line. Diagonal snapped crack crosses central face, upper portion shifted/leaning slightly. No 3D model look.
```

## bs_l01_b_markers.png

批次：P3

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
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
Sprite sheet L01-B of ancient boundary markers: top row 3 toppled stele segments lying on the ground
(60-100 art pixels long); bottom row 2 medium broken steles (about 40x80) and 3 small wayside
markers / cairns (about 24x40). Weathered blue-grey stone, moss, faint ochre-gold carvings, lit upper-left.
[SHEET SUFFIX]
Isolated assets on a fully transparent background (if transparency is unavailable: a flat pure #FF00FF
background with no gradients and no shadows). Every asset separated by at least 64 px of empty space,
arranged in a neat grid, all drawn at the SAME pixel scale, each asset complete and uncropped.
Output as PNG, exact canvas size as specified.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Canvas 1536x1024. EXACT EIGHT ASSETS: top three horizontal toppled stone segments; bottom two medium broken standing steles and three tiny wayside markers/cairns. All steles front flat face only, no left/right thickness face. Blank geometric carvings not letters.
```

## bs_l02_a_gate.png

批次：P3

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
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
Pixel RPG map north-edge landmark. An ancient stone archway carved into a layered rock cliff,
320 art pixels wide and 170 tall, flanked by two worn steles, three wide stone steps in front,
a dark empty doorway at least 104 art pixels wide and 96 tall (no light inside), shallow relief carvings
on the door frame, grass and roots on the cliff top. Cool shadowed stone with a lit top rim.
Canvas 1536x1024 (384x256 art pixels). Transparent background.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
One standalone front-elevation gate module, broad low cliff width 320 height170 art pixels. Doorway opaque dark grey interior, NOT magenta. Door opening width >=104 height>=96 art pixels. Three broad HORIZONTAL stair edges, no perspective. No side walls receding. Only narrow cliff top rim, mostly rock front.
```

## bs_l02_b_cliff_face.png

批次：P3

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
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
Sprite sheet L02-B: 2 straight layered rock cliff-face strips, each 320x110 art pixels, stacked
vertically, whose left and right edges tile horizontally with identical rock-layer seams. Cracks, moss,
water stains, cool shadowed stone.
[SHEET SUFFIX]
Isolated assets on a fully transparent background (if transparency is unavailable: a flat pure #FF00FF
background with no gradients and no shadows). Every asset separated by at least 64 px of empty space,
arranged in a neat grid, all drawn at the SAME pixel scale, each asset complete and uncropped.
Output as PNG, exact canvas size as specified.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Canvas landscape 1536x1024, not panoramic. Exactly two rectangular broad front-elevation cliff strips, vertically stacked. No gate. No top ground expanse, only thin rim. Both have perfectly vertical left/right crop edges, matching horizontal layered seam heights. Grass rare, no flowers or red leaves.
```

## bs_l02_c_cliff_rim.png

批次：P3

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
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
Sprite sheet L02-C: 2 cliff-top rim strips (320x60 art pixels, stacked vertically, horizontally tileable)
with grass overhang, exposed roots and hanging root tendrils; plus 2 cliff end caps (48x170) side by
side on the right.
[SHEET SUFFIX]
Isolated assets on a fully transparent background (if transparency is unavailable: a flat pure #FF00FF
background with no gradients and no shadows). Every asset separated by at least 64 px of empty space,
arranged in a neat grid, all drawn at the SAME pixel scale, each asset complete and uncropped.
Output as PNG, exact canvas size as specified.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Canvas 1536x1024. Four pieces, all complete with magenta gaps. The proposed widths cannot fit side-by-side at exact 4x scale, so use uniformly reduced preview scale while retaining relative dimensions and separate pieces: two long 320x60 rim strips stacked on the left, two 48x170 endcaps side by side on the right. Not a scene. No flowers or red leaves. Straight front-facing edges.
```

## bs_l03_a_gully.png

批次：P3

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
[VIEW-G]
CAMERA: strictly orthographic, looking straight DOWN at exactly 90 degrees, like a flat 2D game map
tile or a satellite tile. The ground is ONE perfectly flat plane. There is NO horizon, NO perspective,
NO vanishing point, NO depth shrinking, NO tilt, NO aerial landscape-illustration look, NO depth of
field, NO haze, NO vignette. Nothing is shown from the side: no cliff faces, no vertical walls,
no waterfalls, no raised terraces, no bridge arches. Height differences are NOT drawn at all.
Every point of the image has exactly the same scale.
Sprite sheet L03-A: 2 horizontally tileable shallow rocky gully segments, each 320x80 art pixels,
stacked vertically, with a thin trickle of water at the bottom, wet stones, rocky banks on both edges.
Cooler and darker than normal ground.
[SHEET SUFFIX]
Isolated assets on a fully transparent background (if transparency is unavailable: a flat pure #FF00FF
background with no gradients and no shadows). Every asset separated by at least 64 px of empty space,
arranged in a neat grid, all drawn at the SAME pixel scale, each asset complete and uncropped.
Output as PNG, exact canvas size as specified.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Canvas 1536x1024. CAMERA EXACTLY STRAIGHT DOWN 90 DEGREES. Two flat horizontal strips ONLY. See water surface and stone/grass bank TOPS; absolutely NO VERTICAL BANK WALL, NO CLIFF FACE, NO waterfall. Thin shallow blue-grey stream, not a deep canyon. Water has flat pixel clusters, no gradients.
```

## bs_l03_b_bridges.png

批次：P3

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
[VIEW-G]
CAMERA: strictly orthographic, looking straight DOWN at exactly 90 degrees, like a flat 2D game map
tile or a satellite tile. The ground is ONE perfectly flat plane. There is NO horizon, NO perspective,
NO vanishing point, NO depth shrinking, NO tilt, NO aerial landscape-illustration look, NO depth of
field, NO haze, NO vignette. Nothing is shown from the side: no cliff faces, no vertical walls,
no waterfalls, no raised terraces, no bridge arches. Height differences are NOT drawn at all.
Every point of the image has exactly the same scale.
Sprite sheet L03-B: top row: 1 old flat-decked stone bridge seen from directly above (parapet tops only, NO arch, NO side view) (136x112 art pixels, deck at least 96 wide),
and the SAME small plank bridge (72x104, deck about 56 wide) in two states: broken (snapped planks,
slack rope) and repaired (fresh planks, tied rope, new posts), identical outline and post positions.
Bottom row: 2 gully end caps (96x80). Wet rock, moss, rope, wood grain.
[SHEET SUFFIX]
Isolated assets on a fully transparent background (if transparency is unavailable: a flat pure #FF00FF
background with no gradients and no shadows). Every asset separated by at least 64 px of empty space,
arranged in a neat grid, all drawn at the SAME pixel scale, each asset complete and uncropped.
Output as PNG, exact canvas size as specified.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Canvas 1536x1024. Exactly FIVE assets. Bridges center axes VERTICAL, CAMERA DIRECTLY ABOVE, only horizontal plank/stone deck surfaces and railing TOPS, no rail upright fronts, no arches. Top row stone bridge, broken wood bridge, repaired same wood bridge. Two wood bridges have same footprint, same size and EXACT same corner post positions. Bottom two shallow stream endcaps only.
```

## bs_l04_terrace.png

批次：P3

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
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
Sprite sheet of a low dry-stone terrace ledge: 2 horizontally tileable straight segments (320x56 art
pixels, stacked, grass overhanging the top, stone faces visible), 1 ramp opening (128x72) where a dirt
road climbs through with two finishing stones at the sides, 2 end caps (64x56). Lit top edge,
darker stone face, moss in the joints.
[SHEET SUFFIX]
Isolated assets on a fully transparent background (if transparency is unavailable: a flat pure #FF00FF
background with no gradients and no shadows). Every asset separated by at least 64 px of empty space,
arranged in a neat grid, all drawn at the SAME pixel scale, each asset complete and uncropped.
Output as PNG, exact canvas size as specified.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Canvas 1536x1024. Exactly five pieces: two very long LOW wall strips above, ramp opening plus two endcaps below. Rock FRONT FACE HEIGHT <=16 art pixels, low shallow ledge, not tall cliff. Thin grassy top only. Ramp clear walkable opening >=96 art pixels, no stairs across opening. No flowers, no red leaves.
```

## bs_c01_camp.png

批次：P4

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
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
Sprite sheet of a small expedition roadside camp. Top row: 1 canvas tent (112x96 art pixels),
1 trader's stall with an awning and goods (120x110), 1 banner pole with a rust-red cloth (32x80).
Bottom row: a campfire in 4 animation frames (40x40 each, identical log pile, only the flames change),
4 supply crates and barrels (24-40), 1 log bench (48x24). Lit upper-left, warm firelight near the fire.
[SHEET SUFFIX]
Isolated assets on a fully transparent background (if transparency is unavailable: a flat pure #FF00FF
background with no gradients and no shadows). Every asset separated by at least 64 px of empty space,
arranged in a neat grid, all drawn at the SAME pixel scale, each asset complete and uncropped.
Output as PNG, exact canvas size as specified.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Canvas 1536x1024. Exactly 12 separate sprites. Top: tent, trader stall, flagpole. Lower rows: FOUR CAMPFIRE ANIMATION FRAMES side by side with IDENTICAL LOGS and different flame silhouettes; FOUR separate supply objects (two crates,two barrels); ONE log bench. Arrange extra lower row if needed, keep every object separate. No text. Front elevation, no side faces, no perspective. Tent rust-red muted cloth.
```

## bs_q01_props.png

批次：P4

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
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
Sprite sheet of interactive field props. Top row: a small two-wheeled salt cart (96x80 art pixels),
a wooden signpost with two BLANK arrow boards (40x72), a patrol marker post (24x64), a rope-tie post (32x56).
Bottom row: a treasure chest closed and open (40x36 each, identical outline), beast footprints pressed
into mud (ground decal, 40x24), a broken wagon wheel (40x40), a snapped spear stuck in the ground (24x56).
Aged wood, iron bands, rope, mud. No text.
[SHEET SUFFIX]
Isolated assets on a fully transparent background (if transparency is unavailable: a flat pure #FF00FF
background with no gradients and no shadows). Every asset separated by at least 64 px of empty space,
arranged in a neat grid, all drawn at the SAME pixel scale, each asset complete and uncropped.
Output as PNG, exact canvas size as specified.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Canvas 1536x1024. Exactly nine isolated sprites. Four upper: small salt cart, BLANK two-arrow sign, patrol post, rope post. Five lower: closed chest, same chest open, beast tracks decal (strict top-down), broken wheel, snapped spear. Chest base footprint and hinge positions identical in both states. Salt cart front elevation, no receding side plane. No readable signs or letters.
```

## bs_f01_a_canopy.png

批次：P4

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
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
A corner canopy overhang seen close to the camera, 320x220 art pixels, one value darker than the scene,
clustered leaf clumps with drooping leaf tips, outer top and side edges perfectly straight and flush
with the canvas edge, inner edge a natural leaf silhouette. Canvas 1536x1024 (384x256 art pixels).
Transparent background.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Canvas exactly landscape 1536x1024, 3:2. Upper RIGHT corner foliage: top edge and right edge straight flush with canvas. Dense dark sage/olive canopy extending inward down-left with ragged leaf silhouette. No trunk, no roots, no ground, no red leaves. Leave lower-left magenta empty. No simulated blur.
```

## bs_f01_b_branches_grass.png

批次：P4

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
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
Sprite sheet F01-B of foreground framing foliage: 2 hanging branch clusters (200x112 art pixels,
stacked vertically) on the left, and 2 horizontally tileable foreground grass-blade strips
(160x48, stacked vertically) on the right. One value darker than the scene.
[SHEET SUFFIX]
Isolated assets on a fully transparent background (if transparency is unavailable: a flat pure #FF00FF
background with no gradients and no shadows). Every asset separated by at least 64 px of empty space,
arranged in a neat grid, all drawn at the SAME pixel scale, each asset complete and uncropped.
Output as PNG, exact canvas size as specified.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Canvas 1536x1024. Exactly four pieces: left column TWO hanging branch clusters stacked; right column TWO short grass blade strips stacked. Dark dusty sage, no red leaves or flowers. Branches complete and separate, grass strip endpoints flat and mutually matched for repeat. Only foliage and wood, no ground.
```

## bs_f01_c_canopy.png

批次：P4

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
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
A corner canopy overhang seen close to the camera, 320x220 art pixels, one value darker than the scene,
clustered leaf clumps with drooping leaf tips, outer top and side edges perfectly straight and flush
with the canvas edge, inner edge a natural leaf silhouette. Canvas 1536x1024 (384x256 art pixels).
Transparent background.
Make the silhouette different from the first: a denser canopy with one long hanging branch.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Canvas exactly landscape 1536x1024. UPPER LEFT corner canopy, denser than the right corner, with one long hanging branch toward middle bottom. Top and left outer edges flush with canvas. Right lower area magenta empty. Darker dusty sage olive greens, no red leaves, no ground or trunk.
```

## bs_e01_fx.png

批次：P4

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
[VIEW-O]
CAMERA: strictly orthographic classic 16-bit RPG overworld sprite convention. ONE fixed camera angle
for every object: show only the object's FRONT face and a thin TOP face. NEVER draw a left or right
side face (no isometric, no 2.5D, no three-quarter turn, no perspective convergence, no foreshortening
that changes with position). Vertical edges are perfectly vertical, horizontal edges perfectly
horizontal and parallel. Each object stands upright on a flat baseline at the bottom of its sprite.
Trees: a rounded canopy mass with a short trunk visible beneath it, never a side view of the tree.
Sprite sheet of tiny ambient effect sprites: a falling leaf in 4 rotation frames at 6x6 art pixels
(a green set and a rust-red set), 4 tiny dust motes (2-3 px), a firefly in 2 frames (3 px),
and one horizontal low mist strip (320x48 art pixels) using only two transparency levels,
softly thinning at both ends and horizontally tileable.
[SHEET SUFFIX]
Isolated assets on a fully transparent background (if transparency is unavailable: a flat pure #FF00FF
background with no gradients and no shadows). Every asset separated by at least 64 px of empty space,
arranged in a neat grid, all drawn at the SAME pixel scale, each asset complete and uncropped.
Output as PNG, exact canvas size as specified.

[CALM]
Colors about 25 percent less saturated than typical bright fantasy pixel art: dusty sage greens,
dull ochre, grey stone. Keep it calm and readable: large plain areas, small details only in occasional
small clusters, never scattered evenly over everything. Flowers and red leaves are rare accents.
Reference image: use only its pixel craft, fixed camera angle and muted palette. Do not copy its scene or objects. This is an individual production asset, not a full map.
Exact output canvas: 1536x1024 pixels, PNG.
BACKGROUND DELIVERY OVERRIDE: Use a completely solid uniform PURE MAGENTA #FF00FF background (the documented chroma-key fallback), with NO gradients, NO halos, NO shadow, NO vignette. Hard pixel silhouette, no fade. Magenta must never occur within any asset.
Canvas 1536x1024. Inventory: top row FOUR green leaf rotations then FOUR rust-red leaf rotations (eight leaves total, each 24 generated px); next row FOUR dust motes, TWO firefly frames (each 8-12 generated px). Bottom ONE long low mist strip (1280x192 generated px). All tiny sprites must remain tiny with enormous empty space. Mist drawn in exactly TWO flat grey bands (#868b86 and #a9aca2) with hard pixel stepped shape, NO gaussian blur or glow; two greys stand for two alpha levels to be applied in documented processing stage. Empty canvas pure magenta. Do not enlarge leaves or invent objects.
```

