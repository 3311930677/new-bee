extends "res://src/tscn/server_nodes/Form/Input.gd"



var submit_input = preload("res://src/tscn/ui/common/button/LeftButton.tscn")
var request_remote
var request_method

var NetContext

func _init():
	NetContext = Global.get("NetContext")
	
func init_tscn():
	instance_tscn = submit_input.instance()
	var ok = instance_tscn.find_node("ok")
	ok.text = value
	
	ok.connect("pressed", self, "pressed")
	

func init_data(data):
	.init_data(data)
	request_remote = data["request_remote"]
	request_method = data["request_method"]
	
	

func pressed():
	if form_name != "":
		var root = get_root()
		var data = root.form_data[form_name]
		NetContext.request_service(request_remote, request_method, data, true)
	

	

