extends Node2D

onready var swtx = $SWTX

onready var hourglass = $hourglass

onready var vboxconttainer = $Name / VBoxContainer

onready var buffcontainer = $BuffIconBox

onready var bufftxcontainer = $BuffTxPos

onready var sprite_texure = $Sprite

onready var sleep_finish = $SleepFinish
onready var sleep_start = $SleepStart

onready var catch_escape = $CatchEscape


onready var atk_hit_self_timer = $AtkHitSelf

var line_process_res = load("res://src/tscn/scence/battle/entity/BattleProcessLine.gd")

var anim_player_zd: AnimationPlayer = null

var source_position

var atk_move = true

var static_data = null
var entity_data = null

var tb_battle_scence
var StaticGameData
var TBBattleManage

var process_line = null

var local_index = - 1


var real_index = - 1


func _ready() -> void :
	process_line = line_process_res.new()
	process_line.battleEntity = self
	
	StaticGameData = Global.get("StaticGameData")
	TBBattleManage = Global.get("TBBattleManage")
	TBBattleManage.connect("operation_ready_success", self, "operation_ready_success_")
	real_index = entity_data["index"]
	
	
	if entity_data["index"] <= 6: hourglass.hide()
	local_index = int(local_index)
	real_index = int(real_index)
	
	TBBattleManage.current_local_position_map[str(local_index)] = self
	
	
	
	tb_battle_scence = Global.get_nodes_in_group("tb_battle_scence")[0]
	tb_battle_scence.connect("round_line_start_", self, "round_line_start_")
	tb_battle_scence.connect("battle_round_start_", self, "battle_round_start_")
	tb_battle_scence.connect("round_line_end_", self, "round_line_end_")
	tb_battle_scence.connect("round_show_hourglass_", self, "round_show_hourglass_")
	
	source_position = self.position
	
	
	
	swtx.hide_m()
	
	if local_index > 6: swtx.fliph()
	if local_index <= 6: hourglass.hide()
		
	
	
	if entity_data["death"]:
		process_line.private_death_heck()
	
	if entity_data["snap"]:
		queue_free()
		pass
	pass


func battle_round_start_():
	hourglass.hide()
	pass


func round_start(starts):
	if not starts.has(str(real_index)): return
	process_line.round_start_data(starts[str(real_index)])
	pass


func round_line_start_(round_line):
	process_line.round_line_start(round_line)
	pass


func round_line_end_(round_line):
	process_line.round_line_end(round_line)
	pass


func round_end(ends):
	if not ends.has(str(real_index)): return
	var self_end_data = ends[str(real_index)]
	
	process_line.round_end_data(self_end_data)
	pass




func operation_ready_success_(index):
	if int(index) == real_index:
		hourglass.hide()
	pass


func move_target():
	
	
	var target_real_index = process_line.current_line_data["harms"].keys().front()
	var keys = process_line.current_line_data["harms"].keys()
	if keys.size() > 1:
		
		for k in keys:
			if int(k) != real_index: target_real_index = k
		pass
	
	
	if target_real_index == null: return
	
	var local_map = TBBattleManage.current_local_position_map
	var obj_entity = null
	for i in local_map.keys():
		if not is_instance_valid(local_map[i]): continue
		if int(local_map[i].entity_data["index"]) == int(target_real_index):
			obj_entity = local_map[i]
	
	var of = 30
	if obj_entity == null: return
	if local_index < 6:
		position = obj_entity.position - Vector2(of, 0)
	else:
		position = obj_entity.position + Vector2(of, 0)
	pass


func reset_position():
	position = source_position




















func atk1_start_offset(skill_name: String, arg1_int):
	pass


func atk1_finish_offset(skill_name: String, arg1_int):
	if arg1_int == 1 and atk_move:
		move_target()
	anim_player_zd.play("atk2" + skill_name)



func atk2_start_offset(skill_name: String, arg1_int):
	pass


func atk2_finish_offset(skill_name: String, arg1_int):
	if arg1_int == 1 and atk_move:
		reset_position()
	
	
	process_line.line_action_start_finish()
	
	anim_player_zd.play("fight_idle")


func hit_start():
	
	process_line.show_hit_action()
	pass

func hit_finish():
	anim_player_zd.play("fight_idle")
	process_line.line_action_end_finish()
	pass

func dodge_start():
	process_line.show_hit_action()
	pass

func dodge_finish():
	anim_player_zd.play("fight_idle")
	process_line.line_action_end_finish()
	pass









