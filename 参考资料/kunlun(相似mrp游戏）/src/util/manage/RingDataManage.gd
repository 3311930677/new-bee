extends Node
class_name RingDataManage

signal key_data_loaded

var NetContext

func _init():
	NetContext = Global.get("NetContext")
	NetContext.set_handler("ArenaRemote", "getRankingTop", self, "_on_key_data_result")

func load_key_data(key):
	NetContext.request_service("ArenaRemote", "getRankingTop", {
		"key": key, 
		"size": 10
	}, true)
	pass

func _on_key_data_result(data):
	data = data["data"]
	emit_signal("key_data_loaded", data)
