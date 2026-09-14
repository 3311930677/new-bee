extends Panel

onready var container = $"Background/Background2/ScrollContainer/VBoxContainer"
onready var popup_menu = $Control / PopupMenu
onready var pet_item_res = preload("res://src/tscn/ui/map/pet/PetLabelItem.tscn")
onready var count_label = $Label

var menu = {
	"1": "出战", 
	"2": "查看", 
	"3": "改名", 
	"4": "抛弃", 
}
var z_menu = {
	"5": "休息", 
	"3": "改名", 
}

var check_node = null
var name_filters = ["$", "@", "#", ";", ":", "&", "%"]
var ScreenUtils
var PetInfoManage
var RoleInfoManage

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	PetInfoManage = Global.get("PetInfoManage")
	RoleInfoManage = Global.get("RoleInfoManage")
	
	PetInfoManage.connect("loaded_all_list_pets", self, "_on_loaded_all_list_pets")
	PetInfoManage.connect("reset_pet", self, "_on_reset_pet")
	PetInfoManage.connect("fight_pet", self, "_on_fight_pet")
	PetInfoManage.connect("pet_change_name_success", self, "_on_change_name_pet")
	
	
	pass

func _on_Ok_pressed() -> void :
	if check_node == null: return
	
	
	if RoleInfoManage.get_pet_fight_id() == check_node.data["id"]:
		Global.get("ScreenUtils").build_menu(popup_menu, z_menu)
	else:
		
		Global.get("ScreenUtils").build_menu(popup_menu, menu)
	
	popup_menu.popup_centered()


func _on_reset_pet():
	
	_on_loaded_all_list_pets()
	pass


func _on_fight_pet():
	
	_on_loaded_all_list_pets()
	pass

func _item_click(node):
	if node == check_node:
		_on_Ok_pressed()
		return
	check_node = node


func _on_loaded_all_list_pets():
	clear_container()
	count_label.text = str("携带数量：%d / 10" % PetInfoManage.list_all_pets.size())
	for i in PetInfoManage.list_all_pets:
		var item = pet_item_res.instance()
		container.add_child(item)
		item.connect("item_click", self, "_item_click")
		item.set_data(i)
		pass
	

func _on_PopupMenu_index_pressed(index: int) -> void :
	var id = popup_menu.get_item_id(index)
	match id:
		1:
			
			PetInfoManage.set_fight_pet(check_node.data["id"])
			pass
		2:
			ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/pet/PetUi.tscn", "load_data", {"pet_type": 1, "id": check_node.data["id"]})
			pass
		3:
			change_pet_name()
			pass
		4:
			ScreenUtils.show_message(str("确定抛弃%s宠物？操作不可回退" % check_node.get_pet_name()), self, "ok_discard")
			pass
		5:
			PetInfoManage.reset_fight()
			pass

func clear_container():
	for i in container.get_children():
		i.queue_free()
	pass


func ok_discard():
	PetInfoManage.discard_pet(check_node.data["id"])
	check_node.queue_free()
	check_node = null
	_on_loaded_all_list_pets()
	

func change_pet_name():
	ScreenUtils.show_popup_menu_edit(self, "request_change_pet_name", 0, "请输入新名称")
	pass


func request_change_pet_name(id, txt):
	for filt in name_filters:
		if txt.find(filt) != - 1:
			ScreenUtils.show_message("存在违规字符，请重试")
			return
	if txt.length() < 1 or txt.length() > 6:
		ScreenUtils.show_message("名称长度为1-6位")
		return
	PetInfoManage.change_pet_name(check_node.data.id, txt)
	pass


func _on_change_name_pet(data):
	check_node.set_data(data)
	pass
