extends Control



var current_node = null
var m_ok = null
var m_cancel = null
var is_on_envent = false;

func set_message(text: String):
	var bbtxt = $"Panel/ScrollContainer/VBoxContainer/RichTextLabel"
	bbtxt.clear()
	bbtxt.append_bbcode(Global.get("RichTextContentFormat").get_content_format(text))

func set_event(node: Node, m1_ok: String, m2_cancel: String):
	current_node = node
	m_ok = m1_ok
	m_cancel = m2_cancel
	if node != null:
		is_on_envent = true
	else:
		is_on_envent = false

func _on_Ok_pressed() -> void :
	if is_on_envent:
		if m_ok != null and not m_ok.empty():
			current_node.call(m_ok)
	queue_free()


func _on_Cance_pressed() -> void :
	if is_on_envent:
		if m_cancel != null and not m_cancel.empty():
			current_node.call(m_cancel)
	queue_free()
