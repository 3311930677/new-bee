extends Popup

signal ok_press

onready var title = $Panel / Label
onready var edit = $Panel / LineEdit
var id = 0


func _on_Button_pressed() -> void :
	emit_signal("ok_press", id, edit.text)
	queue_free()


func _on_Button2_pressed() -> void :
	queue_free()

func set_title(msg):
	$Panel / Label.text = msg
func set_id(id):
	self.id = id
