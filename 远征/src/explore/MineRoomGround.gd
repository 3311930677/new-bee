extends Node2D
const Art := preload("res://src/world/AssetCompletion.gd")
const Surface := preload("res://src/explore/TerrainSurface.gd")

var ventilated := false
var rescued := false
var flat_floor := false

func _draw() -> void:
	if not flat_floor: _draw_floor()
	_draw_state()

func _draw_floor() -> void:
	# 独立矿井空间：入口记事房、双风轮调轨房、械卫炉房。
	draw_rect(Rect2(0, 0, 960, 1248), Color("211f26"))
	for room in [Rect2(300, 810, 360, 355), Rect2(280, 495, 400, 275), Rect2(300, 130, 360, 325)]:
		draw_rect(room.grow(14), Color("51434a"))
		draw_rect(room, Color("393036"))
		for y in range(int(room.position.y), int(room.end.y), 32):
			draw_line(Vector2(room.position.x, y), Vector2(room.end.x, y), Color("44383c"), 2)
	# 两房之间通道宽度足够步行；实体隔门由场景控制。
	draw_rect(Rect2(385, 130, 190, 1015), Color("51443c"))

func _draw_state() -> void:
	texture_filter = preload("res://src/world/WorldPresentation.gd").sampling()
	Surface.tiled(self, "res://image/main_world/rail_texture_visual_v2.png", Rect2(402,200,156,880), Vector2(156,234))
	for pos in [Vector2(340, 680), Vector2(620, 590)]:
		draw_set_transform(pos, PI/4.0 if ventilated else 0.0)
		Art.centered(self, "mine_wheel", Vector2.ZERO, 64, Color.WHITE if ventilated else Color("aaa49a"))
		draw_set_transform(Vector2.ZERO)
	if not ventilated:
		for i in 3:
			Art.centered(self, "smoke", Vector2(385+i*90,610+(i%2)*24), 220, Color(.65,.62,.59,.24))
	var cart := Vector2(480, 880) if not rescued else Vector2(585, 410)
	Art.prop(self, "mine_cart", cart + Vector2(0,8), 64)
	# 获救后入口出现三顶工帽，撤离事实可见且由存档重建。
	if rescued:
		for x in [375, 415, 455]:
			Art.prop(self, "work_helmet", Vector2(x,1028), 24)
	for x in [315, 645]:
		Art.prop(self, "lantern", Vector2(x,280), 66)
