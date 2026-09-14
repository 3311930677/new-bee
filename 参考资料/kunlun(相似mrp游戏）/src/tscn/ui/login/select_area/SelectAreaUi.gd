extends Control

const prefix = "SelectAreaUi->"
onready var default_server_container = $Background / DefaultBg / DefaultServer
onready var servers_container = $Background / ServersBg / ScrollContainer / Servers
var area_item_res = preload("res://src/tscn/ui/login/select_area/AreaItem.tscn")
var ScreenUtils
var NetContext
var checked_node

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	NetContext = Global.get("NetContext")
	NetContext.set_handler("AreaRemote", "getAreaAndRoleCount", self, "_on_areas_result")
	hide()
	NetContext.request_service("AreaRemote", "getAreaAndRoleCount", {}, true)
	

func _area_item_click(node):
	if checked_node == node:
		_on_Ok_pressed()
		return
	checked_node = node

func _on_Ok_pressed() -> void :
	Global.get("RoleInfoManage").cur_area_id = checked_node.data["id"]
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/login/select_role/SelectRoleUi.tscn", "load_data", {"area_id": checked_node.data["id"]})
	queue_free()


func _on_Cance_pressed() -> void :
	queue_free()

func _on_areas_result(data):
	show()
	clear_container()
	data = data["data"]
	Global.log_info(str(prefix, data))
	var ind = 0
	for area_item in data["areas"]:
		var item = area_item_res.instance()
		
		if ind >= data["areas"].size() - 1:
			item.rect_min_size = Vector2(250, 31)
			item.anchor_bottom = 0.5
			item.anchor_top = 0.5
			item.anchor_left = 0.5
			item.anchor_right = 0.5
			item.margin_bottom = 15
			item.margin_top = - 15
			item.margin_right = 125
			item.margin_left = - 125
			default_server_container.add_child(item)
		else:
			item.rect_min_size = Vector2(240, 33)
			servers_container.add_child(item)
		item.set_data(area_item)
		item.connect("item_click", self, "_area_item_click")
		
		for count in data.get("role_count", []):
			if count["area_id"] == area_item["id"]:
				item.show_head_count(count["role_count"])
		ind += 1

func clear_container():
	for i in servers_container.get_children():
		i.queue_free()
	for i in default_server_container.get_children():
		i.queue_free()
