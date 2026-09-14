extends "res://src/tscn/server_nodes/ServerNode.gd"


var bg = preload("res://src/tscn/ui/common/button/LeftButton.tscn")



var NetContext = Global.get("NetContext")

var text

func _init():
	instance_tscn = bg.instance();


func init_data(data):
	.init_data(data)
	text = data["text"]
	
func init_tscn():
	instance_tscn.set_text(get_text())

func get_text():
	return text



