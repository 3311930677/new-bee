extends TextureRect



func _on_TextureButton_pressed() -> void :
	Global.get("ScreenUtils").chage_ui_and_args("res://src/tscn/ui/map/chat/ChatUi.tscn", "load_data", {})
	pass
