# 本轮实际使用的生图提示词

使用内置 image_gen；不支持固定种子。原图与生成路径见 generation_manifest_final.json。地面场景候选没有拉伸上线；正式地表是材料和真实路线遮罩烘焙。

## ground_materials

Create a2x2 sheet of FOUR GROUND MATERIAL TEXTURES for a two-dimensional overhead pixel JRPG. Each quadrant is one full square texture; exact requested canvas1536x1536, no gutters, frames, labels or text.
Image1 is the existing128px hero, used ONLY to match FINE pixel density. Image2 is forest art palette/style only. Do not draw the hero, road layout, trees, bushes or objects.
Top-left: calm mid-green SHORT grass, mostly quiet solid ground with subtle painted clustered blades, no flower dots or dark clumps.
Top-right: a slightly cooler shaded short-grass variant in the SAME close palette, not dramatically darker, similarly quiet.
Bottom-left: calm pale ochre compacted soil, low contrast, a few tiny pebbles and faint worn traces. Entire quadrant earth, NO grass edge or path shape.
Bottom-right: clear shallow muted teal creek water, delicate ripples and a few small stones visible on the bottom, entire quadrant water, NO banks, bridges or objects.
All four textures top-down FLAT GROUND, tiny1–2 source-pixel details and clean discrete color ramps; each texture will display at256x256 world units, so fine strokes should stay comparable to the hero. At least80% of grass quiet; do not make a dotted carpet, camouflage patches, giant square pixel blocks or photographic noise. No dither, no3D lighting, no perspective, no plants taller than flat grass. Edges of each material should be naturally tileable without high-contrast border features. Natural hand-painted pixel surfaces, not a picture of a texture board.

## stable

Two-dimensional hand-drawn overhead JRPG game sprite with fine pixel density matching image1 (existing hero). Orthographic projection: south-facing front straight on, horizontal eaves and steps, vertical posts, roof visible from above. No receding side facade or rotated isometric base, no3D toy rendering. Image2 forest is palette and painting reference. Fine1–2 working pixel edges, deliberate clean color clusters, upper-left light, muted natural materials. COMPLETE silhouette with transparent margins. No surrounding ground, cast shadow, writing, UI or labels. Do not draw the hero.
Asset: Frontier stable, warm timber open central human-sized bay, grey tile roof with modest thatch accents, saddle rail, tiny hay bales and water trough contained inside the lot, no animals. Clear front doorway88worldunits high, roof only upper30% so the door is not tiny.
Approved visible world bounds280x200; requested2x working object art560x400 with transparent margin. Door approximately88worldunits high, about44% of the whole building height, so an adult72unit hero fits naturally. Keep roof shallow and doorway prominent. No schematic rectangles; finished commercial pixel sprite. Genuine transparent background.

## barracks

Two-dimensional hand-drawn overhead JRPG game sprite with fine pixel density matching image1 (existing hero). Orthographic projection: south-facing front straight on, horizontal eaves and steps, vertical posts, roof visible from above. No receding side facade or rotated isometric base, no3D toy rendering. Image2 forest is palette and painting reference. Fine1–2 working pixel edges, deliberate clean color clusters, upper-left light, muted natural materials. COMPLETE silhouette with transparent margins. No surrounding ground, cast shadow, writing, UI or labels. Do not draw the hero.
Asset: Frontier patrol hall, grey tiles, restrained dark-red cloth banners, horizontal stone steps, two slender upright spear racks by the central door. Door88worldunits high; roof upper30%, large clear front, no people.
Requested2x working art for nominal280x210 world footprint. Central door must be approximately88worldunits high, at least40% of visible total height. Keep upper roof shallow and facade readable, a LARGE human doorway not doll-house miniature. Restrained painted pixel materials, no smooth gloss. Real alpha transparency.

## storehouse

Two-dimensional hand-drawn overhead JRPG game sprite with fine pixel density matching image1 (existing hero). Orthographic projection: south-facing front straight on, horizontal eaves and steps, vertical posts, roof visible from above. No receding side facade or rotated isometric base, no3D toy rendering. Image2 forest is palette and painting reference. Fine1–2 working pixel edges, deliberate clean color clusters, upper-left light, muted natural materials. COMPLETE silhouette with transparent margins. No surrounding ground, cast shadow, writing, UI or labels. Do not draw the hero.
Asset: Ventilated timber granary on low stone piers, short loading ramp, a few tied sacks and grain baskets along front sides. Grey roof upper30%, central tall door88worldunits high. No cart blocking the doorway.
Requested2x working art for nominal280x200 world footprint. Central door must be approximately88worldunits high, at least40% of visible total height. Keep upper roof shallow and facade readable, a LARGE human doorway not doll-house miniature. Restrained painted pixel materials, no smooth gloss. Real alpha transparency.

