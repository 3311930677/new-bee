extends RefCounted
## B3 flow furniture; page controllers continue to own game state and navigation.
const UI := preload("res://src/ui/TravelChestUI.gd")
const Page := preload("res://src/ui/ChestPageUI.gd")
const ROOT := "res://assets/ui/travel_chest_b3/"
static var _regions: Dictionary={}
static var _textures: Dictionary={}
static func texture(id: String) -> Texture2D:
	if _textures.has(id):return _textures[id]
	if _regions.is_empty() and FileAccess.file_exists(ROOT+"regions.json"):_regions=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"regions.json"))
	if not _regions.has(id):return null
	var entry:Dictionary=_regions[id]
	var atlas:=AtlasTexture.new()
	atlas.atlas=load(ROOT+String(entry.file))
	var scale:=atlas.atlas.get_size()/Vector2(entry.source_size[0],entry.source_size[1])
	atlas.region=Rect2(Vector2(entry.rect[0],entry.rect[1])*scale,Vector2(entry.rect[2],entry.rect[3])*scale)
	_textures[id]=atlas
	return atlas

static func field(placeholder: String,paper: bool=false) -> LineEdit:
	var edit:=LineEdit.new()
	edit.placeholder_text=placeholder
	edit.custom_minimum_size=Vector2(0,48)
	edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	edit.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	edit.add_theme_font_override("font",G.font_reg)
	edit.add_theme_font_size_override("font_size",G.FS_XS)
	var color:=Color("2b2420") if paper else UI.PAPER
	edit.add_theme_color_override("font_color",color)
	edit.add_theme_color_override("font_placeholder_color",Color("77705f"))
	for state in ["normal","focus","read_only"]:
		var box:=StyleBoxFlat.new()
		box.bg_color=Color("d9cbaa") if paper else UI.FACE
		box.border_color=UI.GOLD if state=="focus" else UI.BRONZE
		box.border_width_bottom=2 if state=="focus" else 1
		box.set_content_margin_all(12)
		edit.add_theme_stylebox_override(state,box)
	return edit

static func text(words: String,role: String="body",color: Color=UI.PAPER) -> Label:
	return Page.line(words,role,color)

static func button(words: String,callback: Callable,primary: bool=false) -> Button:
	var b:=UI.action(words,"primary" if primary else "secondary")
	b.custom_minimum_size.y=56 if primary else 44
	b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	b.pressed.connect(callback)
	return b

static func info(parent: Node,title: String,lines: Array) -> void:
	var d:=UI.Modal.new()
	d.heading=title
	d.lines=lines
	d.closed.connect(d.queue_free)
	parent.add_child(d)

static func wire_focus(root: Node) -> void:
	var controls:Array[Control]=[]
	_collect(root,controls)
	for i in controls.size():
		controls[i].focus_next=controls[(i+1)%controls.size()].get_path()
		controls[i].focus_previous=controls[posmod(i-1,controls.size())].get_path()
static func _collect(root: Node,out: Array[Control]) -> void:
	for child in root.get_children():
		if child is Control and child.focus_mode==Control.FOCUS_ALL and child.is_visible_in_tree():out.append(child)
		_collect(child,out)

class Selection extends Control:
	## Shared index model used by arrows, thumbnails, keyboard and owning controllers.
	signal page_changed(index: int)
	var page_count:=0
	var current:=0
	func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE
	func go(index: int,_instant: bool=false) -> void:
		current=wrapi(index,0,maxi(1,page_count))
		page_changed.emit(current)
	func _unhandled_input(e:InputEvent) -> void:
		if G.ui_blocked:return
		var focus:=get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is Slider:return
		if e.is_action_pressed("ui_left") or e.is_action_pressed("ui_right"):
			go(current+(-1 if e.is_action_pressed("ui_left") else 1))
			get_viewport().set_input_as_handled()

