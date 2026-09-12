extends Control


onready var container = $"Tabs/Panels/BG/Background/Background2/ScrollContainer/VBoxContainer"
onready var popup_menu = $Control / PopupMenu
onready var pet_item_res = preload("res://src/tscn/ui/map/pet/PetLabelItem.tscn")


var PetInfoManage
var ScreenUtils


var open_mode_ = - 1
var check_node = null

func _ready() -> void :
	PetInfoManage = Global.get("PetInfoManage")
	ScreenUtils = Global.get("ScreenUtils")
	PetInfoManage.connect("loaded_all_list_pets", self, "_on_all_pet_loaded")
	PetInfoManage.connect("pet_trader_reset_success", self, "_on_Cancle_pressed")
	PetInfoManage.connect("pet_trader_wash_point_success", self, "_on_Cancle_pressed")
	


func _on_all_pet_loaded():
	clear_container()
	load_pet_list()
	
	show()
	pass

func _item_click(node):
	if node == check_node:
		_on_Ok_pressed()
		return
	
	check_node = node
	pass


func _on_Cancle_pressed() -> void :
	queue_free()


func _on_Ok_pressed() -> void :
	if check_node == null: return
	if PetInfoManage.get_fight_pet_id() != - 1 and check_node.data.id == PetInfoManage.get_fight_pet_id():
		ScreenUtils.show_message("不能对出战的宠物进行操作")
		return
	match int(open_mode_):
		0:
			reset_pet()
			pass
		1:
			wash_point()
			pass
		2:
			release_pet()
			pass
		3:
			refining_pet()
			pass

func open_mode(mode):
	open_mode_ = mode["mode"]
	PetInfoManage.request_data(true, false)
	hide()
	pass

func clear_container():
	for i in container.get_children():
		i.queue_free()

func load_pet_list():
	for i in PetInfoManage.list_all_pets:
		var item = pet_item_res.instance()
		container.add_child(item)
		item.connect("item_click", self, "_item_click")
		item.set_data(i)
		pass
	pass


func reset_pet():
	ScreenUtils.show_message("确定对宠物进行重置？操作不可逆", self, "reset_pet_ok")
	pass
func reset_pet_ok():
	PetInfoManage.trader_pet_reset(check_node.data.id)
	pass

func wash_point():
	ScreenUtils.show_message("确定对宠物进行洗点操作？操作不可逆", self, "wash_point_ok")
	pass
func wash_point_ok():
	PetInfoManage.trader_pet_wash_point(check_node.data.id)
	pass

func release_pet():
	if check_node.data.get("level", 1) < 40:
		ScreenUtils.show_message("宠物等级低于40级无法放生")
		return
	ScreenUtils.show_message("放生该宠物你会获得部分银两补偿，确定放生？", self, "release_pet_ok")
	pass
func release_pet_ok():
	PetInfoManage.trader_pet_release(check_node.data.id)

func refining_pet():
	if check_node.data.get("level", 1) < 40:
		ScreenUtils.show_message("宠物等级低于40级无法炼化")
		return
	ScreenUtils.show_message("宠物炼化后你会获得部分经验丹，并且宠物会消失，是否继续？", self, "refining_pet_ok")
	pass
func refining_pet_ok():
	PetInfoManage.trade_pet_refining(check_node.data.id)
