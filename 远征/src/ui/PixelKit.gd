extends RefCounted
## 像素 UI 组件：框体、按钮、铭牌全部按 2px 网格在代码里绘制（1 美术像素 = 2 UI 像素），
## 与角色、地图的像素颗粒一致；不用缩放贴图，因此不会出现模糊、假像素或颗粒大小不一。
const P := 2.0

const RARITY := {"common": Color("c8c2b4"), "uncommon": Color("6fbf73"), "rare": Color("5aa6e8"),
	"epic": Color("b07ae8"), "legend": Color("f0b14a")}

## 材质色板：face 面、face2 纹理、rim 边框、lit 受光、dark 轮廓、rivet 铆钉。
const MATERIALS := {
	"iron": {"face": Color("2a2530"), "face2": Color("221e28"), "rim": Color("5c4a34"), "lit": Color("c99b5a"), "dark": Color("0e0c11"), "rivet": Color("d9b26a")},
	"wood": {"face": Color("4a3222"), "face2": Color("3c2819"), "rim": Color("2b1b10"), "lit": Color("8d6342"), "dark": Color("160d07"), "rivet": Color("c99b5a")},
	"paper": {"face": Color("e6d6b0"), "face2": Color("d8c596"), "rim": Color("8a6a3a"), "lit": Color("f6ecd2"), "dark": Color("4a3420"), "rivet": Color("8a6a3a")},
	"stone": {"face": Color("3d4045"), "face2": Color("34373b"), "rim": Color("1f2124"), "lit": Color("7c8187"), "dark": Color("111214"), "rivet": Color("9aa0a6")},
	"crimson": {"face": Color("7c2418"), "face2": Color("761f15"), "rim": Color("3a120b"), "lit": Color("b8452c"), "dark": Color("170503"), "rivet": Color("f0c070")},
}

static func snap(r: Rect2) -> Rect2:
	var p := (r.position / P).floor() * P
	var e := (r.end / P).floor() * P
	return Rect2(p, e - p)

## 带倒角轮廓、厚边框、内凹面与材质纹理的像素框体。
static func frame(c: CanvasItem, rect: Rect2, mat := "iron", trim := Color(0, 0, 0, 0), rivets := true,
		glow := false, pressed := false) -> void:
	var r := snap(rect)
	var m: Dictionary = MATERIALS.get(mat, MATERIALS.iron)
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y
	if w < P * 10 or h < P * 10:
		c.draw_rect(r, m.face)
		return
	if not pressed: c.draw_rect(Rect2(x + P, y + P * 2, w, h), Color(0, 0, 0, .42))
	c.draw_rect(Rect2(x + P, y, w - P * 2, h), m.dark)
	c.draw_rect(Rect2(x, y + P, w, h - P * 2), m.dark)
	var rim: Color = trim if trim.a > 0 else m.rim
	if glow: rim = rim.lightened(.2)
	c.draw_rect(Rect2(x + P * 2, y + P, w - P * 4, h - P * 2), rim)
	c.draw_rect(Rect2(x + P, y + P * 2, w - P * 2, h - P * 4), rim)
	c.draw_rect(Rect2(x + P * 2, y + P, w - P * 4, P), rim.lightened(.38))
	c.draw_rect(Rect2(x + P * 2, y + h - P * 2, w - P * 4, P), rim.darkened(.38))
	c.draw_rect(Rect2(x + P * 3, y + P * 3, w - P * 6, h - P * 6), m.dark)
	var face := Rect2(x + P * 4, y + P * 4, w - P * 8, h - P * 8)
	c.draw_rect(face, m.face.darkened(.14) if pressed else m.face)
	_grain(c, face, m, mat)
	c.draw_rect(Rect2(face.position, Vector2(face.size.x, P)), Color(0, 0, 0, .55 if pressed else .32))
	c.draw_rect(Rect2(face.position.x, face.end.y - P, face.size.x, P), Color(m.lit, .2))
	if rivets and w >= P * 24:
		for rx in [x + P * 4, x + w - P * 6]:
			for ry in [y + P, y + h - P * 3]:
				c.draw_rect(Rect2(rx, ry, P * 2, P * 2), m.rivet)
				c.draw_rect(Rect2(rx, ry, P, P), m.rivet.lightened(.45))
				c.draw_rect(Rect2(rx + P, ry + P, P, P), m.rivet.darkened(.5))

