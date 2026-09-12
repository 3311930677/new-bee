extends "res://src/tscn/server_nodes/ServerNode.gd"


var label = preload("res://src/tscn/server_nodes/label/TextLabel.tscn")

var text: String

func init_data(data):
	.init_data(data)
	text = data["text"]

	
func init_tscn():
	instance_tscn = label.instance()
	instance_tscn.text = text
	var color = style.get("color", null)
	if color != null:
		instance_tscn.modulate = Color(color["r"], color["g"], color["b"])
	
		




