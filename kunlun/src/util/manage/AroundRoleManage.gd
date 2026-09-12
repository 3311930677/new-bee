extends Node
class_name AroundRoleManage



const prefix = "AroundRoleManage->"

signal reset_role_display
signal reset_role_position

signal around_role_loaded

var player = preload("res://src/tscn/player/Player.tscn")

var ScreenUtils
var NetContext
var StaticGameData
var RoleInfoManage


var current_around_list_roles_ = {}
var is_load_around_role = true
var emit_around_signal = false

var current_map_role_ = {}

func _init() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	NetContext = Global.get("NetContext")
	StaticGameData = Global.get("StaticGameData")
	RoleInfoManage = Global.get("RoleInfoManage")
	
	NetContext.set_handler("PositionRemote", "updatePosition", self, "_on_around_role_position_result")
	NetContext.set_handler("PositionRemote", "getAroundRole", self, "_on_around_roles_result")
	
	
	NetContext.set_handler("RoleDataRemote", "getRoleShowDatas", self, "_on_role_show_data_result")


func _on_role_show_data_result(data):
	data = data["data"]
	Global.log_info(str(prefix, "外观形象数据：", data))
	var show_datas = {}
	for item in data:
		if item == null: continue
		show_datas[str(item["id"])] = item
		
		current_around_list_roles_[str(item["id"])] = item
	
	
	if emit_around_signal:
		emit_signal("around_role_loaded", current_around_list_roles_)
		emit_around_signal = false
	
	emit_signal("reset_role_display", show_datas)
	pass


func _on_around_role_position_result(data):
	data = data["data"]
	Global.log_info(str(prefix, data))
	
	var ids = []
	if Global.get_nodes_in_group("map_scence").size() <= 0: return
	var map_container = Global.get_nodes_in_group("map_scence")[0]
	
	
	for key in data.keys():
		
		if int(key) == RoleInfoManage.get_role_id(): continue
		if not current_map_role_.has(key):
			
			current_around_list_roles_[str(key)] = {"id": int(key)}
			
			ids.append(int(key))
			
			is_load_around_role = true
			Global.log_info(str(prefix, "有新玩家加入"))
			var p = player.instance()
			p.role_id = int(key)
			
			if data[str(key)]["points"].size() > 0:
				var points = data[str(key)]["points"]
				var x = points[0][0]
				var y = points[0][1]
				p.set_position(Vector2(x, y))
			
			map_container.add_role(p)
	current_map_role_ = data
	
	if ids.size() > 0: update_role_display_datas(ids)
	emit_signal("reset_role_position", current_map_role_)



func _on_around_roles_result(data):
	data = data["data"]
	
	var load_ids = []
	
	for item_id in data:
		if not current_around_list_roles_.has(str(item_id)):
			load_ids.append(item_id)
	
	var arr_keys = current_around_list_roles_.keys().duplicate(true)
	for key in arr_keys:
		
		var falg = true
		for i in data:
			if int(key) == int(i):
				falg = false
				break
		if falg:
			current_around_list_roles_.erase(str(key))
	
	if load_ids.size() > 0:
		
		emit_around_signal = true
		update_role_display_datas(load_ids)
	else:
		emit_signal("around_role_loaded", current_around_list_roles_)
	
	Global.log_info(str(prefix, data))



func upload_points(points):
	var request_data = {
		"points": points
	}
	NetContext.request_gate("PositionRemote", "updatePosition", request_data, false)


func update_role_display_datas(role_ids: Array):
	NetContext.request_gate("RoleDataRemote", "getRoleShowDatas", {"role_ids": role_ids}, false)


func load_around_roles():
	

	
	NetContext.request_gate("PositionRemote", "getAroundRole", {}, true)
	is_load_around_role = false


func reset_all_role_show_info():
	current_map_role_.clear()
	current_around_list_roles_.clear()

func reset_all_map_role():
	current_map_role_.clear()
	pass

func update_role_show_data():
	update_role_display_datas(current_around_list_roles_.keys())
	pass
