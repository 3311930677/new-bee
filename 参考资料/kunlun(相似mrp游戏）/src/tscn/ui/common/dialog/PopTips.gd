extends Control



var nodes = null
var method = ""

func _on_Timer_timeout() -> void :
	if nodes != null:
		nodes.call(method)
	queue_free()

func set_message(st: String):
	$Label.text = st;

func set_event(node, method):
	self.nodes = node
	self.method = method
