extends Node2D

# 第三幕可走地貌；识别图形在实体下层，不用装饰性裂谷充当隐形碰撞。
var map_id := ""


func _draw() -> void:
	match map_id:
		"red_sand_route":
			# 两个出口沿中轴连接；车辙说明这是运货路，路边红岩不挡主路。
			draw_rect(Rect2(423, 80, 114, 1090), Color("b59768", 0.80))
			for x in [453.0, 507.0]:
				draw_line(Vector2(x, 96), Vector2(x, 1152), Color("84694c"), 4)
			for y in [275.0, 640.0, 970.0]:
				_rock(Vector2(105, y), Color("ad6249"))
				_rock(Vector2(855, y + 40), Color("ad6249"))
			draw_rect(Rect2(567, 725, 96, 56), Color("80664b"))
			for x in [585.0, 625.0]:
				draw_line(Vector2(x, 717), Vector2(x, 790), Color("4a4034"), 6)
		"frost_post":
			# 雪地木栈道：宽主街与东向矿道支路，两侧房屋独立留出 NPC 空间。
			_boardwalk(Rect2(426, 80, 108, 1100))
			_boardwalk(Rect2(335, 420, 260, 60))
			_boardwalk(Rect2(335, 840, 300, 60))
			_boardwalk(Rect2(480, 680, 398, 60))
			for p in [Vector2(365, 660), Vector2(595, 970)]:
				draw_rect(Rect2(p + Vector2(-7, -46), Vector2(14, 46)), Color("53483c"))
				draw_rect(Rect2(p + Vector2(-16, -63), Vector2(32, 22)), Color("f4c779"))
				draw_rect(Rect2(p + Vector2(-19, -68), Vector2(38, 7)), Color("dddcd0"))
			for y in [245.0, 1040.0]:
				_rock(Vector2(165, y), Color("889c9c"))
		"rift_mine_road":
			# 侧面的开采沟与两条明亮轨道构成矿道识别点；中央和西出口可步行。
			draw_colored_polygon(PackedVector2Array([Vector2(620, 190), Vector2(960, 230),
				Vector2(960, 1000), Vector2(760, 1090), Vector2(660, 895)]), Color("252e37", 0.9))
			draw_rect(Rect2(418, 160, 124, 948), Color("736956"))
			draw_rect(Rect2(80, 680, 400, 60), Color("736956"))
			for y in range(174, 1100, 38):
				draw_rect(Rect2(424, y, 112, 10), Color("4d3e32"))
			for x in [448.0, 512.0]:
				draw_line(Vector2(x, 165), Vector2(x, 1100), Color("aaafb1"), 5)
			for y in [320.0, 860.0]:
				draw_line(Vector2(385, y), Vector2(385, y + 76), Color("8b7151"), 13)
				draw_line(Vector2(577, y), Vector2(577, y + 76), Color("8b7151"), 13)
				draw_line(Vector2(378, y), Vector2(584, y), Color("ab9061"), 13)


func _boardwalk(rect: Rect2) -> void:
	draw_rect(rect, Color("60574b"))
	for y in range(int(rect.position.y), int(rect.end.y), 16):
		draw_rect(Rect2(rect.position.x + 3, y + 2, rect.size.x - 6, 12), Color("988e74"))
	draw_rect(rect, Color("d8dcd0"), false, 3)


func _rock(at: Vector2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(-43, 20), at + Vector2(-28, -24),
		at + Vector2(10, -46), at + Vector2(42, -8), at + Vector2(30, 24)]), color.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([at + Vector2(-28, -24), at + Vector2(10, -46),
		at + Vector2(18, -9), at + Vector2(-10, 4)]), color.lightened(0.2))
