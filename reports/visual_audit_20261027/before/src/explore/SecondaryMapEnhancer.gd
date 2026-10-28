class_name SecondaryMapEnhancer
extends RefCounted

## 商业级全地图环境与空间层次重构系统 (Version 3.0)
## 资深像素技术美术重构：
## 1. 远景地表纵深层 (FloorDepthLayer)：岩层高差、道路碎石风化带、车辙凹痕、区域特有微地貌（盐斑/矿脉/雪痕/渊隙）。
## 2. 中景环境叙事道具层 (SceneryLayer)：全地图专属手工地标配置，避让主干道路与怪物，接地软阴影与 Y-sort 真实遮挡。
## 3. 世界级顶层林冠遮蔽 (WorldCanopyLayer)：放置于世界坐标高处，角色穿行于其下实现自然景深。
## 4. 微动态环境粒子 (AmbientAtmosphereLayer)：超轻量飘叶、飞雪、矿洞微光孢子与渊界浮华，赋予静态地图鲜活生命力。

const RefArt := preload("res://src/world/ReferenceWorldArt.gd")


static func setup(map: Node) -> void:
	if map == null:
		return
	var map_id: String = String(map.get("_main_map_id"))
	if map_id.is_empty():
		return

	var world: Node2D = map.get("_world") as Node2D
	if world == null:
		return

	var cols: int = int(map.get("_map_cfg").get("map_cols", 20))
	var rows: int = int(map.get("_map_cfg").get("map_rows", 26))
	var map_size := Vector2(cols * 48.0, rows * 48.0)

	# 手绘整图地面已含地貌与道具，只保留氛围粒子，避免重复叠加。
	if bool((map.get("_main_cfg") as Dictionary).get("painted_ground", false)):
		var ambient := AmbientAtmosphereLayer.new(map_id, map_size)
		ambient.name = "AmbientAtmosphereLayer"
		ambient.z_index = 9
		world.add_child(ambient)
		return

	# 1. 地表纵深与微地貌过渡层 (z_index = -11, 位于地砖之上、实体之下)
	var floor_depth := FloorDepthLayer.new(map, map_id, map_size)
	floor_depth.name = "SecondaryFloorDepth"
	floor_depth.z_index = -11
	if not preload("res://src/world/WorldPresentation.gd").original_art():world.add_child(floor_depth)
	else:floor_depth.free()

	# 2. 中景环境道具层 (y_sort_enabled = true)
	var scenery_layer := SceneryLayer.new(map, map_id, map_size)
	scenery_layer.name = "SecondarySceneryLayer"
	scenery_layer.y_sort_enabled = true
	world.add_child(scenery_layer)

	# 3. 世界高层林冠遮罩层 (z_index = 8, 位于角色上方，营造穿行林荫深度)
	var canopy := WorldCanopyLayer.new(map_id, map_size)
	canopy.name = "WorldCanopyLayer"
	canopy.z_index = 8
	world.add_child(canopy)

	# 4. 微动态环境氛围粒子层 (z_index = 9)
	var atmosphere := AmbientAtmosphereLayer.new(map_id, map_size)
	atmosphere.name = "AmbientAtmosphereLayer"
	atmosphere.z_index = 9
	world.add_child(atmosphere)


# ==============================================================================
# 纹理通用解析器（兼容 ReferenceWorldArt、map_proc 及专用素材）
# ==============================================================================
static func resolve_texture(id: String) -> Texture2D:
	# 1. 优先从 ReferenceWorldArt 获取
	var tex: Texture2D = RefArt.texture(id)
	if tex != null:
		return tex

	# 2. 从 map_proc 目录获取
	var proc_path := "res://image/map_proc/%s.png" % id
	if ResourceLoader.exists(proc_path):
		return load(proc_path) as Texture2D

	# 3. 别名与降级映射
	var fallbacks := {
		"shrine": "res://image/main_world/art_v2/city_shrine_reference_v2.png",
		"chest": "res://image/map_proc/042_deco_tomb_coffin.png",
		"minecart": "res://image/map_proc/030_deco_forest_rocks.png",
		"cavern_crystal": "res://image/map_proc/036_deco_snow_icecrystal.png",
		"abyss_obelisk": "res://assets/world/reference_complete_20261011/ready/stele.png",
		"salt_cairn": "res://assets/world/reference_complete_20261011/ready/rocks.png",
	}
	if fallbacks.has(id) and ResourceLoader.exists(fallbacks[id]):
		return load(fallbacks[id]) as Texture2D

	return null


