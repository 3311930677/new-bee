extends Node2D

# 第三幕可走地貌；识别图形在实体下层，不用装饰性裂谷充当隐形碰撞。
var map_id := ""
var use_reference_ground := false
var flat_floor := false
var _choice := ""
var _brazier_choice := ""
var _brazier_art: Texture2D

func _ready() -> void:
	if map_id == "frost_post":
		_brazier_art = FrostCityArt.prop("frost_brazier")
		material = FrostCityArt.cutout_material()


func _process(_delta: float) -> void:
	if map_id != "frost_post": return
	var choice := String((G.prog.get("flags", {}) as Dictionary).get("act3_supply_choice", ""))
	var brazier := String((G.prog.get("flags", {}) as Dictionary).get("act3_brazier_choice", ""))
	if choice != _choice or brazier != _brazier_choice:
		_choice = choice
		_brazier_choice = brazier
		queue_redraw()


func _draw() -> void:
	if flat_floor and map_id != "frost_post":
		# Keep rails as flat material markings; raised rock/ravine/port-water art is superseded.
		if map_id == "rift_mine_road":
			for y in range(170, 1090, 34):
				draw_line(Vector2(435, y), Vector2(525, y), Color("8c8370"), 5)
			for x in [444.0, 516.0]:
				draw_line(Vector2(x, 145), Vector2(x, 1110), Color("c9c4ac"), 3)
		return
	match map_id:
		"red_sand_route":
			# 两个出口沿中轴连接；车辙说明这是运货路，路边红岩不挡主路。
			preload("res://src/explore/TerrainSurface.gd").tiled(self, "res://image/map_proc/014_tile_desert_2.png", Rect2(423, 80, 114, 1090), Vector2(114, 114), Color("dcc599"))
			for x in [453.0, 507.0]:
				draw_line(Vector2(x, 96), Vector2(x, 1152), Color("84694c"), 4)
			for y in [275.0, 640.0, 970.0]:
				_rock(Vector2(105, y), Color("ad6249"))
				_rock(Vector2(855, y + 40), Color("ad6249"))
			draw_rect(Rect2(567, 725, 96, 56), Color("80664b"))
			for x in [585.0, 625.0]:
				draw_line(Vector2(x, 717), Vector2(x, 790), Color("4a4034"), 6)
		"frost_post":
			if not _choice.is_empty():
				var color := Color("c9b477") if _choice == "merchant" else Color("83bfc6")
				for x in [415.0, 545.0]:
					draw_rect(Rect2(x - 3, 235, 6, 95), Color("635543"))
					draw_rect(Rect2(x, 235, 34, 48), color)
					draw_rect(Rect2(x + 8, 245, 18, 5), Color("eee7d4"))
			if not use_reference_ground and not flat_floor:
				# 雪地木栈道：宽主街与东向矿道支路，两侧房屋独立留出 NPC 空间。
				_boardwalk(Rect2(426, 80, 108, 1100))
				_boardwalk(Rect2(335, 420, 260, 60))
				_boardwalk(Rect2(335, 840, 300, 60))
				_boardwalk(Rect2(480, 680, 398, 60))
			for p in [Vector2(365, 660), Vector2(595, 970)]:
				var repaired: bool = p.x == 365 and not _brazier_choice.is_empty()
				if repaired and _brazier_choice == "coal":
					draw_circle(p + Vector2(0, -42), 40, Color(0.98, 0.64, 0.18, 0.16))
				if _brazier_art != null:
					draw_texture_rect(_brazier_art, Rect2(p + Vector2(-18, -64), Vector2(36, 64)), false)
				var lamp := Color("83bfc6") if repaired and _brazier_choice == "shield" else Color("f4c779")
				if _brazier_lit(p):
					draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -48), p + Vector2(-5, -57),
						p + Vector2(-2, -53), p + Vector2(1, -66), p + Vector2(4, -57),
						p + Vector2(8, -54), p + Vector2(7, -48)]), lamp)
					draw_colored_polygon(PackedVector2Array([p + Vector2(-3, -48), p + Vector2(0, -57),
						p + Vector2(3, -49)]), Color("fff3cf"))
				if repaired and _brazier_choice == "shield":
					draw_rect(Rect2(p + Vector2(20, -71), Vector2(8, 43)), Color("6d8490"))
			if not use_reference_ground and not flat_floor:
				for y in [245.0, 1040.0]:
					_rock(Vector2(165, y), Color("889c9c"))
		"rift_mine_road":
			# 侧面的开采沟与两条明亮轨道构成矿道识别点；中央和西出口可步行。
			draw_colored_polygon(PackedVector2Array([Vector2(620, 190), Vector2(960, 230),
				Vector2(960, 1000), Vector2(760, 1090), Vector2(660, 895)]), Color("252e37", 0.9))
			preload("res://src/explore/TerrainSurface.gd").tiled(self, "res://image/main_world/rail_texture_visual_v2.png", Rect2(410, 160, 140, 948), Vector2(140, 210))
			_boardwalk(Rect2(80, 680, 330, 60))
			for y in [320.0, 860.0]:
				draw_line(Vector2(385, y), Vector2(385, y + 76), Color("8b7151"), 13)
				draw_line(Vector2(577, y), Vector2(577, y + 76), Color("8b7151"), 13)
				draw_line(Vector2(378, y), Vector2(584, y), Color("ab9061"), 13)
		"rift_mine_vault":
			preload("res://src/explore/TerrainSurface.gd").tiled(self, "res://image/map_proc/011_tile_tomb_2.png", Rect2(370, 135, 220, 1045), Vector2(110, 110), Color("b7b19e"))
			preload("res://src/explore/TerrainSurface.gd").tiled(self, "res://image/main_world/rail_texture_visual_v2.png", Rect2(410, 135, 140, 1045), Vector2(140, 210))
			for p in [Vector2(230, 440), Vector2(735, 440)]:
				draw_circle(p, 58, Color("574737"))
				draw_arc(p, 44, 0, TAU, 16, Color("bd925a"), 12)
				for i in 8:
					var at: Vector2 = p + Vector2.from_angle(i * TAU / 8) * 59
					draw_rect(Rect2(at - Vector2(9, 9), Vector2(18, 18)), Color("bd925a"))
		"frost_boardwalk":
			preload("res://src/explore/TerrainSurface.gd").tiled(self,
				"res://image/main_world/shenyuan_port_ground_reference_v2.png",
				Rect2(345, 140, 270, 1040), Vector2(135, 180), Color("a1b5c9"), Rect2(12, 120, 270, 320))
			_boardwalk(Rect2(400, 135, 160, 1045))
			for y in range(160, 1150, 95):
				for x in [385.0, 575.0]:
					draw_rect(Rect2(x - 5, y, 10, 44), Color("53483c"))
			for x in [385.0, 575.0]:
				draw_line(Vector2(x, 175), Vector2(x, 1160), Color("c6c4b0"), 5)
		"frost_pass":
			preload("res://src/explore/TerrainSurface.gd").tiled(self,
				"res://image/map_proc/017_tile_glacier_2.png", Rect2(480, 620, 398, 82),
				Vector2(72, 72), Color("d3e4e7"))
			preload("res://src/explore/TerrainSurface.gd").tiled(self,
				"res://image/map_proc/017_tile_glacier_2.png", Rect2(370, 135, 220, 1045),
				Vector2(72, 72), Color("d3e4e7"))
			for y in [230.0, 540.0, 880.0]:
				_rock(Vector2(245, y), Color("a5cbd2"))
				_rock(Vector2(730, y + 70), Color("a5cbd2"))
			for x in [350.0, 610.0]:
				draw_rect(Rect2(x - 24, 310, 48, 85), Color("718f9b"))
				draw_rect(Rect2(x - 18, 320, 36, 55), Color("bddbe1"))
				draw_line(Vector2(x - 9, 330), Vector2(x + 9, 365), Color("4e7c90"), 5)


func _brazier_lit(at: Vector2) -> bool:
	return at.x != 365.0 or not _brazier_choice.is_empty()


func _boardwalk(rect: Rect2) -> void:
	preload("res://src/explore/TerrainSurface.gd").tiled(self, "res://image/main_world/board_texture_visual_v2.png", rect, Vector2(96, 96), Color("d9d5c7"))
	draw_rect(rect, Color("4c483e", 0.65), false, 2)


func _rock(at: Vector2, color: Color) -> void:
	var rock := G.res_tex("res://image/map_proc/030_deco_forest_rocks.png")
	if rock != null:
		draw_texture_rect(rock, Rect2(at + Vector2(-42, -54), Vector2(84, 80)), false, color.lightened(0.3))
		return
	draw_colored_polygon(PackedVector2Array([at + Vector2(-43, 20), at + Vector2(-28, -24),
		at + Vector2(10, -46), at + Vector2(42, -8), at + Vector2(30, 24)]), color.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([at + Vector2(-28, -24), at + Vector2(10, -46),
		at + Vector2(18, -9), at + Vector2(-10, 4)]), color.lightened(0.2))
