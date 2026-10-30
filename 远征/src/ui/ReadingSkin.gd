extends RefCounted
## Material and spacing shared by readable detail dialogs, with distinct families.
const KitV4 := preload("res://src/ui/KitV4.gd")
const BRASS := Color("d9b86c")
const INK := Color("3b2a1a")
const PAPER := Color("eadbc0")
const TEXT := Color("f5edd8")

static func label(words: String, px := 20, ink := INK) -> Label:
	var text := Label.new()
	text.text = words
	text.add_theme_font_override("font", G.font_serif if px >= 24 else G.font_reg)
	text.add_theme_font_size_override("font_size", px)
	text.add_theme_color_override("font_color", ink)
	text.add_theme_constant_override("outline_size", 0)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return text

static func frame(paper := false, _family := "journal") -> PanelContainer:
	var root := PanelContainer.new()
	var box := KitV4.style("paper_card" if paper else "card_bg", 14)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		box.set_content_margin(side, 22)
	root.add_theme_stylebox_override("panel", box)
	return root

static func button(words: String, primary := false) -> Button:
	var btn := Button.new()
	btn.text = words
	btn.custom_minimum_size = Vector2(56,60)
	btn.add_theme_font_override("font",G.font_serif)
	btn.add_theme_font_size_override("font_size",G.FS_SECTION)
	var base := "btn_primary" if primary else "btn_secondary"
	btn.add_theme_stylebox_override("normal", KitV4.style(base + "_normal", 14))
	btn.add_theme_stylebox_override("hover", KitV4.style(base + "_normal", 14))
	btn.add_theme_stylebox_override("pressed", KitV4.style(base + "_pressed", 14))
	btn.add_theme_stylebox_override("disabled", KitV4.style("btn_disabled", 14))
	btn.add_theme_stylebox_override("focus", KitV4.style(base + "_normal", 14))
	btn.add_theme_color_override("font_color",TEXT)
	btn.add_theme_color_override("font_hover_color",Color.WHITE)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return btn
