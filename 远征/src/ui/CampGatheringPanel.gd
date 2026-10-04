extends Control
signal closed
var page:Label
var title:Label
var stories:Array
var seen:Array[String]=[]
func _ready()->void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	G.center_fixed_page.call_deferred(self)
	G.veil(self,.9)
	stories=TableCache._load("res://data/camp_gathering.json").get("stories",[])
	var paper:=G.parchment_box(440,690,16)
	paper.position=Vector2(20,55)
	add_child(paper)
	title=G.serif_label("归路小聚",G.FS_LG,G.TEXT_DARK)
	title.position=Vector2(44,80)
	add_child(title)
	var scene:=TableScene.new()
	scene.position=Vector2(240,267)
	add_child(scene)
	for i in stories.size():
		var texture:=G.res_tex(String(stories[i].art))
		if i==2 and FrostCityArt.rows().has("npc_frost_guard"):
			texture=FrostCityArt.idle("npc_frost_guard").get_frame_texture(&"idle",0)
		if texture==null:texture=G.res_tex("npc_guest_idle")
		if texture==null:continue
		var actor:=Sprite2D.new()
		if i==2 and texture.get_height()>128:
			actor.texture=texture
		else:
			var atlas:=AtlasTexture.new()
			atlas.atlas=texture
			atlas.region=Rect2(0,0,128,128)
			actor.texture=atlas
		actor.scale=Vector2.ONE*(92.0/actor.texture.get_height())
		actor.set_meta("gathering_actor",true)
		actor.position=[Vector2(156,200),Vector2(324,200),Vector2(240,311)][i]
		add_child(actor)
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(44,378)
	scroll.size=Vector2(392,162)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	page=G.text_label("灯、潮纸与轮岗簿放在同一张桌上。先听谁都可以，三段故事都能重看。",G.FS_MD,G.TEXT_DARK)
	page.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	page.custom_minimum_size.x=370
	page.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(page)
	for i in stories.size():
		var index:=i
		var button:=G.gold_button(String(stories[i].speaker)+" · "+String(stories[i].title),360,36,G.FS_SM)
		button.position=Vector2(60,551+i*41)
		button.gui_input.connect(func(e:InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:listen(index))
		add_child(button)
	var back:=G.ghost_button("回到营帐",220,44)
	back.position=Vector2(130,684)
	back.gui_input.connect(func(e:InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:closed.emit())
	add_child(back)
func listen(index:int)->void:
	if index<0 or index>=stories.size():return
	var story:Dictionary=stories[index]
	if not seen.has(String(story.id)):seen.append(String(story.id))
	title.text=String(story.speaker)+" · "+String(story.title)
	page.text=String(story.text)+"\n\n桌上留下："+String(story.object)+"。"
	if seen.size()==3:page.text+="\n三城旧识都已讲过。故事仍可随时重看。"
	Audio.sfx("ui_open")
func _unhandled_input(event:InputEvent)->void:
	if G.ui_blocked:return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
class TableScene extends Node2D:
	func _draw()->void:
		draw_set_transform(Vector2.ZERO,0,Vector2(1,.4))
		draw_circle(Vector2.ZERO,120,Color("302e25",.18))
		draw_set_transform(Vector2.ZERO)
		draw_colored_polygon(PackedVector2Array([Vector2(-90,-28),Vector2(90,-28),Vector2(100,24),Vector2(-100,24)]),Color("725039"))
		draw_rect(Rect2(-96,24,192,9),Color("4a392e"))
		for x in [-80,80]:draw_line(Vector2(x,31),Vector2(x,60),Color("4a392e"),8)
		draw_rect(Rect2(-56,-20,45,29),Color("d9c697"))
		for y in [-12,-5,2]:draw_line(Vector2(-50,y),Vector2(-18,y),Color("627b7d"),2)
		draw_rect(Rect2(23,-16,36,25),Color("596e6e"))
		for x in [31,39,47]:draw_line(Vector2(x,-10),Vector2(x,4),Color("d8caa5"),2)
		draw_circle(Vector2(0,-8),9,Color("ad8250"))
		draw_circle(Vector2(0,-10),5,Color("ffd99a"))
