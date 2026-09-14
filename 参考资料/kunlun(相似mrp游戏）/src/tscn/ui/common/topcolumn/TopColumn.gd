extends Control

const prefix = "TopColumn->"

onready var bbcode_txt: RichTextLabel = $Panel2 / RichTextLabel
onready var pan = $Panel2


onready var time = $Panel / Time
onready var map_name = $Panel / MapName

export (int) var code_speed = 3
export (float) var wait_time = 0.1

var is_scroll = false

var ScreenUtils

var msg_datas = []

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	pan.hide()
	
	var map_info = Global.get("MapInfoManage").get_current_map_info()
	set_title(map_info["level"], map_info["name"])



func set_scorlltext(txt: String):
	msg_datas.push_back(txt)
	pass


func set_title(level: int, name: String):
	if level > 0:
		map_name.text = "LV%d-%s" % [level, name]
	else:
		map_name.text = "%s" % name
	pass

func _process(delta: float) -> void :
	if msg_datas.size() > 0 and is_scroll == false:
		var txt = msg_datas.pop_front()
		bbcode_txt.set_bbcode(txt)
		bbcode_txt.rect_size = Vector2(bbcode_txt.text.length() * 19, bbcode_txt.rect_size.y)
		is_scroll = true
		pan.show()
	wait_time += delta
	if wait_time >= 0.02 and is_scroll:
		if bbcode_txt.rect_position.x + bbcode_txt.rect_size.x >= 0:
			bbcode_txt.rect_position = Vector2(bbcode_txt.rect_position.x - code_speed, bbcode_txt.rect_position.y)
		else:
			is_scroll = false
			
			bbcode_txt.rect_position = Vector2(360, bbcode_txt.rect_position.y)
			pan.hide()
		wait_time = 0
	var current_time = OS.get_datetime()
	var hour = "%02d" % current_time["hour"]
	var minte = "%02d" % current_time["minute"]
	time.text = str(hour, ":", minte)
	pass


func _on_TextureButton_pressed() -> void :
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/worldmap/WorldMap.tscn", "load_data", {})
