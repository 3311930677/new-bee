extends Node




var number_res = load("res://src/tscn/battle/common/NumTextLabel.tscn")

var text_res = load("res://src/tscn/battle/common/BattleTextLabel.tscn")

var operation_res = load("res://src/tscn/battle/common/OperateStatus.tscn")

var tx_res = load("res://src/tscn/battle/common/Tx.tscn")


var battleEntity = null

var current_line_data


var StaticGameData
var DicStaticGameData

func _init() -> void :
	StaticGameData = Global.get("StaticGameData")
	DicStaticGameData = Global.get("DicStaticGameData")
	
	pass






func round_start_data(data):
	var attr = data["battleAttr"]
	setChangeHp(float(attr["returnHp"]))
	setChangeHp(float(attr["bleedHp"]))
	setChangeMp(float(attr["returnMp"]))
	setChangeMp(float(attr["bleedMp"]))
	
	
	if int(attr["returnHp"]) > 0:
		var return_hp_num = number_res.instance()
		return_hp_num.set_num_data(int(attr["returnHp"]), 1, false)
		battleEntity.vboxconttainer.add_child(return_hp_num)
	
	
	if int(attr["bleedHp"]) < 0:
		var bleed_hp_num = number_res.instance()
		bleed_hp_num.set_num_data(int(attr["bleedHp"]), 0, false)
		battleEntity.vboxconttainer.add_child(bleed_hp_num)
	
	
	if int(attr["returnMp"]) > 0:
		var return_mp_num = number_res.instance()
		return_mp_num.set_num_data(int(attr["returnMp"]), 2, false)
		battleEntity.vboxconttainer.add_child(return_mp_num)
	
	
	if int(attr["bleedMp"]) < 0:
		var bleed_mp_num = number_res.instance()
		bleed_mp_num.set_num_data(int(attr["bleedMp"]), 2, false)
		battleEntity.vboxconttainer.add_child(bleed_mp_num)
	
	
	
	if battleEntity.entity_data["otherData"]["hp"] <= 0:
		battleEntity.entity_data["death"] = true
		private_death_heck()
	pass



func round_end_data(data):
	
	private_end_process_buff_id(data["removeBuffs"], true)



func round_line_start(data):
	if int(data["atkIndex"]) != battleEntity.real_index: return
	
	current_line_data = data
	
	var str_behavior = data["behaviorType"]
	
	if str_behavior == "ATTACK":
		line_atk_start()
	elif str_behavior == "SKILL_ATTACK":
		line_skill_start()
		pass
	elif str_behavior == "CAPTURE_ACTION":
		line_capture_start()
		pass
	elif str_behavior == "ESCAPE_ACTION":
		line_escape_start()
		pass
	elif str_behavior == "REBORN_ACTION":
		line_reborn_start()
		pass
	elif str_behavior == "COUNTER_ATTACK":
		line_counter_start()
		pass
	elif str_behavior == "RESTRICT_ACTION":
		line_restrice_start()
		pass
	pass


func round_line_end(data):
	current_line_data = data
	
	if not data["harms"].has(str(battleEntity.real_index)): return
	
	
	var harms = data["harms"][str(battleEntity.real_index)]
	
	
	
	
	
	
	if harms["dodge"]: battleEntity.anim_player_zd.play("dodge")
	else:
		
		show_sj_tx()
		if private_check_has_harm():
			
			if private_atk_hit_is_self():
				
				battleEntity.atk_hit_self_timer.start()
			else:
				battleEntity.anim_player_zd.play("hit")
		else:
			
			
			if current_line_data["behaviorType"] == "CAPTURE_ACTION":
				battleEntity.anim_player_zd.play("hit")
			else:
				battleEntity.sleep_finish.start()
	private_end_process_buff_id(harms.get("removeBuffIds", []), true)
	private_end_process_buff_id(harms.get("addBuffIds", []), false)





func line_atk_start():
	
	battleEntity.anim_player_zd.play("atk1")
	pass

