extends "res://src/tscn/server_nodes/ServerNode.gd"


var title_res = preload("res://src/tscn/server_nodes/components/title/title.tscn")


var title

func init_tscn():
	instance_tscn = title_res.instance();
	instance_tscn.set_title(title)
	
func init_data(data):
	.init_data(data)
	title = data["title_text"]
	
