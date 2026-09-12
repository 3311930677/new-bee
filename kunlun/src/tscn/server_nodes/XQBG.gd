extends "res://src/tscn/server_nodes/ServerNode.gd"


var bg = preload("res://src/tscn/ui/common/bg/Background.tscn")

var bgs = [
	preload("res://src/tscn/ui/common/bg/Background.tscn"), 
	preload("res://src/tscn/ui/common/bg/Background2.tscn"), 
	preload("res://src/tscn/ui/common/bg/Background3.tscn"), 
	preload("res://src/tscn/ui/common/bg/Background4.tscn"), 
]

var bg_index = 0;


func _init():
	instance_tscn = bg.instance();
	

func init_data(data):
	.init_data(data)
	bg_index = data["bg_index"]
	

func init_tscn():
	instance_tscn = bgs[bg_index].instance()
	