class Shell extends Control:
	const UI=preload("res://src/ui/TravelChestUI.gd")
	const Page=preload("res://src/ui/ChestPageUI.gd")
	var heading: String
	var tray_height: float
	var background: Control
	var title: Label
	var back: Button
	var tabs: HBoxContainer
	var stage: Control
	var tray: Control
	var scroll: ScrollContainer
	var body: VBoxContainer
	var footer: HBoxContainer
	var safe:=Rect2()
	var closed: Callable
	var header_actions:Array[Control]=[]
	## 换皮用：layout 末尾再调一次，页面可按自己的底图重排标题栏/页签/滚动区；为空时布局不变
	var skin_layout: Callable
	func _init(words: String="",height: float=352) -> void:
		heading=words
		tray_height=height
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		theme=UI.theme()
		background=Page.Stage.new()
		add_child(background)
		stage=Control.new()
		stage.mouse_filter=Control.MOUSE_FILTER_IGNORE
		stage.clip_contents=true
		add_child(stage)
		tray=UI.Tray.new()
		add_child(tray)
		back=UI.action("‹","back")
		back.tooltip_text="返回"
		back.pressed.connect(func():if closed.is_valid():closed.call())
		add_child(back)
		title=UI.label(heading,"title")
		add_child(title)
		tabs=HBoxContainer.new()
		tabs.add_theme_constant_override("separation",4)
		add_child(tabs)
		scroll=Page.scroll()
		add_child(scroll)
		body=VBoxContainer.new()
		body.add_theme_constant_override("separation",8)
		body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		scroll.add_child(body)
		footer=HBoxContainer.new()
		footer.add_theme_constant_override("separation",12)
		add_child(footer)
		get_viewport().size_changed.connect(layout)
		preload("res://src/ui/UiSafeArea.gd").watch(self,layout)
		layout()
	func layout(safe_override: Rect2=Rect2()) -> void:
		safe=safe_override if safe_override.has_area() else G.ui_safe_rect(self)
		var has_tabs:=tabs.get_child_count()>0
		var start:=safe.position.y+(112 if has_tabs else 56)
		var top:=safe.position.y+116 if tray_height<=0 else safe.end.y-tray_height
		Page.place(background,Vector2.ZERO,get_viewport_rect().size)
		Page.place(back,safe.position+Vector2(8,6),Vector2(44,44))
		Page.place(title,safe.position+Vector2(64,8),Vector2(safe.size.x-80,40))
		tabs.visible=has_tabs
		Page.place(tabs,safe.position+Vector2(12,60),Vector2(safe.size.x-24,44))
		Page.place(stage,Vector2(safe.position.x,start),Vector2(safe.size.x,maxf(0,top-start)))
		Page.place(tray,Vector2(safe.position.x,top),Vector2(safe.size.x,safe.end.y-top))
		var has_footer:=footer.get_child_count()>0
		var bottom:=safe.end.y-(80 if has_footer else 12)
		Page.place(scroll,Vector2(safe.position.x+16,top+16),Vector2(safe.size.x-32,maxf(40,bottom-top-16)))
		Page.place(footer,Vector2(safe.position.x+12,safe.end.y-68),Vector2(safe.size.x-24,56))
		footer.visible=has_footer
		for action in header_actions:Page.place(action,Vector2(safe.end.x-72,safe.position.y+6),Vector2(64,44))
		if skin_layout.is_valid():skin_layout.call(safe)
	func tab(words: String,callback: Callable) -> Button:
		var b:=UI.action(words,"tab")
		b.custom_minimum_size.y=44
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.pressed.connect(callback)
		tabs.add_child(b)
		return b

class Switch extends Button:
	const UI=preload("res://src/ui/TravelChestUI.gd")
	var heading: Label
	var value: Label
	var on:=false
	var words_on: String
	var words_off: String
	## 换皮用：底板九宫格、开 / 关两张开关贴图、标题左缩进（左侧放图标框时加大）
	var plate: StyleBox
	var knob_on: Texture2D
	var knob_off: Texture2D
	var inset:=12.0
	func _init(words: String,active: bool=false,yes: String="开",no: String="关") -> void:
		text=words
		on=active
		words_on=yes
		words_off=no
		custom_minimum_size=Vector2(0,52)
		size_flags_horizontal=Control.SIZE_EXPAND_FILL
		heading=UI.label(words,"body")
		add_child(heading)
		value=UI.label("","caption",UI.AGED)
		value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		add_child(value)
	func _ready() -> void:
		for state in ["normal","hover","pressed","focus","disabled"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
		for property in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:add_theme_color_override(property,Color.TRANSPARENT)
		for event in [resized,focus_entered,focus_exited,mouse_entered,mouse_exited]:event.connect(queue_redraw)
	func _draw() -> void:
		if plate!=null:draw_style_box(plate,Rect2(Vector2.ZERO,size))
		else:UI.surface(self,Rect2(Vector2.ZERO,size),UI.FACE,UI.COPPER if has_focus() else Color("3a3037"))
		heading.position=Vector2(inset,0)
		heading.size=Vector2(size.x-inset-144,size.y)
		value.text=words_on if on else words_off
		value.position=Vector2(size.x-140,0)
		value.size=Vector2(68,size.y)
		var skin_knob:=knob_on if on else knob_off
		if skin_knob!=null:
			draw_texture(skin_knob,(Vector2(size.x-12-skin_knob.get_width(),(size.y-skin_knob.get_height())*.5)).floor())
			return
		# 轨道 + 滑块：开时滑块在右、轨道亮铜；关时滑块在左、轨道暗槽，一眼可辨是开关。
		var p:=Vector2(size.x-66,(size.y-26)*.5)
		var track:=Rect2(p,Vector2(54,26))
		draw_rect(track,UI.BRONZE if on else UI.NIGHT)
		draw_rect(track,UI.GOLD if on else UI.ASH,false,1.0)
		var knob:=Rect2(p+Vector2(30 if on else 4,4),Vector2(20,18))
		draw_rect(knob,UI.GOLD if on else UI.ASH)
		draw_rect(Rect2(knob.position,Vector2(knob.size.x,2)),Color(1,1,1,.35))
		draw_rect(Rect2(knob.position+Vector2(0,knob.size.y-2),Vector2(knob.size.x,2)),Color(0,0,0,.25))

## 行卡片：和 Switch 同一种底色与描边，让滑条行、倍速行与开关行视觉一致。
class Card extends MarginContainer:
	const UI=preload("res://src/ui/TravelChestUI.gd")
	func _init() -> void:
		size_flags_horizontal=Control.SIZE_EXPAND_FILL
		for side in ["margin_left","margin_right"]:add_theme_constant_override(side,12)
	func _ready() -> void:
		resized.connect(queue_redraw)
	var plate: StyleBox  # 换皮用，为空时画法不变
	func _draw() -> void:
		if plate!=null:draw_style_box(plate,Rect2(Vector2.ZERO,size))
		else:UI.surface(self,Rect2(Vector2.ZERO,size),UI.FACE,Color("3a3037"))
