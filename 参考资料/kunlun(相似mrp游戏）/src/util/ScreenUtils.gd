extends Node
class_name ScreenUtils

const prefix = "ScreenUtils->"

func _init() -> void :
	pass

func _private_show_tips(tscn_path, msg, node, method):
	var dialog = Global.get_nodes_in_group("dialogs")[0]
	if dialog != null:
		var dg = load(tscn_path).instance()
		dg.set_message(msg)
		dg.set_event(node, method)
		dialog.add_child(dg)
	else: Global.log_info(str(prefix, "dialogs 容器不存在"))
	pass

func _preivate_show_message(tscn_path, msg: String, node: Node = null, method_ok_name: String = "", method_cancel_name: String = ""):
	var dialog = Global.get_nodes_in_group("dialogs")[0]
	if dialog != null:
		var dg = load(tscn_path).instance()
		dg.set_message(msg)
		dg.set_event(node, method_ok_name, method_cancel_name)
		dialog.add_child(dg)
		dg.popup_centered()
	else: Global.log_info(str(prefix, "dialogs 容器不存在"))
	pass
	

func clear_scence():
	var scences = Global.get_nodes_in_group("current_scence_container")[0]
	if scences != null:
		for item_scence in scences.get_children():
			item_scence.queue_free()
	else: Global.log_info(str(prefix, "没找到场景容器"))


func clear_ui():
	var ui = Global.get_nodes_in_group("UI")[0]
	if ui != null:
		for item_ui in ui.get_children():
			item_ui.queue_free()
	else: Global.log_info(str(prefix, "没找到UI组件"))
	
func change_scence(path: String, arg_func: String = "", dic_args = {}, is_add_pre_call: bool = false):
	var new_scence = load(path).instance()
	var scences_container = Global.get_nodes_in_group("current_scence_container")[0]
	if scences_container != null:
		if is_add_pre_call and arg_func != "": new_scence.call(arg_func, dic_args)
		scences_container.add_child(new_scence)
		if not is_add_pre_call and arg_func != "": new_scence.call(arg_func, dic_args)
	else: Global.log_info(str(prefix, "没找到场景容器"))


func change_ui(path: String):
	var new_ui = load(path).instance()
	var ui = Global.get_nodes_in_group("UI")[0]
	if ui != null: ui.add_child(new_ui)
	else: Global.log_info(str(prefix, "没找到UI组件"))

func chage_ui_and_args(path: String, arg_func: String, dic_args: Dictionary, is_add_pre_call: bool = false):
	var new_ui = load(path).instance()
	var ui = Global.get_nodes_in_group("UI")[0]
	if ui != null:
		if is_add_pre_call: new_ui.call(arg_func, dic_args)
		ui.add_child(new_ui)
		if not is_add_pre_call: new_ui.call(arg_func, dic_args)
	else: Global.log_info(str(prefix, "没找到UI组件"))


func hide_please_wait():
	var wait = Global.get_nodes_in_group("please_wait")[0]
	if wait != null: wait.m_hide()
	else: Global.log_info(str(prefix, "wait 组件不存在"))



func show_please_wait(msg: String = "请稍后"):
	var wait = Global.get_nodes_in_group("please_wait")[0]
	if wait != null: wait.m_show(msg)
	else: Global.log_info(str(prefix, "wait 组件不存在"))


func show_message(msg: String, node: Node = null, method_ok_name: String = "", method_cancel_name: String = ""):
	_preivate_show_message("res://src/tscn/ui/common/dialog/Dialog.tscn", msg, node, method_ok_name, method_cancel_name)


func show_message_plus(msg: String, node: Node = null, method_ok_name: String = "", method_cancel_name: String = ""):
	_preivate_show_message("res://src/tscn/ui/common/dialog/DialogPlus.tscn", msg, node, method_ok_name, method_cancel_name)

func show_tips(msg: String, node: Node = null, hide_method = ""):
	_private_show_tips("res://src/tscn/ui/common/dialog/PopTips.tscn", msg, node, hide_method)
func show_tips_plus(msg: String, node: Node = null, hide_method = ""):
	_private_show_tips("res://src/tscn/ui/common/dialog/PopTipsPlus.tscn", msg, node, hide_method)


func show_top_tips(bbmsg: String):
	var colum = Global.get_nodes_in_group("topcolumn")
	if colum != null:
		colum[0].set_scorlltext(bbmsg)
	else:
		Global.log_info(str(prefix, "topcolum为空，无法在顶部显示提示信息"))

func show_popup_menu_edit(node: Node, result_func: String, id = 0, title: String = "请输入数量："):
	var popup_menu_edit = load("res://src/tscn/ui/common/dialog/PopupPanel.tscn")
	var popup_menu = popup_menu_edit.instance()
	popup_menu.connect("ok_press", node, result_func)
	
	var ui = Global.get_nodes_in_group("UI")[0]
	if ui != null: ui.add_child(popup_menu)
	else: Global.log_info(str(prefix, "没找到UI组件"))
	popup_menu.popup_centered()
	popup_menu.set_title(title)
	popup_menu.set_id(id)




func show_select_attach_ui(node: Node, result_func: String, show_bind: bool = false):
	var new_ui = load("res://src/tscn/ui/common/attach/SelectAttachUi.tscn")
	var u = new_ui.instance()
	u.show_bind = show_bind
	
	var ui = Global.get_nodes_in_group("UI")[0]
	if ui != null: ui.add_child(u)
	else: Global.log_info(str(prefix, "没找到UI组件"))
	
	u.load_data({})
	u.set_result_node(node)
	u.set_result_func(result_func)
	
	pass





func show_select_attach_article_ui(arg_meta: Dictionary):
	var new_ui = load("res://src/tscn/ui/common/attach/SelectAttachArtcleUi.tscn")
	var u = new_ui.instance()
	u.set_meta("data", arg_meta)
	var ui = Global.get_nodes_in_group("UI")[0]
	if ui != null: ui.add_child(u)
	else: Global.log_info(str(prefix, "没找到UI组件"))
	pass



func show_npc_dialog(data):
	var new_ui = load("res://src/tscn/ui/common/dialog/DialogNpc.tscn")
	var u = new_ui.instance()
	var ui = Global.get_nodes_in_group("UI")[0]
	if ui != null: ui.add_child(u)
	else: Global.log_info(str(prefix, "没找到UI组件"))
	u.set_npc_data(data)


func show_npc_task_dialog(data):
	var new_ui = load("res://src/tscn/ui/common/dialog/DialogNpc.tscn")
	var u = new_ui.instance()
	var ui = Global.get_nodes_in_group("UI")[0]
	if ui != null: ui.add_child(u)
	else: Global.log_info(str(prefix, "没找到UI组件"))
	u.set_task_data(data)


func show_dialog(data):
	var new_ui = load("res://src/tscn/ui/common/dialog/DialogNpc.tscn")
	var u = new_ui.instance()
	var ui = Global.get_nodes_in_group("UI")[0]
	if ui != null: ui.add_child(u)
	else: Global.log_info(str(prefix, "没找到UI组件"))
	u.set_data(data)

func show_combat_info():
	var new_ui = load("res://src/tscn/ui/battle/CombatInfo.tscn")
	var u = new_ui.instance()
	var ui = Global.get_nodes_in_group("UI")[0]
	if ui != null: ui.add_child(u)
	else: Global.log_info(str(prefix, "没找到UI组件"))


func build_menu(pupup_menu, dic_menu):
	
	pupup_menu.clear()
	
	pupup_menu.rect_size.y = 0
	pupup_menu.rect_size.x = 0
	
	var arr_key = dic_menu.keys()
	for k in arr_key:
		pupup_menu.add_item(dic_menu[str(k)], int(k))
	pass

func get_ui_container():
	return Global.get_nodes_in_group("UI")[0]

func get_map_container():
	if Global.get_nodes_in_group("map_scence").size() < 1: return null
	else:
		return Global.get_nodes_in_group("map_scence")[0]

























var map_scence = null
var scence_container: Node2D = null
func change_new_fight_scence():
	if Global.get_nodes_in_group("map_scence").size() <= 0:
		Global.log_info(str("可能触发了多场战斗"))
		return
	clear_ui()
	scence_container = Global.get_nodes_in_group("current_scence_container")[0]

	map_scence = Global.get_nodes_in_group("map_scence")[0]
	scence_container.remove_child(map_scence)
	
	change_scence("res://src/tscn/scence/battle/TbBattleScence.tscn")
	change_ui("res://src/tscn/scence/battle/ui/TBBttleUi.tscn")
	
	pass
func change_new_map_scnece():
	clear_ui()
	clear_scence()
	chage_ui_and_args("res://src/tscn/ui/map/MainControlUi.tscn", "load_data", {})
	scence_container.add_child(map_scence)
	pass




























var page_uis = []


func add_page_ui(ui_node):
	var ui = Global.get_nodes_in_group("UI")[0]
	if ui != null:
		ui.add_child(ui_node)
		page_uis.append(ui_node)
		

func del_last_page_ui():
	if (page_uis.size() > 0):
		page_uis[page_uis.size() - 1].queue_free()
		page_uis.remove(page_uis.size() - 1)
		

func quit_():
	Global.get_tree().quit()
	pass
