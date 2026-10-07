# AvatarPanel.gd —— 旅人小像；头像即时保存，不影响职业或伙伴。
class_name AvatarPanel
extends Control

signal closed
signal changed

const UI := preload("res://src/ui/JournalUI.gd")
const Avatars := preload("res://src/ui/AvatarCatalog.gd")
const AVATAR_IDS := []
const PICK_FILTERS := ["*.png,*.jpg,*.jpeg,*.webp,*.bmp ; 图片文件"]

var _paper: PanelContainer
var _content: Control
var _preview: TextureRect
var _state_l: Label
var _use_custom_btn: Button
var _role_cards: Array[Control] = []
var _picker: FileDialog
var _toast_l: Label
var _tip: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Audio.sfx("ui_open")
	_build()
	_refresh()
	resized.connect(_layout_panel)
	_layout_panel.call_deferred()


func _build() -> void:
	G.veil(self, 0.66, true)
	_paper = UI.paper(388, 548)
	add_child(_paper)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.add_child(_content)
	var eyebrow := UI.label("昭元行旅录", 14, Color("c4b994"), true)
	_content.add_child(eyebrow)
	var title := UI.art_label("旅人小像", 30, UI.GOLD)
	title.position.y = 26
	_content.add_child(title)
	var close := UI.button("×", 44, 44, "dark_quiet")
	close.name = "CloseButton"
	close.position = Vector2(278, -8)
	close.tooltip_text = "关闭"
	close.pressed.connect(_close)
	_content.add_child(close)
	var frame := Panel.new()
	frame.position = Vector2(102, 88)
	frame.size = Vector2(112, 112)
	var portrait_style := UI.surface(Color("29423d"), Color("b79d68"), 2)
	portrait_style.set_border_width_all(3)
	frame.add_theme_stylebox_override("panel", portrait_style)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(frame)
	_preview = TextureRect.new()
	_preview.position = Vector2(8, 8)
	_preview.size = Vector2(96, 96)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_preview)
	_state_l = UI.label("", 14, UI.MUTED)
	_state_l.position.y = 210
	_state_l.size.x = 316
	_state_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_state_l)
	var instructions := UI.label("上传你喜欢的图片作为旅人小像。\n可随时更换，不使用职业或宠物头像。",14,UI.MUTED,true)
	instructions.position = Vector2(0,248)
	instructions.size = Vector2(316,56)
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(instructions)
	var upload := UI.button("选择本机图片", 316, 46, "primary")
	upload.name = "UploadButton"
	upload.position.y = 318
	upload.pressed.connect(_open_picker)
	_content.add_child(upload)
	_use_custom_btn = UI.button("用上次上传的图", 316, 44, "quiet")
	_use_custom_btn.position.y = 374
	_use_custom_btn.pressed.connect(func():
		if G.use_custom_avatar():
			_refresh()
			changed.emit())
	_content.add_child(_use_custom_btn)
	_tip = UI.label("图片与头像选择仅保存在本机", 14, UI.MUTED)
	_tip.size.x = 316
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_tip)


func _layout_panel() -> void:
	_paper.position = Vector2(46, (maxf(800, get_viewport_rect().size.y) - _paper.custom_minimum_size.y) * 0.5)


func _close() -> void:
	Audio.sfx("ui_close")
	closed.emit()


func _pick_role(id: String) -> void:
	if not AVATAR_IDS.has(id):
		return
	G.use_preset_avatar(id)
	Audio.sfx("ui_click")
	_refresh()
	changed.emit()


func _picker_node() -> FileDialog:
	if _picker != null and is_instance_valid(_picker):
		return _picker
	_picker = FileDialog.new()
	_picker.title = "选一张图片做头像"
	_picker.access = FileDialog.ACCESS_FILESYSTEM
	_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_picker.use_native_dialog = DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG)
	for f in PICK_FILTERS:
		_picker.add_filter(f, "图片")
	_picker.size = Vector2i(720, 480)
	_picker.file_selected.connect(func(path: String):
		var err := do_upload(path)
		if not err.is_empty():
			_toast(err))
	add_child(_picker)
	return _picker


func _open_picker() -> void:
	_picker_node().popup_centered()


## 上传一张图片做头像：返回空串=成功（自动化验证直接调它，绕开系统文件框）
func do_upload(path: String) -> String:
	var err := G.import_avatar(path)
	if err.is_empty():
		_refresh()
		changed.emit()
	else:
		_toast(err)
	return err


func _refresh() -> void:
	if _preview != null:
		_preview.texture = G.avatar_texture()
		_preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if G.avatar_use_custom else CanvasItem.TEXTURE_FILTER_NEAREST
	var using_custom := G.avatar_use_custom and G.has_custom_avatar()
	var has_custom := G.has_custom_avatar()
	_state_l.text = "当前使用：自定义图片" if using_custom else "尚未上传 · 默认行旅标记"
	_use_custom_btn.visible = has_custom
	_use_custom_btn.disabled = using_custom
	_use_custom_btn.modulate.a = 0.6 if using_custom else 1.0
	_use_custom_btn.add_theme_color_override("font_disabled_color", UI.MUTED)
	_paper.custom_minimum_size.y = 492 if has_custom else 444
	_paper.size.y = _paper.custom_minimum_size.y
	_tip.position.y = 430 if has_custom else 374
	_layout_panel()
	for card in _role_cards:
		UI.select_card(card, not using_custom and String(card.get_meta("avatar_id")) == G.current_avatar_id())


func _toast(msg: String) -> void:
	if is_instance_valid(_toast_l):
		_toast_l.queue_free()
	_toast_l = UI.label(msg, 14, Color("9d5139"))
	_toast_l.position.y = _tip.position.y
	_toast_l.size.x = 316
	_toast_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_l.add_theme_stylebox_override("normal", UI.surface(UI.PAPER))
	_content.add_child(_toast_l)
	var toast := _toast_l
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(toast, "modulate:a", 0.0, 0.3)
	tween.tween_callback(toast.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:   # GM 控制台等全屏层优先（轮次 14）
		return
	if event.is_action_pressed("ui_cancel"):
		Audio.sfx("ui_close")
		closed.emit()
		get_viewport().set_input_as_handled()
