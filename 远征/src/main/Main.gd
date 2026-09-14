# Main.gd —— 场景流：Title → Login → CreateRole → GameHome
extends Control

const TITLE_SCENE := "res://src/ui/Title.tscn"
const LOGIN_SCENE := "res://src/ui/Login.tscn"
const CREATE_ROLE_SCENE := "res://src/ui/CreateRole.tscn"
const GAME_HOME_SCENE := "res://src/ui/GameHome.tscn"


func _ready() -> void:
	# _ready 期间场景树仍在构建，切场景必须延迟一帧
	go_title.call_deferred()


func go_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)


func go_login() -> void:
	get_tree().change_scene_to_file(LOGIN_SCENE)


func go_create_role() -> void:
	get_tree().change_scene_to_file(CREATE_ROLE_SCENE)


func go_game_home() -> void:
	get_tree().change_scene_to_file(GAME_HOME_SCENE)
