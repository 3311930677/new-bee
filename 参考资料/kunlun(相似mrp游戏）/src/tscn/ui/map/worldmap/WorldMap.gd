extends Control


var ScreenUtils
var MapInfoManage

func _ready() -> void :
	print_stray_nodes()
	
	ScreenUtils = Global.get("ScreenUtils")
	MapInfoManage = Global.get("MapInfoManage")
	MapInfoManage.connect("map_change_success", self, "map_change_success")
	for item in $"Background/TextureRect/Control".get_children():
		item.connect("item_click", self, "_item_click")

func _on_Cancle_pressed() -> void :
	queue_free()

func load_data(data):
	pass


func _item_click(item_click) -> void :
	if item_click.city_id == - 1: return
	var map_citys = MapInfoManage.get_city_maps(item_click.city_id)
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/worldmap/SelectSmallWorlMap.tscn", "load_data", map_citys)

func map_change_success(map_id):
	queue_free()
	pass
