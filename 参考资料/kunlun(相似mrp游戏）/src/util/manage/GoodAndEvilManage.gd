extends Node
class_name GoodAndEvilManage

signal _on_evil_loaded
signal _on_good_loaded

var NetContext

func _init() -> void :
	NetContext = Global.get("NetContext")
	NetContext.set_handler("SneakCorrelationRemote", "getEvil", self, "_on_evil_result")
	NetContext.set_handler("SneakCorrelationRemote", "getGood", self, "_on_good_result")
	pass

func _on_evil_result(data):
	data = data["data"]
	emit_signal("_on_evil_loaded", data)
func _on_good_result(data):
	data = data["data"]
	emit_signal("_on_good_loaded", data)


func request_good_evil(type, page, count):
	var met = "getGood"
	if type == 2:
		met = "getEvil"
	NetContext.request_service("SneakCorrelationRemote", met, {
		"page": page, 
		"count": count, 
	}, true)

func accept_arrest_task(id):
	NetContext.request_service("ArrestTaskRemote", "acceptTask", {
		"villain_id": id
	}, true)
	pass
