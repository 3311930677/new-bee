extends Control


onready var box = $"Background/Control"
onready var lineBox = $"Background/Control/BgLine"
onready var txt = $Background / Tips / ScrollContainer / VBoxContainer / Label

var is_drag = false
var offset = Vector2.ZERO


var ScreenUtils
var MapInfoManage


var item_map_res = preload("res://src/tscn/ui/map/worldmap/SmallMapItem.tscn")

var line_t_res = load("res://src/tscn/ui/map/worldmap/line_t.tres")
var line_v_res = load("res://src/tscn/ui/map/worldmap/line_v.tres")


var role_in_current_map = false
var role_current_map
var city_maps
var walk_map = []

var check_map_info = null

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	MapInfoManage = Global.get("MapInfoManage")
	
	pass


func load_data(data):
	
	role_current_map = MapInfoManage.get_current_map_info()
	if data.has(role_current_map["map_id"]): role_in_current_map = true
	city_maps = data
	create_map()



func create_map():
	if not role_in_current_map:
		role_current_map = city_maps[city_maps.keys()[0]]
	

	DBS_map(role_current_map, 9000 / 2 + 100, 9000 / 2 + 100)

	pass

func DBS_map(current_map, map_x, map_y):
	var current_map_id = current_map["map_id"]
	if current_map_id in walk_map:
		return
	else:
		walk_map.append(current_map_id)
	
	

	var item = item_map_res.instance()
	item.rect_position = Vector2(map_x, map_y)
	box.add_child(item)
	item.rect_size = Vector2(23, 22)
	item.rect_scale = Vector2(2, 2)
	item.connect("item_click", self, "_item_click")
	item.set_data(current_map)
	

	var tab = 65
	
	var maps = MapInfoManage.get_map_portal(current_map_id)
	for map in maps:
		var line = TextureRect.new()
		var next_map_id = map["next_map_desc"]
		var direction = map["direction"]
		var x = map_x
		var y = map_y
		if direction == 0:
			y = map_y - tab
			line.texture = line_v_res
			line.rect_position = Vector2(map_x + 14, map_y - 25)
		elif direction == 1:
			y = map_y + tab
			line.texture = line_v_res
			line.rect_position = Vector2(map_x + 14, map_y + 51)
		elif direction == 2:
			x = map_x - tab
			line.texture = line_t_res
			line.rect_position = Vector2(map_x - 27, map_y + 8)
		elif direction == 3:
			x = map_x + tab
			line.texture = line_t_res
			line.rect_position = Vector2(map_x + 52, map_y + 8)
			
		if not city_maps.has(str(next_map_id)):
			line.free()
			continue


		lineBox.add_child(line)
		
		current_map = city_maps[str(next_map_id)]
		
		DBS_map(current_map, x, y)
		



func set_title(map_name):
	$Head / XQTitle.set_title(map_name)


func _item_click(map_info):
	check_map_info = map_info
	
	var level_value = map_info["level"]
	if level_value != 0:
		level_value = str("LV", level_value, "-")
	else:
		level_value = ""
		
	var title = str(level_value, map_info["name"])
	set_title(title)
	
	
	txt.text = title
	pass

















func _on_Cancle_pressed() -> void :
	queue_free()


func _process(delta: float) -> void :
	if is_drag:
		$Background / Control.rect_position = get_global_mouse_position() + offset



func _on_TextureButton_button_down() -> void :
	offset = $Background / Control.rect_position - get_global_mouse_position()
	is_drag = true

func _on_TextureButton_button_up() -> void :
	is_drag = false


func _on_Ok_pressed() -> void :
	if check_map_info == null: return
	if check_map_info["map_id"] == MapInfoManage.get_current_map_info()["map_id"]: return
	ScreenUtils.show_message(str("确定进入 %s 地图？" % check_map_info["name"]), self, "_join_map")
	pass

func _join_map():
	Global.get("MapInfoManage").change_map(check_map_info["map_id"])
	queue_free()
	pass
