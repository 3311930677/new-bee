extends Control
signal item_click


enum TYPE{
	jn = 0, 
	wu = 1, 
	tao = 2, 
	fang = 3, 
	gong = 4
}

export (TYPE) var item_type = TYPE.jn
onready var tex = $Tex
onready var bg = $Bg
var res_s_light = [
	load("res://src/tscn/ui/battle/res/ji_light.tres"), 
	load("res://src/tscn/ui/battle/res/wu_light.tres"), 
	load("res://src/tscn/ui/battle/res/tao_light.tres"), 
	load("res://src/tscn/ui/battle/res/fang_light.tres"), 
	load("res://src/tscn/ui/battle/res/gong_light.tres"), 
]

var res_s_normal = [
	load("res://src/tscn/ui/battle/res/ji_normal.tres"), 
	load("res://src/tscn/ui/battle/res/wu_normal.tres"), 
	load("res://src/tscn/ui/battle/res/tao_normal.tres"), 
	load("res://src/tscn/ui/battle/res/fang_normal.tres"), 
	load("res://src/tscn/ui/battle/res/gong_normal.tres"), 
]

func _ready() -> void :
	tex.texture = res_s_light[item_type]
	pass


func _on_TextureButton_pressed() -> void :
	emit_signal("item_click")
	pass
