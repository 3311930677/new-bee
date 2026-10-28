extends RefCounted
## Material and spacing shared by readable detail dialogs, with distinct families.
const BRASS := Color("bda073")
const INK := Color("382d24")
const PAPER := Color("f1e6d0")
const TEXT := Color("efe3c9")

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

static func frame(paper := false, family := "journal") -> PanelContainer:
	var root := PanelContainer.new()
	var box := StyleBoxTexture.new()
	box.texture = load("res://assets/ui/kit_20261013/card_frame_parchment.png" if paper else "res://assets/ui/kit_20261013/panel_iron.png")
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		box.set_texture_margin(side, 18)
		box.set_content_margin(side, 22)
	box.modulate_color = Color("f8eed6") if paper else Color("c1d8cd") if family == "market" else Color("d6d5e0") if family == "quiet" else Color.WHITE
	root.add_theme_stylebox_override("panel", box)
	return root

static func button(words: String, primary := false) -> Button:
	var button := Button.new()
	button.text = words
	button.custom_minimum_size = Vector2(56,60)
	button.add_theme_font_override("font",G.font_serif)
	button.add_theme_font_size_override("font_size",G.FS_SECTION)
	for pair in [["normal",Color.WHITE],["hover",Color(1.12,1.1,1.04)],["pressed",Color(.8,.84,.8)],["disabled",Color(.5,.5,.5)],["focus",Color("f8d58b")]]:
		var box := StyleBoxTexture.new()
		box.texture = load("res://assets/ui/introduction_20261015/button_red.png" if primary else "res://assets/ui/introduction_20261015/button_dark.png")
		box.modulate_color = pair[1]
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: box.set_texture_margin(side,16)
		box.set_content_margin(SIDE_LEFT,12)
		box.set_content_margin(SIDE_RIGHT,12)
		button.add_theme_stylebox_override(pair[0],box)
	button.add_theme_color_override("font_color",TEXT)
	button.add_theme_color_override("font_hover_color",Color.WHITE)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button
