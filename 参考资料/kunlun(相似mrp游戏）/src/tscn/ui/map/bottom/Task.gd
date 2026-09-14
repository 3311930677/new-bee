extends TextureRect


signal item_click

export (int) var bg_index = 1
export (int) var num_index = 1
export (float) var speed = 0.2
export (bool) var signal_ = true
export (String) var paths = null

onready var bg = $Bg
onready var num = $Bg / Num

var is_glimmer = false
var index = 0
var str_bg_n_template = "res://src/tscn/ui/common/tres/bottom/icon_n_%d.tres"
var str_bg_l_template = "res://src/tscn/ui/common/tres/bottom/icon_l_%d.tres"
var num_template = "res://src/tscn/ui/common/tres/bottom/num_%d.tres"


var light_bg = null
var black_bg = null

var all_delta = 0.0

func _ready() -> void :

	var file = File.new()
	if file.file_exists(str_bg_n_template % bg_index):
		black_bg = load(str_bg_n_template % bg_index)
	if file.file_exists(str_bg_l_template % bg_index):
		light_bg = load(str_bg_l_template % bg_index)
	
	bg.texture = black_bg
	num.texture = load(num_template % num_index)
	pass

func _process(delta: float) -> void :
	all_delta += delta
	if is_glimmer:
		if all_delta >= speed:
			all_delta = 0.0
			index += 1
			if light_bg != null and black_bg != null:
				if index % 2 == 0:
					bg.texture = light_bg
				else:
					bg.texture = black_bg


func start_glimmer():
	is_glimmer = true
	pass

func stop_glimmer():
	is_glimmer = false
	all_delta = 0.0
	bg.texture = black_bg
	pass


func _on_TextureButton_pressed() -> void :
	if signal_:
		emit_signal("item_click")
	else:
		Global.get("ScreenUtils").chage_ui_and_args(paths, "load_data", {})
	stop_glimmer()
	pass
