extends Node2D
const prefix = "BattleScence"
enum ROLE_POSITION{
	LEFT, 
	RIGHT
}


onready var c_map_node = $Map
onready var c_room_type_txt = $Common / RoomType
onready var positions = $Position
onready var c_battle_nodes = $Battles
onready var battle_result = $Position2D / BattleResult
onready var end_time = $EndTimer

signal battle_round_start_

signal round_line_start_

signal round_line_end_

signal battle_round_end_

signal round_show_hourglass_

var victory = load("res://assets/battle/victory.png")
var failure = load("res://assets/battle/failure.png")
var entity_res = preload("res://src/tscn/scence/battle/entity/BattleEntity.tscn")

var role_position = ROLE_POSITION.RIGHT


var MapeUtils
var NetContext
var MapInfoManage
var ScreenUtils
var TBBattleManage
var RoleInfoManage
var PetInfoManage


var round_all_data = null
var round_index = 0

var round_end_max_count = 1
var round_end_c_count = 0


var battle_end_data = null


var current_line_run_down = true


func _ready() -> void :
	MapeUtils = Global.get("MapeUtils")
	NetContext = Global.get("NetContext")
	ScreenUtils = Global.get("ScreenUtils")
	MapInfoManage = Global.get("MapInfoManage")
	TBBattleManage = Global.get("TBBattleManage")
	RoleInfoManage = Global.get("RoleInfoManage")
	PetInfoManage = Global.get("PetInfoManage")
	
	TBBattleManage.connect("battle_round_data_success", self, "_on_battle_round_data")
	TBBattleManage.connect("battle_round_end", self, "battle_round_end")
	
	load_map()
	init_room_data()
	load_entity()
	current_line_run_down = true


func _on_battle_round_data(data):
	round_all_data = data
	round_index = 0
	var start_data = data["start"]
	var end_data = data["end"]
	var rounds = data["round"]
	
	
	if current_line_run_down:
		current_line_run_down = false
		emit_signal("battle_round_start_")
		round_start()
		round_line_start()
	


func round_start():
	var local_map = TBBattleManage.current_local_position_map
	for k in local_map.keys():
			
		if not is_instance_valid(local_map[k]): continue
		local_map[k].round_start(round_all_data["start"])

func round_end():
	var local_map = TBBattleManage.current_local_position_map
	for k in local_map.keys():
		if local_map[k] == null: continue
		local_map[k].round_end(round_all_data["end"])
	pass


func round_line_start():
	
	if round_index >= round_all_data["round"].size():
		current_line_run_down = true
		Global.log_info(str("回合数据执行完毕！"))
		round_end()
		restart_continue()
		return
	
	var line = round_all_data["round"][round_index]
	emit_signal("round_line_start_", line)
	
	pass

func round_line_end():
	var line = round_all_data["round"][round_index]
	emit_signal("round_line_end_", line)


func round_line_start_complate():
	round_end_max_count = round_all_data["round"][round_index]["harms"].keys().size()
	round_end_c_count = 0
	round_line_end()
	pass


func round_line_end_complate():
	round_end_c_count += 1
	
	if round_end_c_count >= round_end_max_count:
		round_index += 1
		round_line_start()
		
	pass




func battle_round_end(data):
	battle_end_data = data
	Global.log_info("收到战斗结束通知！！");
	if current_line_run_down:
		battle_end_line()
	pass


func restart_continue():
	if battle_end_data == null:
		emit_signal("round_show_hourglass_")
	else:
		
		battle_end_line()



func battle_end_line():
	var iswin = int(battle_end_data["battleState"]) == 1
	if iswin: battle_result.texture = victory
	else: battle_result.texture = failure
	$Position2D.show()
	end_time.start()


















