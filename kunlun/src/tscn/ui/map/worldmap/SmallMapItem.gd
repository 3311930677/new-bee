extends Control

signal item_click

var map_info
var city_res = preload("res://src/tscn/ui/map/worldmap/city.tres")
var field_res = preload("res://src/tscn/ui/map/worldmap/field.tres")
var village_res = preload("res://src/tscn/ui/map/worldmap/village.tres")

var MapInfoManage

func set_data(data):
	map_info = data
	var role_current_map = MapInfoManage.get_current_map_info()
	if role_current_map["map_id"] == data["map_id"]:
		$Men.visible = true
		checked()
	else:
		$Men.visible = false
	
	if data["level"] == 0:
		$Icon.texture = city_res
	else:
		$Icon.texture = field_res

func _on_TextureButton_pressed():
	var smi = Global.get_nodes_in_group("small_map_items")
	for i in smi:
		i.uncheck()
	
	checked()
	pass

func checked():
	$SelectOn.visible = true
	emit_signal("item_click", map_info)

func uncheck():
	$SelectOn.visible = false

func _ready():
	$AnimationPlayer.play("Idel")
	MapInfoManage = Global.get("MapInfoManage")

