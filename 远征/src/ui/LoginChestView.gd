extends Control
## 登录页：参考稿整张做背景（assets/ui/login_20261014，build_login_kit.py 生成，1:1 不缩放）。
## 输入框、按钮、画像卡都画在背景里，这里只在对应位置叠透明控件：
## LineEdit 自己画占位字和输入字，按钮只画悬停 / 按下 / 焦点反馈，底部提示和报错用 Label。
const UI:=preload("res://src/ui/TravelChestUI.gd")
const Flow:=preload("res://src/ui/FlowChestUI.gd")
const KIT:="res://assets/ui/login_20261014/"
const FADE:=24.0
var host:Control
var _kit:Dictionary
var _backdrop:TextureRect
var _art:TextureRect
var _back:Button
var _go:Button
var _guest:Button
var _eye:Button
var _error:Label
var _note:Label
var _avatar:TextureRect
var _form_scroll:Control
var _art_top:=0.0
var _last_keyboard:=-1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	theme=UI.theme()
	_kit=JSON.parse_string(FileAccess.get_file_as_string(KIT+"login_kit.json"))
	# 屏幕比原图高时：原图的暗化模糊版铺满，原图上下沿渐隐进去，不留硬边。
	_backdrop=TextureRect.new();_backdrop.name="LoginBackdrop"
	_backdrop.texture=load(KIT+"login_backdrop.png")
	_backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	_backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)
	_art=TextureRect.new();_art.name="LoginArt"
	_art.texture=load(KIT+"login_bg.png")
	_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode=TextureRect.STRETCH_SCALE
	_art.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	_art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_art.size=Vector2(_kit.size[0],_kit.size[1])
	var edge:=Shader.new()
	edge.code="shader_type canvas_item; uniform float fade_top=0.0; uniform float fade_bottom=0.0; uniform float art_h=853.0; void fragment(){ vec4 c=texture(TEXTURE,UV); float y=UV.y*art_h; if(fade_top>0.0){c.a*=smoothstep(0.0,fade_top,y);} if(fade_bottom>0.0){c.a*=smoothstep(0.0,fade_bottom,art_h-y);} COLOR=c; }"
	var mat:=ShaderMaterial.new();mat.shader=edge;mat.set_shader_parameter("art_h",float(_kit.size[1]))
	_art.material=mat
	add_child(_art)
	# 题字、副题画在背景里；占位节点只给外部按可见性判断布局状态。
	host._wordmark=_marker("Wordmark")
	host._subtitle=Label.new();host._subtitle.name="Subtitle";host._subtitle.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(host._subtitle)
	_back=Flow.button("‹",func():G.go("res://src/ui/Title.tscn"))
	_back.skin="back"
	_back.tooltip_text="返回标题"
	add_child(_back)
	# 纸面区域：两个输入框 + 画像卡。
	host._paper=_marker("RegistrationPaper")
	_form_scroll=host._paper
	host._account=_field("输入账号")
	host._account.name="Account"
	host._account.text=G.account if G.account!="游客" else ""
	host._password=_field("输入密码")
	host._password.name="Password"
	host._password.secret=true
	_eye=_Hotspot.new("显示或隐藏密码")
	_eye.focus_mode=Control.FOCUS_NONE
	_eye.pressed.connect(func():host._password.secret=not host._password.secret;_eye.queue_redraw())
	_eye.draw.connect(func():
		# 原图画的是睁眼；明文显示时压一道斜线，表示"再点隐藏"。
		if not host._password.secret:
			var c:=_eye.size*.5
			_eye.draw_line(c+Vector2(-11,8),c+Vector2(11,-8),Color("3a2a18"),2.0))
	add_child(_eye)
	host._account.text_submitted.connect(func(_words:String):host._password.grab_focus())
	host._password.text_submitted.connect(func(_words:String):host._do_login(false))
	host._avatar_card_btn=_Hotspot.new("自选旅人画像 · 导入图片")
	host._avatar_card_btn.name="AvatarCard"
	host._avatar_card_btn.pressed.connect(func():host._select_avatar("custom"))
	add_child(host._avatar_card_btn)
	# 自选画像导入后盖在罗盘圆盘上（圆形遮罩），未导入时露出原图罗盘。
	_avatar=TextureRect.new();_avatar.name="AvatarDisc"
	_avatar.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_avatar.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_avatar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var round_mask:=Shader.new()
	round_mask.code="shader_type canvas_item; void fragment(){ vec4 c=texture(TEXTURE,UV); c.a*=1.0-smoothstep(0.46,0.5,distance(UV,vec2(0.5))); COLOR=c; }"
	var round_mat:=ShaderMaterial.new();round_mat.shader=round_mask;_avatar.material=round_mat
	host._avatar_card_btn.add_child(_avatar)
	host._avatar_medallion=_avatar
	_go=_Hotspot.new("登录入城");_go.name="LoginButton"
	_go.pressed.connect(func():host._do_login(false))
	add_child(_go)
	_guest=_Hotspot.new("游客入城");_guest.name="GuestButton"
	_guest.pressed.connect(func():host._do_login(true))
	add_child(_guest)
	_note=_caption("◆ 旅途进度自动保存在本机 · 离线可读 ◆",Color("e2cfa4"))
	host._footer=_note
	_error=_caption("",Color("ffb59a"))
	var plate:=StyleBoxFlat.new()
	plate.bg_color=Color("1a0f0a",.86);plate.border_color=Color("b8862e");plate.set_border_width_all(1)
	plate.content_margin_left=10;plate.content_margin_right=10;plate.content_margin_top=2;plate.content_margin_bottom=2
	_error.add_theme_stylebox_override("normal",plate)
	_error.visible=false
	refresh_avatar()
	get_viewport().size_changed.connect(layout)
	layout()
	Flow.wire_focus(self)
	await get_tree().process_frame
	layout()

