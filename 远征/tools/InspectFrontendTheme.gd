extends Node

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_frontend_theme_review.json"
	G._init_state_defaults()
	G.set_meta("ui_review_mode",true)
	G.selected_role = "zs"
	G.prog.level = 12
	G.ensure_starter_equip(true)
	var home := preload("res://src/ui/GameHome.tscn").instantiate()
	add_child(home)
	for i in 5: await get_tree().process_frame
	var report := {"home":_inspect(home)}
	home._open_bag()
	for i in 5: await get_tree().process_frame
	report.bag = _inspect(home._bag)
	var file := FileAccess.open("res://shots/ui_all_polish_20261005/runtime_nodes.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("FRONTEND_THEME_INSPECT_OK")
	get_tree().quit()

func _inspect(node: Node) -> Dictionary:
	var rows: Array = []
	_walk(node,node,rows)
	return {"nodes":rows,"controls":rows.size(),"containers":rows.filter(func(r):return r.container).size(),"themes":rows.filter(func(r):return r.theme_attached).size()}

func _walk(node: Node, root: Node, rows: Array) -> void:
	if node is Control and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		rows.append({"path":str(root.get_path_to(node)),"class":node.get_class(),
			"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],
			"anchors":[node.anchor_left,node.anchor_top,node.anchor_right,node.anchor_bottom],
			"container":node is Container,"theme_attached":node.theme!=null,"variation":node.theme_type_variation,
			"focus":node.focus_mode,"text":node.text if node is Label or node is Button else ""})
	for child in node.get_children(): _walk(child,root,rows)
