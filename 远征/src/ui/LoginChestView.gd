extends Control
const UI:=preload("res://src/ui/TravelChestUI.gd")
const Page:=preload("res://src/ui/ChestPageUI.gd")
const Flow:=preload("res://src/ui/FlowChestUI.gd")
const Fix:=preload("res://src/ui/ReviewFixUI.gd")
var host:Control
var _back:Button
var _go:Button
var _guest:Button
var _error:Label
var _avatar:TextureRect
var _note:Label
var _form:VBoxContainer
var _gap:Control
var _form_scroll:ScrollContainer
var _last_keyboard:=-1
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=UI.theme()
	_back=Flow.button("‹",func():G.go("res://src/ui/Title.tscn"))
	_back.skin="back"
	_back.tooltip_text="返回标题"
	add_child(_back)
	host._wordmark=Page.picture(preload("res://src/ui/UIWordmark.gd").ART,Vector2(220,88))
	add_child(host._wordmark)
	host._subtitle=UI.label("昭元行旅录","caption",UI.AGED)
	host._subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	add_child(host._subtitle)
	host._paper=PanelContainer.new()
	var paper:=StyleBoxFlat.new();paper.bg_color=Color.TRANSPARENT
	paper.content_margin_left=10;paper.content_margin_right=10;paper.content_margin_top=10;paper.content_margin_bottom=10
	host._paper.add_theme_stylebox_override("panel",paper)
	add_child(host._paper)
	var form:=VBoxContainer.new()
	_form=form
	form.add_theme_constant_override("separation",8)
	_form_scroll=Page.scroll()
	_form_scroll.follow_focus=true
	_form_scroll.add_child(form)
	host._paper.add_child(_form_scroll)
	form.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	form.add_child(Flow.text("旅人登记","object",Color("2b2420")))
	var gap:=Control.new()
	_gap=gap
	gap.custom_minimum_size.y=0
	form.add_child(gap)
	form.add_child(Flow.text("通关文牒","caption",Color("6e5434")))
	host._account=Flow.field("你的文牒账号",true)
	host._account.text=G.account if G.account!="游客" else ""
	form.add_child(host._account)
	form.add_child(Flow.text("通关秘钥","caption",Color("6e5434")))
	var secret:=Control.new();secret.custom_minimum_size.y=48
	secret.add_theme_constant_override("separation",0)
	form.add_child(secret)
	host._password=Flow.field("输入通关密码",true)
	host._password.secret=true
	secret.add_child(host._password)
	host._password.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for state in ["normal","focus","read_only"]:
		var box:StyleBoxFlat=host._password.get_theme_stylebox(state).duplicate();box.content_margin_right=48;host._password.add_theme_stylebox_override(state,box)
	var eye:=Flow.button("",func():host._password.secret=not host._password.secret)
	eye.skin="quiet"
	eye.tooltip_text="显示或隐藏密码"
	eye.draw.connect(func():
		eye.draw_arc(Vector2(22,24),8,0,TAU,24,Color("6e5434"),1.5,true)
		eye.draw_circle(Vector2(22,24),3,Color("6e5434")))
	eye.custom_minimum_size=Vector2(44,48)
	eye.size_flags_horizontal=Control.SIZE_SHRINK_END
	secret.add_child(eye)
	eye.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE);eye.offset_left=-44;eye.offset_top=0;eye.offset_bottom=0
	host._account.text_submitted.connect(func(_words:String):host._password.grab_focus())
	host._password.text_submitted.connect(func(_words:String):host._do_login(false))
	host._avatar_card_btn=Flow.button("",func():host._select_avatar("custom"))
	host._avatar_card_btn.custom_minimum_size.y=64
	form.add_child(host._avatar_card_btn)
	_avatar=Page.picture(G.avatar_texture(),Vector2(48,48))
	_avatar.position=Vector2(8,8)
	host._avatar_card_btn.add_child(_avatar)
	host._avatar_medallion=_avatar
	var words:=UI.label("自选旅人画像 · 导入图片","caption",UI.PAPER)
	words.position=Vector2(68,0)
	words.size=Vector2(180,64)
	words.add_theme_font_size_override("font_size",12)
	words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	host._avatar_card_btn.add_child(words)
	_error=Flow.text("","caption",UI.RED)
	_error.custom_minimum_size.y=24
	_error.visible=false
	form.add_child(_error)
	var seal:=Flow.text("昭元行牒","section",Color("8a3c2d"))
	seal.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	form.add_child(seal)
	_go=Flow.button("登录入城",func():host._do_login(false),true)
	add_child(_go)
	_guest=Flow.button("游客入城",func():host._do_login(true))
	add_child(_guest)
	_note=UI.label("旅途进度自动保存在本机","tag",UI.AGED)
	_note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	add_child(_note)
	host._footer=_note
	get_viewport().size_changed.connect(layout)
	layout()
	Flow.wire_focus(self)
	await get_tree().process_frame
	layout()
	await get_tree().process_frame
	layout()
