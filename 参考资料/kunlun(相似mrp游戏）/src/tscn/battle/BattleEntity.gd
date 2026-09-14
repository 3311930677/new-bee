extends Node2D
const prefix = "BattleEntity"

onready var swtx = $SWTX
onready var vboxconttainer = $Name / VBoxContainer
onready var buffcontainer = $BuffIconBox
onready var bufftxcontainer = $BuffTxPos
onready var tx_res = preload("res://src/tscn/battle/common/Tx.tscn")
onready var num_res = preload("res://src/tscn/battle/common/NumTextLabel.tscn")
onready var text_res = preload("res://src/tscn/battle/common/BattleTextLabel.tscn")
onready var operate_res = preload("res://src/tscn/battle/common/OperateStatus.tscn")



var is_flip = false

var StaticGameData
var CombatManage
var RoleUtils

var combatScence

var private_state_round
var local_index
var static_data
var entity_data
var anim_player_zd: AnimationPlayer = null

var source_position
var atk_move = true

var curent_round_index = - 1
var curent_round_data = - 1
var curent_hit_index = - 1

func _ready() -> void :
	StaticGameData = Global.get("StaticGameData")
	CombatManage = Global.get("CombatManage")
	
	CombatManage.connect("fight_round_state_", self, "fight_round_state_")
	
	CombatManage.connect("fight_round_line_", self, "combat_fight_round_line_start")
	
	
	combatScence = Global.get_nodes_in_group("combat_scence")[0]
	combatScence.connect("round_line_start_", self, "round_start_")
	combatScence.connect("round_line_end_", self, "round_end_")
	combatScence.connect("round_show_hourglass_", self, "round_show_hourglass_")
	swtx.hide_m()
	
	if local_index > 5:
		swtx.flip = true
	
	pass


func set_pet_data(data):
	entity_data = data
	$Name.text = data["data"]["name"]
	static_data = Global.get("StaticGameData").get_pet_data(data["data"]["race_id"])
	init_common_data()
	anim_player_zd = Global.get("RoleUtils").parseZDNpc(static_data["img_dir"])
	add_child(anim_player_zd)
	anim_player_zd.play("fight_idle")
	if not is_flip:
		$Sprite.flip_h = true
	
	if static_data["atk_range"] == 0:
		atk_move = true
	else:
		atk_move = false
	
	
	var cur_pet_Rect = Global.get("RoleUtils").getPetRec(static_data["img_dir"])
	$Name.rect_position.y = - (cur_pet_Rect.size.y + 20)
	


func set_monster_data(data):
	entity_data = data
	var monster_name = entity_data["data"].get("name", null)
	static_data = Global.get("StaticGameData").get_pet_data(data["id"])
	if monster_name == null or monster_name.length() <= 1:
		$Name.text = static_data["race"]
	else:
		$Name.text = monster_name

	init_common_data()
	anim_player_zd = Global.get("RoleUtils").parseZDNpc(static_data["img_dir"])
	add_child(anim_player_zd)
	anim_player_zd.play("fight_idle")
	
	
	if static_data["atk_range"] == 0:
		atk_move = true
	else:
		atk_move = false
	
	
	var cur_pet_Rect = Global.get("RoleUtils").getPetRec(static_data["img_dir"])
	$Name.rect_position.y = - (cur_pet_Rect.size.y + 20)
	
	if Global.get("CombatManage").check_boss_room():
		$Name["custom_colors/font_color"] = Color(1, 0, 0, 1)
	elif data["data"].has("petGradeType"):
		var grade = data["data"]["petGradeType"]
		if grade == 1:
			$Name.text = str($Name.text, "[变异]")
			$Name["custom_colors/font_color"] = Color(0, 1, 1, 1)
			pass
		elif grade == 2:
			$Name.text = str($Name.text, "[宝宝]")
			$Name["custom_colors/font_color"] = Color(0, 1, 0, 1)
			pass
		elif grade == 3:
			$Name.text = str($Name.text, "[精英]")
			$Name["custom_colors/font_color"] = Color(1, 165 / 255.0, 79 / 255.0)
			pass
		elif grade == 4:
			$Name["custom_colors/font_color"] = Color(1, 1, 1, 1)
			pass
		elif grade == 5:
			$Name["custom_colors/font_color"] = Color(1, 0, 0, 1)



func set_player_data(data):
	entity_data = data
	$Name.text = data["data"]["name"]
	init_common_data()
	var role_type = Global.get("StaticGameData").get_role_type(data["data"]["race_id"], data["data"]["job_id"], data["data"]["division_id"])
	anim_player_zd = Global.get("RoleUtils").parseZDRole(role_type["role_type"], role_type["sex"])
	add_child(anim_player_zd)
	anim_player_zd.play("fight_idle")
	$Sprite.scale = Vector2(1.2, 1.2)
	
	if data["data"]["job_id"] == 2:
		atk_move = false
	
	if local_index <= 5:
		$Sprite.flip_h = true
	
	var popularity = data["data"].get("popularity", 0)
	var color = Global.get("StaticGameData").get_popularity_color(popularity)
	$Name["custom_colors/font_color"] = color

func init_common_data():
	$BuffIconBox.real_index = entity_data["index"]
	$BuffTxPos.real_index = entity_data["index"]
	if local_index < 6: $hourglass.hide()
	pass


func set_face_direction(dir):
	if dir == 1:
		$Sprite.flip_h = false
	if dir == 2:
		$Sprite.flip_h = true














func round_start_(data, round_index):
	private_state_round = 0
	var behavior = data["behavior"]
	if entity_data["index"] != behavior["entity_index"]: return
	
	curent_round_index = round_index
	curent_round_data = data
	match int(behavior["type"]):
		1:
			
			normal_atk()
			pass
		2:
			skill_atk()
			
			pass
		3:
			run_away()
			
			pass
		4:
			catch_pet()
			
			pass
		5:
			
			pass
		6:
			
			back_life()
			pass
		7:
			back_atk()
			pass
		8:
			
			anti_shock()
			pass
		9:
			
			recover_hmp()
			pass




func round_end_(data, round_index):
	curent_hit_index = - 1
	private_state_round = 1
	var behavior = data["behavior"]
	var s_data = data["data"]
	var targets = behavior["targets"]
	var index = targets.find(entity_data["index"])
	if index == - 1: return
	
	curent_hit_index = index
	
	curent_round_index = round_index
	curent_round_data = data
	
	
	
	match int(behavior["type"]):
		8:
			
			sj_anti_shock()
			return
	
	var hit_action = false
	
	if show_sj_num(): hit_action = true
	
	
	if hit_action: anim_player_zd.play("hit")
	else:
		
		show_sj_tx()
		$NoHitAnim.start(0.5)

func combat_fight_round_line_start(data):
	data = data["data"]
	
	var start_data = data["round_start_data"]
	
	for info in start_data:
		if info["entity_index"] == entity_data["index"]:
			
			run_start_data(info)
			pass
	
	
	
	var end_data = data["round_end_data"]
	for info in start_data:
		if info["entity_index"] == entity_data["index"]:
			
			run_end_data(info)
			pass
	pass


func run_start_data(data_info):
	var dic_buffs = data_info["buff_result"]
	
	var arr_keys = ["bloodBack_hp", "poison_hp", "bleed_hp"]
	
	for key in arr_keys:
		if dic_buffs.has(key):
			for bl in dic_buffs.get(key, []):
				var num = bl
				var num_ins = num_res.instance()
				set_hp(num)
				if bl > 0:
					num_ins.set_num_data(num, 1, false)
				else:
					num_ins.set_num_data(num, 0, false)
				vboxconttainer.add_child(num_ins)
	
	if dic_buffs.has("bloodBack_mp"):
		for bm in dic_buffs.get("bloodBack_mp", []):
			var num = bm
			var num_ins = num_res.instance()
			set_mp(num)
			num_ins.set_num_data(num, 2, false)
			vboxconttainer.add_child(num_ins)
		pass
	
	if data_info.get("is_death", false):
		death()
		pass


func run_end_data(data_info):
	pass


func run_away_complate():
	
	combatScence.run_away(curent_round_data)
	combatScence.sub_round_end_ok(curent_round_index)

	pass

func back_life_tx_compkate_():
	
	hit_finish()
	pass


func catch_tx_timeout_():
	
	combatScence.sub_round_end_ok(curent_round_index)

	
	if curent_round_data["data"]["is_success"]:
		
		combatScence.catch_pet(curent_round_data)
	else:
		
		pass


func normal_atk():
	show_txt("普攻")
	anim_player_zd.play("atk1")


func skill_atk():
	var skill_id = curent_round_data["behavior"]["data"]["skill_id"]
	var skill_info = StaticGameData.get_skill_data(skill_id)
	var attack_model = skill_info["attack_model"]
	
	show_txt(skill_info["name"])
	
	if anim_player_zd.has_animation(str("atk1", attack_model)):
		anim_player_zd.play(str("atk1", attack_model))
	else:
		if anim_player_zd.has_animation("atk1攻击二"):
			anim_player_zd.play("atk1攻击二")
		elif anim_player_zd.has_animation("atk1攻击三"):
			anim_player_zd.play("atk1攻击三")
		else: anim_player_zd.play("atk1")

func run_away():
	
	var run_a = curent_round_data["data"].get("is_runAway", false)
	var op = operate_res.instance()
	vboxconttainer.add_child(op)
	op.connect("operate_time_out", self, "run_away_complate")
	if run_a:
		
		op.show_taopao(true)
	else:
		
		op.show_taopao()

func catch_pet():
	show_txt("捕捉")
	anim_player_zd.play("atk1catch")
	pass



func recover_hmp():
	
	
	var hp = curent_round_data["data"]["hp"]

	var txt = curent_round_data["data"].get("text", null)
	if txt != null and txt.length() > 1:
		show_txt(txt)
	
	var num = num_res.instance()
	set_hp(hp)
	if hp > 0:
		num.set_num_data(hp, 1, false)
	else:
		num.set_num_data(hp, 0, false)
	vboxconttainer.add_child(num)
	
	hit_finish()
	pass


func back_life():
	
	revive()
	
	var tx = tx_res.instance()
	tx.play_animation_name = "24"
	
	var hp = curent_round_data["data"]["hp"]
	
	var num = num_res.instance()
	set_hp(hp)
	num.set_num_data(hp, 1, false)
	vboxconttainer.add_child(num)
	
	tx.connect("tx_timeout", self, "back_life_tx_compkate_")
	add_child(tx)


func back_atk():
	show_txt("反击")
	anim_player_zd.play("atk1")
	pass


func anti_shock():
	
	show_txt("反震")
	combatScence.sub_round_start_ok(curent_round_index)
	pass

func sj_anti_shock():
	
	show_sj_num()
	
	show_sj_tx()
	
	$NoHitAnim.start(0.3)
	pass


func move_target():
	var behavior = curent_round_data["behavior"]
	var obj_entity = combatScence.real_index[str(behavior["targets"][0])]
	var of = 30
	if local_index < 6:
		position = obj_entity.position - Vector2(of, 0)
	else:
		position = obj_entity.position + Vector2(of, 0)
	pass


func reset_position():
	position = source_position


func show_sj_tx():
	var behavior = curent_round_data["behavior"]
	var tx = tx_res.instance()
	var is_show_tx = true
	
	
	if int(behavior["type"]) == 1 or int(behavior["type"]) == 7 or int(behavior["type"]) == 8:
		
		var f_en_info = combatScence.get_real_entity_info(behavior["entity_index"])
			
		if f_en_info["type"] == 3:
			is_show_tx = false
		tx.play_animation_name = "0"
		
	elif int(behavior["type"]) == 2:
		var skill_id = behavior["data"]["skill_id"]
		var skill_info = StaticGameData.get_skill_data(skill_id)
		
		var tx_id = skill_info["tx_id"]
		tx.play_animation_name = str(tx_id)
	
	elif int(behavior["type"]) == 4:
		tx.play_animation_name = "-1"
		tx.connect("tx_timeout", self, "catch_tx_timeout_")
	
	if is_show_tx:
		add_child(tx)
	else:
		tx.queue_free()


func show_sj_num():
	
	if not curent_round_data["data"].has("target_results"): return false
	
	var hit_info = curent_round_data["data"]["target_results"][curent_hit_index]
	
	entity_data["death"] = hit_info.get("is_death", false)
	
	var cirit = hit_info.get("is_crit", false)
	
	var hit_action = false
	
	if hit_info.get("hps", []).size() > 0:
		var hps = hit_info["hps"]
		for hp in hps:
			var num = num_res.instance()
			set_hp(hp)
			if hp < 0:
				hit_action = true
				num.set_num_data(hp, 0, cirit)
			else:
				
				num.set_num_data(hp, 1, cirit)
			vboxconttainer.add_child(num)
	if hit_info.get("mps", []).size() > 0:
		var mps = hit_info["mps"]
		for mp in mps:
			var num = num_res.instance()
			num.set_num_data(mp, 2, cirit)
			vboxconttainer.add_child(num)
			set_mp(mp)
	if hit_info.get("buffs", []).size() > 0:
		var buffs = hit_info["buffs"]
		
		for buff in buffs:
			Global.log_info(str(buff["desc"]))
			
			var txt = text_res.instance()

			txt.set_bbcode_txt(buff["name"], buff["desc"])
			vboxconttainer.add_child(txt)
			
			buffcontainer.add_buff(buff)
			
			bufftxcontainer.add_buff(buff)
	var txt_ = hit_info.get("text", null)
	if txt_ != null and txt_.length() > 1:
		show_txt(txt_)
	
	if hit_info.get("dodge", false) and hit_action == false:
		anim_player_zd.play("dodge")
		var num = num_res.instance()
		num.set_num_data(0, 0, false)
		vboxconttainer.add_child(num)
		return false
	return hit_action


func show_self_state():
	
	if curent_round_data["behavior"]["data"].has("self_result"):
		var self_results = curent_round_data["behavior"]["data"]["self_result"]
		var cirit = self_results.get("is_crit", false)
		if self_results.get("hps", []).size() > 0:
			var hps = self_results["hps"]
			for hp in hps:
				var num = num_res.instance()
				set_hp(hp)
				if hp < 0:
					num.set_num_data(hp, 0, cirit)
				else:
					
					num.set_num_data(hp, 1, cirit)
				vboxconttainer.add_child(num)
		if self_results.get("mps", []).size() > 0:
			var mps = self_results["mps"]
			for mp in mps:
				set_mp(mp)
				if mp > 0:
					var num = num_res.instance()
					num.set_num_data(mp, 2, cirit)
					vboxconttainer.add_child(num)
			pass
		if self_results.get("buffs", []).size() > 0:
			var buffs = self_results["buffs"]
			
			for buff in buffs:
				
				Global.log_info(str(buff["desc"]))
				
				var txt = text_res.instance()

				txt.set_bbcode_txt(buff["name"], buff["desc"])
				vboxconttainer.add_child(txt)
				
				buffcontainer.add_buff(buff)
				
				bufftxcontainer.add_buff(buff)
		var txt_ = self_results.get("text", null)
		if txt_ != null and txt_.length() > 1:
			show_txt(txt_)
	
	if curent_round_data["behavior"]["type"] == 4:
		var suc = curent_round_data["data"]["is_success"]
		
		var op = operate_res.instance()
		vboxconttainer.add_child(op)
		if suc:
			op.show_catch(true)
			pass
		else:
			op.show_catch()
			pass


func death():
	set_hp( - 99999)
	$Sprite.hide()
	$BuffIconBox.hide()
	$BuffIconBox.clear()
	swtx.start_m()
	pass


func revive():
	$Sprite.show()
	$BuffIconBox.show()
	swtx.hide_m()
	entity_data["death"] = false
	entity_data["attr"]["hp"] = 0
	pass

func is_death():
	return entity_data["death"]


func set_hp(num):
	entity_data["attr"]["hp"] += num
	
	if is_death():
		
		if entity_data["type"] == 1 and entity_data["id"] == Global.get("RoleInfoManage").get_role_id():
			var arr = Global.get_nodes_in_group("main_head")
			if arr.size() > 0:
				arr[0].set_role_hp(0, entity_data["attr"]["max_hp"])
			pass
		if entity_data["type"] == 2 and entity_data["id"] == Global.get("PetInfoManage").get_fight_pet_id():
			var arr = Global.get_nodes_in_group("main_head")
			if arr.size() > 0:
				arr[0].set_pet_hp(0, entity_data["attr"]["max_hp"])
			pass
		return
	
	if entity_data["attr"]["hp"] <= 0: entity_data["attr"]["hp"] = 0
	if entity_data["attr"]["hp"] > entity_data["attr"]["max_hp"]: entity_data["attr"]["hp"] = entity_data["attr"]["max_hp"]
	
	
	if entity_data["type"] == 1 and entity_data["id"] == Global.get("RoleInfoManage").get_role_id():
		var arr = Global.get_nodes_in_group("main_head")
		if arr.size() > 0:
			arr[0].set_role_hp(entity_data["attr"]["hp"], entity_data["attr"]["max_hp"])
		pass
	if entity_data["type"] == 2 and entity_data["id"] == Global.get("PetInfoManage").get_fight_pet_id():
		var arr = Global.get_nodes_in_group("main_head")
		if arr.size() > 0:
			arr[0].set_pet_hp(entity_data["attr"]["hp"], entity_data["attr"]["max_hp"])





func set_mp(num):
	
	entity_data["attr"]["mp"] += num
	
	if is_death(): return
	
	if entity_data["attr"]["mp"] <= 0:
		entity_data["attr"]["mp"] = 0
	
	if entity_data["attr"]["mp"] > entity_data["attr"]["max_mp"]:
		entity_data["attr"]["mp"] = entity_data["attr"]["max_mp"]
	
	if entity_data["type"] == 1 and entity_data["id"] == Global.get("RoleInfoManage").get_role_id():
		var arr = Global.get_nodes_in_group("main_head")
		if arr.size() > 0:
			arr[0].set_role_mp(entity_data["attr"]["hp"], entity_data["attr"]["max_hp"])
		pass
	
	if entity_data["type"] == 2 and entity_data["id"] == Global.get("PetInfoManage").get_fight_pet_id():
		var arr = Global.get_nodes_in_group("main_head")
		if arr.size() > 0:
			arr[0].set_pet_mp(entity_data["attr"]["mp"], entity_data["attr"]["max_mp"])
		pass



func show_txt(txt, model = 0):
	var txt_ = text_res.instance()
	txt_.set_m_text(txt)
	txt_.set_m_color_model(model)
	vboxconttainer.add_child(txt_)





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
	
	show_self_state()
	
	combatScence.sub_round_start_ok(curent_round_index)
	
	anim_player_zd.play("fight_idle")
	if entity_data["death"]:
		death()



func hit_start():
	
	show_sj_tx()
	pass

func hit_finish():
	anim_player_zd.play("fight_idle")
	
	if entity_data["death"]:
		death()
		pass
	
	combatScence.sub_round_end_ok(curent_round_index)
	pass

func dodge_start():
	pass

func dodge_finish():
	anim_player_zd.play("fight_idle")
	
	if entity_data["death"]:
		death()
		pass
	combatScence.sub_round_end_ok(curent_round_index)



func fight_round_state_(data):
	if entity_data["index"] == data["index"]:
		$hourglass.hide()


func round_show_hourglass_():
	
	if local_index > 5 and not is_death():
		$hourglass.show()
	pass


func _on_NoHitAnim_timeout() -> void :
	hit_finish()


func _on_show_info_pressed() -> void :
	Global.log_info(entity_data)
	pass
