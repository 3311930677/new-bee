extends SubViewport
const Craft = preload("res://src/ui/CraftUI.gd")

func _ready() -> void:
	G.set_meta("ui_review_mode",true)
	size=Vector2i(480,360)
	render_target_update_mode=UPDATE_ALWAYS
	var bg := ColorRect.new()
	bg.color=Color("102833")
	bg.size=Vector2(480,360)
	add_child(bg)
	for i: int in 4:
		var b := Craft.action("世界",Vector2(12+i*116,42),Vector2(108,78),"nav")
		b.caption.position=Vector2(0,48)
		b.caption.size=Vector2(108,24)
		b.caption.set_meta("fixed_y",48)
		Craft.icon(b,"world",Vector2(34,6),Vector2(40,40))
		add_child(b)
		if i == 1: b.selected=true
		if i == 2: b.set("_down",true);b.set("_hover",true)
		if i == 3: b.disabled=true
		var label := Label.new()
		label.text=["Normal","Selected","Pressed","Disabled"][i]
		label.position=Vector2(18+i*116,12)
		label.add_theme_font_size_override("font_size",12)
		add_child(label)
	for i: int in 3:
		var b := Craft.action(["竞技","召唤","兑换"][i],Vector2(45+i*150,196),Vector2(68,78),"badge")
		b.caption.position=Vector2(0,56)
		b.caption.size=Vector2(68,22)
		b.caption.set_meta("fixed_y",56)
		Craft.icon(b,["swords","summon","exchange"][i],Vector2(14,7),Vector2(40,40))
		add_child(b)
		if i == 1: b.set("_hover",true)
		if i == 2: b.disabled=true
	for i in 8: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_texture().get_image().save_png("res://shots/icons_20261007/component_states.png")
	print("ICON_STATES_OK")
	get_tree().quit()
