extends Navigation2D

onready var icon = $Objects / Player

var entrance = preload("res://src/tscn/entrance/Entrance.tscn")
var default_npc = preload("res://src/tscn/default/npc/Npc.tscn")
var temp_current_map_data_path = "user://current_map_data.bat"
var temp_key = "lkjos;pfsj"



var tilemap = TileMap.new()

var collision_tilemap: TileMap = TileMap.new()
var map_info

var path = []
var FileHelper
func _ready() -> void :
	FileHelper = Global.get("FileHelper")
	if not FileHelper.file_exits(temp_current_map_data_path):
		
		var c_m_dic = {}
		c_m_dic["current"] = "1001"
		pass
	else: FileHelper.read_encrypted(temp_current_map_data_path, temp_key)

func create_map():
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
	for protal in map_info["protal"]:
		var p = entrance.instance()
		p.set_data(protal)
		$Objects.add_child(p)
		pass
	for npc in map_info["npcs"]:
		var n = default_npc.instance()
		n.set_data(npc)
		$Objects.add_child(n)
	for build in map_info["builds"]:
		$Objects.add_child(build)
	$Map.add_child(tilemap)
	$Map.add_child(collision_tilemap)






















