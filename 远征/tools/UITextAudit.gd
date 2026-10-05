extends RefCounted

static func write(root: Node, output: String) -> void:
	var report := {"text_nodes":[],"nonlinear_text":[],"compact_art":[],"short_text_boxes":[]}
	_walk(root,report)
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))

static func _walk(node: Node, report: Dictionary) -> void:
	if node is Control and node.is_visible_in_tree() and (node is Label or node is Button or node is LineEdit or node is RichTextLabel):
		var filter: int = node.texture_filter
		var canvas: Node = node.get_parent()
		while filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE and canvas != null:
			if canvas is CanvasItem: filter = canvas.texture_filter
			canvas = canvas.get_parent()
		var text: String = node.text
		var px: int = node.get_theme_font_size("font_size")
		var font: Font = node.get_theme_font("font") if not node is RichTextLabel else node.get_theme_font("normal_font")
		var row := {"path":str(node.get_path()),"text":text,"font":font.resource_path,
			"size":px,"filter":filter,"height":font.get_height(px),"rect_height":node.size.y}
		report.text_nodes.append(row)
		if filter != CanvasItem.TEXTURE_FILTER_LINEAR: report.nonlinear_text.append(row)
		if px < 24 and font in [G.font_art,G.font_display]: report.compact_art.append(row)
		if not text.is_empty() and font.get_height(px)>node.size.y+1: report.short_text_boxes.append(row)
	for child in node.get_children(): _walk(child,report)
