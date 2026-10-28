# Native seal engraving; completion affects colour, never grants an extra reward.
extends Control
var oath_id:="shelter"
var earned:=false

func _ready()->void:
	custom_minimum_size=Vector2(72,72)
	size=custom_minimum_size
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_meta("oath_pattern_id",oath_id)
	queue_redraw()

func _draw()->void:
	var ink:=Color("755c37") if earned else Color("a89b80")
	var light:=Color("e4c585") if earned else Color("d7ccb2")
	draw_circle(Vector2(36,36),33,Color("d4bf93") if earned else Color("e2d6b9"))
	draw_arc(Vector2(36,36),30,0,TAU,40,ink,2)
	draw_arc(Vector2(36,36),25,0,TAU,32,light,1)
	match oath_id:
		"shelter":
			draw_polyline(PackedVector2Array([Vector2(18,45),Vector2(18,26),Vector2(36,15),Vector2(54,26),Vector2(54,45)]),ink,3)
			draw_circle(Vector2(36,32),5,ink)
			draw_line(Vector2(36,39),Vector2(36,52),ink,3)
			draw_line(Vector2(25,45),Vector2(47,45),ink,3)
		"conquest":
			for flip in [-1,1]:
				var top:=Vector2(36+flip*15,20)
				var bottom:=Vector2(36-flip*13,53)
				draw_line(bottom,top,ink,3)
				draw_polyline(PackedVector2Array([top+Vector2(-flip*10,2),top,top+Vector2(-flip*1,11)]),ink,3)
			draw_circle(Vector2(36,37),6,light)
		"harvest":
			draw_polyline(PackedVector2Array([Vector2(17,50),Vector2(36,22),Vector2(55,50),Vector2(17,50)]),ink,3)
			draw_line(Vector2(36,33),Vector2(36,52),ink,3)
			for flip in [-1,1]:
				draw_line(Vector2(36,39),Vector2(36+flip*12,33),ink,3)
				draw_circle(Vector2(36+flip*11,31),4,ink)
