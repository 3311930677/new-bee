# Main.gd —— 场景流：Title → CharSelect → GameHome
extends Control

const TITLE_SCENE := "res://src/ui/Title.tscn"
const CHAR_SELECT_SCENE := "res://src/ui/CharSelect.tscn"
const GAME_HOME_SCENE := "res://src/ui/GameHome.tscn"


func _ready() -> void:
	# _ready 期间场景树仍在构建，切场景必须延迟一帧
	go_title.call_deferred()


func go_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)


func go_char_select() -> void:
	get_tree().change_scene_to_file(CHAR_SELECT_SCENE)


func go_game_home() -> void:
	get_tree().change_scene_to_file(GAME_HOME_SCENE)
