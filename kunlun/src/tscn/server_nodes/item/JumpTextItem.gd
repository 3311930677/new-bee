extends "res://src/tscn/server_nodes/item/TextItem.gd"


var DialogManage



var url: String

func _init():
	DialogManage = Global.get("DialogManage")
	
func init_data(data):
	.init_data(data)
	url = data["url"]
	
func click():
	DialogManage.request(url)
	pass