func line_skill_start():
	
	
	var sk_data = StaticGameData.get_skill_data_temp(int(current_line_data["skillId"]))
	
	
	show_battle_txt(sk_data["name"])
	
	if private_check_has_harm():
		
		
		
		if battleEntity.anim_player_zd.has_animation(str("atk1", sk_data["attack_model"])):
			battleEntity.anim_player_zd.play(str("atk1", sk_data["attack_model"]))
		else:
			if battleEntity.anim_player_zd.has_animation("atk1攻击二"):
				battleEntity.anim_player_zd.play("atk1攻击二")
			elif battleEntity.anim_player_zd.has_animation("atk1攻击三"):
				battleEntity.anim_player_zd.play("atk1攻击三")
			else: battleEntity.anim_player_zd.play("atk1")
	else:
		
		
		var model_atk = str("atk1", sk_data["attack_model"])
		if battleEntity.anim_player_zd.has_animation(model_atk):
			battleEntity.anim_player_zd.play(model_atk)
		else:
			
			battleEntity.sleep_start.start()

		pass
	

func line_escape_start():
	
	var run = current_line_data["self"]["runaway"]
	var op = operation_res.instance()
	battleEntity.vboxconttainer.add_child(op)
	if not run:
		op.show_taopao()
		battleEntity.sleep_finish.start()
	else:
		op.show_taopao(true)
		
		battleEntity.catch_escape.start()

func line_capture_start():
	show_battle_txt("捕捉")
	battleEntity.anim_player_zd.play("atk1catch")
	
	

func line_restrice_start():
	var self_data = current_line_data["self"]
	var formatChangeAttrs = self_data["formatChangeAttr"].split("&")
	for i in formatChangeAttrs:
		if i.empty(): continue
		var arr_k_v = i.split(":")
		var key = arr_k_v[0]
		var value = arr_k_v[1]
		var attach_txt = ""
		
		if key == "restrict_type":
			if value == "immobilize": attach_txt = "(定身)"
			if value == "lethargy": attach_txt = "(睡眠)"
		show_battle_txt(str("限制行动", attach_txt), 1)
	
	battleEntity.sleep_finish.start()
	pass

func line_counter_start():
	show_battle_txt("反击", 2)
	line_atk_start()
	pass

func line_reborn_start():
	show_battle_txt("复活", 2)
	private_revive()
	show_self_num()
	battleEntity.entity_data["death"] = false
	battleEntity.sleep_finish.start()
	pass



func line_action_start_finish():
	
	private_show_self_state()
	battleEntity.tb_battle_scence.round_line_start_complate()
	pass


func line_action_end_finish():
	
	battleEntity.tb_battle_scence.round_line_end_complate()
	
	
	var harm_item = private_get_round_item_harm()
	if current_line_data["behaviorType"] == "CAPTURE_ACTION":
		if not harm_item.empty() and harm_item["snap"]:
			
			private_remove_self()
	pass



func timer_catch_escape_timeout():
	
	battleEntity.tb_battle_scence.round_line_end_complate()
	private_remove_self_and_pet()
	pass



func timer_atk_hit_self_timeout():
	
	battleEntity.anim_player_zd.play("hit")
	pass













func private_end_process_buff_id(arr_buff_id, removeable = false):
	
	for buff_info in arr_buff_id:
		
		if removeable:
			
			battleEntity.buffcontainer.remove_buff(buff_info)
			
			battleEntity.bufftxcontainer.remove_buff(buff_info)
		else:
			
			
			var tips = DicStaticGameData.buff_tx_tips.get(str(buff_info["buffId"]), null)
			if tips != null: show_battle_bbcode_txt(tips)
			
			
			battleEntity.buffcontainer.add_buff(buff_info)
			
			battleEntity.bufftxcontainer.add_buff(buff_info)


func private_show_self_state():
	
	var self_data = current_line_data["self"]
	
	battleEntity.entity_data["death"] = self_data.get("death", false)
	
	
	private_end_process_buff_id(self_data["addBuffIds"], false)
	private_end_process_buff_id(self_data["removeBuffIds"], true)
	
	
	show_self_num()
	
	
	if current_line_data["behaviorType"] == "CAPTURE_ACTION":
		var keys = current_line_data["harms"].keys()
		if keys.size() <= 0:
			Global.log_info(str("捕捉数据出现错误"))
			return
		var item_harm_ = current_line_data["harms"][keys.front()]
		
		var op = operation_res.instance()
		battleEntity.vboxconttainer.add_child(op)
		if item_harm_["snap"]: op.show_catch(true)
		else: op.show_catch()
	
	
	private_death_heck()
	pass