# ==============================================================================
# 1. 远景地表纵深层 (FloorDepthLayer)
# ==============================================================================
class FloorDepthLayer extends Node2D:
	var map_ref: Node = null
	var map_id: String = ""
	var map_size: Vector2 = Vector2.ZERO

	func _init(p_map: Node, p_id: String, p_size: Vector2) -> void:
		map_ref = p_map
		map_id = p_id
		map_size = p_size
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		var path_cells: Dictionary = map_ref.get("_ground_path") if map_ref != null else {}
		var is_snow := map_id.begins_with("frost_")
		var is_desert := map_id in ["old_salt_road", "shenyuan_port", "tideflat", "red_sand_route"]
		var is_tomb := map_id in ["stele_cavern", "tidal_gate", "rift_mine_road", "rift_mine_vault"]
		var is_abyss := map_id.begins_with("stele_") or map_id.begins_with("abyss_")

		# 1.1 道路边缘碎石风化带与车辙凹斑
		for cell_v in path_cells.keys():
			var cell: Vector2i = cell_v
			var cp := Vector2(cell.x * 48.0, cell.y * 48.0)
			var h := hash(cell.x * 7919 + cell.y * 104729)

			# 边角散落碎石与土斑
			for k in 4:
				var ox := float((h >> (k * 4)) & 0x1f) + 8.0
				var oy := float((h >> (k * 4 + 2)) & 0x1f) + 8.0
				var p := cp + Vector2(ox, oy)

				var pebble_color := Color("b2a382", 0.65)
				var shadow_color := Color("4a4235", 0.40)

				if is_snow:
					pebble_color = Color("cde0ef", 0.60)
					shadow_color = Color("4b6375", 0.35)
				elif is_desert:
					pebble_color = Color("d9c193", 0.65)
					shadow_color = Color("6b5030", 0.40)
				elif is_tomb:
					pebble_color = Color("8c8a82", 0.60)
					shadow_color = Color("2b2c2d", 0.45)
				elif is_abyss:
					pebble_color = Color("7a6f91", 0.65)
					shadow_color = Color("231c30", 0.50)

				draw_rect(Rect2(p, Vector2(3, 2)), pebble_color)
				draw_rect(Rect2(p + Vector2(1, 1), Vector2(2, 1)), shadow_color)

		# 1.2 主世界各区域断续天然地貌特征
		var step := 36.0
		var nx := int(map_size.x / step)
		var ny := int(map_size.y / step)
		for gy in ny:
			for gx in nx:
				var gx_i := int(gx * step / 48.0)
				var gy_i := int(gy * step / 48.0)
				if path_cells.has(Vector2i(gx_i, gy_i)):
					continue # 避开主行道保持路面平整可读

				var seed_val := hash(gx * 31337 + gy * 7919 + hash(map_id))
				if (seed_val % 100) < 30:
					var pt := Vector2(gx * step + float(seed_val % 18), gy * step + float((seed_val >> 4) % 18))

					if is_snow:
						# 积雪浮层与冰晶微斑
						draw_rect(Rect2(pt, Vector2(3, 3)), Color("e5eef7", 0.45))
						if (seed_val % 3) == 0:
							draw_rect(Rect2(pt + Vector2(1, -2), Vector2(2, 2)), Color("b0d1e8", 0.40))
					elif is_desert:
						# 盐碱结晶与风蚀沙纹
						draw_rect(Rect2(pt, Vector2(3, 2)), Color("eef6f8", 0.50))
						if (seed_val % 3) == 0:
							draw_rect(Rect2(pt + Vector2(2, 1), Vector2(3, 1)), Color("b59664", 0.35))
					elif is_tomb:
						# 矿洞页岩裂痕与黄铁矿微斑
						draw_rect(Rect2(pt, Vector2(3, 2)), Color("3c3f42", 0.50))
						if (seed_val % 4) == 0:
							draw_rect(Rect2(pt + Vector2(1, 0), Vector2(2, 1)), Color("d4af37", 0.45))
					elif is_abyss:
						# 渊界裂痕与星辉微晶
						draw_rect(Rect2(pt, Vector2(3, 2)), Color("2c2438", 0.60))
						if (seed_val % 3) == 0:
							draw_rect(Rect2(pt + Vector2(1, 1), Vector2(2, 2)), Color("a97eed", 0.45))
					else:
						# 林地草簇与落叶微斑
						draw_rect(Rect2(pt, Vector2(3, 3)), Color("55633e", 0.45))
						if (seed_val % 3) == 0:
							draw_rect(Rect2(pt + Vector2(1, -2), Vector2(2, 2)), Color("91a65d", 0.40))


