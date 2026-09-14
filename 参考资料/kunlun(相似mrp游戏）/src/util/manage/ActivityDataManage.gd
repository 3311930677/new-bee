extends Node
class_name ActivityDataManage


signal xb_activity_data_load_success

var NetContext


var xbTowerActivityData = {}


var xb_start_npc_id = 200000
var xb_end_npc_id = 200069


func _init() -> void :
	NetContext = Global.get("NetContext")
	NetContext.set_handler("XBTowerRemote", "getXBData", self, "_on_xb_activity_data_handler")
	pass

func _on_xb_activity_data_handler(data):
	data = data["data"]
	xbTowerActivityData = data
	emit_signal("xb_activity_data_load_success", data)


func flush_xb_data(wait = true):
	NetContext.request_service("XBTowerRemote", "getXBData", {}, wait)
	pass

func get_xb_level():
	return int(xbTowerActivityData.get("level", 0))


func process_npc_activity(node: Node):
	
	
	if int(node.get_id()) >= xb_start_npc_id and int(node.get_id()) <= xb_end_npc_id:
		private_process_xb_npc_data(node)


func private_process_xb_npc_data(node: Node):
	
	connect("xb_activity_data_load_success", node, "_on_activity_xb_callback")
	
	if int(node.get_id() - xb_start_npc_id) > xbTowerActivityData.get("level", 0):
		node.hide()


	pass
