# Prologue.gd —— 序章卷轴：登录/创角之后、进主城之前的一段叙事
# 目的：让玩家在见到主城之前就知道——自己在哪、为什么出征、第一站去哪。
# 文本全部来自 data/lore.json（G.prologue_pages / G.world_setting），代码不写死剧情。
# 交互：点卷轴任意处 / 点「继 续」/ 回车 翻页；右上「跳 过」直接入城（同样记为已看）。
extends Control

const VIEW_W := 480.0
const VIEW_H := 800.0
const GAME_HOME := "res://src/ui/GameHome.tscn"

## 测试接口：置空串时不切场景（tools/VerifyLore.gd 用它驱动整段序章）
var on_finish_scene := GAME_HOME

var _pages: Array = []
var _page := 0
var _lines_box: VBoxContainer = null
var _kicker: Label = null
var _title: Label = null
var _page_lbl: Label = null
var _dots: HBoxContainer = null
var _next_btn: Control = null
var _tw: Tween = null


func _ready() -> void:
	Audio.play_bgm("bgm_title")
	_pages = _build_pages()
	_build()
	_show_page(0)


## 首屏补一页「世界志」：把 lore.json 的 world 段（界名/纪年/局势/你是谁）讲清楚
func _build_pages() -> Array:
	var out: Array = []
	var w := G.world_setting()
	if not w.is_empty():
		var lines: Array = []
		var era := String(w.get("era", ""))
		var premise := String(w.get("premise", ""))
		var you := String(w.get("you", ""))
		if not premise.is_empty():
			lines.append(premise)
		if not you.is_empty():
			lines.append(you)
		out.append({
			"kicker": era,
			"title": String(w.get("name", "昭元")) + "界",
			"lines": lines,
		})
	var pages := G.prologue_pages()
	if pages.is_empty():
		out.append({"kicker": "序 章", "title": "启程", "lines": ["八碑八主，碑响则路开。"]})
	else:
		out.append_array(pages)
	return out


# ---------- 构建 ----------
func _build() -> void:
	var bg := TextureRect.new()
	var tex: Texture2D = load("res://image/background/enter.png")
	if tex != null:
		bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(VIEW_W, VIEW_W * 1672.0 / 941.0)
	bg.position = Vector2(0, VIEW_H - bg.size.y)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 序章氛围压暗：不吃点击（正文之上还有继续/跳过的按钮要能用）
	G.veil(self, 0.62, false)

	var banner := G.banner_box("序 章", 200, 50)
	banner.position = Vector2((VIEW_W - 200.0) * 0.5, 34)
	add_child(banner)

	var sub := G.gold_label("开 卷 · 远征图志", G.FS_XS, false, Color("d8bd8a", 0.75), false)
	sub.position = Vector2(0, 88)
	sub.custom_minimum_size = Vector2(VIEW_W, 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	var panel := G.parchment_box(408, 500, 18.0)
	panel.position = Vector2(36, 128)
	add_child(panel)

	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	_kicker = G.gold_label("", G.FS_XS, false, Color("8a6a34"), false)
	_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_kicker.position = Vector2(0, 0)
	_kicker.custom_minimum_size = Vector2(372, 0)
	content.add_child(_kicker)

	_title = G.serif_label("", G.FS_LG + 4, Color("6a4a1e"))
	_title.position = Vector2(0, 24)
	_title.custom_minimum_size = Vector2(372, 34)
	content.add_child(_title)

	var rule := ColorRect.new()
	rule.color = Color(G.BANNER.r, G.BANNER.g, G.BANNER.b, 0.35)
	rule.position = Vector2(0, 66)
	rule.custom_minimum_size = Vector2(372, 2)
	content.add_child(rule)

	_lines_box = VBoxContainer.new()
	_lines_box.add_theme_constant_override("separation", 12)
	_lines_box.position = Vector2(0, 84)
	_lines_box.custom_minimum_size = Vector2(372, 340)
	_lines_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_lines_box)

	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 8)
	_dots.position = Vector2(0, 432)
	_dots.custom_minimum_size = Vector2(372, 12)
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_dots)
	for i in _pages.size():
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(7, 7)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dots.add_child(d)

	_page_lbl = G.gold_label("", G.FS_XS, false, Color("8a6a34", 0.85), false)
	_page_lbl.position = Vector2(0, 408)
	_page_lbl.custom_minimum_size = Vector2(372, 0)
	_page_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_page_lbl)

	# 卷轴本身可点（手游习惯：点哪都能翻页）
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_advance())

	var skip := G.gold_button("跳 过", 102, 36, G.FS_SM)
	skip.position = Vector2(36, 660)
	skip.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Audio.sfx("ui_cancel")
			_finish())
	add_child(skip)

	_next_btn = G.gold_button("继 续", 132, 42, G.FS_MD)
	_next_btn.position = Vector2(312, 656)
	_next_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_advance())
	add_child(_next_btn)

	var hint := G.gold_label("点卷轴或按回车翻页", G.FS_XS, false, Color("cfb98a", 0.8), false)
	hint.position = Vector2(0, 712)
	hint.custom_minimum_size = Vector2(VIEW_W, 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)


# ---------- 翻页 ----------
func _show_page(i: int) -> void:
	_page = clampi(i, 0, maxi(0, _pages.size() - 1))
	var p: Dictionary = _pages[_page]
	_kicker.text = String(p.get("kicker", ""))
	_title.text = String(p.get("title", ""))
	_page_lbl.text = "%d / %d" % [_page + 1, _pages.size()]
	var i2 := 0
	for c in _dots.get_children():
		if c is ColorRect:
			(c as ColorRect).color = G.GOLD_BRIGHT if i2 == _page else Color(0.55, 0.48, 0.36, 0.7)
		i2 += 1

	for c in _lines_box.get_children():
		c.queue_free()
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.set_parallel(true)
	var rows: Array = p.get("lines", [])
	var idx := 0
	for row in rows:
		# 段首空两格（全角空格）：中文书卷的排法，比左顶格更像"文"，不像模板
		var l := G.text_label("　" + String(row), G.FS_MD, Color("4a3a22"))
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		l.custom_minimum_size = Vector2(372, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.modulate.a = 0.0
		_lines_box.add_child(l)
		_tw.tween_property(l, "modulate:a", 1.0, 0.35).set_delay(0.12 * float(idx))
		idx += 1

	_next_btn.set_meta("label_hint", _page >= _pages.size() - 1)
	var btn_label := _find_label(_next_btn)
	if btn_label != null:
		btn_label.text = "启 程" if _page >= _pages.size() - 1 else "继 续"


func _find_label(root: Node) -> Label:
	for c in root.get_children():
		if c is Label:
			return c as Label
	return null


func _advance() -> void:
	if _page >= _pages.size() - 1:
		Audio.sfx("ui_confirm")   # 末页「启程」：确认音比翻页更"重"，收得住
		_finish()
	else:
		Audio.sfx("ui_page")
		_show_page(_page + 1)


func _finish() -> void:
	G.mark_lore_seen()
	if on_finish_scene.is_empty():
		return
	G.go(on_finish_scene)


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:   # GM 控制台等全屏层优先（轮次 14）
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_right"):
		_advance()
	elif event.is_action_pressed("ui_cancel"):
		Audio.sfx("ui_cancel")
		_finish()
