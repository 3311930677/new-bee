extends RefCounted
## Text uses smooth glyph sampling; pixel art keeps its own nearest-neighbor filter.

static func apply_to(node: Node) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion(): return
	if not (node is Label or node is Button or node is LineEdit or node is RichTextLabel or node is TextEdit): return
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if node is RichTextLabel: return
	var px: int = node.get_theme_font_size("font_size")
	var font: Font = node.get_theme_font("font")
	# Thin display faces and brush strokes need room; compact controls retain full strokes.
	if px < 24 and (font == G.font_display or font == G.font_art):
		node.add_theme_font_override("font", G.font_bold if font == G.font_display else G.font_reg)
	if px < 24 and node.get_theme_constant("outline_size") > 1:
		node.add_theme_constant_override("outline_size", 1)

static func theme_for_text() -> Theme:
	var theme := Theme.new()
	theme.default_font = G.font_reg
	theme.default_font_size = G.FS_SM
	for kind in ["Label", "Button", "LineEdit", "RichTextLabel", "TextEdit"]:
		theme.set_constant("outline_size", kind, 0)
	return theme
