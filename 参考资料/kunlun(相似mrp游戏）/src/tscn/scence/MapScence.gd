extends Navigation2D

onready var objects = $Objects
onready var map = $Map
const prefix = "MapScence->"
var entrance = preload("res://src/tscn/entrance/Entrance.tscn")
var default_npc = preload("res://src/tscn/default/npc/Npc.tscn")
var player = preload("res://src/tscn/player/Player.tscn")

var temp_current_map_data_path = "user://current_map_data.bin"
var temp_key = "lkjos;pfsj"
var c_m_dic = {}

onready var MapeUtils = Global.get("MapeUtils")
onready var FileHelper = Global.get("FileHelper")
onready var ScreenUtils = Global.get("ScreenUtils")
onready var MapInfoManage = Global.get("MapInfoManage")
onready var RoleInfoManage = Global.get("RoleInfoManage")



var tilemap
var collision_tilemap
var map_info

var player_entity = null

func _ready() -> void :
	MapInfoManage.connect("map_change_success", self, "_on_map_change")
	pass

func _enter_tree():
	Global.get("RoleInfoManage").reload_ui()
	Global.get("PetInfoManage").emit_signal("pet_reload_show")


func change_map(mapNo: String):
	_clear_objects()
	
	c_m_dic["current"] = mapNo
	mapNo = str(mapNo, ".mape")
	map_info = MapeUtils.loadMape("res://assets/map/xq/mapres", mapNo)
	if map_info == null:
		ScreenUtils.show_message(str(prefix, "地图读取失败：", mapNo))
		return
	create_map()
	FileHelper.save_encrypted(temp_current_map_data_path, c_m_dic, temp_key)


func _clear_objects():
	for obj in $Objects.get_children():
		if obj.name != "Player" and obj != null:
			obj.queue_free()
	if tilemap != null: tilemap.queue_free()
	if collision_tilemap != null: collision_tilemap.queue_free()

func create_map():
	tilemap = TileMap.new()
	collision_tilemap = TileMap.new()
	tilemap.cell_size = Vector2(map_info["cell_h"], map_info["cell_w"])
	collision_tilemap.cell_size = Vector2(map_info["cell_h"], map_info["cell_w"])
	tilemap.tile_set = map_info["tileset"]
	collision_tilemap.tile_set = Global.get("MapeUtils").creat_collosion_tilemap()
	collision_tilemap.collision_layer = 5
	var x = 0
	var y = 0
	for i in map_info["map_data_list"]:
		for j in i:
			var map_data = j
			if abs(map_data) > map_info["max_tile_id"]: map_data = 0
			tilemap.set_cell(x, y, abs(map_data))
			
			if map_data < 0: collision_tilemap.set_cell(x, y, 1)
			else: collision_tilemap.set_cell(x, y, 0)
			x = x + 1
		y = y + 1
		x = 0
	
	
	for portal in MapInfoManage.get_map_portal(map_info["desc"]):
		var p = entrance.instance()
		p.set_data(portal)
		p.connect("entrance_map_change", self, "_entrance_map_change")
		$Objects.call_deferred("add_child", p)
		
		
		if Global.get_nodes_in_group("player").size() > 0:
			var player_ = Global.get_nodes_in_group("player")[0]
			if p.current_dic == player_.entrance_dir:
				player_.set_position(p.get_position())
		pass

	
	for npc in MapInfoManage.get_map_npc(map_info["desc"]):
		var n = default_npc.instance()
		$Objects.call_deferred("add_child", n)
		n.call_deferred("set_data", npc)
		pass
	
	
	for build_item in map_info["builds"]:
		$Objects.add_child(build_item)
	$Map.call_deferred("add_child", tilemap)
	$Map.call_deferred("add_child", collision_tilemap)

	
	var data = Global.get("GameData")

	var top_column = Global.get_nodes_in_group("topcolumn")[0]
	var info = MapInfoManage.get_map_info(map_info["desc"])
	
	
	
	
	
	MapInfoManage.init_map_state()
	top_column.set_title(info.get("level", 100), info.get("name", "默认名称"))
	
	if MapInfoManage.rename_map_name != null:
		top_column.set_title( - 1, MapInfoManage.rename_map_name)


func _on_map_change(mapno):
	change_map(mapno)


func load_data(data):
	change_map(String(RoleInfoManage.get_role_current_map()))
	
	var p = player.instance()
	p.is_player = true
	objects.add_child(p)
	player_entity = p
	
	p.set_position(RoleInfoManage.get_role_position())
	
	p.load_player_data(RoleInfoManage.get_role_info())
	
	if not data.get("is_fight_to_map", false):
		
		Global.get("MailInfoManage").check_has_mail()
		
		Global.get("ShopInfoManage").request_data()
		
	
		Global.get("AroundRoleManage").reset_all_map_role()
		
		Global.get("TaskInfoManage").request_task()
		
		Global.get("TBBattleManage").request_has_fight()
		


	else:
		
		Global.get("AroundRoleManage").reset_all_map_role()
		pass



func add_role(p_layer):
	$Objects.call_deferred("add_child", p_layer)
	pass



func _on_Timer_timeout() -> void :
	Global.get("AroundRoleManage").is_load_around_role = false
	pass
