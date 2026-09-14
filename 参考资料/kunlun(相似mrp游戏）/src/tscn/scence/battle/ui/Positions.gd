extends Control

signal index_click

func _ready() -> void :
	for item in get_children():
		item.get_child(0).connect("item_click", self, "_item_click")

func _item_click(index):
	emit_signal("index_click", index)
	pass
