extends Control

onready var title = $Head / XQTitle
onready var box = $Background / Background2 / ScrollContainer / VBoxContainer
onready var menu = $Control / PopupMenu

var player_item_res = preload("res://src/tscn/ui/common/player/PlayerLabelItem.tscn")


var good_and_evil = 1


var page = 0

var page_count = 10

var ScreenUtils
var GoodAndEvilManage

var source_data
var check_node = null

var evil_dic = {
	"1": "查看信息", 
	"2": "查看宠物", 
	"3": "接取通缉"
}
var good_dic = {
	"1": "查看信息", 
	"2": "查看宠物", 
}


func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	GoodAndEvilManage = Global.get("GoodAndEvilManage")
	GoodAndEvilManage.connect("_on_evil_loaded", self, "_on_item_loaded")
	GoodAndEvilManage.connect("_on_good_loaded", self, "_on_item_loaded")
	pass


func load_data(data):
	source_data = data
	clear_container()
	GoodAndEvilManage.request_good_evil(source_data["type"], page, page_count)
	if source_data["type"] == 1:
		title.set_title("善人榜")
	else:
		title.set_title("恶人榜")



func add_item(item_data):
	var p = player_item_res.instance()
	p.connect("item_click", self, "_item_click")
	box.add_child(p)
	p.set_data(item_data)
	pass


func clear_container():
	for e in box.get_children():
		e.queue_free()

func ok_accept_task():
	if check_node.data["popularity"] > 0: return
	GoodAndEvilManage.accept_arrest_task(check_node.data["id"])
	pass
	
func _item_click(node):
	if node == check_node:
		_on_Ok_pressed()
		return
	check_node = node


func _on_item_loaded(data):
	for i in data:
		add_item(i)

func _on_Cancle_pressed() -> void :
	queue_free()


func _on_TextureButton_pressed() -> void :
	Global.log_info(str("下一页"))
	page = page + 1
	GoodAndEvilManage.request_good_evil(source_data["type"], page, page_count)


func _on_Ok_pressed() -> void :
	if check_node == null:
		return
	if source_data["type"] == 1:
		Global.get("ScreenUtils").build_menu(menu, good_dic)
	else:
		Global.get("ScreenUtils").build_menu(menu, evil_dic)
	menu.popup_centered()


func _on_PopupMenu_index_pressed(index: int) -> void :
	var id = menu.get_item_id(index)
	if id == 3:
		ScreenUtils.show_message(str("你是否接取抓捕", check_node.data["role_name"], "任务？"), self, "ok_accept_task")
		pass
	else:
		Global.get("PlayerOperate").current_player_info = check_node.data
		Global.get("PlayerOperate").role_id = check_node.data["id"]
		Global.get("PlayerOperate").team_name = null
		Global.get("PlayerOperate").menu_item_click(id)
	pass

