extends Node2D

# 首章失路兽蓝武器的地图轮廓。使用同一脚点附近的局部像素坐标，
# 只负责视觉；装备与战斗数值仍来自 Inventory / equip.json。
const BLUE := Color("5aa0e0")
const EDGE := Color("16263e")
const LIGHT := Color("d9f0ff")
const GOLD := Color("dfb565")

var weapon_tpl := ""


func set_weapon(tpl: String) -> void:
	weapon_tpl = tpl
	queue_redraw()


func _poly(points: PackedVector2Array, fill: Color) -> void:
	draw_colored_polygon(points, EDGE)
	var inset := PackedVector2Array()
	var center := Vector2.ZERO
	for point in points:
		center += point
	center /= float(points.size())
	for point in points:
		inset.append(center + (point - center) * 0.78)
	draw_colored_polygon(inset, fill)


func _draw() -> void:
	match weapon_tpl:
		"tpl_sword_ruin":
			# 残锋：宽厚断刃、缺口、十字护手。
			_poly(PackedVector2Array([Vector2(-5, -24), Vector2(3, -24), Vector2(5, -12),
				Vector2(1, -9), Vector2(5, -6), Vector2(3, 4), Vector2(-3, 4)]), BLUE)
			_poly(PackedVector2Array([Vector2(-11, 3), Vector2(10, 3), Vector2(9, 7),
				Vector2(-10, 7)]), GOLD)
			_poly(PackedVector2Array([Vector2(-2, 6), Vector2(3, 6), Vector2(3, 18),
				Vector2(-2, 18)]), GOLD)
			draw_line(Vector2(-2, -19), Vector2(-2, -1), LIGHT, 2.0)
		"tpl_spear_iron":
			# 穿杨：长杆与两侧倒钩，让枪尖与基础槽图一眼不同。
			_poly(PackedVector2Array([Vector2(0, -31), Vector2(6, -18), Vector2(2, -13),
				Vector2(-2, -13), Vector2(-6, -18)]), LIGHT)
			_poly(PackedVector2Array([Vector2(-8, -15), Vector2(0, -12), Vector2(8, -15),
				Vector2(5, -8), Vector2(-5, -8)]), BLUE)
			_poly(PackedVector2Array([Vector2(-2, -8), Vector2(2, -8), Vector2(2, 24),
				Vector2(-2, 24)]), GOLD)
		"tpl_staff_frost":
			# 霜语：杖首双弯枝托着冰晶，柄末有冰蓝尾饰。
			_poly(PackedVector2Array([Vector2(-2, -8), Vector2(2, -8), Vector2(2, 23),
				Vector2(-2, 23)]), GOLD)
			_poly(PackedVector2Array([Vector2(-9, -24), Vector2(-5, -17), Vector2(0, -14),
				Vector2(5, -17), Vector2(9, -24), Vector2(8, -11), Vector2(0, -7),
				Vector2(-8, -11)]), BLUE)
			_poly(PackedVector2Array([Vector2(0, -29), Vector2(6, -20), Vector2(0, -13),
				Vector2(-6, -20)]), LIGHT)
			draw_circle(Vector2(0, 23), 3.0, BLUE)
		"tpl_hammer_dawn":
			# 晨星：宽横锤头与日光脊，轮廓不与枪杖混淆。
			_poly(PackedVector2Array([Vector2(-2, -15), Vector2(2, -15), Vector2(2, 22),
				Vector2(-2, 22)]), GOLD)
			_poly(PackedVector2Array([Vector2(-13, -25), Vector2(13, -25),
				Vector2(13, -11), Vector2(-13, -11)]), BLUE)
			draw_line(Vector2(-8, -19), Vector2(8, -19), LIGHT, 2.0)
			draw_circle(Vector2(0, -18), 3.0, GOLD)
