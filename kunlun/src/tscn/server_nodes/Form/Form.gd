extends "res://src/tscn/server_nodes/XQBG.gd"




var request_remote
var request_method

var NetContext
func _init():
	NetContext = Global.get("NetContext")

func init_data(data):
	.init_data(data)
	request_remote = data["request_remote"]
	request_method = data["request_method"]



func submit(data: Dictionary):
	NetContext.request_service(request_remote, request_method, data, true)
