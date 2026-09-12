extends Control

var ScreenUtils
var RoleInfoManage

var inspect_id = - 1


func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	RoleInfoManage = Global.get("RoleInfoManage")
	
	RoleInfoManage.connect("role_info_result", self, "_on_role_info_result")

func load_data(data):
	$Tabs / HBoxContainer / AttrTab.checked()
	
	hide()
	if data.get("role_type", 0) == 0:
		
		inspect_id = - 1

		RoleInfoManage.inspect_self_data()
		pass
	else:
		
		inspect_id = data["role_type"]
		RoleInfoManage.request_role_data(data["role_type"], true)
		
		reset_tab()
		pass
	
	pass
	
func reset_tab():
	$Tabs / HBoxContainer / StateTab.queue_free()
	
	var w = 350 / 5
	var inde = 0
	for item in $"Tabs/HBoxContainer".get_children():
		item.rect_size.x = w
		item.rect_position.x = inde * w


func hide_all_tabs():
	for item in $"Tabs/Panels".get_children():
		item.visible = false


func _on_Cancle_pressed() -> void :
	queue_free()


func _on_AttrTab_tab_click(node) -> void :
	hide_all_tabs()
	$Tabs / Panels / RoleAttr.visible = true


func _on_InfoTab_tab_click(node) -> void :
	hide_all_tabs()
	$"Tabs/Panels/RoleInfo".visible = true


func _on_AttributeTab_tab_click(node) -> void :
	hide_all_tabs()
	$"Tabs/Panels/RoleEqui".visible = true


func _on_SkillTab_tab_click(node) -> void :
	hide_all_tabs()
	$"Tabs/Panels/RoleSkill".visible = true


func _on_LibraryTab_tab_click(node) -> void :
	hide_all_tabs()
	$"Tabs/Panels/RoleLib".visible = true


func _on_StateTab_tab_click(node) -> void :
	hide_all_tabs()
	$"Tabs/Panels/RoleState".visible = true


func _on_role_info_result(data):
	show()
	
	$"Head/XQTitle".set_title(data["role"]["role_name"])
	pass
