# GameHome.gd —— 进入游戏占位页（选人完成后的落点）
extends Control


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = G.BG_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var role := G.get_role(G.selected_role)
	var name_txt: String = G.player_name
	if name_txt.is_empty():
		name_txt = String(role.get("name", "旅人"))

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	box.add_child(G.gold_label("远 征 世 界", 40, true, G.GOLD_BRIGHT))

	var who := "%s · %s（%s · %s）" % [name_txt, role.get("name", ""),
		G.gender, role.get("job", "")]
	box.add_child(G.gold_label(who, 20, false, G.NAME_GREEN))

	if not G.account.is_empty():
		box.add_child(G.gold_label("账号：%s" % G.account, 15, false, Color("b8a888")))

	var hint := G.gold_label("主线玩法随阶段 1~2 开发逐步开放\n（战斗竖切 → 远征循环）", 15, false, Color("b8a888"))
	hint.add_theme_constant_override("outline_size", 2)
	box.add_child(hint)

	var back := G.menu_button("重新创建角色")
	back.gui_input.connect(_on_back)
	box.add_child(back)


func _on_back(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		get_tree().change_scene_to_file("res://src/ui/CreateRole.tscn")
