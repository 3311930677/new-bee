# P08-E6 霜关建筑与居民美术（2026-10-01）

上轮 d1b6c2a 已接入细雪/栈道，43项回归及四职业授业取得通过。本轮继续把程序占位实体替换成同系列像素图，主角重绘仍后置，整体S0–S7目标保持。

## 本包结果与验证边界

七张素材已实际接入：三栋不同用途建筑、三名居民四帧待机及同源头像、未燃火盆。原PNG保留生成分辨率，NPC源条实际为2170×725、2172×724、2170×725，未伪称生成器达成512×128；`data/frost_city_art.json`登记实际源尺寸、SHA256、各帧区域和脚点，原生AtlasTexture.region/margin统一逻辑画布，世界内身高76。新素材以nearest及运行时alpha阈值0.5画硬边；未用脚本改写源PNG。`tools/register_frost_art.py`只分析像素并输出登记表，需Pillow/NumPy。

建筑宽192、底座4，原碰撞、站位、道路、出口、主支线表不改。永久火盆由ThirdActGround画结构与修复状态；修灯任务实体仅画名称/标记，保留365,660交互位置，避免旧占位火盆覆盖新图。损坏风灯未修复时不点亮，煤火暖光/挡风蓝焰跟随原永久选择；另一只普通火盆保持点亮。发现旧对话固定800高会遮住长屏角色，已改为当前视口底部190px处，提示文字随底部240px处定位。

- 最终正式回归：`tools/_logs/frost_art_final.log` **44/44**，每项退出0、自己的完成行、无运行期错误；新增VerifyFrostArt检查原图实际脚底像素与native margin、4帧逻辑画布/身体尺度、真实播放节点、同源头像、建筑碰撞/基座、任务实体不重绘占位物、煤火/挡风存读、800/1067对话与提示位置。
- 回归运行器新增第44项后，`frost_art_selftest.log` **11/11**故障注入自检通过。
- 破军/晨星各从E4已验收28步源档副本，以既有真实输入工具走完霜关六支线，选择挡风板，重新启动独立B进程验证不重复奖励。最终`frost_art_final_zs.log`、`frost_art_final_fz.log`各有PLAYTHROUGH_ALL_OK；A/B状态及存档字节一致，原装备实例、技能、伙伴、坐骑投入和主线字段一致。该回放证明已有六支线与挡风选择，不代表煤火选择的真实输入链；煤火由专项状态/存读检查覆盖。
- `shots/frost_art_20261001` **20张**原生SubViewport实际渲染图，480×800/480×1067分别查看街道、三建筑完整轮廓、三头像和两火盆选择，全部逐张目检。截图是隔离源档的布景，不作为解锁或自然游玩取得的证明。
- `tools/accept_frost_art.py`汇总逐项完成标记、11自检、两职业真实输入/A-B/源档哈希、7素材、20图、英雄与地理/剧情表差异以及真实玩家存档保护，输出`shots/frost_art_20261001/acceptance.json`。真实玩家存档SHA256仍为`C5D29EE55C033619C4F5232D55A6C4F186D40ADD556DB61EE0D776B9FDA2660C`。

已遇到并修正的工具问题：首次截图误用headless导致dummy renderer无纹理，精确定位并停止该截图子进程后改用实际GLES3渲染器；旧长屏对话位置和任务火盆覆盖均在截图检查中发现并修正，最终回归/回放/截图均在修正后取得。issue43退出期RID/资源/RenderingServer析构诊断仍存在，沿用既有运行器规则，没有放宽运行期错误判定；不宣称Android性能或全人工通关验收完成。

下一包继续其他地区/任务物件/明雷与战斗怪物画风、全养成资源与自然技能熟练链；第四幕s29–s36、两最终首领、18条支线补齐、机关房链及S4/S7门槛仍未完成。当前内容数保持主线28/36、支线18/36、首领6/8、14地图、v6存档。主角重绘仍后置，整体目标继续。

## 实施规则

三建筑各自有用途轮廓：驿舍、物资铺、巡界岗。原建筑id/菜单/碰撞/站位不变；同昭元按192宽、固定基座画图。三居民用四帧轻微呼吸，保留NPC站位/交互半径/剧情与关系；脚与骨盆登记、帧间身体尺度与头像裁切必须验证。头像来自同一待机源图，避免面貌不同。火盆图只含未点亮的结构，炭火/挡风片/煤火暖光仍从永久选择在运行时画出。

## 新素材与完整提示词

生成器原始输出保留在`C:\Users\Administrator\.codex\generated_images\01a0f14f-1707-7a33-9862-03a5eaa2ebc8`；项目PNG为其未修改副本，SHA256见登记表/验收清单。