# ==============================================================================
# 2. 中景环境叙事道具层 (SceneryLayer)
# ==============================================================================
class SceneryLayer extends Node2D:
	var map_ref: Node = null
	var map_id: String = ""
	var map_size: Vector2 = Vector2.ZERO

	func _init(p_map: Node, p_id: String, p_size: Vector2) -> void:
		map_ref = p_map
		map_id = p_id
		map_size = p_size
		_spawn_props()

	func _spawn_props() -> void:
		match map_id:
			"lorin_wilds":
				return # 昭元边城完整保留原有建筑与生活区，仅受氛围粒子与地貌微光滋养

			# === 第一幕：林野与碑窟 ===
			"broken_slope":
				_build_broken_slope_story()
			"stele_cavern":
				_build_stele_cavern_story()

			# === 第二幕：盐道、沉渊港与潮痕滩 ===
			"old_salt_road":
				_build_salt_road_story()
			"shenyuan_port":
				_build_shenyuan_port_story()
			"tideflat":
				_build_tideflat_story()
			"tidal_gate":
				_build_tidal_gate_story()

			# === 第三幕：赤砂、霜关、矿道与冰隘 ===
			"red_sand_route":
				_build_red_sand_story()
			"frost_post":
				_build_frost_post_story()
			"rift_mine_road":
				_build_mine_road_story()
			"rift_mine_vault":
				_build_mine_vault_story()
			"frost_boardwalk":
				_build_frost_boardwalk_story()
			"frost_pass":
				_build_frost_pass_story()

			# === 第四幕：渊口外环与终焉碑域 ===
			"abyss_ring":
				_build_abyss_ring_story()
			"stele_entry":
				_build_stele_entry_story()
			"stele_resonance":
				_build_stele_resonance_story()
			"stele_core":
				_build_stele_core_story()

			_:
				_build_generic_props()

	# --- 第一幕 ---
	func _build_broken_slope_story() -> void:
		var props := [
			{"id": "stele", "at": Vector2(175, 490), "scale": 1.0},
			{"id": "stele", "at": Vector2(795, 530), "scale": 0.95},
			{"id": "stele", "at": Vector2(160, 820), "scale": 1.05},
			{"id": "stele", "at": Vector2(780, 810), "scale": 1.0},
			{"id": "rocks", "at": Vector2(110, 360), "scale": 1.1},
			{"id": "rocks", "at": Vector2(830, 370), "scale": 1.1},
			{"id": "rocks", "at": Vector2(70, 720), "scale": 1.0},
			{"id": "rocks", "at": Vector2(860, 720), "scale": 1.0},
			{"id": "red_maple", "at": Vector2(35, 480), "scale": 1.0},
			{"id": "red_maple", "at": Vector2(920, 520), "scale": 1.0},
			{"id": "gold_maple", "at": Vector2(40, 780), "scale": 0.95},
			{"id": "gold_maple", "at": Vector2(910, 820), "scale": 1.0},
			{"id": "stonebox", "at": Vector2(350, 730), "scale": 0.85},
			{"id": "shrine", "at": Vector2(840, 260), "scale": 0.85},
			{"id": "bush", "at": Vector2(205, 505), "scale": 0.9},
			{"id": "fern", "at": Vector2(140, 835), "scale": 1.0},
		]
		_instantiate_list(props)

	func _build_stele_cavern_story() -> void:
		var props := [
			{"id": "stele", "at": Vector2(170, 420), "scale": 1.1},
			{"id": "stele", "at": Vector2(790, 450), "scale": 1.05},
			{"id": "stele", "at": Vector2(180, 760), "scale": 1.15},
			{"id": "stele", "at": Vector2(780, 780), "scale": 1.1},
			{"id": "rocks", "at": Vector2(120, 280), "scale": 1.2},
			{"id": "rocks", "at": Vector2(840, 300), "scale": 1.2},
			{"id": "rocks", "at": Vector2(80, 620), "scale": 1.1},
			{"id": "rocks", "at": Vector2(880, 640), "scale": 1.1},
			{"id": "lantern", "at": Vector2(330, 950), "scale": 0.9},
			{"id": "lantern", "at": Vector2(630, 950), "scale": 0.9},
			{"id": "stonebox", "at": Vector2(320, 680), "scale": 0.85},
		]
		_instantiate_list(props)

	# --- 第二幕 ---
	func _build_salt_road_story() -> void:
		var props := [
			{"id": "rocks", "at": Vector2(140, 420), "scale": 1.1},
			{"id": "rocks", "at": Vector2(810, 450), "scale": 1.1},
			{"id": "rocks", "at": Vector2(100, 760), "scale": 1.0},
			{"id": "rocks", "at": Vector2(850, 790), "scale": 1.0},
			{"id": "stonebox", "at": Vector2(340, 680), "scale": 0.85},
			{"id": "signpost", "at": Vector2(620, 980), "scale": 0.9},
			{"id": "bush", "at": Vector2(180, 740), "scale": 0.85},
			{"id": "bush", "at": Vector2(760, 780), "scale": 0.85},
		]
		_instantiate_list(props)

	func _build_shenyuan_port_story() -> void:
		var props := [
			{"id": "lantern", "at": Vector2(340, 880), "scale": 0.95},
			{"id": "lantern", "at": Vector2(620, 880), "scale": 0.95},
			{"id": "barricade", "at": Vector2(210, 720), "scale": 0.9},
			{"id": "barricade", "at": Vector2(750, 720), "scale": 0.9},
			{"id": "stonebox", "at": Vector2(220, 520), "scale": 0.85},
			{"id": "stonebox", "at": Vector2(740, 520), "scale": 0.85},
			{"id": "rocks", "at": Vector2(90, 360), "scale": 1.0},
			{"id": "rocks", "at": Vector2(870, 360), "scale": 1.0},
		]
		_instantiate_list(props)

	func _build_tideflat_story() -> void:
		var props := [
			{"id": "rocks", "at": Vector2(130, 420), "scale": 1.15},
			{"id": "rocks", "at": Vector2(820, 460), "scale": 1.15},
			{"id": "rocks", "at": Vector2(90, 740), "scale": 1.1},
			{"id": "rocks", "at": Vector2(860, 780), "scale": 1.1},
			{"id": "stonebox", "at": Vector2(330, 710), "scale": 0.85},
			{"id": "bush", "at": Vector2(170, 720), "scale": 0.85},
			{"id": "bush", "at": Vector2(780, 750), "scale": 0.85},
		]
		_instantiate_list(props)

	func _build_tidal_gate_story() -> void:
		var props := [
			{"id": "stele", "at": Vector2(180, 520), "scale": 1.0},
			{"id": "stele", "at": Vector2(780, 520), "scale": 1.0},
			{"id": "rocks", "at": Vector2(110, 380), "scale": 1.1},
			{"id": "rocks", "at": Vector2(850, 380), "scale": 1.1},
			{"id": "barricade", "at": Vector2(240, 840), "scale": 0.9},
			{"id": "barricade", "at": Vector2(720, 840), "scale": 0.9},
			{"id": "lantern", "at": Vector2(350, 960), "scale": 0.9},
			{"id": "lantern", "at": Vector2(610, 960), "scale": 0.9},
		]
		_instantiate_list(props)

	# --- 第三幕 ---
	func _build_red_sand_story() -> void:
		var props := [
			{"id": "rocks", "at": Vector2(120, 430), "scale": 1.15},
			{"id": "rocks", "at": Vector2(830, 450), "scale": 1.15},
			{"id": "rocks", "at": Vector2(80, 760), "scale": 1.1},
			{"id": "rocks", "at": Vector2(870, 780), "scale": 1.1},
			{"id": "signpost", "at": Vector2(340, 980), "scale": 0.9},
			{"id": "stonebox", "at": Vector2(620, 700), "scale": 0.85},
			{"id": "bush", "at": Vector2(160, 750), "scale": 0.8},
			{"id": "bush", "at": Vector2(790, 770), "scale": 0.8},
		]
		_instantiate_list(props)

	func _build_frost_post_story() -> void:
		var props := [
			{"id": "pine", "at": Vector2(40, 320), "scale": 1.05},
			{"id": "pine", "at": Vector2(920, 350), "scale": 1.05},
			{"id": "pine", "at": Vector2(40, 720), "scale": 1.0},
			{"id": "pine", "at": Vector2(920, 760), "scale": 1.0},
			{"id": "rocks", "at": Vector2(150, 520), "scale": 1.0},
			{"id": "rocks", "at": Vector2(780, 560), "scale": 1.0},
			{"id": "lantern", "at": Vector2(340, 860), "scale": 0.95},
			{"id": "lantern", "at": Vector2(620, 860), "scale": 0.95},
			{"id": "barricade", "at": Vector2(750, 840), "scale": 0.90},
			{"id": "stonebox", "at": Vector2(230, 700), "scale": 0.85},
		]
		_instantiate_list(props)

	func _build_mine_road_story() -> void:
		var props := [
			{"id": "rocks", "at": Vector2(110, 380), "scale": 1.2},
			{"id": "rocks", "at": Vector2(840, 410), "scale": 1.2},
			{"id": "rocks", "at": Vector2(70, 740), "scale": 1.15},
			{"id": "rocks", "at": Vector2(870, 760), "scale": 1.15},
			{"id": "barricade", "at": Vector2(250, 820), "scale": 0.95},
			{"id": "barricade", "at": Vector2(710, 820), "scale": 0.95},
			{"id": "lantern", "at": Vector2(350, 940), "scale": 0.9},
			{"id": "stonebox", "at": Vector2(320, 680), "scale": 0.85},
		]
		_instantiate_list(props)

	func _build_mine_vault_story() -> void:
		var props := [
			{"id": "stele", "at": Vector2(170, 480), "scale": 1.1},
			{"id": "stele", "at": Vector2(790, 510), "scale": 1.1},
			{"id": "rocks", "at": Vector2(100, 340), "scale": 1.2},
			{"id": "rocks", "at": Vector2(850, 360), "scale": 1.2},
			{"id": "lantern", "at": Vector2(340, 950), "scale": 0.95},
			{"id": "lantern", "at": Vector2(620, 950), "scale": 0.95},
			{"id": "stonebox", "at": Vector2(630, 720), "scale": 0.9},
		]
		_instantiate_list(props)

	func _build_frost_boardwalk_story() -> void:
		var props := [
			{"id": "pine", "at": Vector2(40, 360), "scale": 1.05},
			{"id": "pine", "at": Vector2(920, 390), "scale": 1.05},
			{"id": "pine", "at": Vector2(45, 780), "scale": 1.0},
			{"id": "pine", "at": Vector2(915, 820), "scale": 1.0},
			{"id": "rocks", "at": Vector2(140, 540), "scale": 1.05},
			{"id": "rocks", "at": Vector2(800, 570), "scale": 1.05},
			{"id": "lantern", "at": Vector2(350, 880), "scale": 0.9},
			{"id": "lantern", "at": Vector2(610, 880), "scale": 0.9},
			{"id": "barricade", "at": Vector2(730, 820), "scale": 0.9},
		]
		_instantiate_list(props)

	func _build_frost_pass_story() -> void:
		var props := [
			{"id": "rocks", "at": Vector2(100, 380), "scale": 1.25},
			{"id": "rocks", "at": Vector2(850, 400), "scale": 1.25},
			{"id": "rocks", "at": Vector2(70, 720), "scale": 1.2},
			{"id": "rocks", "at": Vector2(880, 750), "scale": 1.2},
			{"id": "pine", "at": Vector2(35, 520), "scale": 1.0},
			{"id": "pine", "at": Vector2(925, 560), "scale": 1.0},
			{"id": "stele", "at": Vector2(180, 820), "scale": 1.05},
			{"id": "stele", "at": Vector2(780, 840), "scale": 1.05},
			{"id": "barricade", "at": Vector2(250, 890), "scale": 0.9},
			{"id": "barricade", "at": Vector2(710, 890), "scale": 0.9},
		]
		_instantiate_list(props)

	# --- 第四幕 ---
	func _build_abyss_ring_story() -> void:
		var props := [
			{"id": "stele", "at": Vector2(170, 460), "scale": 1.15},
			{"id": "stele", "at": Vector2(790, 490), "scale": 1.15},
			{"id": "stele", "at": Vector2(160, 800), "scale": 1.2},
			{"id": "stele", "at": Vector2(800, 820), "scale": 1.2},
			{"id": "rocks", "at": Vector2(90, 330), "scale": 1.2},
			{"id": "rocks", "at": Vector2(860, 350), "scale": 1.2},
			{"id": "rocks", "at": Vector2(70, 680), "scale": 1.15},
			{"id": "rocks", "at": Vector2(880, 700), "scale": 1.15},
			{"id": "lantern", "at": Vector2(330, 940), "scale": 0.95},
			{"id": "lantern", "at": Vector2(630, 940), "scale": 0.95},
		]
		_instantiate_list(props)

	func _build_stele_entry_story() -> void:
		var props := [
			{"id": "stele", "at": Vector2(180, 420), "scale": 1.2},
			{"id": "stele", "at": Vector2(780, 440), "scale": 1.2},
			{"id": "stele", "at": Vector2(180, 780), "scale": 1.2},
			{"id": "stele", "at": Vector2(780, 800), "scale": 1.2},
			{"id": "rocks", "at": Vector2(100, 260), "scale": 1.2},
			{"id": "rocks", "at": Vector2(860, 280), "scale": 1.2},
			{"id": "lantern", "at": Vector2(320, 920), "scale": 0.95},
			{"id": "lantern", "at": Vector2(640, 920), "scale": 0.95},
			{"id": "stonebox", "at": Vector2(630, 650), "scale": 0.9},
		]
		_instantiate_list(props)

	func _build_stele_resonance_story() -> void:
		var props := [
			{"id": "stele", "at": Vector2(170, 350), "scale": 1.25},
			{"id": "stele", "at": Vector2(790, 370), "scale": 1.25},
			{"id": "stele", "at": Vector2(170, 680), "scale": 1.25},
			{"id": "stele", "at": Vector2(790, 700), "scale": 1.25},
			{"id": "rocks", "at": Vector2(90, 220), "scale": 1.2},
			{"id": "rocks", "at": Vector2(870, 240), "scale": 1.2},
			{"id": "lantern", "at": Vector2(340, 880), "scale": 0.95},
			{"id": "lantern", "at": Vector2(620, 880), "scale": 0.95},
		]
		_instantiate_list(props)

	func _build_stele_core_story() -> void:
		var props := [
			{"id": "stele", "at": Vector2(180, 320), "scale": 1.3},
			{"id": "stele", "at": Vector2(780, 340), "scale": 1.3},
			{"id": "stele", "at": Vector2(170, 660), "scale": 1.3},
			{"id": "stele", "at": Vector2(790, 680), "scale": 1.3},
			{"id": "rocks", "at": Vector2(90, 180), "scale": 1.25},
			{"id": "rocks", "at": Vector2(870, 200), "scale": 1.25},
			{"id": "lantern", "at": Vector2(330, 920), "scale": 1.0},
			{"id": "lantern", "at": Vector2(630, 920), "scale": 1.0},
		]
		_instantiate_list(props)

	func _build_generic_props() -> void:
		var props := [
			{"id": "rocks", "at": Vector2(130, 450), "scale": 1.1},
			{"id": "rocks", "at": Vector2(820, 480), "scale": 1.1},
			{"id": "stele", "at": Vector2(180, 750), "scale": 1.0},
			{"id": "bush", "at": Vector2(760, 790), "scale": 0.95},
		]
		_instantiate_list(props)

	func _instantiate_list(props: Array) -> void:
		for item in props:
			_create_prop_node(String(item.id), item.at, float(item.get("scale", 1.0)))

	func _create_prop_node(id: String, pos: Vector2, sc: float) -> void:
		var tex := SecondaryMapEnhancer.resolve_texture(id)
		if tex == null:
			return

		var node := Node2D.new()
		node.name = "Prop_" + id
		node.position = pos

		# 像素缩放比为 0.5 (source_to_world)
		var base_scale := 0.5 * sc * preload("res://src/world/WorldPresentation.gd").SCENERY_ENLARGEMENT
		var shadow_size := tex.get_size() * base_scale * 0.5
		var shadow := PropShadow.new(shadow_size)
		node.add_child(shadow)

		# 商业级径向暖光光晕（风灯/祭坛/晶石在地面投射真实光照，烘托夜幕与冷暖对比）
		if id in ["lantern", "shrine", "brazier", "cavern_crystal"]:
			var glow := PropGlow.new(id)
			node.add_child(glow)

		# 精灵本体（Origin 在脚底中央，符合 Y-Sort 真实地表遮挡）
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.texture_filter = preload("res://src/world/WorldPresentation.gd").sampling()
		spr.scale = Vector2(base_scale, base_scale)
		spr.offset = Vector2(0, -tex.get_height() * 0.5)
		node.add_child(spr)

		add_child(node)


