class_name PortGround
extends Node2D

var _event := ""
var _rope := ""
var use_reference_ground := false
var flat_floor := false


func _process(_delta: float) -> void:
	var current := String(G.economy_state().get("port_event", ""))
	var rope := String((G.prog.get("flags", {}) as Dictionary).get("act2_pier_rope", ""))
	if current != _event or rope != _rope:
		_event = current
		_rope = rope
		queue_redraw()


# 沉渊港地面识别层：潮水、石堤、栈桥与双侧木板步道。
# 作为 MapScene 地砖之上的纯视觉层，不阻挡玩家、NPC 或出口。
func _draw() -> void:
	if not use_reference_ground and not flat_floor: _draw_base()
	_draw_state()


func _draw_base() -> void:
	var water := Color("376d78")
	var foam := Color("95c5bf", 0.72)
	var quay := Color("8c8171")
	var timber := Color("74563c")
	for side in [0, 1]:
		var x := 0.0 if side == 0 else 640.0
		draw_rect(Rect2(x, 0, 320, 1248), water)
		for y in range(46, 1248, 74):
			draw_line(Vector2(x + 32, y), Vector2(x + 218, y - 10), foam, 2)
			draw_line(Vector2(x + 52, y + 12), Vector2(x + 156, y + 4), foam.darkened(0.12), 1)
		draw_rect(Rect2(320 if side == 0 else 622, 0, 18, 1248), quay)
	# 两岸店铺建在木制平台上；平台分别接入横桥。
	for plat in [Rect2(270, 222, 135, 160), Rect2(270, 855, 135, 184),
			Rect2(555, 352, 135, 160), Rect2(555, 852, 135, 205)]:
		draw_rect(plat, Color("84664b"))
		for py in range(int(plat.position.y) + 7, int(plat.end.y), 18):
			draw_line(Vector2(plat.position.x, py), Vector2(plat.end.x, py),
				Color("b3956e", 0.68), 2)
	# 港口中轴的石板主街保持通畅，店铺在街两侧。
	draw_rect(Rect2(408, 0, 144, 1248), Color("b9a88b", 0.85))
	for y in range(0, 1248, 48):
		draw_line(Vector2(408, y), Vector2(552, y), Color("736e62", 0.45), 1)
		var seam_x := 456 + (int(y / 48) % 2) * 48
		draw_line(Vector2(seam_x, y),
			Vector2(seam_x, y + 48), Color("736e62", 0.38), 1)
	# 两条栈桥伸向水边；横桥连通市集与港务厅。
	for y in [372, 838]:
		draw_rect(Rect2(315, y, 330, 78), timber)
		for py in range(y + 8, y + 78, 10):
			draw_line(Vector2(320, py), Vector2(640, py), Color("ad8861", 0.65), 2)
		for px in range(330, 645, 72):
			draw_rect(Rect2(px, y - 7, 8, 92), Color("4c3a2d"))
	# 东西出口各有木栈通到陆路，玩家不需要踩着水面进出港口。
	for route in [Rect2(0, 640, 408, 62), Rect2(552, 675, 408, 62)]:
		draw_rect(route, timber)
		for py in range(int(route.position.y) + 8, int(route.end.y), 12):
			draw_line(Vector2(route.position.x, py), Vector2(route.end.x, py),
				Color("b69269", 0.72), 2)
	for x in [340, 620]:
		draw_line(Vector2(x, 486), Vector2(x, 565), Color("493c33"), 5)
		draw_rect(Rect2(x - 18, 486, 36, 28), Color("dcc393"))
		draw_line(Vector2(x - 12, 505), Vector2(x + 12, 505), Color("66513b"), 2)



func _draw_state() -> void:
	# 潮位牌和船缆，不占交互层。
	if not _rope.is_empty():
		var rope_color := Color("e0c395") if _rope == "replace" else Color("a08662")
		draw_line(Vector2(570, 701), Vector2(624, 730), rope_color, 4)
		draw_circle(Vector2(624, 730), 7, Color("70503a"))
		draw_arc(Vector2(624, 730), 9, 0, TAU, 20, rope_color, 3)

	# 回港供货选择有地图回应：盐渠来船 / 堤道粮袋，不压中轴通行带。
	if _event == "dredge":
		var hull := PackedVector2Array([Vector2(158, 438), Vector2(274, 438), Vector2(259, 504), Vector2(174, 504)])
		draw_colored_polygon(hull, Color("684833"))
		draw_polyline(PackedVector2Array([Vector2(158, 438), Vector2(274, 438), Vector2(259, 504), Vector2(174, 504), Vector2(158, 438)]), Color("342b27"), 3)
		for x in [182, 217, 247]:
			draw_rect(Rect2(x, 451, 25, 29), Color("d7cdb1"))
			draw_line(Vector2(x + 3, 465), Vector2(x + 22, 465), Color("9a8b70"), 2)
		draw_line(Vector2(268, 450), Vector2(329, 479), Color("b59c70"), 2)
	elif _event == "embank":
		draw_rect(Rect2(717, 460, 121, 57), Color("7b634c"))
		for x in range(725, 835, 23):
			draw_line(Vector2(x, 464), Vector2(x, 513), Color("b1936d"), 2)
		for x in [735, 775, 807]:
			draw_rect(Rect2(x, 469, 24, 30), Color("c4a46a"))
			draw_line(Vector2(x + 3, 480), Vector2(x + 21, 480), Color("745638"), 3)
		draw_line(Vector2(717, 458), Vector2(717, 526), Color("463526"), 6)
		draw_line(Vector2(841, 458), Vector2(841, 526), Color("463526"), 6)
