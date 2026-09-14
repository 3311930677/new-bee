extends Node
class_name DialogManage

const prefix = "DialogManage->"

var NetContext
var ScreenUtils


var ServerPageManage

func _init() -> void :
	NetContext = Global.get("NetContext")
	ScreenUtils = Global.get("ScreenUtils")
	ServerPageManage = Global.get("ServerPageManage")
	
	NetContext.set_handler("DialogRemote", "requestNpc", self, "_on_npc_req_result")
	NetContext.set_handler("DialogRemote", "request", self, "_on_req_result")
	NetContext.set_handler("DialogRemote", "clickItem", self, "_on_item_result")


func _on_npc_req_result(data):
	data = data["data"]
	if typeof(data) == TYPE_STRING:
		data = parse_json(data)
	Global.log_info(str(prefix, data))
	ScreenUtils.show_npc_dialog(data)
	pass
	

func response_handler(data):
	if (data["type"] == 1):
		
		ScreenUtils.show_dialog(data)
	
	if (data["type"] == 2):
		var root = data["root"]
		
		var server_node = ServerPageManage.get_node(root)
		
		ScreenUtils.add_page_ui(server_node.get_tscn())
		


func _on_req_result(data):
	data = data["data"]
	Global.log_info(str(prefix, data))
	response_handler(data)
	pass


func _on_item_result(data):
	data = data["data"]
	Global.log_info(str(prefix, data))
	response_handler(data)
	pass



func request(url):
	NetContext.request_service("DialogRemote", "request", {
		"url": url
	}, true)



func request_npc(npc_id):
	NetContext.request_service("DialogRemote", "requestNpc", {
		"id": npc_id
	}, true)
	
	

func item_click(url, index):
	NetContext.request_service("DialogRemote", "clickItem", {
		"url": url, 
		"index": index
	}, true)
	pass
