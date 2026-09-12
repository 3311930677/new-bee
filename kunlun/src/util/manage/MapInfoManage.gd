extends Node
class_name MapInfoManage

const prefix = "MapInfoManage"

signal map_change_success


var ScreenUtils
var NetContext
var StaticGameData


var map_data = {}
var npc_data = {}
var portal_data = {}

var current_map = 1001



var probability = 0
var yuguaiing = false

var rename_map_name = null


var p_target_point: Vector2 = Vector2.ZERO

var direction = 0


var reduce_num_monster_arr = []


var c_player_entity = null

func _init() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	NetContext = Global.get("NetContext")
	StaticGameData = Global.get("StaticGameData")
	
	StaticGameData.connect("_loaded_complete", self, "convert_data")
	
	NetContext.set_handler("PositionRemote", "changeMap", self, "_on_change_map_success")
	NetContext.set_handler("FightRemote", "encounterMonster", self, "_on_encounter_moster")
	NetContext.set_handler("FightRemote", "encounterMonsterPlaying", self, "_on_encounter_moster_playing")

var temp_change_map = 1001

func change_map(map_desc, is_command = false, map_name = null):
	rename_map_name = map_name
	temp_change_map = int(map_desc)
	to_npc = null
	NetContext.request_gate("PositionRemote", "changeMap", {
		"map_id": temp_change_map, 
		"is_command": is_command
	}, true)
	direction = 0
	p_target_point = Vector2.ZERO
	reduce_num_monster_arr.clear()



var to_npc = null


func change_map_to_npc(to_npc_ = null):
	if to_npc_ == null:
		Global.log_info(str("目标npc为空无法传送"))
		return
	var map_desc = to_npc_["map_desc"]
	
	if int(map_desc) == int(current_map):
		ScreenUtils.show_message("你已在当前地图！！")
		return
	
	if int(map_desc) >= 900000:
		ScreenUtils.show_message("目标地图无法传送")
		return
	rename_map_name = null
	temp_change_map = int(map_desc)
	to_npc = to_npc_
	NetContext.request_gate("PositionRemote", "changeMap", {
		"map_id": temp_change_map, 
		"is_command": false
	}, true)
	direction = 0
	p_target_point = Vector2.ZERO




func get_city_maps(city_id):
	var temp_map = {}
	for item in map_data.keys():
		if map_data[item]["city_id"] == city_id:
			temp_map[item] = map_data[item].duplicate()
	return temp_map


func get_current_map_info():
	return get_map_info(current_map)
func get_current_map_city():
	return get_current_map_info()["city_id"]

func get_map_info(map_id):
	if map_data.has(str(map_id)):
		return map_data[str(map_id)]
	else:
		return {}

func get_map_npc(map_id):
	if npc_data.has(str(map_id)):
		return npc_data[str(map_id)]
	else:
		return []

func get_map_portal(map_id):
	if portal_data.has(str(map_id)):
		return portal_data[str(map_id)]
	else:
		return []
func get_reduce_num_monster_arr():
	return reduce_num_monster_arr

func init_map_state():
	if map_data[str(current_map)]["map_type"] == 2:
		probability = 1
	else:
		probability = 0
	pass

func convert_data():
	map_data.clear()
	npc_data.clear()
	portal_data.clear()
	
	
	for map in StaticGameData.all_static_data["maps"]:
		map_data[str(map["map_id"])] = map
	
	for npc in StaticGameData.all_static_data["npcs"]:
		if npc_data.has(str(npc["map_desc"])): npc_data[npc["map_desc"]].append(npc)
		else: npc_data[str(npc["map_desc"])] = [npc]
	
	for portal in StaticGameData.all_static_data["portals"]:
		if portal_data.has(str(portal["current_map_desc"])):
			portal_data[str(portal["current_map_desc"])].append(portal)
		else:
			portal_data[str(portal["current_map_desc"])] = [portal]



func yuguai():
	
	








		
	if probability == 1 and not Global.get("TBBattleManage").current_fighting:
		Global.get("TBBattleManage").request_monster_fight()




func yuguai_playing():




	if not Global.get("TBBattleManage").current_fighting:
		Global.get("TBBattleManage").request_monster_npc_fight()
	pass


func _on_change_map_success(data):

	current_map = temp_change_map
	Global.get("RoleInfoManage").set_role_current_map(current_map)
	emit_signal("map_change_success", str(current_map))
	if map_data[str(current_map)]["map_type"] == 2:
		probability = 1
	else:
		probability = 0
	
	
	if to_npc != null:
		var arr_nodes = Global.get_nodes_in_group("player")
		if arr_nodes != null and arr_nodes.size() > 0:
			var player = arr_nodes[0]
			player.set_target_points(Vector2(to_npc.get("x", 100), to_npc.get("y", 100)))
		pass
	
	var arr_nodes = Global.get_nodes_in_group("player")
	var player = null
	if arr_nodes != null and arr_nodes.size() > 0:
		player = arr_nodes[0]
	else:
		player = c_player_entity
	
	
	if player != null:
		var ar_b = Global.get_nodes_in_group("main_bottom")
		if ar_b.size() > 0:
			player.camera.limit_bottom = Global.get("MapeUtils").parse_current_map.get("x_num", 22) * 16 + ar_b[0].rect_size.y / 1.4;
		else:
			player.camera.limit_bottom = Global.get("MapeUtils").parse_current_map.get("x_num", 22) * 16 + 90
			
	if player != null and p_target_point != Vector2.ZERO:
		player.set_position(p_target_point)
		
	Global.get("AroundRoleManage").reset_all_role_show_info()

func _on_encounter_moster(data):
	probability = 1;
	yuguaiing = false

func _on_encounter_moster_playing(data):
	yuguaiing = false