func _marker(id:String) -> Control:
	var c:=Control.new();c.name=id;c.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c

func _field(hint:String) -> LineEdit:
	var edit:=LineEdit.new()
	edit.placeholder_text=hint
	edit.max_length=16
	var clear:=StyleBoxEmpty.new();clear.content_margin_left=4;clear.content_margin_right=4
	var focus:=StyleBoxFlat.new()
	focus.bg_color=Color(1,.97,.86,.22);focus.border_color=Color("b07a2a")
	focus.border_width_bottom=2;focus.content_margin_left=4;focus.content_margin_right=4
	for state in ["normal","read_only"]:edit.add_theme_stylebox_override(state,clear)
	edit.add_theme_stylebox_override("focus",focus)
	edit.add_theme_font_override("font",G.font_reg)
	edit.add_theme_font_size_override("font_size",16)
	edit.add_theme_color_override("font_color",Color("2b2014"))
	edit.add_theme_color_override("font_placeholder_color",Color("8f7a5c"))
	edit.add_theme_color_override("caret_color",Color("8a3a1c"))
	edit.add_theme_color_override("selection_color",Color("c89848",.35))
	add_child(edit)
	return edit

func _caption(words:String,color:Color) -> Label:
	var l:=Label.new()
	l.text=words
	l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font",G.font_serif)
	l.add_theme_font_size_override("font_size",13)
	l.add_theme_color_override("font_color",color)
	l.add_theme_color_override("font_shadow_color",Color("140a05"))
	l.add_theme_constant_override("shadow_offset_x",1);l.add_theme_constant_override("shadow_offset_y",1)
	add_child(l)
	return l

func refresh_avatar() -> void:
	var tex:=G.custom_avatar_texture() if G.avatar_use_custom else null
	_avatar.texture=tex
	_avatar.visible=tex!=null

func error(words:String) -> void:_error.text=words;_error.visible=not words.is_empty();layout()

## 背景图里某块区域在屏幕上的位置（kit 里是原图坐标）。
func _rect(id:String) -> Rect2:
	var r:Array=_kit.rects[id]
	return Rect2(r[0],r[1]+_art_top,r[2]-r[0],r[3]-r[1])

