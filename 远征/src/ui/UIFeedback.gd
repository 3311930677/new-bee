extends RefCounted
## Non-interactive feedback. Reward owners call this only after successful settlement.

static func mark_ready(button: Control) -> void:
	if button.has_meta("ready_halo"): return
	button.set_meta("ready_halo", true)
	var halo := ReadyHalo.new()
	halo.name = "ReadyHalo"
	halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(halo)

static func present(parent: Control, title: String, detail: String, kind: String) -> void:
	var old := parent.get_node_or_null("RewardRibbon")
	if old != null:
		parent.remove_child(old)
		old.queue_free()
	var ribbon := RewardRibbon.new()
	ribbon.name = "RewardRibbon"
	ribbon.title = title
	ribbon.detail = detail
	ribbon.kind = kind
	parent.add_child(ribbon)

class ReadyHalo extends Control:
	var clock := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(dt: float) -> void:
		clock += dt
		queue_redraw()
	func _draw() -> void:
		var owner_control := get_parent() as Control
		if owner_control == null or not owner_control.is_visible_in_tree(): return
		if owner_control.mouse_filter == Control.MOUSE_FILTER_IGNORE: return
		if owner_control.get("disabled") == true: return
		var pulse := .5 + .5*sin(clock*2.6)
		var ink := Color("e5c98b")
		draw_rect(Rect2(Vector2(1,1), size-Vector2(2,2)), Color(ink,.14+.16*pulse), false, 1)
		var x := 10.0 + (size.x-20.0)*fposmod(clock*.24,1)
		draw_line(Vector2(maxf(8,x-16),size.y-2),Vector2(minf(size.x-8,x+16),size.y-2),Color(ink,.72),1)
		var p := Vector2(size.x-9,9)
		draw_line(p-Vector2(3,0),p+Vector2(3,0),Color(ink,.5+.5*pulse),1)
		draw_line(p-Vector2(0,3),p+Vector2(0,3),Color(ink,.5+.5*pulse),1)

class RewardRibbon extends Control:
	var title := "收获入囊"
	var detail := ""
	var kind := "reward"
	var clock := 0.0
	var accent := Color("e6c483")
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 90
		accent = Color("91c9be") if kind == "unlock" else Color("e6c483")
		size = Vector2(minf(380,get_parent().size.x-40),100)
		position = Vector2(roundf((get_parent().size.x-size.x)*.5),100)
		var heading := G.serif_label(title,28,Color("f8e5b8"))
		heading.position = Vector2(54,10)
		heading.size = Vector2(size.x-68,40)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(heading)
		var words := G.text_label(detail,15,Color("d3dfdc"))
		words.position = Vector2(54,52)
		words.size = Vector2(size.x-68,38)
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(words)
		modulate.a = 0
		var finish := position
		position.y -= 12
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(self,"modulate:a",1.0,.24)
		tween.tween_property(self,"position",finish,.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.chain().tween_interval(1.7)
		tween.chain().tween_property(self,"modulate:a",0.0,.32)
		tween.chain().tween_callback(queue_free)
	func _process(dt: float) -> void:
		clock += dt
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(0,4,size.x,size.y),Color("080f15",.4))
		draw_rect(Rect2(Vector2.ZERO,size),Color("1a3039",.98))
		draw_line(Vector2(10,0),Vector2(size.x-10,0),Color(accent,.7))
		draw_line(Vector2(10,size.y-1),Vector2(size.x-10,size.y-1),Color(accent,.45))
		var center := Vector2(28,45)
		draw_arc(center,15,-PI*.7,PI*.7,32,Color(accent,.62),1,true)
		draw_colored_polygon(PackedVector2Array([center-Vector2(0,10),center+Vector2(7,0),center+Vector2(0,10),center-Vector2(7,0)]),accent)
		for i in 8:
			var angle := TAU*float(i)/8
			var distance := 18+minf(clock,.7)*24
			var p := center+Vector2(cos(angle),sin(angle))*distance
			var alpha := clampf(1-clock/1.2,0,1)
			draw_rect(Rect2(p.round(),Vector2.ONE*2),Color(accent,alpha))
