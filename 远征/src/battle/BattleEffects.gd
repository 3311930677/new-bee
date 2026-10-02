extends RefCounted

static func impact(parent: Node, at: Vector2, kind: String, tint: Color, strong := false) -> void:
	var fx := Impact.new()
	fx.position = at
	fx.kind = kind
	fx.tint = tint
	fx.strong = strong
	parent.add_child(fx)

static func trail(parent: CanvasItem, source: Node2D, tint: Color) -> void:
	var fx := Trail.new()
	fx.source = source
	fx.tint = tint
	parent.add_child(fx)

class Impact extends Node2D:
	var kind := "slash"
	var tint := Color("ffe08a")
	var strong := false
	var age := 0.0
	var duration := .38
	func _process(delta: float) -> void:
		age += delta
		if age >= duration: queue_free()
		else: queue_redraw()
	func _draw() -> void:
		var t := clampf(age/duration,0,1)
		var fade := 1.0-t
		var r := (42.0 if strong else 30.0)*(.3+t)
		var glow := Color(tint,tint.a*fade*.25)
		draw_circle(Vector2.ZERO, r*.65, glow)
		draw_arc(Vector2.ZERO,r*.7,0,TAU,28,Color(tint,fade*.75),2)
		match kind:
			"pierce":
				draw_colored_polygon(PackedVector2Array([Vector2(-r,5),Vector2(r*1.3,-6),Vector2(-r,-3)]),Color("e7fbff",fade))
				draw_line(Vector2(-r*1.4,10),Vector2(r*.9,-4),Color(tint,fade),3)
			"arcane", "heal":
				for i in 3:
					var a := t*TAU+i*TAU/3
					var p := Vector2(cos(a),sin(a))*r*.7
					draw_colored_polygon(PackedVector2Array([p+Vector2(0,-7),p+Vector2(5,0),p+Vector2(0,7),p-Vector2(5,0)]),Color(tint,fade))
				draw_arc(Vector2.ZERO,r,0,TAU,32,Color(tint,fade*.7),2)
			"hammer":
				for i in 6:
					var v := Vector2.from_angle(TAU*i/6)
					draw_line(v*9,v*r,Color(tint,fade),4)
				draw_arc(Vector2.ZERO,r*1.25,0,TAU,32,Color("fff1c7",fade*.6),3)
			_:
				for i in 2:
					var off := Vector2(i*9-5,i*6-3)
					draw_colored_polygon(PackedVector2Array([off+Vector2(-r*.8,r*.65),off+Vector2(r*.7,-r*.8),off+Vector2(r*.2,-r*.05)]),Color("fff5d9",fade))
		for i in (12 if strong else 8):
			var angle := i*2.39996
			var p := Vector2.from_angle(angle)*(r*(.8+float(i%3)*.18))
			draw_rect(Rect2(p,Vector2(3,3)),Color(tint,fade))

class Trail extends Node2D:
	var source: Node2D
	var tint := Color("ffe08a")
	var points := PackedVector2Array()
	var age := 0.0
	func _process(delta: float) -> void:
		age += delta
		if age > .42 or not is_instance_valid(source):
			queue_free()
			return
		var p := to_local(source.global_position)+Vector2(0,-24)
		if points.is_empty() or points[-1].distance_to(p)>3:
			points.append(p)
			if points.size()>12: points.remove_at(0)
		queue_redraw()
	func _draw() -> void:
		for i in range(1,points.size()):
			var a := float(i)/float(points.size())*(1-age/.42)*.45
			draw_line(points[i-1],points[i],Color(tint,a),5)
			draw_line(points[i-1]+Vector2(0,9),points[i]+Vector2(0,9),Color(tint,a*.5),2)