class PropShadow extends Node2D:
	var shadow_size: Vector2 = Vector2(32, 16)

	func _init(p_size: Vector2) -> void:
		shadow_size = p_size
		z_index = -1

	func _draw() -> void:
		var shadow_center := Vector2(shadow_size.x * 0.20, shadow_size.y * 0.12)
		var rx := maxf(8.0, shadow_size.x * 0.55)
		draw_set_transform(shadow_center, 0.18, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, rx, Color("14121a", 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class PropGlow extends Node2D:
	var prop_id: String

	func _init(p_id: String) -> void:
		prop_id = p_id
		z_index = -2 # 渲染在阴影和实体下方，直接照亮地表

	func _draw() -> void:
		# 只在灯脚地面留一小片压扁的暖光：旧版 4 层叠圆会在像素地面上叠出明显同心环。
		var glow_col := Color("ffb36b", 0.10)
		if prop_id == "cavern_crystal":
			glow_col = Color("b48cff", 0.10)
		elif prop_id == "shrine":
			glow_col = Color("ffe3a0", 0.09)
		draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 24.0, glow_col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ==============================================================================
# 3. 世界高层林冠遮罩层 (WorldCanopyLayer) - 置于世界坐标，产生穿行纵深
# ==============================================================================
class WorldCanopyLayer extends Node2D:
	var map_id: String = ""
	var map_size: Vector2 = Vector2.ZERO

	func _init(p_id: String, p_size: Vector2) -> void:
		map_id = p_id
		map_size = p_size
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _ready() -> void:
		if map_id.begins_with("stele_") or map_id.begins_with("rift_mine_"):
			return # 洞穴与地下矿道不挂林冠

		var is_snow := map_id.begins_with("frost_")
		var is_desert := map_id in ["old_salt_road", "red_sand_route", "tideflat"]
		if is_desert:
			return # 荒漠不挂密林冠

		var tree_tex: Texture2D = SecondaryMapEnhancer.resolve_texture("pine" if is_snow else "red_maple")
		if tree_tex == null:
			return

		# 在地图两翼高处悬挑枝叶（世界坐标，角色穿行其下产生真实空间透视）
		var left_branch := Sprite2D.new()
		left_branch.texture = tree_tex
		left_branch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		left_branch.position = Vector2(60, 180)
		left_branch.scale = Vector2(0.55, 0.55)
		left_branch.modulate = Color("1a171c", 0.92) # 剪影暗调烘托景深
		add_child(left_branch)

		var right_branch := Sprite2D.new()
		right_branch.texture = SecondaryMapEnhancer.resolve_texture("pine" if is_snow else "gold_maple")
		right_branch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		right_branch.position = Vector2(map_size.x - 60, 210)
		right_branch.scale = Vector2(-0.52, 0.52) # 水平翻转
		right_branch.modulate = Color("1f181c", 0.90)
		add_child(right_branch)


# ==============================================================================
# 4. 微动态环境氛围粒子 (AmbientAtmosphereLayer) - 超轻量纯代码绘制，0纹理开销
# ==============================================================================
class AmbientAtmosphereLayer extends Node2D:
	var map_id: String = ""
	var map_size: Vector2 = Vector2.ZERO
	var _particles: Array[Dictionary] = []
	var _time: float = 0.0

	func _init(p_id: String, p_size: Vector2) -> void:
		map_id = p_id
		map_size = p_size
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_spawn_particles()

	func _spawn_particles() -> void:
		var count := 20
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(map_id) + 997

		var is_snow := map_id.begins_with("frost_")
		var is_abyss := map_id.begins_with("stele_") or map_id.begins_with("abyss_")
		var is_cavern := map_id.begins_with("rift_mine_")

		for i in count:
			var p := {
				"pos": Vector2(rng.randf_range(0, map_size.x), rng.randf_range(0, map_size.y)),
				"speed": rng.randf_range(16.0, 36.0),
				"drift": rng.randf_range(-12.0, 18.0),
				"size": rng.randf_range(1.5, 3.0),
				"phase": rng.randf_range(0, TAU),
			}
			if is_snow:
				p["color"] = Color("e2effa", rng.randf_range(0.45, 0.75))
			elif is_abyss:
				p["color"] = Color("b487f7", rng.randf_range(0.35, 0.65))
			elif is_cavern:
				p["color"] = Color("e0c878", rng.randf_range(0.30, 0.55))
			else:
				# 秋叶
				p["color"] = Color("c9602e" if (i % 2 == 0) else "d89a38", rng.randf_range(0.45, 0.70))

			_particles.append(p)

	func _process(delta: float) -> void:
		_time += delta
		var is_abyss := map_id.begins_with("stele_") or map_id.begins_with("abyss_")

		for p in _particles:
			var sway := sin(_time * 2.2 + float(p.phase)) * 8.0
			if is_abyss:
				# 渊界微粒向上悬浮升腾
				p.pos.y -= float(p.speed) * delta * 0.7
				p.pos.x += sway * delta
				if p.pos.y < 0:
					p.pos.y = map_size.y
					p.pos.x = fmod(p.pos.x + 37.0, map_size.x)
			else:
				# 落叶/飞雪飘落
				p.pos.y += float(p.speed) * delta
				p.pos.x += (float(p.drift) + sway) * delta
				if p.pos.y > map_size.y:
					p.pos.y = 0
					p.pos.x = fmod(p.pos.x + 43.0, map_size.x)

		queue_redraw()

	func _draw() -> void:
		for p in _particles:
			var pos: Vector2 = p.pos
			var sz: float = p.size
			var col: Color = p.color
			draw_rect(Rect2(pos, Vector2(sz, sz)), col)