func load_entity():
	
	if role_position == ROLE_POSITION.LEFT:
		var l_to_r = {
			"1": 7, 
			"2": 6, 
			"3": 9, 
			"4": 8, 
			"5": 11, 
			"6": 10
		}
		var r_to_l = {
			"7": 1, 
			"8": 0, 
			"9": 3, 
			"10": 2, 
			"11": 5, 
			"12": 4
		}
		var self_map = TBBattleManage.current_fight_room["left"]
		_load_entity(self_map, l_to_r)
		var oop_map = TBBattleManage.current_fight_room["right"]
		_load_entity(oop_map, r_to_l)
		pass
	else:
		var self_map = TBBattleManage.current_fight_room["right"]
		_load_entity(self_map, {})
		var oop_map = TBBattleManage.current_fight_room["left"]
		_load_entity(oop_map, {})







func _load_entity(entity_map, yinshe):
	
	var pos = positions.get_children()
	
	for k in entity_map.keys():
		var battle_data = entity_map[k]
		var index = yinshe.get(k, int(k) - 1)
		var p = pos[index]
		var entity = entity_res.instance()
		
		entity.local_index = index + 1
		entity.position = p.position
		if battle_data["type"] == "role":
			entity.set_player_data(battle_data)
			pass
		elif battle_data["type"] == "monster":
			entity.set_monster_data(battle_data)
			pass
		elif battle_data["type"] == "pet":
			entity.set_pet_data(battle_data)
			pass
		else:
			Global.log_info("未知实体类型")
		c_battle_nodes.add_child(entity)
	pass



func init_room_data():
	var a = ["", "", "切磋", "boss", "偷袭", ""]
	if TBBattleManage.current_fight_room.get("roomType", 0) < a.size():
		c_room_type_txt.text = a[TBBattleManage.current_fight_room.get("roomType", 0)]
	else:
		if TBBattleManage.current_fight_room.get("roomType", 0) == 21:
			c_room_type_txt.text = "擂台"
		else:
			c_room_type_txt.text = ""
	
	var left_map = TBBattleManage.current_fight_room["left"]
	
	var role_entity = _role_exists(left_map)
	
	if role_entity == null:
	
		role_position = ROLE_POSITION.RIGHT
	
	else:
	
		role_position = ROLE_POSITION.LEFT
	
	pass


func _role_exists(lr_map: Dictionary):
	for item in lr_map.keys():
		var info = lr_map[item]
		if info["type"] == "role":
			if int(info["id"]) == RoleInfoManage.get_role_id():
				
					return item
	return null




func load_map():
	var map_info = MapeUtils.loadMape("res://assets/map/xq/mapres", str(MapInfoManage.current_map, ".mape"))
	if map_info == null:
		ScreenUtils.show_message(str(prefix, "地图读取失败：", MapInfoManage.current_map))
		return
	var tilemap = TileMap.new()
	tilemap.cell_size = Vector2(map_info["cell_h"], map_info["cell_w"])
	tilemap.tile_set = map_info["tileset"]
	var x = 0
	var y = 0
	for i in map_info["map_data_list"]:
		for j in i:
			var map_data = j
			if abs(map_data) > map_info["max_tile_id"]: map_data = 0
			tilemap.set_cell(x, y, abs(map_data))
			x = x + 1
		y = y + 1
		x = 0
	for i in map_info["builds"]:
		i.queue_free()
	tilemap.scale = Vector2(1.4, 1.8)
	c_map_node.call_deferred("add_child", tilemap)




func _on_EndTimer_timeout() -> void :
	
	var local_index = TBBattleManage.current_local_position_map
	for k in local_index.keys():
		var entity = local_index[k]
		if is_instance_valid(entity):
			entity.process_line.queue_free()
	var arr = Global.get_nodes_in_group("tb_battle_ui")
	if arr.size() > 0:
		arr[0].selector.queue_free()
	ScreenUtils.change_new_map_scnece()
	
	Global.get("TaskInfoManage").request_refresh_task()
	TBBattleManage.current_fighting = false