| 项目素材ID | 原始输出文件 |
|---|---|
| city_frost_lodge_reference_v2 | exec-94c0a1a7-8316-4988-ad4d-f37637304e55.png |
| city_frost_supply_reference_v2 | exec-4746db54-5337-4b26-9109-c78b735d32e3.png |
| city_frost_guardhouse_reference_v2 | exec-d68ca4d2-8d3c-4a67-8835-f0417bde2598.png |
| npc_frost_envoy_idle_reference_v2 | exec-e35ba68c-5b7e-4f0a-bf3e-5dd17f0084b5.png |
| npc_frost_guard_idle_reference_v2 | exec-7e85e0f9-f583-4344-bea4-5f17f01ac543.png |
| npc_frost_miner_idle_reference_v2 | exec-7f9e1fe1-8911-41c2-bd50-4cebcb6edaea.png |
| frost_brazier_reference_v2 | exec-7bce7afa-0c28-4fe8-b4a3-16642e53e5f0.png |

### city_frost_lodge_reference_v2

输入：D:\new bee\远征\image\main_world\city_hall_reference_v2.png；D:\new bee\远征\image\main_world\frost_post_ground_reference_v2.png

Redraw image 1 into a compact snow-country Chinese fantasy courier lodge for Frost Post, keeping the reference's game building camera, scale, refined crisp pixel painting and dark-edged timber/stone material language. Image 2 is only the winter palette reference, not a floor to include. Replace the large civic hall with a modest broad-roofed timber-and-pale-stone inn/post station: snow lightly resting on blue-grey tiled eaves, warm amber lit lattice windows, a clear central wooden doorway facing the same downward game-view direction as the reference, a small chimney, a closed letter cabinet or bundled scroll case at one side, a small lantern under the eaves. Recognizable rest-house/courier purpose, no banners with symbols or text. 3/4 top-down 2D RPG building sprite, visible front and right side, camera and pixel detail density exactly like image 1. Single freestanding building with its own narrow stone doorstep/base, width greater than height, no landscape ground tile or large snow island; completely transparent outside the building. Base along the bottom at a stable horizontal line, whole roof and chimney fully visible with breathing room around the silhouette. Fine natural timber grain, small stone joints, restrained small snow details, no rough polygon blocks, no photo texture, no exaggerated chunky pixels or modern objects. No people, no writing, no UI, no frame, no detached shadows, no painted backdrop. PNG with real alpha transparency.

### city_frost_supply_reference_v2

输入：D:\new bee\远征\image\main_world\city_hall_reference_v2.png；D:\new bee\远征\image\main_world\frost_post_ground_reference_v2.png

Redraw image 1 into a compact winter supplies shop for a Chinese fantasy snowbound frontier post. Match image 1's 3/4 top-down RPG building camera, refined crisp pixel painting, scale, pale-stone/earthy timber and dark blue-grey tile materials. Image 2 is only the winter palette reference. A broad low timber-and-stone shop with light snow on blue-grey tiled eaves, one clear doorway and one open sheltered stall window facing down toward the viewer; amber lantern under the eaves, small neatly stacked grain sacks, two wooden supply chests and muted herb jars tucked close to one side of its narrow stone base. Practical provisions store silhouette clearly different from an inn or watchpost, no huge piles spread into neighboring space. Freestanding single building, roof and all props fit inside a compact wide silhouette, width greater than height. Entire sprite on real transparent alpha background, base at stable bottom line, no large ground slab or snow island, no separate environmental scenery or cast shadow. Fine small wood grain, seams, tile rows and delicate snow, restrained clean pixel-art texture rather than rough giant square blocks or smooth 3D rendering. No people, no lettering, no signs with text, no numbers, no UI, no border, no modern objects. Keep camera and pixel detail density exactly like image 1.

### city_frost_guardhouse_reference_v2

输入：D:\new bee\远征\image\main_world\city_hall_reference_v2.png；D:\new bee\远征\image\main_world\frost_post_ground_reference_v2.png

Redraw image 1 into a compact winter frontier guardhouse for Frost Post in a classic Chinese fantasy 2D RPG. Match the exact 3/4 top-down building camera and refined crisp pixel painting of image 1; image 2 is only a pale winter palette reference. Modest fortified timber-and-pale-stone guard station, broad blue-grey tiled roof with light snow on eaves, reinforced wooden doorway facing down toward the viewer, small amber-lit guard window, a short side weapon rack with two spears within the building's silhouette, a tiny plain muted teal pennant with no emblem or lettering. A sturdy readable silhouette distinct from a courier lodge and a store; no tall extra tower or castle wall sprawling across the scene. Width greater than height. Whole building fully visible with padding, stable bottom base line, its own narrow stone doorstep/base only. Truly transparent PNG background, no scenery floor, no large snow mound/island, no detached cast shadow. Fine small stone joints, natural timber grain, neat tile rows and subtle snow, not coarse polygon blocks, not chunky giant pixels, not smooth photorealistic 3D. No people, no text, no UI, no border, no modern objects.

### npc_frost_envoy_idle_reference_v2

