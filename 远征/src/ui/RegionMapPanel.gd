class_name RegionMapPanel
extends "res://src/ui/RegionChestMap.gd"
func _unhandled_input(event:InputEvent) -> void:
	if G.ui_blocked:return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()