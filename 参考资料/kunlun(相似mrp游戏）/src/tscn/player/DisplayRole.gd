extends Node2D

var anim_player_cg: AnimationPlayer = null

var RoleUtils
var StaticGameData

func _ready() -> void :
	RoleUtils = Global.get("RoleUtils")
	StaticGameData = Global.get("StaticGameData")
	load_data({
		"race_id": 2, 
		"job_id": 1, 
		"division_id": 1
	})

func load_data(data):
	data = StaticGameData.get_role_type(data["race_id"], data["job_id"], data["division_id"])
	anim_player_cg = RoleUtils.parseCGRole(data["role_type"], data["sex"])
	add_child(anim_player_cg)
	anim_player_cg.play("left_idle")
