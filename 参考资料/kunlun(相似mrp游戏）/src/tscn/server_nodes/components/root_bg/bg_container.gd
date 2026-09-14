extends Control

onready var bg = $Background
onready var bg2 = $Background / Background2

func _ready() -> void :
	
	var root_size = bg.rect_size
	
	bg2.margin_bottom = (root_size.y / 2 - 20)
	bg2.margin_top = - (root_size.y / 2 - 20)
	bg2.margin_left = - (root_size.x / 2 - 16)
	bg2.margin_right = (root_size.x / 2 - 16)
	pass
