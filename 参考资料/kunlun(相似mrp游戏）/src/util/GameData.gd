extends Node

const prefix = "GameData->"


var colors = {
	"red": Color(1, 0, 0, 1), 
	"black": Color(0, 0, 0, 1), 
	"green": Color(0, 1, 0, 1), 
	"blue": Color(0, 0, 1, 1), 
	"purple": Color(1, 0, 1, 1), 
	"grey": Color(0.5, 0.5, 0.5, 1), 
	"orange": Color(1, 165 / 255, 0, 1), 
	"grass_green": Color(42 / 255, 171 / 255, 42 / 255, 1), 
	"green_yellow": Color(173 / 255, 255 / 255, 47 / 255, 1), 
}

var game_data_path = "res://assets/map/game_data.bin"

var test_path = "user://test.json"
var test_bin_path = "user://test.bin"

var game_data_key = "Qq913413756aa"

var game_all_data

var FileHelper


func _init() -> void :
	FileHelper = Global.get("FileHelper")
	read_data()


	pass


func read_data():
	game_all_data = FileHelper.read_encrypted(game_data_path, game_data_key)

func get_map_all_npcs(map_id):
	var npcs = []
	for npc in game_all_data["xq_npc"]:
		if int(npc["map_desc"]) == int(map_id):
			npcs.append(npc)
	return npcs

func get_npc_by_npcid(npc_id):
	for npc in game_all_data["xq_npc"]:
		if int(npc["npc_id"]) == npc_id:
			return npc


func get_all_map_data():
	if game_all_data == null or not game_all_data["basic"].has("maps"):
		Global.log_info(str(prefix, "地图数据不存在"))
		Global.get("ScreenUtils").show_message("地图数据不存在")
		return []
	else: return game_all_data["basic"]["maps"]


func search_map_with_desc(map_no):
	var map_data_arr = get_all_map_data()
	for map_item in map_data_arr:
		if int(map_item.get("_desc", "-1")) == int(map_no):
			return map_item
	Global.log_info(str(prefix, "地图未找到"))
	return {}

func search_map_with_id(map_id):
	var map_data_arr = get_all_map_data()
	if map_id <= map_data_arr.size():
		return map_data_arr[int(map_id) - 1]
	else:
		Global.log_info(str(prefix, "不存在这个地图信息"))
		return {}


func convert_data():
	var data = FileHelper.read(game_data_path)
	FileHelper.save_encrypted("res://assets/map/game_data.bin", data, game_data_key)
	pass