func show_hit_action():
	var harm_item = private_get_round_item_harm()
	show_battle_sj_tx()
	if not harm_item.empty():
		
		if harm_item["dodge"]:
			var num = number_res.instance()
			num.set_num_data(null, 0, false)
			battleEntity.vboxconttainer.add_child(num)
		else:
			
			show_sj_num()
			show_sj_other_state()
		
	private_death_heck()




func show_self_num():
	var self_data = current_line_data["self"]
	var arr_attrs_values = self_data["formatChangeAttr"].split("&")
	
	for item in arr_attrs_values:
		if item.empty(): continue
		var arr_key_value = item.split(":")
		var attr = arr_key_value[0]
		var value = float(arr_key_value[1])
		
		if attr == "Hp":
			var num = number_res.instance()
			setChangeHp(value)
			var mode = 0
			if value > 0: mode = 1
			num.set_num_data(value, mode, false)
			battleEntity.vboxconttainer.add_child(num)
			pass
		if attr == "Mp":
			setChangeMp(value)
			var num = number_res.instance()
			num.set_num_data(value, 2, false)
			battleEntity.vboxconttainer.add_child(num)
			pass
	
	
	var mmp = float(self_data["addMp"])
	setChangeMp(mmp)
	pass


func show_sj_tx():
	var behavior = current_line_data["behaviorType"]
	
	var skill_id = int(current_line_data["skillId"])
	
	
	var tx = tx_res.instance()
	var is_show_tx = true
	
	if behavior == "ATTACK" or behavior == "COUNTER_ATTACK":
		tx.play_animation_name = "0"
	elif behavior == "SKILL_ATTACK":
		var skill_info = StaticGameData.get_skill_data_temp(skill_id)
		tx.play_animation_name = str(skill_info["tx_id"])
	elif behavior == "CAPTURE_ACTION":
		tx.play_animation_name = "-1"
	else: is_show_tx = false
	if is_show_tx:
		battleEntity.add_child(tx)
	else:
		tx.queue_free()


func show_sj_num():
	
	
	var harm_item = private_get_round_item_harm()
	if harm_item.empty(): return
	
	
	battleEntity.entity_data["death"] = harm_item.get("death", false)
	
	
	var bash = harm_item.get("bash", false)
	
	var hit_action = false
	
	if harm_item.get("hps", []).size() > 0:
		var hps = harm_item["hps"]
		for hp in hps:
			if hp == 0: continue
			var num = number_res.instance()
			setChangeHp(hp)
			if hp < 0:
				num.set_num_data(hp, 0, bash)
			else:
				
				num.set_num_data(hp, 1, bash)
			battleEntity.vboxconttainer.add_child(num)
	if harm_item.get("mps", []).size() > 0:
		var mps = harm_item["mps"]
		for mp in mps:
			var num = number_res.instance()
			num.set_num_data(mp, 2, bash)
			battleEntity.vboxconttainer.add_child(num)
			setChangeMp(mp)
	
	
	

func show_sj_other_state():
	var harm_item = private_get_round_item_harm()
	if harm_item.empty(): return
	var str_format = harm_item["attachFormatData"]
	var arr_kv = str_format.split("&")
	var a = ""
	
	for kv in arr_kv:
		if kv.length() <= 1 or kv.empty(): continue
		var ar_kv = kv.split(":")
		var key = ar_kv[0]
		var value = ar_kv[1]
		
		if key == "tips": show_battle_txt(value, 1)
		if key == "Hp":
			var hp = int(value)
			var num = number_res.instance()
			setChangeHp(hp)
			if hp <= 0:
				num.set_num_data(hp, 0, false)
			else:
				
				num.set_num_data(hp, 1, false)
			battleEntity.vboxconttainer.add_child(num)
		if key == "Mp":
			var mp = int(value)
			var num = number_res.instance()
			num.set_num_data(mp, 2, false)
			battleEntity.vboxconttainer.add_child(num)
			setChangeMp(mp)
			


