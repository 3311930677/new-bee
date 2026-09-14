extends "res://src/tscn/server_nodes/Form/Input.gd"

var text_input = preload("res://src/tscn/server_nodes/Form/TextInput.tscn")

func init_tscn():
	instance_tscn = text_input.instance()
	
	
	instance_tscn.connect("text_changed", self, "text_changed")
	
	
	


func text_changed(new_text: String):
	if form_name != "" and input_name != "":
		var root = get_root()
		print(root.node_name, root.form_data)
		root.form_data[form_name][input_name] = new_text
	