输入：D:\new bee\远征\image\generated_201_333\ready\npcs\npc_port_worker_idle.png

Edit this exact four-frame horizontal pixel NPC idle strip, replacing the dockworker with Ning Yan, a young adult male courier of a Chinese fantasy snowy frontier post. Keep the original sheet format: ONE ROW of exactly FOUR evenly spaced complete full-body frames, same camera and standing three-quarter/front orientation, equal cell widths and cell heights. Intended small game sprite cells 128×128, whole strip 512×128; crisp detailed restrained pixel painting with small readable features matching the reference, no huge block pixels. Character: slim young man, black hair tied back, thoughtful calm face, blue-grey winter tunic, short muted sage/blue cloak with pale fur collar, dark trousers and brown boots, leather messenger satchel and a small tied letter bundle held close to his body. No readable letters, no icons or writing. Subtle breathing only: tiny cloak/chest movement and a very slight hand shift; head position, pelvis, body size and BOTH boot soles exactly aligned across all four cells, feet on the SAME y baseline, character anchor at each cell's exact horizontal center. Keep all full silhouettes fully inside their own cells with transparent separation. No walking or change of angle. Actual transparent alpha outside sprites; no ground, no shadow, no halo, no border, no numbers, no text, no grid lines, no additional characters or props outside cells. Do not keep any dockworker face or dockworker outfit.

### npc_frost_guard_idle_reference_v2

输入：D:\new bee\远征\image\generated_201_333\ready\npcs\npc_port_worker_idle.png

Edit this exact four-frame horizontal pixel NPC idle strip into Cen Xue, an adult female winter border guard in a Chinese fantasy 2D RPG. Preserve ONE ROW of exactly FOUR equally spaced complete full-body idle frames, equal cells, same three-quarter/front standing camera as this reference. Intended cells128×128, total512×128; detailed crisp readable small pixel sprite matching reference's texture density, not chunky huge pixels. Woman around30, practical black low ponytail, composed watchful face, muted teal padded guard tunic with modest steel shoulder/forearm plates, short blue-grey fur-collared winter cloak, dark trousers, fitted sturdy leather boots, sheathed short sword at her belt held close to body. Practical fully covered clothing, no ornate oversized armor. Four frames differ ONLY in subtle breathing and slight cloak-edge movement. Head, pelvis, body scale and boot positions remain exactly registered in every cell; soles on SAME baseline and character anchor at each cell's exact horizontal center. No walking, no angle change, whole boots and hair fully visible within each own cell with transparent gutters. Real alpha transparency, no background, no floor or shadow, no glow, no writing, no UI, no numbering, no border, no grid lines. Replace the original worker face/body/outfit completely; this is one female guard repeated across four frames, not four people.

### npc_frost_miner_idle_reference_v2

输入：D:\new bee\远征\image\generated_201_333\ready\npcs\npc_port_worker_idle.png

Edit this exact four-frame horizontal pixel NPC idle strip into Tao Duo, a middle-aged Chinese fantasy frost-country miner. Keep the same small detailed 2D RPG pixel painting and standing three-quarter/front camera. ONE ROW exactly FOUR equal-width equal-height full-body idle cells, intended128×128 each /512×128 whole strip. Weathered stocky man about45, short black hair and a small moustache, worn brown padded winter work coat, grey scarf, dark trousers and sturdy boots; a leather tool strap and a compact old mining pick carried low at his side, contained within his silhouette, no giant weapon. Muted earthy workwear, fine cloth seams and tiny metal highlights, readable fine pixels rather than coarse blocks. Same miner repeated across four registered frames with tiny chest/scarf breathing only. Keep head position, pelvis, scale, stance and BOTH boot soles exactly aligned: same foot baseline and anchor at each cell center. No walking, no change of angle, no large arm motion. Whole silhouette and pick fully visible within every own cell, transparent gutters separating frames. Real transparent alpha background, no ground or shadows, no halo, no lettering or labels, no grid, no UI, no border, no additional characters.

### frost_brazier_reference_v2

输入：D:\new bee\远征\image\main_world\city_hall_reference_v2.png

Extract and redraw the small metal fire-bowl motif from image 1 into ONE standalone winter roadside brazier prop sprite, in exactly the same refined crisp classic Chinese fantasy RPG pixel painting and 3/4 top-down game camera. A modest dark iron bowl on a short sturdy timber/stone pedestal, a little frost on the rim, three delicate side supports, weathered small seams. UNLIT bowl with a few dark charcoal chunks, absolutely NO flame or glowing light: flame color/repair/shield are dynamic runtime game layers. Fully visible prop with stable base along bottom, compact slightly taller-than-wide silhouette, entirely real transparent alpha surrounding it. No large ground slab, no snow island, no backdrop, no detached cast shadow, no building, no additional objects, no people, no text/UI/frame, no photorealistic texture or huge block pixels. Only the brazier and stand, suitable to render about36 pixels wide by64 high in game.
