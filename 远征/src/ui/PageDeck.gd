# PageDeck.gd —— 通用水平滑动分页容器（一屏一项：大卡轮播）
# 能力：1) 手指/鼠标横向拖拽翻页（松手按位移判定）2) 左右箭头点击
#      3) 键盘翻页：key_mode 决定吃哪组键（lr=←→/AD、ud=↑↓/WS、both、none）
#      4) 圆点指示器；wrap=true 首尾循环（轮播场景箭头常驻不隐藏）
# 版式：轨道装在 clip 里只裁页面，圆点画在轨道下方（footer 区），
#      这样整屏大卡不会被圆点压住文案；只有一页时箭头与圆点自动隐藏。
class_name PageDeck
extends Control

signal page_changed(i: int)

const DOT_OFF := Color("9a8a68")
const DOT_ON := Color("e2b95c")
const DOT_GAP := 8

var page_count := 0:
	set(v):
		page_count = v
		_rebuild_dots()

var current := 0
## 吃哪组键：both（←→↑↓ / WASD）| lr（←→/AD）| ud（↑↓/WS）| none（由宿主接管）
## 嵌在别处做二级导航时一律给 lr/none，免得跟宿主的键位打架
var key_mode := "both"
## 首尾循环：末尾再往右回到第一张，箭头常驻
var wrap := false

var _view_w := 408.0
var _view_h := 320.0
var _footer := 0.0
var _clip := Control.new()
var _track := Control.new()
var _dots := HBoxContainer.new()
var _prev_btn := Control.new()
var _next_btn := Control.new()
var _tween: Tween = null
var _dragging := false
var _drag_start := 0.0          # 按下时的指针 x
var _drag_base := 0.0           # 按下时轨道 x


## w/h 是一页（一项）的尺寸；footer_h > 0 时圆点落在页面下方的页脚带里
func _init(w := 408.0, h := 320.0, footer_h := 0.0) -> void:
	_view_w = w
	_view_h = h
	_footer = footer_h
	custom_minimum_size = Vector2(w, h + footer_h)
	size = Vector2(w, h + footer_h)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.position = Vector2.ZERO
	_clip.size = Vector2(w, h)
	add_child(_clip)

	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.position = Vector2.ZERO
	_clip.add_child(_track)

	# 左右箭头（Kenney CC0 棕色箭头，22×21）：贴在两缘、垂直居中
	_prev_btn = _arrow_btn("arrowBrown_left", Vector2(4, h * 0.5 - 17))
	_next_btn = _arrow_btn("arrowBrown_right", Vector2(w - 26, h * 0.5 - 17))
	_clip.add_child(_prev_btn)
	_clip.add_child(_next_btn)

	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", DOT_GAP)
	add_child(_dots)
	_layout_dots()


func _arrow_btn(tex_name: String, pos: Vector2) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(22, 34)   # 命中区比箭头大一圈好点
	root.position = pos
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var tex: Texture2D = G.res_tex(tex_name)
	if tex != null:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(22, 21)
		pic.size = Vector2(22, 34)
		pic.position = Vector2(0, 6.5)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(pic)
	root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if tex_name.ends_with("left"):
				prev_page()
			else:
				next_page())
	return root


func _layout_dots() -> void:
	var y := _view_h - 17.0
	if _footer > 0.0:
		y = _view_h + (_footer - 14.0) * 0.5
	_dots.position = Vector2(0, y)
	_dots.custom_minimum_size = Vector2(_view_w, 14)


## 装页：page 是一屏一项，页宽等于本容器宽；page_size 省略时按自身最小高度
func add_page(page: Control, page_size := Vector2.ZERO) -> void:
	var ps := page_size
	if ps == Vector2.ZERO:
		ps = Vector2(_view_w, page.custom_minimum_size.y)
	page.custom_minimum_size = ps
	page.size = ps
	page.position = Vector2(float(page_count) * _view_w, 0)
	_track.add_child(page)
	self.page_count += 1
	_refresh_arrows()


