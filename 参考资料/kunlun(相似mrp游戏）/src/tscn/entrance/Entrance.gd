extends Node2D
class_name Entrance

signal entrance_map_change

enum Entrance_Dir{
	UP = 0, 
	DOWN = 1, 
	LEFT = 2, 
	RIGHT = 3
}

var current_dic = Entrance_Dir.UP

var cur_portal_info



var MapInfoManage
var NTeamManage
var ScreenUtils

var count = 0

func _ready() -> void :
	MapInfoManage = Global.get("MapInfoManage")
	NTeamManage = Global.get("NTeamManage")
	ScreenUtils = Global.get("ScreenUtils")
	MapInfoManage.connect("map_change_success", self, "_on_map_change_success")
	pass

func set_data(data: Dictionary):
	cur_portal_info = data
	add_to_group("entrances")
	current_dic = int(data["direction"])
	position = Vector2(data.x, data.y)
	$EntranceName.text = data["next_map_name"]
	if current_dic == 10:
		hide()

func _on_Area2D_body_entered(body: Node) -> void :
	if NTeamManage.self_is_follow(): return
	
	if Global.get("TBBattleManage").current_fighting: return
	
	
	if current_dic == 10: return
	
	if body is KinematicBody2D and body.is_player:
		
		
		
		if current_dic == Entrance_Dir.UP:
			body.entrance_dir = Entrance_Dir.DOWN
		elif current_dic == Entrance_Dir.DOWN:
			body.entrance_dir = Entrance_Dir.UP
		elif current_dic == Entrance_Dir.LEFT:
			body.entrance_dir = Entrance_Dir.RIGHT
		elif current_dic == Entrance_Dir.RIGHT:
			body.entrance_dir = Entrance_Dir.LEFT
		else:
			body.entrance_dir = 10
		
		MapInfoManage.change_map(cur_portal_info["next_map_desc"])
		$Area2D.collision_layer = 0
		


func get_position():
	var offest = 70
	
	if current_dic == Entrance_Dir.UP:
		return position + Vector2(0, + offest / 2)
	elif current_dic == Entrance_Dir.DOWN:
		return position + Vector2(0, - offest / 2)
	elif current_dic == Entrance_Dir.LEFT:
		return position + Vector2( + offest / 2, 0)
	elif current_dic == Entrance_Dir.RIGHT:
		return position + Vector2( - offest / 2, 0)
	else:
		return position


func _on_Timer_timeout() -> void :
	$Area2D.collision_layer = 11
	pass

func _on_map_change_success(map_id):
	$Timer.start()
	pass
