extends Control

onready var light_res = load("res://src/tscn/ui/common/tres/dipan_pressed.tres")
onready var black_res = load("res://src/tscn/ui/common/tres/dipan_normal.tres")
onready var dipan = $Dipan
onready var display_role = $DisplayRole
signal item_click

var item_checked

var StaticGameData

var data

func _ready() -> void :
	StaticGameData = Global.get("StaticGameData")
	pass

func checked():
	dipan.texture = light_res
	emit_signal("item_click", self)

func unchecked():
	dipan.texture = black_res

func _on_TextureButton_pressed() -> void :
	var dipans = Global.get_nodes_in_group("role_dipan_item")
	for item in dipans:
		item.unchecked()
	checked()

func set_data(data):
	self.data = data
	
	display_role.load_data(data)
