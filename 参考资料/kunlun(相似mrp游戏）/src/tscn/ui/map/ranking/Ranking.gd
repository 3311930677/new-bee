extends Control

onready var menu = $Control / PopupMenu
onready var container = $"Background/Background2/ScrollContainer/VBoxContainer"
onready var title = $"Head/XQTitle"
var player_item_res = preload("res://src/tscn/ui/common/player/PlayerLabelItem.tscn")

var ScreenUtils
var PlayerOperate
var RankingInfoManage

var data
var check_node = null

var dic_menu = {
	"1": "查看信息", 
	"2": "查看宠物", 
	"4": "添加好友"
}

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	PlayerOperate = Global.get("PlayerOperate")
	RankingInfoManage = Global.get("RankingInfoManage")
	RankingInfoManage.connect("load_rank_data_success", self, "_on_load_rank_data_success")


func set_data(data):
	self.data = data
	
	if data.get("type", 0) == - 1:
		title.set_title("经验排行榜")
	RankingInfoManage.request_rank(data.get("type", 0))
	hide()
	pass


func add_item(item_data):
	var p = player_item_res.instance()
	p.connect("item_click", self, "_item_click")
	container.add_child(p)
	p.set_data(item_data)
	pass


func clear_container():
	for i in container.get_children():
		i.queue_free()


func _on_load_rank_data_success(data):
	clear_container()
	for i in data:
		add_item(i)
	show()

func _item_click(node):
	if node == check_node:
		_on_Ok_pressed()
		return
	check_node = node
	pass

func _on_Cancle_pressed() -> void :
	queue_free()


func _on_PopupMenu_index_pressed(index: int) -> void :
	var id = menu.get_item_id(index)
	PlayerOperate.current_player_info = check_node.data
	PlayerOperate.role_id = check_node.data["id"]
	PlayerOperate.menu_item_click(id)


func _on_Ok_pressed() -> void :
	if check_node == null: return
	ScreenUtils.build_menu(menu, dic_menu)
	menu.popup_centered()