## 跳到第 i 页（带滑动动画）
func go(i: int, instant := false) -> void:
	if page_count <= 0:
		return
	i = wrapi(i, 0, page_count) if wrap else clampi(i, 0, page_count - 1)
	current = i
	var target := Vector2(-float(i) * _view_w, 0)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if instant:
		_track.position = target
	else:
		Audio.sfx("ui_page")   # 翻页（instant 是初始化落位，不响）
		_tween = create_tween()
		_tween.tween_property(_track, "position", target, 0.22)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_refresh_arrows()
	_refresh_dots()
	page_changed.emit(i)


func next_page() -> void:
	go(current + 1)


func prev_page() -> void:
	go(current - 1)


# ---------- 拖拽 ----------
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_dragging = true
			_drag_start = (e as InputEventMouseButton).global_position.x
			_drag_base = _track.position.x
			if _tween != null and _tween.is_valid():
				_tween.kill()
		else:
			if _dragging:
				_end_drag((e as InputEventMouseButton).global_position.x)
			_dragging = false
	elif e is InputEventMouseMotion and _dragging:
		var dx := (e as InputEventMouseMotion).global_position.x - _drag_start
		# 拖出边界时给一半阻尼，松手自然回弹
		var raw := _drag_base + dx
		var min_x := -float(maxi(0, page_count - 1)) * _view_w
		if raw > 0.0:
			raw *= 0.4
		elif raw < min_x:
			raw = min_x + (raw - min_x) * 0.4
		_track.position = Vector2(raw, 0)


func _end_drag(x: float) -> void:
	var dx := x - _drag_start
	var w := _view_w
	if dx < -w * 0.16:
		go(current + 1)
	elif dx > w * 0.16:
		go(current - 1)
	else:
		go(current)   # 幅度不够：回弹归位


# ---------- 键盘 ----------
func _unhandled_input(e: InputEvent) -> void:
	if page_count <= 1 or key_mode == "none":
		return
	if G.ui_blocked:   # GM 控制台等全屏浮层优先
		return
	var prev := false
	var next := false
	if key_mode == "lr" or key_mode == "both":
		prev = prev or e.is_action_pressed("move_left") or e.is_action_pressed("ui_left")
		next = next or e.is_action_pressed("move_right") or e.is_action_pressed("ui_right")
	if key_mode == "ud" or key_mode == "both":
		prev = prev or e.is_action_pressed("move_up") or e.is_action_pressed("ui_up")
		next = next or e.is_action_pressed("move_down") or e.is_action_pressed("ui_down")
	if prev:
		prev_page()
		get_viewport().set_input_as_handled()
	elif next:
		next_page()
		get_viewport().set_input_as_handled()


# ---------- 指示器 ----------
func _rebuild_dots() -> void:
	for c in _dots.get_children():
		c.queue_free()
	for i in page_count:
		# 圆点可点跳页（手游习惯）：外面包 14×14 命中区，点按去 go(i)
		var hit := Control.new()
		hit.custom_minimum_size = Vector2(14, 14)
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var idx := i
		hit.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				go(idx))
		var d := ColorRect.new()
		d.color = DOT_ON if i == current else DOT_OFF
		d.custom_minimum_size = Vector2(7, 7)
		d.size = Vector2(7, 7)
		d.position = Vector2(3.5, 3.5)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hit.add_child(d)
		_dots.add_child(hit)
	_dots.visible = page_count > 1
	_refresh_dots()


func _refresh_dots() -> void:
	var i := 0
	for c in _dots.get_children():
		if c.get_child_count() > 0:
			var dot := c.get_child(0) as ColorRect
			if dot != null:
				dot.color = DOT_ON if i == current else DOT_OFF
		i += 1


func _refresh_arrows() -> void:
	var multi := page_count > 1
	_prev_btn.visible = multi and (wrap or current > 0)
	_next_btn.visible = multi and (wrap or current < page_count - 1)
