extends TextureButton

export var index: int = 0

signal item_click

func _ready() -> void :
	connect("pressed", self, "_on_TextureButton_pressed")

func _on_TextureButton_pressed() -> void :
	emit_signal("item_click", index)
	pass