## 材质纹理：铁铜/木/纸用横向拉丝或纹理条，石材用砌缝；种子只取尺寸，同尺寸框体纹理稳定不闪。
static func _grain(c: CanvasItem, face: Rect2, m: Dictionary, mat: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(face.size.x) * 73856093 ^ int(face.size.y) * 19349663 ^ mat.hash()
	var rows := int(face.size.y / P)
	if mat == "stone":
		for i in range(6, rows, 7):
			c.draw_rect(Rect2(face.position.x, face.position.y + i * P, face.size.x, P), Color(m.dark, .6))
			var shift := 9 if (i / 7) % 2 == 0 else 3
			for bx in range(shift, int(face.size.x / P), 12):
				c.draw_rect(Rect2(face.position.x + bx * P, face.position.y + maxf(0, i - 6) * P, P, P * 6), Color(m.dark, .45))
		return
	for i in rows:
		for k in (1 if mat == "paper" else 2):
			var span := float(rng.randi_range(3, 14)) * P
			var sx := face.position.x + floorf(rng.randf_range(0, maxf(0, face.size.x - span)) / P) * P
			var lit := rng.randf() > .62
			c.draw_rect(Rect2(sx, face.position.y + i * P, minf(span, face.size.x), P), Color(m.lit, .12) if lit else m.face2)

## 金色角码：大面板四角的 L 形包角。
static func brackets(c: CanvasItem, rect: Rect2, col := Color("d9b26a"), arm := 7) -> void:
	var r := snap(rect)
	var L := P * arm
	for corner in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)],
			[Vector2(r.position.x, r.end.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]:
		var o: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		var hx := o.x if d.x > 0 else o.x - L
		var vy := o.y if d.y > 0 else o.y - L
		var hy := o.y if d.y > 0 else o.y - P * 2
		var vx := o.x if d.x > 0 else o.x - P * 2
		c.draw_rect(Rect2(hx, hy, L, P * 2), col.darkened(.35))
		c.draw_rect(Rect2(vx, vy, P * 2, L), col.darkened(.35))
		c.draw_rect(Rect2(hx, hy, L, P), col)
		c.draw_rect(Rect2(vx, vy, P, L), col)

## 斜向扫光：phase 0..1 扫过一次，超出范围不画。只在框体面内绘制。
static func sweep(c: CanvasItem, rect: Rect2, phase: float) -> void:
	if phase < 0.0 or phase > 1.0: return
	var r := snap(rect)
	var inner := Rect2(r.position + Vector2.ONE * P * 4, r.size - Vector2.ONE * P * 8)
	var rows := int(inner.size.y / P)
	var head := inner.position.x - inner.size.y + phase * (inner.size.x + inner.size.y * 2)
	for i in rows:
		var bx := floorf((head + (rows - i) * P * .5) / P) * P
		for k in 4:
			var px := bx + k * P
			if px < inner.position.x or px >= inner.end.x: continue
			c.draw_rect(Rect2(px, inner.position.y + i * P, P, P), Color(1, .95, .8, [.10, .22, .22, .10][k]))

## 入场：淡入 + 自下推入 + 回弹。截图审查模式下直接落到终态，保证截图稳定。
static func enter(node: CanvasItem, delay := 0.0, from := Vector2(0, 22)) -> void:
	if G.get_meta("ui_review_mode", false) or DisplayServer.get_name() == "headless": return
	var target: Vector2 = node.position
	node.modulate.a = 0.0
	node.position = target + from
	var tw := node.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(node, "modulate:a", 1.0, .3)
	tw.parallel().tween_property(node, "position", target, .46).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func label(words: String, px := 16, color := Color("e9d9b6"), spacing := 1) -> Label:
	var l := Label.new()
	l.text = words
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var f := FontVariation.new()
	f.base_font = G.font_serif
	f.spacing_glyph = spacing
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l

## 静态铭牌：一块框体，用作标题牌、信息底板。
class Plaque extends Control:
	const Kit = preload("res://src/ui/PixelKit.gd")
	const UiKitLib = preload("res://src/ui/UiKit.gd")
	var mat := "iron"
	var trim := Color(0, 0, 0, 0)
	var rivets := true
	var corner := false
	var kit_id := ""   # 素材包九宫格：panel_iron / card_paper / plaque_title / plaque_small / nav_base / quest_slip …
	func _init(material := "iron") -> void:
		mat = material
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _ready() -> void:
		resized.connect(queue_redraw)
	func _draw() -> void:
		var skin: StyleBoxTexture = UiKitLib.style(kit_id) if not kit_id.is_empty() else null
		if skin != null:
			draw_style_box(skin, UiKitLib.snap(Rect2(Vector2.ZERO, size)))
			return
		Kit.frame(self, Rect2(Vector2.ZERO, size), mat, trim, rivets)
		if corner: Kit.brackets(self, Rect2(Vector2.ZERO, size))

## 像素按钮：悬停上浮一格、按下下沉一格、主按钮周期扫光、点击迸出像素火星。
class PixelButton extends Button:
	const Kit = preload("res://src/ui/PixelKit.gd")
	const UiKitLib = preload("res://src/ui/UiKit.gd")
	var caption: Label
	var mat := "iron"
	var trim := Color(0, 0, 0, 0)
	var shine := false
	var ornate := false  # 主按钮两端的金色像素菱形（代码绘制模式）
	var kit := ""        # 素材包前缀：hero / btn / tab；设置后用 *_normal/_pressed/_disabled 贴图代替代码框体
	var selected := false
	var _t := 0.0
	var _hover := false
	var _sparks: Array = []
	func _init(words := "", material := "iron", font_px := 18) -> void:
		mat = material
		caption = Kit.label(words, font_px, Color("f8e2b0") if material == "crimson" else Color("e9d9b6"), 4 if font_px >= 22 else 1)
		add_child(caption)
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	func _ready() -> void:
		for s in ["normal", "hover", "pressed", "focus", "disabled"]: add_theme_stylebox_override(s, StyleBoxEmpty.new())
		mouse_entered.connect(func(): _hover = true; queue_redraw())
		mouse_exited.connect(func(): _hover = false; queue_redraw())
		for e in [button_down, button_up, focus_entered, focus_exited, resized]: e.connect(queue_redraw)
		button_down.connect(_burst)
	func _burst() -> void:
		if G.get_meta("ui_review_mode", false): return
		var at := get_local_mouse_position()
		if not Rect2(Vector2.ZERO, size).has_point(at): at = size * .5
		for i in 12:
			var a := randf() * TAU
			_sparks.append({"p": at, "v": Vector2(cos(a), sin(a) - .6) * randf_range(60, 150), "life": randf_range(.35, .6),
				"c": [Color("ffe2a0"), Color("ffb347"), Color("fff4d6")][i % 3]})
	func _process(d: float) -> void:
		_t += d
		for s in _sparks:
			s.p += s.v * d
			s.v.y += 260.0 * d
			s.life -= d
		_sparks = _sparks.filter(func(s): return s.life > 0)
		if shine or not _sparks.is_empty(): queue_redraw()
	func _draw() -> void:
		var sink := Kit.P if is_pressed() else 0.0
		var lift := -Kit.P if _hover and not is_pressed() and not disabled else 0.0
		var r := Rect2(Vector2(0, sink + lift), size)
		var skin: StyleBoxTexture = null
		if not kit.is_empty():
			var state := "disabled" if disabled else ("pressed" if is_pressed() else ("selected" if selected else "normal"))
			skin = UiKitLib.style(kit + "_" + state)
			if skin == null: skin = UiKitLib.style(kit + "_normal")
		if skin != null:
			draw_style_box(skin, UiKitLib.snap(r))
			if (_hover or has_focus()) and not disabled and not is_pressed():
				# 悬停：亮金框；仅键盘焦点：淡金框（默认焦点不再常亮一圈框）。
				var o := UiKitLib.snap(r).grow(2)
				var col := Color("ffe08a", .85) if _hover else Color("e8c06a", .32)
				for edge in [Rect2(o.position, Vector2(o.size.x, 2)), Rect2(o.position.x, o.end.y - 2, o.size.x, 2),
						Rect2(o.position, Vector2(2, o.size.y)), Rect2(o.end.x - 2, o.position.y, 2, o.size.y)]:
					draw_rect(edge, col)
		else:
			Kit.frame(self, r, mat, trim, size.x >= 140, _hover or has_focus(), is_pressed())
		if shine and not disabled: Kit.sweep(self, r, fmod(_t, 3.6) / 1.1)
		if ornate and skin == null:
			var cy := floorf((r.position.y + r.size.y * .5) / Kit.P) * Kit.P
			for cx in [r.position.x + Kit.P * 12, r.end.x - Kit.P * 13]:
				for row in [[-2, 1], [-1, 3], [0, 5], [1, 3], [2, 1]]:
					var half := float(row[1] - 1) * .5
					draw_rect(Rect2(cx - half * Kit.P, cy + row[0] * Kit.P, row[1] * Kit.P, Kit.P), Color("e8c06a"))
				draw_rect(Rect2(cx, cy - Kit.P, Kit.P, Kit.P), Color("fff1c8"))
		caption.position = Vector2(0, sink + lift - 1)
		caption.size = size
		caption.modulate = Color(.55, .55, .55) if disabled else Color.WHITE
		for s in _sparks:
			draw_rect(Rect2((s.p / Kit.P).floor() * Kit.P, Vector2.ONE * Kit.P), Color(s.c, clampf(s.life * 2.4, 0, 1)))
