# AvatarPanel.gd —— 更换头像浮层（上传本地图片 / 切回职业头像）
# 结构与其它浮层一致：遮罩 → 木匾 → 羊皮纸 → 内包 content 手动布局；父层负责 closed 后回收。
# 登录页是表单内的选择器，登录之后走这个浮层（主页点自己头像即可唤出）。
class_name AvatarPanel
extends Control

signal closed
signal changed          # 头像换了：父层据此刷新自己的头像贴图

const VIEW_W := 480.0
const CONTENT_W := 368.0
const PREVIEW := 132.0   # 预览尺寸（也是"上传后最多被看到的清晰度"上限，落盘是 256 方图）
const PICK_FILTERS := ["*.png,*.jpg,*.jpeg,*.webp,*.bmp ; 图片文件"]
const AVATAR_IDS := ["zs", "ck", "fs", "fz"]
const ROLE_NAMES := {"zs": "破军", "ck": "穿杨", "fs": "霜语", "fz": "晨星"}

var _content: Control = null
var _preview: TextureRect = null
var _state_l: Label = null
var _use_custom_btn: Control = null
var _use_role_btn: Control = null
var _picker: FileDialog = null
var _toast_l: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Audio.sfx("ui_open")
	_build()
	_refresh()


func _build() -> void:
	# 浮层底衬：统一走 G.veil（深棕 + 暗角 + 斜纹），不再各写一块纯灰
	G.veil(self, 0.74, true)

	var banner := G.banner_box("更换头像", 240, 50)
	banner.position = Vector2(120, 56)
	add_child(banner)

	var panel := G.parchment_box(400, 440, 16.0)
	panel.position = Vector2(40, 128)
	add_child(panel)

	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_content)

	# 预览：头像 + 金边方框（和主页左上角同一个内容，换之前先看清）
	var frame := Panel.new()
	frame.position = Vector2((CONTENT_W - PREVIEW) * 0.5, 4)
	frame.custom_minimum_size = Vector2(PREVIEW, PREVIEW)
	frame.size = Vector2(PREVIEW, PREVIEW)
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0.16, 0.11, 0.06, 0.10)
	fs.set_corner_radius_all(6)
	fs.set_border_width_all(3)
	fs.border_color = Color(G.BOX_EDGE.r, G.BOX_EDGE.g, G.BOX_EDGE.b, 0.85)
	_apply_shadow(fs)
	frame.add_theme_stylebox_override("panel", fs)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(frame)

	_preview = TextureRect.new()
	_preview.position = Vector2(6, 6)
	_preview.custom_minimum_size = Vector2(PREVIEW - 12.0, PREVIEW - 12.0)
	_preview.size = Vector2(PREVIEW - 12.0, PREVIEW - 12.0)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_preview)

	# 当前状态一行（用哪张图、从哪来），换完立刻能对得上
	_state_l = G.gold_label("", G.FS_XS, false, Color("8a6a34"), false)
	_state_l.position = Vector2(0, PREVIEW + 14.0)
	_state_l.custom_minimum_size = Vector2(CONTENT_W, 0)
	_state_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_state_l)

	# 主操作：上传本地图片（唯一的主按钮）
	var up := G.gold_button("上传本地图片", G.BTN_L.x, G.BTN_L.y, G.FS_MD)
	up.position = Vector2((CONTENT_W - G.BTN_L.x) * 0.5, PREVIEW + 44.0)
	up.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_open_picker())
	_content.add_child(up)

	# 次操作：切回上次上传的图（没上传过就压灰，不给假按钮）
	_use_custom_btn = G.ghost_button("用上次上传的图", G.BTN_M.x, G.BTN_M.y, G.FS_SM)
	_use_custom_btn.position = Vector2((CONTENT_W - G.BTN_M.x) * 0.5, PREVIEW + 108.0)
	_use_custom_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if G.use_custom_avatar():
				_toast("已换回上次上传的头像")
				_refresh()
				changed.emit()
			else:
				_toast("还没上传过图片"))
	_content.add_child(_use_custom_btn)

	# 恢复默认：保留已上传的图片，只切换当前使用的头像来源。
	_use_role_btn = G.ghost_button("用职业头像", G.BTN_M.x, G.BTN_M.y, G.FS_SM)
	_use_role_btn.position = Vector2((CONTENT_W - G.BTN_M.x) * 0.5, PREVIEW + 160.0)
	_use_role_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var rid := G.avatar_id if not G.get_role(G.avatar_id).is_empty() else G.selected_role
			if G.get_role(rid).is_empty():
				rid = "zs"
			G.use_role_avatar(rid)
			_toast("已切回职业头像")
			_refresh()
			changed.emit())
	_content.add_child(_use_role_btn)

	var tip := G.gold_label("图片只保存在本机，不联网、不上传",
		G.FS_XS, false, Color("8a6a34"), false)
	tip.position = Vector2(0, PREVIEW + 216.0)
	tip.custom_minimum_size = Vector2(CONTENT_W, 0)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(tip)

	var back := G.ghost_button("返回", G.BTN_S.x, G.BTN_S.y, G.FS_SM)
	back.position = Vector2((CONTENT_W - G.BTN_S.x) * 0.5, PREVIEW + 246.0)
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Audio.sfx("ui_close")
			closed.emit())
	_content.add_child(back)


func _apply_shadow(sb: StyleBoxFlat) -> void:
	sb.shadow_color = Color(0, 0, 0, 0.28)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 2)


# ---------- 选文件 ----------
## 懒建 FileDialog：只在真要选文件时才建，headless 验证路径不碰它
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
	var using_custom := G.avatar_use_custom and G.has_custom_avatar()
	if _state_l != null:
		if using_custom:
			_state_l.text = "当前：上传的图片"
		else:
			var rid := G.avatar_id if not G.avatar_id.is_empty() else G.selected_role
			_state_l.text = "当前：职业头像 · %s" % String(ROLE_NAMES.get(rid, rid))
	if _use_custom_btn != null:
		var usable := G.has_custom_avatar() and not using_custom
		_use_custom_btn.modulate = Color.WHITE if usable else Color(1, 1, 1, 0.45)
		_use_custom_btn.mouse_filter = Control.MOUSE_FILTER_STOP if usable \
			else Control.MOUSE_FILTER_IGNORE


func _toast(msg: String) -> void:
	if _toast_l != null:
		_toast_l.queue_free()
	_toast_l = G.gold_label(msg, G.FS_SM, false, Color("5a3a1e"))
	_toast_l.position = Vector2(0, 404)
	_toast_l.custom_minimum_size = Vector2(VIEW_W, 0)
	_toast_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_toast_l)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_toast_l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_toast_l.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Audio.sfx("ui_close")
		closed.emit()
		get_viewport().set_input_as_handled()
