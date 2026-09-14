extends Node2D


var RoleUtils
var PetInfoManage
var StaticGameData

var follow_role_ = null;
var static_data
var player_self_y_data
var hold_id = - 1
var anim: AnimationPlayer = null
var anim_player_cg: AnimationPlayer = null

var last_animation = "left_idle"
var current_animation = ""
var offset_x = 0

func _ready() -> void :
	RoleUtils = Global.get("RoleUtils")
	PetInfoManage = Global.get("PetInfoManage")
	StaticGameData = Global.get("StaticGameData")
	
	PetInfoManage.connect("pet_reload_show", self, "_on_pet_reload_show")
	follow_role_ = get_meta("role")
	anim_player_cg = follow_role_.anim_player_cg
	static_data = get_meta("pet_static_data")
	if has_meta("hold_id"):
		hold_id = get_meta("hold_id")
	player_self_y_data = follow_role_.self_y_data
	load_ani()
	pass


func _process(delta: float) -> void :
	
	last_animation = follow_role_.anim_player_cg.current_animation
	if self.position.x != offset_x:
		if self.position.x < offset_x:
			translate(Vector2(4, 0))
			pass
		else:
			translate(Vector2( - 4, 0))
			pass

	
	if current_animation != last_animation:
		current_animation = last_animation
		if anim != null:
			if anim.has_animation(current_animation):
				anim.play(current_animation)
			change_position(current_animation)


func _on_pet_reload_show():
	
	if not follow_role_.is_player: return
	
	var pet_race = PetInfoManage.fight_pet_details["petHold"]["pet_race_id"]
	static_data = StaticGameData.get_pet_data(pet_race)
	load_ani()
	pass



func change_position(ani_str):
	if (ani_str.find("left") != - 1):
		offset_x = 40
		pass
	else:
		offset_x = - 40
		pass

func load_ani():
	if anim != null:
		anim.free()
	
	anim = RoleUtils.parseCGNpc(static_data["img_dir"])
	if anim == null or anim.get_animation_list().size() < 4:
		hide()
	else:
		show()
	if anim != null:
		add_child(anim)
		anim.play("left_idle")
	

