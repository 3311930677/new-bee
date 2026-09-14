extends "res://src/tscn/server_nodes/item/TextItem.gd"




var show_ids
var hide_ids

var request_remote
var request_method
	
var NetContext

func _init():
	NetContext = Global.get("NetContext")
	
func init_data(data):
	.init_data(data)
	request_remote = data["request_remote"]
	request_method = data["request_method"]
	
func click():
	if form_name != "":
		var root = get_root()
		var data = root.form_data[form_name]
		NetContext.request_service(request_remote, request_method, data, true)
	


