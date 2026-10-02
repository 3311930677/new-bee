class_name TidalGateGround
extends Node2D

# 水闸战场的双侧水道、闸墙和退潮石道；中央保持首领战可走空间。
func _draw() -> void:
	for side in [0, 1]:
		var x := 0.0 if side == 0 else 610.0
		preload("res://src/explore/TerrainSurface.gd").tiled(self,
			"res://image/main_world/shenyuan_port_ground_reference_v2.png",
			Rect2(x, 0, 350, 1248), Vector2(175, 220), Color("89b2bb"), Rect2(12, 120, 270, 320))
		for y in range(65, 1200, 78):
			draw_line(Vector2(x + 35, y), Vector2(x + 245, y - 13),
				Color("95bfc0", 0.6), 2)
		draw_rect(Rect2(332 if side == 0 else 610, 0, 18, 1248), Color("74777a"))
	for y in range(0, 1248, 64):
		draw_line(Vector2(350, y), Vector2(610, y), Color("68757a", 0.38), 2)
	for x in [365.0, 595.0]:
		draw_rect(Rect2(x - 17, 245, 34, 130), Color("565d61"))
		draw_rect(Rect2(x - 25, 237, 50, 16), Color("929799"))
		draw_circle(Vector2(x, 312), 12, Color("b3a57e"))
	# 上方横闸与悬挂的铁链，不遮住中央首领脚点。
	draw_rect(Rect2(350, 175, 260, 34), Color("4b5358"))
	for x in [380.0, 480.0, 580.0]:
		draw_line(Vector2(x, 210), Vector2(x, 268), Color("9a9277"), 4)
