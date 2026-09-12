extends "res://src/tscn/server_nodes/ServerNode.gd"



var value: String

var input_name: String

var form_name: String


func init_data(data):
	.init_data(data)
	value = data.get("value", "")
	input_name = data.get("input_name", "")
	form_name = data.get("form_name", "")


func init_after():
	var root = get_root()
	if form_name != "" and root.form_data.get(form_name, null) == null:
		root.form_data[form_name] = {}

	
	
		
	

			
		
		
	
	