func refresh_avatar() -> void:_avatar.texture=G.avatar_texture()
func error(words:String) -> void:_error.text=words;_error.visible=not words.is_empty();layout()
func layout(safe_override:Rect2=Rect2(),keyboard_override:float=-1) -> void:
	var safe:=safe_override if safe_override.has_area() else G.ui_safe_rect(self)
	(host._paper.get_theme_stylebox("panel") as StyleBoxFlat).bg_color=Color.TRANSPARENT
	Page.place(_back,safe.position+Vector2(8,6),Vector2(44,44))
	Page.place(host._wordmark,Vector2(safe.get_center().x-110,safe.position.y+40),Vector2(220,88))
	Page.place(host._subtitle,Vector2(safe.get_center().x-100,safe.position.y+132),Vector2(200,22))
	host._wordmark.visible=true
	host._subtitle.visible=true
	_guest.visible=true
	_note.visible=true
	_form.add_theme_constant_override("separation",4)
	_gap.custom_minimum_size.y=0
	var paper_height:=clampf(360.0+(safe.size.y-800)*.25,320,450)+(24 if _error.visible else 0)
	host._paper.custom_minimum_size.y=paper_height
	var paper_width:=safe.size.x*.60
	Page.place(host._paper,Vector2(safe.get_center().x-paper_width*.5,safe.position.y+safe.size.y*.235),Vector2(paper_width,paper_height))
	Page.place(_go,Vector2(safe.position.x+36,maxf(host._paper.position.y+paper_height+16,safe.end.y-224)),Vector2(safe.size.x-72,56))
	Page.place(_guest,Vector2(safe.position.x+36,_go.position.y+64),Vector2(safe.size.x-72,48))
	Page.place(_note,Vector2(safe.position.x+24,_guest.position.y+60),Vector2(safe.size.x-48,24))
	if safe.size.y<780:
		host._wordmark.position.y=safe.position.y+16
		host._subtitle.visible=false
		host._paper.position.y=safe.position.y+128
		_form.add_theme_constant_override("separation",4)
		_gap.custom_minimum_size.y=0
		host._paper.custom_minimum_size.y=paper_height
		host._paper.size.y=paper_height
		_note.visible=false
		_go.position.y=host._paper.position.y+paper_height+16
		_guest.position.y=_go.position.y+64
	var keyboard:=DisplayServer.virtual_keyboard_get_height() if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) else 0
	if keyboard>0:
		keyboard_override=float(keyboard)*get_viewport_rect().size.y/maxf(1,get_window().size.y)
	if keyboard_override>0:
		(host._paper.get_theme_stylebox("panel") as StyleBoxFlat).bg_color=Color("ead8b0")
		var bottom:=safe.end.y-keyboard_override
		host._wordmark.visible=false
		host._subtitle.visible=false
		_guest.visible=false
		_note.visible=false
		host._paper.custom_minimum_size.y=maxf(176,bottom-safe.position.y-132)
		Page.place(host._paper,Vector2(safe.position.x+24,safe.position.y+52),Vector2(safe.size.x-48,host._paper.custom_minimum_size.y))
		_go.position.y=bottom-68
func _process(_delta:float) -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):return
	var height:=DisplayServer.virtual_keyboard_get_height()
	if height!=_last_keyboard:_last_keyboard=height;layout()
