extends "res://src/tscn/server_nodes/button/RightButton.gd"


var show_ids
var hide_ids

	
func init_data(data):
	.init_data(data)
	show_ids = data["show_ids"]
	hide_ids = data["hide_ids"]
	
func click():
	
	for id in show_ids:
		var nodes = get_root().search_node_by_id(id)
		for node in nodes:
			node.show()
			
	for id in hide_ids:
		var nodes = get_root().search_node_by_id(id)
		for node in nodes:
			node.hide()


