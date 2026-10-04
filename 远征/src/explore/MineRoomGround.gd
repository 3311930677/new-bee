extends Node2D

var ventilated := false
var rescued := false

func _draw() -> void:
	# 独立矿井空间：入口记事房、双风轮调轨房、械卫炉房。
	draw_rect(Rect2(0, 0, 960, 1248), Color("211f26"))
	for room in [Rect2(300, 810, 360, 355), Rect2(280, 495, 400, 275), Rect2(300, 130, 360, 325)]:
		draw_rect(room.grow(14), Color("51434a"))
		draw_rect(room, Color("393036"))
		for y in range(int(room.position.y), int(room.end.y), 32):
			draw_line(Vector2(room.position.x, y), Vector2(room.end.x, y), Color("44383c"), 2)
	# 两房之间通道宽度足够步行；实体隔门由场景控制。
	draw_rect(Rect2(385, 130, 190, 1015), Color("51443c"))
	for x in [444, 516]:
		draw_line(Vector2(x, 200), Vector2(x, 1080), Color("a19681"), 5)
	for y in range(220, 1080, 30):
		draw_line(Vector2(427, y), Vector2(533, y), Color("746352"), 7)
	for pos in [Vector2(340, 680), Vector2(620, 590)]:
		draw_circle(pos, 32, Color("776254"))
		draw_circle(pos, 24, Color("292c31"))
		for i in 4:
			var axis := Vector2.RIGHT.rotated(float(i) * PI / 2.0 + (PI / 4.0 if ventilated else 0.0))
			draw_line(pos - axis * 23, pos + axis * 23, Color("aa9476"), 6)
	if not ventilated:
		for i in 7:
			draw_rect(Rect2(290 + i * 35, 570 + (i % 3) * 18, 130, 56), Color("92928a", 0.24))
	var cart := Vector2(480, 880) if not rescued else Vector2(585, 410)
	draw_rect(Rect2(cart - Vector2(23, 29), Vector2(46, 26)), Color("a27c50"))
	draw_line(cart - Vector2(28, 30), cart + Vector2(28, -30), Color("d0a473"), 4)
	for x in [-17, 17]: draw_circle(cart + Vector2(x, 0), 7, Color("1e2025"))
	# 获救后入口出现三顶工帽，撤离事实可见且由存档重建。
	if rescued:
		for x in [375, 415, 455]:
			draw_circle(Vector2(x, 1020), 10, Color("d0a35a"))
	for x in [315, 645]:
		draw_rect(Rect2(x - 9, 215, 18, 65), Color("655057"))
		draw_circle(Vector2(x, 215), 12, Color("e5a166"))