func round_show_hourglass_():
	if local_index <= 6: hourglass.hide()
	else:
		if not entity_data["death"]: hourglass.show()
	pass















































func set_pet_data(data):
	entity_data = data
	$Name.text = data["otherData"]["name"]
	static_data = Global.get("StaticGameData").get_pet_data(data["otherData"]["raceId"])
	
	anim_player_zd = Global.get("RoleUtils").parseZDNpc(static_data["img_dir"])
	add_child(anim_player_zd)
	anim_player_zd.play("fight_idle")
	if local_index > 6:
		$Sprite.flip_h = true
	
	if static_data["atk_range"] == 0:
		atk_move = true
	else:
		atk_move = false
	
	
	var cur_pet_Rect = Global.get("RoleUtils").getPetRec(static_data["img_dir"])
	$Name.rect_position.y = - (cur_pet_Rect.size.y + 20)
	


func set_monster_data(data):
	entity_data = data
	
		
	var monster_name = entity_data["otherData"].get("name", null)
	static_data = Global.get("StaticGameData").get_pet_data(data["otherData"]["raceId"])
	if monster_name == null or monster_name.length() <= 1:
		$Name.text = static_data["race"]
	else:
		$Name.text = monster_name

	
	anim_player_zd = Global.get("RoleUtils").parseZDNpc(static_data["img_dir"])
	
	if anim_player_zd == null:
		if static_data["atk_range"] == 0:
			anim_player_zd = Global.get("RoleUtils").parseZDNpc("gw_kuangshi")
		else:
			anim_player_zd = Global.get("RoleUtils").parseZDNpc("gw_shuyao")
	add_child(anim_player_zd)
	anim_player_zd.play("fight_idle")
	
	
	if static_data["atk_range"] == 0:
		atk_move = true
	else:
		atk_move = false
	
	
	var cur_pet_Rect = Global.get("RoleUtils").getPetRec(static_data["img_dir"])
	if cur_pet_Rect == null:
		if static_data["atk_range"] == 0:
			cur_pet_Rect = Global.get("RoleUtils").getPetRec("gw_kuangshi")
		else:
			cur_pet_Rect = Global.get("RoleUtils").getPetRec("gw_shuyao")
		
		
	$Name.rect_position.y = - (cur_pet_Rect.size.y + 20)
	
	if Global.get("TBBattleManage").get_battle_room_type() == 3:
		$Name["custom_colors/font_color"] = Color(1, 0, 0, 1)
	elif data["otherData"].has("monsterGrade"):
		var grade = data["otherData"]["monsterGrade"]
		if grade == 0:
			$Name.text = str($Name.text, "[变异]")
			$Name["custom_colors/font_color"] = Color(0, 1, 1, 1)
			pass
		elif grade == 1:
			$Name.text = str($Name.text, "[宝宝]")
			$Name["custom_colors/font_color"] = Color(0, 1, 0, 1)
			pass
		elif grade == 2:
			$Name.text = str($Name.text, "[精英]")
			$Name["custom_colors/font_color"] = Color(1, 165 / 255.0, 79 / 255.0)
			pass
		elif grade == 4:
			$Name["custom_colors/font_color"] = Color(1, 0, 0)
		else:
			$Name["custom_colors/font_color"] = Color(1, 1, 1, 1)
			pass


func set_player_data(data):
	entity_data = data
	$Name.text = data["otherData"]["name"]
	
	var role_type = Global.get("StaticGameData").get_role_type(data["otherData"]["raceId"], data["otherData"]["jobId"], data["otherData"]["divisionId"])
	anim_player_zd = Global.get("RoleUtils").parseZDRole(role_type["role_type"], role_type["sex"])
	add_child(anim_player_zd)
	anim_player_zd.play("fight_idle")
	$Sprite.scale = Vector2(1.2, 1.2)
	
	if data["otherData"]["jobId"] == 2:
		atk_move = false
	
	if local_index <= 6:
		$Sprite.flip_h = true
	
	
	var popularity = data["otherData"].get("popularity", 0)
	var color = Global.get("StaticGameData").get_popularity_color(popularity)
	$Name["custom_colors/font_color"] = color



func _on_SleepFinish_timeout() -> void :
	process_line.line_action_end_finish()
	pass


func _on_CatchEscape_timeout() -> void :
	process_line.timer_catch_escape_timeout()
	pass



func _on_AtkHitSelf_timeout() -> void :
	process_line.timer_atk_hit_self_timeout()
	pass


func _on_SleepStart_timeout() -> void :
	process_line.line_action_start_finish()
	pass
