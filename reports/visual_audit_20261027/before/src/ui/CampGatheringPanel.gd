extends Control
signal closed
const Reading := preload("res://src/ui/ReadingSkin.gd")
var page: Label
var title: Label
var stories: Array
var seen: Array[String] = []
var _frame: PanelContainer
var _stage: Control
var _column: VBoxContainer
var _reading_scroll: ScrollContainer
var _buttons: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("visual_family","journal")
	G.page_background(self,.72,"res://image/background/art_v2/camp_bluehour.png",false)
	stories = TableCache._load("res://data/camp_gathering.json").get("stories",[])
	_frame = Reading.frame(true)
	_frame.name = "GatheringPage"
	add_child(_frame)
	var column := VBoxContainer.new()
	_column = column
	column.add_theme_constant_override("separation",10)
	_frame.add_child(column)
	title = Reading.label("归路小聚",26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var hint := Reading.label("营灯下  听旧识讲一路见闻",16,Color("786447"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	_stage = TableScene.new()
	_stage.custom_minimum_size = Vector2(0,176)
	column.add_child(_stage)
	for i in stories.size():
		var texture: Texture2D
		if i == 2 and FrostCityArt.rows().has("npc_frost_guard"):
			texture = FrostCityArt.idle("npc_frost_guard").get_frame_texture(&"idle",0)
		else: texture = G.res_tex(String(stories[i].art))
		if texture == null: texture = G.res_tex("npc_guest_idle")
		if texture == null: continue
		var actor := Sprite2D.new()
		if texture.get_width()>128 and not (i==2 and texture.get_height()>128):
			var part := AtlasTexture.new()
			part.atlas = texture
			part.region = Rect2(0,0,128,128)
			actor.texture = part
		else: actor.texture = texture
		actor.scale = Vector2.ONE*(76.0/actor.texture.get_height())
		actor.set_meta("gathering_actor",true)
		_stage.add_child(actor)
		var at := i
		_stage.resized.connect(func():
			var factor := minf(1.0,_stage.size.y/176.0)
			actor.position = Vector2(_stage.size.x*[.23,.77,.50][at],[48.0,48.0,132.0][at])*factor+Vector2(_stage.size.x*(1-factor)*.5,0)
			actor.scale = Vector2.ONE*(76.0/actor.texture.get_height())*factor)
	var paper_scroll := ScrollContainer.new()
	_reading_scroll = paper_scroll
	paper_scroll.name = "StoryReading"
	paper_scroll.follow_focus = true
	paper_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paper_scroll.custom_minimum_size.y = 88
	paper_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(paper_scroll)
	page = Reading.label("灯、潮纸与轮岗簿放在同一张桌上。先听谁都可以，三段故事都能重看。",22)
	page.name = "StoryText"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paper_scroll.add_child(page)
	for i in stories.size():
		var button := Reading.button(String(stories[i].speaker)+" · "+String(stories[i].title))
		button.name = "Story_"+String(stories[i].id)
		button.pressed.connect(listen.bind(i))
		column.add_child(button)
		_buttons.append(button)
	var back := Reading.button("回到营帐",true)
	back.pressed.connect(func(): Audio.sfx("ui_close"); closed.emit())
	column.add_child(back)
	back.grab_focus.call_deferred()
	get_viewport().size_changed.connect(layout)
	preload("res://src/ui/UiSafeArea.gd").watch(self,layout)
	layout()

func layout() -> void:
	if _frame == null: return
	var safe := G.ui_safe_rect(self)
	var width := minf(456,safe.size.x-24)
	_frame.position = Vector2(safe.get_center().x-width*.5,safe.position.y+12).round()
	_frame.size = Vector2(width,safe.size.y-24)
	page.custom_minimum_size.x = width-68
	_stage.queue_redraw()
	var compact := safe.size.y < 760
	_stage.custom_minimum_size.y = 64 if compact else clampf(safe.size.y*.21,176,240)
	_column.add_theme_constant_override("separation",6 if compact else 10)
	_reading_scroll.custom_minimum_size.y = 48 if compact else 88

func listen(index: int) -> void:
	if index < 0 or index >= stories.size(): return
	var story: Dictionary = stories[index]
	if not seen.has(String(story.id)): seen.append(String(story.id))
	title.text = String(story.speaker)+" · "+String(story.title)
	page.text = String(story.text)+"\n\n桌上留下："+String(story.object)+"。"
	if seen.size()==3: page.text += "\n三城旧识都已讲过。故事仍可随时重看。"
	for i in _buttons.size(): _buttons[i].modulate = Color("f4d699") if i == index else Color.WHITE
	Audio.sfx("ui_page")

func _unhandled_input(event: InputEvent) -> void:
	if not G.ui_blocked and event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()

class TableScene extends Control:
	var table: Texture2D = preload("res://assets/world/reference_complete_20261011/ready/nighttable.png")
	var lamp: Texture2D = preload("res://assets/world/reference_complete_20261011/ready/lantern.png")
	var ledger: Texture2D = preload("res://assets/world/reference_complete_20261011/ready/ledger.png")
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		var center := Vector2(size.x*.5,92)
		var factor := minf(1.0,size.y/176.0)
		var origin := Vector2(size.x*(1-factor)*.5,0)
		draw_set_transform(origin+center*factor,0,Vector2(factor,factor*.24))
		draw_circle(Vector2.ZERO,134,Color("362418",.13))
		draw_set_transform(origin,0,Vector2.ONE*factor)
		draw_texture_rect(table,Rect2(center+Vector2(-126,-52),Vector2(252,120)),false)
		draw_texture_rect(ledger,Rect2(center+Vector2(-58,-38),Vector2(44,32)),false)
		draw_texture_rect(lamp,Rect2(center+Vector2(25,-65),Vector2(38,66)),false)
