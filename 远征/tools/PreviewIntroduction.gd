extends Control

func _ready() -> void:
	G.SAVE_PATH = "res://shots/introduction_20261015/preview_isolated_save.json"
	get_window().size = Vector2i(480, 1067 if "--tall" in OS.get_cmdline_user_args() else 800)
	var page := preload("res://src/ui/IntroductionPanel.gd").new()
	page.closed.connect(func(): get_tree().quit())
	add_child(page)