## forge

Two-dimensional hand-drawn overhead JRPG game sprite with fine pixel density matching image1 (existing hero). Orthographic projection: south-facing front straight on, horizontal eaves and steps, vertical posts, roof visible from above. No receding side facade or rotated isometric base, no3D toy rendering. Image2 forest is palette and painting reference. Fine1–2 working pixel edges, deliberate clean color clusters, upper-left light, muted natural materials. COMPLETE silhouette with transparent margins. No surrounding ground, cast shadow, writing, UI or labels. Do not draw the hero.
Asset: Compact blacksmith workshop with open central front bay88worldunits high, furnace inside the bay, short stone chimney, anvil and quench trough at outer front corners. Grey roof upper30%, no exaggerated smoke or glowing lava.
Requested2x working art for nominal280x200 world footprint. Central door must be approximately88worldunits high, at least40% of visible total height. Keep upper roof shallow and facade readable, a LARGE human doorway not doll-house miniature. Restrained painted pixel materials, no smooth gloss. Real alpha transparency.

## kennel

Two-dimensional hand-drawn overhead JRPG game sprite with fine pixel density matching image1 (existing hero). Orthographic projection: south-facing front straight on, horizontal eaves and steps, vertical posts, roof visible from above. No receding side facade or rotated isometric base, no3D toy rendering. Image2 forest is palette and painting reference. Fine1–2 working pixel edges, deliberate clean color clusters, upper-left light, muted natural materials. COMPLETE silhouette with transparent margins. No surrounding ground, cast shadow, writing, UI or labels. Do not draw the hero.
Asset: Timber companion barn and fenced side pen, central human doorway88worldunits high, feeding trough and tiny straw bundle inside the approved outline, low rail fencing at side corners, no animals or people.
Requested2x working art for nominal280x210 world silhouette. Adult doorway about88worldunits tall whenever the facility has a doorway; roof compact, not a tiny doll-house door. Preserve complete outline and the bottom-center approach. Fine painted pixels with restrained highlights, not realistic material shaders. Real alpha transparency.

## archive

Two-dimensional hand-drawn overhead JRPG game sprite with fine pixel density matching image1 (existing hero). Orthographic projection: south-facing front straight on, horizontal eaves and steps, vertical posts, roof visible from above. No receding side facade or rotated isometric base, no3D toy rendering. Image2 forest is palette and painting reference. Fine1–2 working pixel edges, deliberate clean color clusters, upper-left light, muted natural materials. COMPLETE silhouette with transparent margins. No surrounding ground, cast shadow, writing, UI or labels. Do not draw the hero.
Asset: Compact archive/map pavilion, two-tier facade with a low upper balcony, ink-blue cloth accent, scroll rack tucked inside. Central door88worldunits high, keep upper floor and roof compact rather than dwarfing the doorway, horizontal front steps.
Requested2x working art for nominal280x220 world silhouette. Adult doorway about88worldunits tall whenever the facility has a doorway; roof compact, not a tiny doll-house door. Preserve complete outline and the bottom-center approach. Fine painted pixels with restrained highlights, not realistic material shaders. Real alpha transparency.

## shrine

Two-dimensional hand-drawn overhead JRPG game sprite with fine pixel density matching image1 (existing hero). Orthographic projection: south-facing front straight on, horizontal eaves and steps, vertical posts, roof visible from above. No receding side facade or rotated isometric base, no3D toy rendering. Image2 forest is palette and painting reference. Fine1–2 working pixel edges, deliberate clean color clusters, upper-left light, muted natural materials. COMPLETE silhouette with transparent margins. No surrounding ground, cast shadow, writing, UI or labels. Do not draw the hero.
Asset: Open altar terrace, horizontal three shallow stone steps, a bronze incense burner, restrained cloth ribbons and two narrow stone posts, no roof or enclosed building. Entire platform complete and uncropped, no large trees.
Requested2x working art for nominal240x180 world silhouette. Adult doorway about88worldunits tall whenever the facility has a doorway; roof compact, not a tiny doll-house door. Preserve complete outline and the bottom-center approach. Fine painted pixels with restrained highlights, not realistic material shaders. Real alpha transparency.