func _put(node:Control,id:String) -> void:
	var r:=_rect(id);node.position=r.position;node.size=r.size

func layout(safe_override:Rect2=Rect2(),keyboard_override:float=-1) -> void:
	var safe:=safe_override if safe_override.has_area() else G.ui_safe_rect(self)
	var art_h:=float(_kit.size[1])
	var content:Array=_kit.content
	var keyboard:=DisplayServer.virtual_keyboard_get_height() if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) else 0
	if keyboard>0:
		keyboard_override=float(keyboard)*get_viewport_rect().size.y/maxf(1,get_window().size.y)
	var typing:=keyboard_override>0
	if typing:
		# 软键盘弹起：整张图上移，让登录按钮落在键盘上沿之上；键盘太高时优先保住账号框。
		var bottom:=safe.end.y-keyboard_override
		_art_top=maxf(bottom-float(_kit.rects.login_btn[3])-8,safe.position.y-float(_kit.rects.account_field[1])+8)
	else:
		# 居中；内容（题字到底部提示）必须完整落在安全区里，放不下时先保题字。
		_art_top=safe.position.y+(safe.size.y-art_h)*.5
		_art_top=minf(_art_top,safe.end.y-float(content[1]))
		_art_top=maxf(_art_top,safe.position.y-float(content[0]))
	_art_top=roundf(_art_top)
	_art.position=Vector2(0,_art_top)
	var view_h:=get_viewport_rect().size.y
	var mat:=_art.material as ShaderMaterial
	mat.set_shader_parameter("fade_top",FADE if _art_top>0 else 0.0)
	mat.set_shader_parameter("fade_bottom",FADE if _art_top+art_h<view_h else 0.0)
	_back.position=safe.position+Vector2(8,6);_back.size=Vector2(44,44)
	_put(host._wordmark,"title")
	_put(host._subtitle,"subtitle")
	_put(host._paper,"paper")
	_put(host._account,"account_text")
	_put(host._password,"password_text")
	_put(_eye,"eye")
	_put(host._avatar_card_btn,"avatar_card")
	var disc:Dictionary=_kit.avatar
	var card:Array=_kit.rects.avatar_card
	var r:=float(disc.radius)
	_avatar.position=Vector2(float(disc.center[0])-card[0]-r,float(disc.center[1])-card[1]-r)
	_avatar.size=Vector2(r,r)*2
	_put(_go,"login_body")
	_put(_guest,"guest_body")
	_put(_note,"note")
	host._wordmark.visible=not typing
	host._subtitle.visible=not typing
	_guest.visible=not typing
	_note.visible=not typing and not _error.visible
	if typing:
		# 报错挪到纸面上沿（题字已移出屏幕），保证键盘弹起时也看得到。
		var paper:=_rect("paper")
		_error.position=Vector2(paper.position.x,paper.position.y-30);_error.size=Vector2(paper.size.x,24)
	else:
		_put(_error,"note")

func _process(_delta:float) -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):return
	var height:=DisplayServer.virtual_keyboard_get_height()
	if height!=_last_keyboard:_last_keyboard=height;layout()


## 叠在背景画好的按钮上的透明热区：本身不画底，只画悬停提亮 / 按下压暗 / 键盘焦点金框。
class _Hotspot extends Button:
	func _init(label:String) -> void:
		text=""
		flat=true
		tooltip_text=label
		set("accessibility_name",label)
		focus_mode=Control.FOCUS_ALL
		mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		for state in ["normal","hover","pressed","disabled","focus","hover_pressed"]:
			add_theme_stylebox_override(state,StyleBoxEmpty.new())
		for s in [mouse_entered,mouse_exited,button_down,button_up,focus_entered,focus_exited]:
			s.connect(queue_redraw)
	func _draw() -> void:
		var box:=Rect2(Vector2.ZERO,size)
		if is_pressed():draw_rect(box,Color(0,0,0,.22))
		elif is_hovered():draw_rect(box,Color(1,.86,.55,.10))
		if has_focus() and not is_hovered():draw_rect(box.grow(-1),Color("f0c060"),false,2.0)
