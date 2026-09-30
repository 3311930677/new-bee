class_name SaltRoadGround
extends Node2D

# 盐道旧桥的干河床与残桥。只作地貌，不阻断玩家通向港口的道路。
func _draw() -> void:
	var ravine := PackedVector2Array([
		Vector2(600, 325), Vector2(960, 280), Vector2(960, 520),
		Vector2(610, 555), Vector2(555, 490)])
	draw_colored_polygon(ravine, Color("62574c", 0.86))
	draw_polyline(PackedVector2Array([
		Vector2(600, 325), Vector2(960, 280)]), Color("c4ae84"), 5)
	draw_polyline(PackedVector2Array([
		Vector2(610, 555), Vector2(960, 520)]), Color("c4ae84"), 5)
	for i in 9:
		var px := 625.0 + i * 34.0
		draw_line(Vector2(px, 386 + (i % 3) * 8), Vector2(px + 70, 412 + (i % 2) * 12),
			Color("94806a", 0.5), 2)
	# 车辙尽头只剩半截栈桥：断口下是河床，并非可走出口。
	draw_colored_polygon(PackedVector2Array([
		Vector2(495, 393), Vector2(634, 390), Vector2(609, 487), Vector2(496, 491)]),
		Color("62462f"))
	for x in range(502, 620, 14):
		draw_line(Vector2(x, 397), Vector2(x - 4, 484), Color("b28a58"), 6)
	for p in [Vector2(622, 405), Vector2(612, 450), Vector2(605, 484)]:
		draw_line(p, p + Vector2(16, 6), Color("382d28"), 3)
	for p in [Vector2(566, 518), Vector2(594, 527), Vector2(627, 504)]:
		draw_circle(p, 8, Color("e9dfc7", 0.65))
