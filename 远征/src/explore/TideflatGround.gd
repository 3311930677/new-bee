class_name TideflatGround
extends Node2D

# 潮退后露出的盐纹与浅水。中心道留空，实体碰撞仍由 MapScene 负责。
func _draw() -> void:
	var pool := Color("517e7d", 0.83)
	var rim := Color("d4e2d2", 0.8)
	for row in range(3):
		for side in [0, 1]:
			var x: float = 290.0 + float(side) * 380.0 + float(row % 2) * 12.0
			var y: float = 235.0 + float(row) * 352.0
			draw_set_transform(Vector2(x, y), 0.0, Vector2(1.7, 0.48))
			draw_circle(Vector2.ZERO, 84, rim)
			draw_circle(Vector2.ZERO, 76, pool)
			draw_circle(Vector2(-18, -12), 31, Color("a5cfca", 0.34))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for y in range(165, 1150, 125):
		for side in [-1, 1]:
			var start := Vector2(480 + side * 128, y)
			draw_arc(start, 23, 0.2 if side > 0 else 3.35,
				2.4 if side > 0 else 5.55, 12, Color("f0eee2", 0.65), 2)
	# 潮位标尺与折断的木桩把滩涂从普通沙地图中区分出来。
	for x in [290.0, 750.0]:
		draw_line(Vector2(x, 560), Vector2(x, 625), Color("5e4c39"), 6)
		draw_rect(Rect2(x - 11, 564, 22, 32), Color("dfcca0"))
		for yy in [572.0, 580.0, 588.0]:
			draw_line(Vector2(x - 7, yy), Vector2(x + 7, yy), Color("63828a"), 2)
