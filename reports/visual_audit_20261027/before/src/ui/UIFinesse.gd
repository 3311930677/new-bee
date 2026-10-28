extends RefCounted
## 手绘几何徽记、召唤星阵与短促奖励反馈；不加载额外贴图。

class Emblem extends Control:
	var key := "world"
	var family := "atlas"
	var lift := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := G.Visuals.colors(family)
		var p := size * 0.5
		var r := minf(size.x,size.y)*0.48
		var edge: Color = c.accent
		match key:
			"world":
				draw_circle(p+Vector2(0,2),r,Color("111d25",0.35))
				draw_circle(p,r,c.dark)
				draw_arc(p,r-1,0,TAU,40,edge,1)
				for i in 8:
					var v := Vector2.from_angle(i*TAU/8)
					draw_line(p+v*(r-5),p+v*(r-2),edge)
			"swords":
				var shield := PackedVector2Array([p+Vector2(-r*.82,-r*.7),p+Vector2(0,-r),p+Vector2(r*.82,-r*.7),p+Vector2(r*.75,r*.3),p+Vector2(0,r),p+Vector2(-r*.75,r*.3)])
				draw_colored_polygon(shield,c.dark)
				shield.append(shield[0])
				draw_polyline(shield,edge,1)
			"book":
				draw_colored_polygon(PackedVector2Array([p+Vector2(-r,-r*.6),p+Vector2(-2,-r*.7),p+Vector2(2,-r*.55),p+Vector2(r,-r*.7),p+Vector2(r,r*.7),p+Vector2(2,r*.85),p+Vector2(-2,r*.7),p+Vector2(-r,r*.8)]),Color(c.accent,0.18))
			"growth":
				for side in [-1.0,1.0]:
					for i in 3:
						var q := p+Vector2(side*(r-4-i*3),r*.7-i*6)
						draw_colored_polygon(PackedVector2Array([q,q+Vector2(-side*5,-7),q+Vector2(side*2,-9)]),Color(edge,0.72))
			"bag":
				draw_colored_polygon(PackedVector2Array([p+Vector2(-r*.55,-r*.8),p+Vector2(r*.55,-r*.8),p+Vector2(r*.8,r*.65),p+Vector2(r*.5,r*.85),p+Vector2(-r*.5,r*.85),p+Vector2(-r*.8,r*.65)]),Color(c.accent,0.24))
			"exchange":
				draw_circle(p,r*.87,Color(c.accent,0.16))
				draw_arc(p,r*.9,.2,PI-.2,20,edge,1)
				draw_arc(p,r*.9,PI+.2,TAU-.2,20,edge,1)
			"summon":
				for i in 8:
					var v := Vector2.from_angle(i*TAU/8)
					draw_line(p+v*(r*.68),p+v*(r*(1.0 if i%2==0 else .83)),edge,1)
				G.Visuals.diamond(self,p,r*.65,Color(c.accent,0.22))
			"settings":
				draw_arc(p,r*.84,.2,PI*.8,16,Color(edge,0.55),1)
				draw_arc(p,r*.84,PI+.2,TAU-.6,16,Color(edge,0.55),1)
		if lift > 0:
			draw_arc(p,r+2,-PI*.8,-PI*.2,12,Color(c.light,lift*.65),1)

