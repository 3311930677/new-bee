extends Control

onready var title = $"Head/XQTitle"
onready var box = $Background / Background2 / ScrollContainer / VBoxContainer
onready var menu = $Control / PopupMenu
var item_res = preload("res://src/tscn/ui/common/ring/RingItem.tscn")


var PlayerOperate
var ScreenUtils
var RingDataManage

var check_node = null

var dic_menu = {
	"1": "查看信息", 
	"2": "查看宠物", 
}

func _ready():
	RingDataManage = Global.get("RingDataManage")
	PlayerOperate = Global.get("PlayerOperate")
	ScreenUtils = Global.get("ScreenUtils")
	
	RingDataManage.connect("key_data_loaded", self, "_on_key_data_loaded")
	pass

func load_data(data):
	var key = data.get("key")
	var type = int(data.get("type", - 1))
	RingDataManage.load_key_data(key)
	if type == 1:
		title.set_title("本届擂台风云榜")
	elif type == 0:
		title.set_title("上届擂台风云榜")
	hide()
	

func clear_container():
	for i in box.get_children():
		i.queue_free()
	pass
func _on_Ok_pressed():
	if check_node == null:
		return
	ScreenUtils.build_menu(menu, dic_menu)


func _on_Cancle_pressed():
	queue_free()

func _on_key_data_loaded(data):
	clear_container()
	var index = 1

	data.sort_custom(self, "sort_custom")
	
	for i in data:
		var item = item_res.instance()
		box.add_child(item)
		i["index"] = index
		item.set_data(i)
		item.connect("item_click", self, "_on_item_click")
		index += 1
		pass
	show()
	pass

func sort_custom(a, b):
	if b["value"] - a["value"] > 0:
		return false
	return true

func _on_item_click(node):
	if node == check_node:
		_on_Ok_pressed()
		return
	check_node = node
	pass

func _on_PopupMenu_index_pressed(index):
	var id = menu.get_item_id(index)
	PlayerOperate.current_player_info = check_node.data
	PlayerOperate.menu_item_click(id)
