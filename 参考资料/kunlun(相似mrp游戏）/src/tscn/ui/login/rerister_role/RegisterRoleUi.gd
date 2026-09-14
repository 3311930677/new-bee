extends Control

onready var heads = [
	$"Background/Background2/Background2/RegisterRoleHeadItem1", 
	$"Background/Background2/Background2/RegisterRoleHeadItem2", 
	$"Background/Background2/Background2/RegisterRoleHeadItem3", 
	$"Background/Background2/Background2/RegisterRoleHeadItem4", 
	$"Background/Background2/Background2/RegisterRoleHeadItem5", 
	$"Background/Background2/Background2/RegisterRoleHeadItem6"
]


onready var text_scroller = $Background / Background2 / Background3 / ScrollContainer
onready var text = $Background / Background2 / Background3 / ScrollContainer / VBoxContainer / Label
onready var role_name = $Background / Background2 / Control / RoleName

var scroll_index = 0
var ScreenUtils
var NetContext
var checked_role_head_item
var area_id = 1
func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	NetContext = Global.get("NetContext")
	NetContext.set_handler("RoleRemote", "createRole", self, "_on_create_role_success_result")

func _process(delta: float) -> void :
	text_scroller.set_v_scroll(scroll_index)
	scroll_index += 0.5
	if scroll_index >= text_scroller.get_v_scrollbar().max_value - text_scroller.rect_size.y + 5:
		scroll_index = 0


func _on_Cancle_pressed() -> void :
	ScreenUtils.change_ui("res://src/tscn/ui/login/select_area/SelectAreaUi.tscn")
	queue_free()


func _on_register_pressed() -> void :
	if role_name.text.length() < 2:
		ScreenUtils.show_message("角色昵称过短！！")
		return
	if checked_role_head_item == null:
		ScreenUtils.show_message("请选择一个种族")
		return
	ScreenUtils.show_message(str("确定使用:", role_name.text, "注册角色？"), self, "_creat_role_ok")

func _creat_role_ok():
	var na = role_name.text
	for i in Global.get("ChatInfoManage").filter_char:
		if na.find(i) != - 1:
			ScreenUtils.show_message("名称中含有特殊或违禁字符")
			return
	NetContext.request_service("RoleRemote", "createRole", {
		"area_id": area_id, 
		"race_id": checked_role_head_item.index, 
		"name": na
	}, true)
	pass

func _on_create_role_success_result(data):
	ScreenUtils.show_message("角色注册成功！！！", self, "_change_ui_select_role", "_change_ui_select_role")
	pass

func _change_ui_select_role():
	
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/login/select_role/SelectRoleUi.tscn", "load_data", {"area_id": area_id})
	
	queue_free()
	pass

func _on_RegisterRoleHeadItem1_item_click(item) -> void :
	checked_role_head_item = item
	var l = $Background / Background2 / Background3 / ScrollContainer / VBoxContainer / Label
	l.text = Global.get("StaticGameData").all_static_data["role_race"][int(item.index - 1)].info

func load_data(data):
	area_id = data["area_id"]
