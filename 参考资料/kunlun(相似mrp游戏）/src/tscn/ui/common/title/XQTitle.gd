extends Control

export (String) var title = "XQ"

func _ready() -> void :
	$HBoxContainer / Label.text = title
	pass

func set_title(te):
	$HBoxContainer / Label.text = te
	title = te