func show_battle_txt(txt, model = 0):
	var txt_ = text_res.instance()
	txt_.set_m_text(txt)
	txt_.set_m_color_model(model)
	battleEntity.vboxconttainer.add_child(txt_)

func show_battle_bbcode_txt(txt):
	var txt_ = text_res.instance()
	txt_.set_bbcode_txt(txt)
	battleEntity.vboxconttainer.add_child(txt_)
	pass


func show_battle_sj_tx():
	var behavior = current_line_data["behaviorType"]
	
	
	if behavior == "RESTRICT_ACTION": return
	
	var tx = tx_res.instance()
	var is_show_tx = true
	
	
	if behavior == "ATTACK" or behavior == "COUNTER_ATTACK":
		tx.play_animation_name = "0"
		
	elif behavior == "SKILL_ATTACK":
		var skill_id = current_line_data["skillId"]
		var skill_info = StaticGameData.get_skill_data_temp(skill_id)
		
		var tx_id = skill_info["tx_id"]
		tx.play_animation_name = str(tx_id)
	
	elif behavior == "CAPTURE_ACTION":
		tx.play_animation_name = "-1"
		tx.connect("tx_timeout", self, "catch_tx_timeout_")
	
	battleEntity.add_child(tx)



func private_death_heck():
	if battleEntity.entity_data["death"]:
		
		setChangeHp( - 999999)
		battleEntity.sprite_texure.hide()
		battleEntity.buffcontainer.hide()
		
		for item in battleEntity.bufftxcontainer.get_children():
			item.queue_free()
		
		battleEntity.swtx.start_m()
		pass
	pass


func private_revive():
	battleEntity.sprite_texure.show()
	battleEntity.buffcontainer.show()
	battleEntity.swtx.hide_m()
	if battleEntity.entity_data["death"] or battleEntity.entity_data["otherData"]["hp"] <= 0:
		battleEntity.entity_data["otherData"]["hp"] = 0
	battleEntity.entity_data["death"] = false
	pass





func setChangeHp(change_value):
	battleEntity.entity_data["otherData"]["hp"] += float(change_value)
	if battleEntity.entity_data["otherData"]["hp"] > battleEntity.entity_data["otherData"]["maxHp"]:
		battleEntity.entity_data["otherData"]["hp"] = battleEntity.entity_data["otherData"]["maxHp"]
	pass
func setChangeMp(change_value):
	battleEntity.entity_data["otherData"]["mp"] += float(change_value)
	if battleEntity.entity_data["otherData"]["mp"] > battleEntity.entity_data["otherData"]["maxMp"]:
		battleEntity.entity_data["otherData"]["mp"] = battleEntity.entity_data["otherData"]["maxMp"]
		
	pass



func private_check_has_harm():
	var harms = current_line_data["harms"]
	
	for harm in harms.keys():
		var item = harms[harm]
		if item["dodge"]: return true
		if item["hps"].size() > 0: return true
		if item["mps"].size() > 0: return true
	
	return false


func private_get_round_item_harm():
	var harms = current_line_data["harms"]
	for harm in harms.keys():
		if int(battleEntity.real_index) == int(harm):
			return harms[harm]
	return {}

func private_remove_self():
	
	Global.get("TBBattleManage").current_local_position_map.erase(str(battleEntity.local_index))
	
	battleEntity.process_line.queue_free()
	battleEntity.queue_free()
	pass
func private_remove_self_and_pet():
	
	
	var pet_index = battleEntity.local_index + 1
	
	if battleEntity.local_index % 2 == 0:
		pet_index = battleEntity.local_index - 1
	
	var local_map = battleEntity.TBBattleManage.current_local_position_map
	
	if local_map.has(str(pet_index)):
		var tscn_entity = local_map[str(pet_index)]
		tscn_entity.process_line.queue_free()
		tscn_entity.queue_free()
		local_map.erase(str(pet_index))
	private_remove_self()
	pass


func private_atk_hit_is_self():
	var index = current_line_data["atkIndex"]
	var harms = current_line_data["harms"]
	if int(index) == battleEntity.real_index and harms.has(str(battleEntity.real_index)):
		return true
	return false