class Sigil extends Control:
	var phase := 0.0
	var charge := 0.0
	var bloom := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(delta: float) -> void:
		if not is_visible_in_tree(): return
		phase += delta
		queue_redraw()
	func _draw() -> void:
		var p := size*.5
		var r := minf(size.x,size.y)*.38
		var ink := Color("bca4d6")
		draw_circle(p,r,Color("342841",.76))
		draw_circle(p,r*.76,Color("1e1c30",.85))
		for ring in 3:
			var radius := r*(.7+ring*.14)
			for arc in 3:
				var a := phase*(.18 if ring%2==0 else -.12)+arc*TAU/3
				draw_arc(p,radius,a,a+1.65,32,Color(ink,.28+charge*.4),1)
		for i in 12:
			var a := i*TAU/12-phase*.08
			var q := p+Vector2.from_angle(a)*r*.91
			G.Visuals.diamond(self,q,2 if i%3 else 4,Color("f0d3a0",.35+charge*.55))
		for i in 6:
			var a := i*TAU/6+phase*.08
			draw_line(p+Vector2.from_angle(a)*r*.57,p+Vector2.from_angle(a+TAU/3)*r*.57,Color(ink,.2+charge*.3))
		var floating := p+Vector2(0,sin(phase*1.6)*3)
		G.Visuals.diamond(self,floating,18+charge*7,Color("8eaed9"))
		G.Visuals.diamond(self,floating+Vector2(-3,-2),12+charge*4,Color("dedcf0"))
		G.Visuals.diamond(self,floating+Vector2(0,8),7,Color("5b719d"))
		if bloom > 0:
			draw_arc(p,r*(1+bloom*.7),0,TAU,60,Color("f7dba6",1-bloom),2)

class CardSurface extends Control:
	var rarity := "white"
	var reverse := true
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var hue: Color = G.RARITY_HUE.get(rarity,Color("b8ad98"))
		var fill := Color("292536") if reverse else hue.darkened(.76)
		var edge := Color("b9a482") if reverse else hue.lightened(.12)
		var rect := Rect2(Vector2.ZERO,size)
		draw_style_box(_style(fill,edge),rect)
		draw_style_box(_style(Color.TRANSPARENT,Color(edge,.32)),rect.grow(-5))
		var p := size*.5
		if reverse:
			draw_arc(p,size.x*.33,0,TAU,32,Color(edge,.4),1)
			for i in 4:
				var v := Vector2.from_angle(PI*.5*i)
				draw_line(p+v*(size.x*.15),p+v*(size.x*.39),Color(edge,.5))
			G.Visuals.diamond(self,p,size.x*.18,Color("44384e"))
			G.Visuals.diamond(self,p,size.x*.18,Color.TRANSPARENT)
		else:
			draw_circle(Vector2(size.x*.5,size.y*.36),size.x*.36,Color(hue,.1))
			draw_arc(Vector2(size.x*.5,size.y*.36),size.x*.34,.15,TAU-.15,36,Color(hue,.26),1)
		# 顶部宝石与独立底边收束。
		G.Visuals.diamond(self,Vector2(size.x*.5,6),3,edge)
		draw_line(Vector2(10,size.y-6),Vector2(size.x-10,size.y-6),Color(edge,.45))
	func _style(fill: Color,edge: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = fill
		s.border_color = edge
		s.set_border_width_all(1)
		s.set_corner_radius_all(5)
		s.shadow_color = Color("070911",.36)
		s.shadow_size = 2 if fill.a > 0 else 0
		s.shadow_offset = Vector2(0,3)
		return s

class Burst extends Control:
	var progress := 0.0
	var hue := Color("efd59b")
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw := create_tween()
		tw.tween_method(func(v: float): progress=v; queue_redraw(),0.0,1.0,.72)
		tw.tween_callback(queue_free)
	func _draw() -> void:
		var p := size*.5
		var r := minf(size.x,size.y)*.5
		var alpha := sin(progress*PI)
		draw_arc(p,r*(.22+progress*.74),0,TAU,40,Color(hue,alpha*.58),1)
		for i in 10:
			var v := Vector2.from_angle(i*TAU/10-.2)
			var q := p+v*r*(.25+progress*.7)
			draw_line(q-v*(7*(1-progress)),q,Color(hue,alpha*.8),1)
			if i%2==0: G.Visuals.diamond(self,q,2*(1-progress)+1,Color(hue,alpha))

static func celebrate(parent: Control, at: Vector2, hue := Color("e8c78d"), extent := 130.0) -> void:
	var fx := Burst.new()
	fx.size = Vector2.ONE*extent
	fx.position = at-fx.size*.5
	fx.hue = hue
	fx.z_index = 12
	parent.add_child(fx)