## npcs

Two-dimensional hand-drawn JRPG NPC sprite sheet, EXACTLY3columns x3rows,9different down-facing full-body standing NPCs, each centered in its own cell with generous transparent margins. Image1 existing hero sets projection, body proportions and fine painted pixel density; image2 forest sets natural palette. Do NOT redraw or include the hero. Fine pixel color ramps and crisp tiny edges, not3D miniatures or smooth plastic. Same upper-left light, no cast shadow or ground. Adults about3.3heads tall, complete feet.
Row1: elderly steward, grey topknot, short beard, indigo robe, holding ledger; middle-aged gate guard, red headband, leather/lamellar vest and upright spear; middle-aged woman archivist, hair bun, muted teal robe and map roll.
Row2: cheerful young beast keeper with brown apron and feed bucket; stocky smith with leather apron and hammer; tall patrol instructor in dark red uniform with one armored shoulder and sword at hip.
Row3: elderly stable keeper with straw hat and grooming brush; bamboo-hatted peddler with ochre cloak and loaded backpack; noticeably shorter child with twin buns, pale-yellow clothes and paper pinwheel.
Every adult SAME relative visible height; child0.72 adult height. All front-facing and idle, no action poses. No cells overlap, no labels, writing, borders or accessories outside cells. Requested canvas1536x1536 with genuine alpha transparency.

## foliage_alpha

Edit target: six sprite sheet attached. Remove ALL colored gradient background, all background glow and ALL dark rectangular backdrop. Preserve exactly the six fine 2D hand-drawn pixel trees/bush/fern, same positions, same colors, complete roots, same 3 columns 2 rows. Genuine transparent alpha around each separate sprite, no checkerboard baked into image, no floor or cast shadow. Do not turn this into 3D. Output a transparent sprite sheet.

## props

Production sprite sheet for a pure 2D hand-drawn fine-pixel Chinese travel RPG. Transparent alpha, nine isolated objects in 3 columns and 3 rows, generous clear gutters, no background, no ground, no people, no letters. Straight camera aligned: see front face and top surfaces from elevated top-down view, never isometric or 3D rendered. Restrained natural wood, bronze, stone and lantern gold. Row1: wooden footbridge aligned north-south, open center deck no obstruction, width suited to one human and length twice width; wooden road barricade front-facing; small low gray stone treasure coffer. Row2: low wooden night table with two stools, open wooden visitor ledger stand with blank book; hanging bronze lantern on short timber post. Row3: hanging wind chime on small wooden stand; small upright weathered stone marker; group of three gray rocks. Match fine hand-painted pixel edge texture, light from upper left. Every object fully visible, flat illustrated game sprite with carefully clustered tiny pixels, no smooth gradient background, no extrusion or perspective rotation.

## construction

Single small unfinished Chinese village building site for pure 2D top-down hand-drawn pixel RPG. Front-facing camera elevated enough to see top surfaces, no diagonal isometric walls, no 3D rendered model. Transparent alpha, full object isolated, no ground patch/background/people/text. Low stone foundation, a few vertical timber posts, stacked planks and rolled muted beige canvas on one side. Center opening accessible, incomplete shrine lot clearly under construction without a gray placeholder signboard. Fine crisp clustered hand-painted pixels, restrained natural colors and upper-left light, wide shallow silhouette. Human opening roughly one third of total visible object height.

## frontend_login_portrait

Edit the attached travel-chest illustration into a TALL PORTRAIT 9:20 game screen background, approximately 960 wide by 2134 high. Actual output must be tall portrait, NOT landscape. Keep pure flat 2D hand-painted fine pixel art, no 3D render. Recompose chest as a vertically elongated open lacquer travel chest seen directly from above. Quiet dark wood top 20 percent for live title. Middle 58 percent contains a single large VERTICAL blank parchment sheet, width 80 percent canvas, no text or ruler marks. Chest sides have very restrained bronze corners and small supplies OUTSIDE blank writing region. Lower22percent quiet dark wood for login buttons. Tiny lantern at upper-left edge only. Do not draw UI or labels or characters. Expand canvas vertically; don't rotate or enlarge a horizontal image to fill portrait.
