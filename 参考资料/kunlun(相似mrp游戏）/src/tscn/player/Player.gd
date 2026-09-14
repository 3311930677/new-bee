extends Node2D



export (int) var probability = 200

export (int) var count_mili_yuguai = 8

var pet_res = preload("res://src/tscn/pet/Pet.tscn")
var current_follow_pet = null
var anim_player_cg: AnimationPlayer = null
var camera = null

var entrance_dir = 0

var path = []
var distance = Vector2.ZERO
var is_player = false

var click_points = []

var sleep_times = 0.0
var sleep_upload = 14.0
var max_interval_times = 1.0
var max_interval_upload = 30.0
var yuguai_all_time = 0

var role_id
var inited = false

var follow_pet = null
var encounter_monster_ = false

var MapeUtils
var RoleUtils
var StaticGameData
var MapInfoManage
var AroundRoleManage
var RoleInfoManage
var NTeamManage
var PetInfoManage
var self_y_data



func load_player_data(data: Dictionary):
	load_data(data)
	$"name/Sprite".visible = true
	$"name/AnimationPlayer".play("idle")
	MapeUtils.connect("mapchange_", self, "_mapeutils_map_change_")
	RoleInfoManage.connect("role_reload_display", self, "_on_role_reload_display")
	RoleInfoManage.connect("role_pet_show_reload", self, "_on_role_pet_show_reload")
	
	PetInfoManage.connect("reset_pet", self, "_on_reset_pet")
	PetInfoManage.connect("fight_pet", self, "_on_fight_pet")
	add_to_group("player")
	name = "Player"
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.current = true
	camera.zoom = Vector2(0.7, 0.75)
	camera.limit_top = - 20
	camera.limit_left = 0
	
	camera.limit_right = MapeUtils.parse_current_map.get("y_num", 26) * 16
	var ar_b = Global.get_nodes_in_group("main_bottom")
	if ar_b.size() > 0:
		camera.limit_bottom = MapeUtils.parse_current_map.get("x_num", 22) * 16 + ar_b[0].rect_size.y / 1.2;
	else:
		camera.limit_bottom = MapeUtils.parse_current_map.get("x_num", 22) * 16 + 120
	add_child(camera)
	role_id = RoleInfoManage.get_role_id()
	
	click_points.append([position.x, position.y, 0])
	AroundRoleManage.connect("reset_role_position", self, "_reset_role_position")
	if MapInfoManage.direction == - 1:
		set_position(MapInfoManage.p_target_point)
	$Encounter.start()
	MapInfoManage.c_player_entity = self
	
	if RoleInfoManage.get_self_user_indetity() == 100:
		$name / VBoxContainer / Gm.show()
	else:
		$name / VBoxContainer / Gm.hide()



func load_data(data: Dictionary):
	
	self_y_data = data
	var type_data = StaticGameData.get_role_type(data["race_id"], data["job_id"], data["division_id"])
	var role_type = type_data.get("role_type", 21)
	var sex = type_data.get("sex", 0)
	anim_player_cg = RoleUtils.parseCGRole(role_type, sex)
	add_child(anim_player_cg)
	anim_player_cg.play("left_idle")
	$name.text = data["role_name"]
	set_name_color(data)
	
	if not is_player and not inited:
		inited = true
		AroundRoleManage.connect("reset_role_display", self, "_reset_role_display")
		AroundRoleManage.connect("reset_role_position", self, "_reset_role_position")



func set_target_points(v2: Vector2):
	path = Global.get_nodes_in_group("map_scence")[0].get_simple_path(self.position, v2, true)
	pass


func upload_points():
	
	if click_points.size() <= 0:
		click_points.append([position.x, position.y, 0])
	else:
		click_points[0][2] = 0
	var up_points = click_points.duplicate(true)
	
	
	AroundRoleManage.upload_points(up_points)
	click_points.clear()
	set_name_color(self_y_data)


func other_record():
	if is_player:
		if not NTeamManage.self_is_follow():
			return
	if click_points.size() > 0 and sleep_times >= click_points.front()[2]:
		
		var temp_clicks = click_points.pop_front()
		set_target_points(Vector2(temp_clicks[0], temp_clicks[1]))
		sleep_times = 0.0

func move_to_path(walk_speed):
	var last_point = position
	while (path.size()):
		var distance_between_points = last_point.distance_to(path[0])
		distance = path[0] - position


		if distance.x > 0 and anim_player_cg.current_animation != "right_walk":
			anim_player_cg.play("right_walk")
		elif distance.x < 0 and anim_player_cg.current_animation != "left_walk":
			anim_player_cg.play("left_walk")
		if distance_between_points >= 2:
			position = last_point.linear_interpolate(path[0], walk_speed / distance_between_points)
			yuguai()
			return
		last_point = path[0]
		path.remove(0)
	position = last_point
	if distance.x > 0 and anim_player_cg.current_animation == "right_walk" or anim_player_cg.current_animation == "right_idle":
		anim_player_cg.play("right_idle")
	elif distance.x < 0 and anim_player_cg.current_animation == "left_walk" or anim_player_cg.current_animation == "left_idle":
		anim_player_cg.play("left_idle")
	



func set_position(v2):
	position = v2
	set_target_points(v2)
	path.resize(0)



func _ready() -> void :
	MapeUtils = Global.get("MapeUtils")
	RoleUtils = Global.get("RoleUtils")
	StaticGameData = Global.get("StaticGameData")
	MapInfoManage = Global.get("MapInfoManage")
	AroundRoleManage = Global.get("AroundRoleManage")
	RoleInfoManage = Global.get("RoleInfoManage")
	NTeamManage = Global.get("NTeamManage")
	PetInfoManage = Global.get("PetInfoManage")
	
	load_data({
		"race_id": 1, 
		"job_id": 0, 
		"division_id": 0, 
		"role_name": ""
	})
	pass

func _on_role_reload_display(role_info):
	
	load_data(role_info)
	
	
	pass

func _on_role_pet_show_reload():
	var pet_fight_id = Global.get("PetInfoManage").fight_pet_id
	if (current_follow_pet != null and pet_fight_id != current_follow_pet.hold_id) or (pet_fight_id > 0 and current_follow_pet == null):
		var node = get_node("pet")
		if node != null: node.queue_free()
		
		var pet_race = Global.get("PetInfoManage").fight_pet_details["petHold"]["pet_race_id"]
		var static_pet_data = StaticGameData.get_pet_data(pet_race)
		
		if static_pet_data["battle_grade"] == 1:
			var pet = pet_res.instance()
			pet.set_meta("pet_static_data", static_pet_data)
			pet.set_meta("role", self)
			pet.set_meta("hold_id", pet_fight_id)
			pet.name = "pet"
			current_follow_pet = pet
			add_child(pet)
	pass

func _reset_role_display(map_rols_info):
	if map_rols_info.has(str(role_id)):
		var data = map_rols_info[str(role_id)]
		
		load_data(data)
		
		
		if data.has("pet_race") and data["pet_race"] > 0 and follow_pet == null:
			var static_pet_data = StaticGameData.get_pet_data(data.get("pet_race"))
			if static_pet_data.get("battle_grade", 100) == 1:
				var pet = pet_res.instance()
				pet.set_meta("pet_static_data", static_pet_data)
				pet.set_meta("role", self)
				add_child(pet)
				follow_pet = pet
		
		
		if data.get("identity", 0) == 100:
			$name / VBoxContainer / Gm.show()
		else:
			$name / VBoxContainer / Gm.hide()
		pass


func _reset_role_position(map_rols):
	
	if is_player:
		
		if NTeamManage.self_is_follow() and map_rols.has(str(NTeamManage.get_team_leader_id())):
			click_points.append_array(map_rols[str(NTeamManage.get_team_leader_id())]["points"])
			pass
		return
	
	if map_rols.has(str(role_id)):
		var arr_pos = map_rols[str(role_id)]["points"]
		if arr_pos.size() <= 1 and arr_pos[0][2] == 0:
			click_points.clear()
			return
		click_points.append_array(map_rols[str(role_id)]["points"])
	else:
		
		queue_free()

func _unhandled_input(event: InputEvent) -> void :
	
	if not is_player or NTeamManage.self_is_follow(): return
	
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == BUTTON_LEFT:
		var mouse_position = get_global_mouse_position()
		
		mouse_position.x = int(mouse_position.x)
		mouse_position.y = int(mouse_position.y)
		
		if mouse_position.x < 0 or mouse_position.y < 0: return
		if mouse_position.x > MapeUtils.parse_current_map.get("y_num", 26) * 16 or mouse_position.y > MapeUtils.parse_current_map.get("x_num", 22) * 16 + 90: return
		path = find_parent("MapScence").get_simple_path(self.position, mouse_position, true)
		if sleep_times >= max_interval_times:
		
			var temp = [mouse_position.x, mouse_position.y, sleep_times]
			click_points.append(temp)
			sleep_times = 0.0

func _process(delta: float) -> void :
	
	if path.size() <= 0:
		if anim_player_cg.current_animation.find("idle") == - 1:
			if anim_player_cg.current_animation == "left_walk":
				anim_player_cg.play("left_idle")
			else:
				anim_player_cg.play("right_idle")

	
	var walk_speed = 90 * delta
	sleep_times += delta
	sleep_upload += delta
	yuguai_all_time += delta
	other_record()
	move_to_path(walk_speed)
	
	if is_player and sleep_upload >= max_interval_upload:
		sleep_upload = 0.0
		upload_points()
	
	
	
	if yuguai_all_time >= count_mili_yuguai and Global.get("RoleInfoManage").get_role_has_state_enemy():
		MapInfoManage.yuguai()
		yuguai_all_time = 0.0
	


func _mapeutils_map_change_(dic_map_info):
	$Camera.limit_right = dic_map_info.get("y_num", 26) * 16
	$Camera.limit_bottom = dic_map_info.get("x_num", 22) * 16 + 90
	
	path.resize(0)
	
	click_points.clear()
	
	upload_points()


func yuguai():
	
	if MapInfoManage.get_current_map_info().get("map_type", 1) != 2: return
	if not is_player: return
	if not encounter_monster_: return
	if Global.get("RoleInfoManage").get_role_has_exorcism(): return
	if NTeamManage.self_is_follow(): return
	if randi() % probability == 1:
		encounter_monster_ = false
		MapInfoManage.yuguai()


func fight_start_():
	RoleInfoManage.set_role_position(Vector2(position))


func set_name_color(info):
	if not info.has("popularity"): return
	var p = int(info["popularity"])
	if is_player: p = int(RoleInfoManage.role_info["popularity"])
	if p >= - 50 and p < 0:
		$name["custom_colors/font_color"] = Color(210 / 255.0, 105 / 255.0, 30 / 255.0, 1);
		pass
	elif p >= - 100 and p < - 50:
		$name["custom_colors/font_color"] = Color(255 / 255.0, 69 / 255.0, 0 / 255.0, 1);
	elif p <= - 100:
		$name["custom_colors/font_color"] = Color(1, 0, 0, 1);
	elif p > 0 and p <= 50:
		$name["custom_colors/font_color"] = Color(144 / 255.0, 238 / 255.0, 144 / 255.0, 1);
	elif p > 50 and p < 100:
		$name["custom_colors/font_color"] = Color(0, 1, 0.5, 1);
	elif p >= 100:
		$name["custom_colors/font_color"] = Color(0, 1, 1, 1);
	else:
		$name["custom_colors/font_color"] = Color(1, 1, 1, 1);
	


func _on_Encounter_timeout() -> void :
	encounter_monster_ = true
	Global.log_info("超时！！！！！！！！！！！")
	$Encounter.start()
	pass

func _on_reset_pet():
	if current_follow_pet != null:
		current_follow_pet.queue_free()
		current_follow_pet = null
	pass

func _on_fight_pet():
	if current_follow_pet == null:
		_on_role_pet_show_reload()
		pass
	pass
