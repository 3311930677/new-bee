class_name RoleUtils




var skill_data = {}

var rolePath = ["res://assets/js/zd_xs", "res://assets/js/zd_fs", "res://assets/js/zd_zs", "res://assets/js/zd_fz"]

var roleCGPath = [
	"res://assets/js/cg_xs", 
	"res://assets/js/cg_fs", 
	"res://assets/js/cg_zs", 
	"res://assets/js/cg_fz"
	]

var petPath = "res://assets/pet"

var pet_hetght = {
	
}
var role_type_arr_job = [22, 13, 33]
var role_type_arr_division = [21, 23, 12, 11, 32, 31]

var pet_heads = {
	
}

func _ready() -> void :
	
	pass
func parsePetHead(PetImgDir: String):
	var dir = Directory.new()
	if dir.open(petPath + "/" + str(PetImgDir)) != OK:
		print("打开失败")
		return null
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	var aefs = null
	while (file_name != ""):
		if file_name.ends_with("tx.aef") or file_name.ends_with("touxiang.aef"):
			aefs = Global.get("MapeUtils").parseAef(petPath + "/" + str(PetImgDir), file_name)
			break
		file_name = dir.get_next()
	if aefs == null:
		print("当前文件没有头像")
		return null
	var all_pwds = Global.get("MapeUtils").parseAllPathPwd(petPath + "/" + str(PetImgDir))
	var frames = []
	for index in aefs["animations"].size():
		var anim = aefs["animations"][index]
		for frame_id in anim["serise"]:
			var frame = aefs["frame_ids"][str(frame_id)]
			var frame_png = pwdToImg(all_pwds, frame, "", "", [], true)
			frames.append(frame_png)
	pet_heads[PetImgDir] = frames
	return frames






func parseCGRole(roleType: int, sex: int) -> AnimationPlayer:
	var path = roleCGPath[int(roleType / 10)]
	roleType = roleType % 10
	var all_pwds: Dictionary = Global.get("MapeUtils").parseAllPathPwd(path)
	var role_json = openJsonFileToDic(path)
	
	var parse_sex = ""
	if sex == 0: parse_sex = "nan"
	else: parse_sex = "nv"
	
	var sex_role_json = role_json[parse_sex]
	var role_aef = Global.get("MapeUtils").parseAef(path, sex_role_json["aef"])
	var wq_name = ""
	var head_name = ""
	
	if role_json["wqIsTemplate"]:
		wq_name = role_json["wqTemplate"] %roleType
	else:
		wq_name = sex_role_json["wq"]
	
	if role_json["headIsTemplate"]:
		head_name = role_json["headTemplate"].format([parse_sex, roleType], "%d")
	else:
		head_name = sex_role_json["head"]
	
	
	var animations = []
	for i in range(4):
		var anim = createAnimationsWithAef(i, role_aef, all_pwds, head_name, wq_name, [])
		animations.append(anim)
		anim.loop = true
	var anim_player = AnimationPlayer.new()
	anim_player.name = "cg"


	anim_player.add_animation("left_walk", animations[0])
	anim_player.add_animation("left_idle", animations[1])
	anim_player.add_animation("right_walk", animations[2])
	anim_player.add_animation("right_idle", animations[3])
	
	return anim_player;








func parseCGNpc(PetType: String) -> AnimationPlayer:
	var dir = Directory.new()
	if dir.open(petPath + "/" + str(PetType)) != OK:
		print("打开失败")
		return null
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	var aefs = null
	while (file_name != ""):
		if file_name.ends_with("cg.aef") or file_name.ends_with("changgui.aef") or file_name.find("changgui") != - 1:
			aefs = Global.get("MapeUtils").parseAef(petPath + "/" + str(PetType), file_name)
			break
		file_name = dir.get_next()
	if aefs == null:
		print("当前文件没有战斗动画！只有常规或者头像")
		return null
	
	var all_pwds = Global.get("MapeUtils").parseAllPathPwd(petPath + "/" + str(PetType))
	var vec = getMaxSmallPic(all_pwds, aefs["frames"][0]["imgs"])
	if not pet_hetght.has(PetType):
		pet_hetght[PetType] = vec
		
	
	var animations = []
	for i in aefs["animations"].size():
		var ani = createAnimationsWithAef(i, aefs, all_pwds)
		animations.append(ani)
		ani.loop = true
	var anim_player = AnimationPlayer.new()
	anim_player.name = "zd"
	
	anim_player.add_animation("left_idle", animations[0])
	anim_player.add_animation("right_idle", animations[1])
	if (animations.size() > 2):
		anim_player.add_animation("left_walk", animations[2])
		anim_player.add_animation("right_walk", animations[3])
	return anim_player;
	pass


func parseZDNpc(PetType: String) -> AnimationPlayer:
	var dir = Directory.new()
	if dir.open(petPath + "/" + str(PetType)) != OK:
		print("打开失败")
		return null
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	var aefs = null
	while (file_name != ""):
		if file_name.ends_with("zd.aef") or file_name.ends_with("zhandou.aef") or file_name.find("zhandou") != - 1:
			aefs = Global.get("MapeUtils").parseAef(petPath + "/" + str(PetType), file_name)
			break
		file_name = dir.get_next()
	if aefs == null:
		print("当前文件没有战斗动画！只有常规或者头像")
		return null
	
	var all_pwds = Global.get("MapeUtils").parseAllPathPwd(petPath + "/" + str(PetType))
	var vec = getMaxSmallPic(all_pwds, aefs["frames"][0]["imgs"])
	if not pet_hetght.has(PetType):
		pet_hetght[PetType] = vec
		
	
	var animations = []
	for i in aefs["animations"].size():
		var ani = createAnimationsWithAef(i, aefs, all_pwds)
		animations.append(ani)
	
	if animations.size() < 5:
		print("宠物动画数量特殊，只有4个动画，请使用json文件配置")
		return null
	
	var anim_player = AnimationPlayer.new()
	anim_player.name = "zd"
	
	animations[0].loop = true
	
	anim_player.add_animation("fight_idle", animations[0].duplicate())
	
	var hit_anim = animations[3].duplicate()
	addHitAnimMethod(hit_anim)
	anim_player.add_animation("hit", hit_anim)
	
	var dodge = animations[4].duplicate()
	addDodgeAnimMethod(dodge)
	anim_player.add_animation("dodge", dodge)
	
	var a1 = animations[1].duplicate()
	var a2 = animations[2].duplicate()
	addOneAtkMethod(a1, ["", 1])
	addTwoAtkMethod(a2, ["", 1])
	anim_player.add_animation("atk1", a1)
	anim_player.add_animation("atk2", a2)
	
	if animations.size() == 6:
		var a1_a = animations[1].duplicate()
		var a2_a = animations[5].duplicate()
		addOneAtkMethod(a1_a, ["", 1])
		addTwoAtkMethod(a2_a, ["", 1])
		anim_player.add_animation("atk1攻击二", a1_a)
		anim_player.add_animation("atk2攻击二", a2_a)
	elif animations.size() > 6:
		var f_r = File.new();
		var path_file = petPath + "/" + str(PetType) + "/config.json"
		if f_r.file_exists(path_file) and f_r.open(path_file, File.READ) == OK:
			
			var txt = f_r.get_as_text()
			f_r.close()
			var config = parse_json(txt)
			var arr_dic = config["jn"]
			for a_d in arr_dic:
				
				var skill_name = a_d["name"]
				
				var is_base_skill_name = false;
				if anim_player.has_animation(skill_name):
					anim_player.remove_animation(skill_name)
					is_base_skill_name = true
				
				if a_d["anims"].size() > 1 and not is_base_skill_name:
					var anim1: Animation = animations[a_d["anims"][0]].duplicate()
					var anim2: Animation = animations[a_d["anims"][1]].duplicate()
					
					addOneAtkMethod(anim1, [skill_name, a_d["rangedAtk"]])
					addTwoAtkMethod(anim2, [skill_name, a_d["rangedAtk"]])
					
					if is_base_skill_name:
						skill_name = ""
					anim_player.add_animation(str("atk1" + skill_name), anim1)
					anim_player.add_animation(str("atk2" + skill_name), anim2)
				else:
					
					var anim1: Animation = animations[a_d["anims"][0]].duplicate()
					if skill_name == "hit":
						addHitAnimMethod(anim1)
					elif skill_name == "dodge":
						addDodgeAnimMethod(anim1)
					anim_player.add_animation(skill_name, anim1)
			
			addFightBackAnimMethod(animations[config["fight_back"]])
			anim_player.add_animation("fight_back", animations[config["fight_back"]].duplicate())
		else:
			print("宠物动画数量过多，未能检测到配置文件，请手动配置")
	else:
		
		addFightBackAnimMethod(animations[2])
		anim_player.add_animation("fight_back", animations[2].duplicate())
	return anim_player











func parseZDRole(roleType: int, sex: int) -> AnimationPlayer:
	var path = rolePath[int(roleType / 10)]
	roleType = roleType % 10
	var all_pwds: Dictionary = Global.get("MapeUtils").parseAllPathPwd(path)
	var role_json = openJsonFileToDic(path)
	
	var parse_sex = ""
	if sex == 0: parse_sex = "nan"
	else: parse_sex = "nv"
	
	var sex_role_json = role_json[parse_sex]
	var role_aef = Global.get("MapeUtils").parseAef(path, sex_role_json["aef"])
	var wq_name = ""
	var head_name = ""
	var tx_names = []
	
	if role_json["wqIsTemplate"]:
		wq_name = role_json["wqTemplate"] %roleType
	else:
		wq_name = sex_role_json["wq"]
	
	if role_json["headIsTemplate"]:
		head_name = role_json["headTemplate"].format([parse_sex, roleType], "%d")
	else:
		head_name = sex_role_json["head"]
	tx_names.append(role_json["q5tx"])
	
	
	var animations = []
	for i in range(5):
		var anim = createAnimationsWithAef(i, role_aef, all_pwds, head_name, wq_name, tx_names)
		animations.append(anim)
	var anim_player = AnimationPlayer.new()
	anim_player.name = "zd"
	
	animations[0].loop = true
	anim_player.add_animation("fight_idle", animations[0])
	
	addHitAnimMethod(animations[3])
	anim_player.add_animation("hit", animations[3])
	
	addDodgeAnimMethod(animations[4])
	anim_player.add_animation("dodge", animations[4])
	
	addOneAtkMethod(animations[1], ["", 1])
	addTwoAtkMethod(animations[2], ["", 1])
	anim_player.add_animation("atk1", animations[1])
	anim_player.add_animation("atk2", animations[2])
	if not role_json["isSkill"]:
		return anim_player
	else:
		
		var jns: Array = role_json["jn"]
		for i in jns:
			var anims = []
			var txs = i["txs"]
			for a_index in i["anims"]:
				var anim = createAnimationsWithAef(a_index, role_aef, all_pwds, head_name, wq_name, txs)
				anims.append(anim)
			
			addOneAtkMethod(anims[0], i["name"])
			addTwoAtkMethod(anims[1], i["name"])
			anim_player.add_animation("atk1" + str(i["name"][0]), anims[0])
			anim_player.add_animation("atk2" + str(i["name"][0]), anims[1])
	return anim_player


func pwdToImg(all_pwds: Dictionary, _frame: Array, head: String = "", wq: String = "", tx: Array = [], is_source_rect = false) -> Image:
	

	var rec2
	if is_source_rect:
		rec2 = Rect2(20, 25, 40, 40)
	else:
		rec2 = Rect2(125, 140, 250, 150)
	
	var temp_img: Image = Image.new()
	temp_img.create(rec2.size.x, rec2.size.y, false, Image.FORMAT_RGBA8)
	
	for r in _frame:
		
		if not all_pwds.has(r.pwd_id):
			continue
		
		var dic_pwd = all_pwds[r.pwd_id]
		var fname: String = dic_pwd.fileName
		
		if fname.find("_t") != - 1 and not head.empty():
			if fname != head:
				continue
		
		if fname.find("wq") != - 1 and not wq.empty():
			if fname != wq:
				continue
		if fname.find("tx") != - 1 and tx.size() > 0:
			var flag = false
			for t_i in tx:
				var sub_name = "tx_" + str(t_i)
				if fname.find(sub_name) != - 1:
					flag = true
					break
			if not flag:
				continue
		
		var img_pic = dic_pwd.pics[r.img_id - 1]
		temp_img.blend_rect(img_pic, Rect2(0, 0, img_pic.get_width(), img_pic.get_height()), Vector2(r.x + rec2.position.x, r.y + rec2.position.y))
		
	return temp_img


func getMaxSmallPic(all_pwd_dic: Dictionary, frame_img_arr: Array) -> Rect2:
	var x1 = 0
	var y1 = 0
	var x2 = 0
	var y2 = 0
	for r in frame_img_arr:
		var pid = r.pwd_id
		var imgid = r.img_id - 1
		var dic_pwd = all_pwd_dic[pid]
		var img_pic: Image = dic_pwd["pics"][imgid]
		var width = img_pic.get_width()
		var height = img_pic.get_height()
		if r.x < x1: x1 = r.x
		if r.y < y1: y1 = r.y
		if (r.x + width) > x2: x2 = r.x + width
		if (r.y + height) > y2: y2 = r.y + height
		pass
	x2 = x2 - x1
	y2 = y2 - y1
	x1 = x1
	y1 = y1
	var rec = Rect2(x1, y1, x2, y2)
	return rec

func openJsonFileToDic(path: String) -> Dictionary:
	var file_json = File.new()
	if file_json.open(path + str("/role.json"), File.READ) != OK:
		print("配置文件打开失败")
		return {}
	var txt = file_json.get_as_text()
	file_json.close()
	var dic = parse_json(txt)
	return dic
func getPetRec(petId):
	if pet_hetght.has(str(petId)):
		return pet_hetght[str(petId)]
	return null

func getSkillData(roleType: int):
	var index = int(roleType / 10)
	if skill_data.has("" + str(index)):
		return skill_data[str(index)]
	var path = rolePath[index]
	var role_json = openJsonFileToDic(path)
	var skillDatas: Array = role_json["jn"]
	skill_data[str(index)] = skillDatas
	return skillDatas


func createAnimationsWithAef(anim_index, role_aef, all_pwds, head_name = "", wq_name = "", tx_names = []) -> Animation:
	var anim = role_aef["animations"][anim_index]
	var frames = []
	for frame_id in anim["serise"]:
		var frame = role_aef["frame_ids"][str(frame_id)]
		var frame_png = pwdToImg(all_pwds, frame, head_name, wq_name, tx_names)
		frames.append(frame_png)
	
	var m_animtaion = Animation.new()
	m_animtaion.loop = false
	m_animtaion.length = frames.size() * 0.125
	
	var track_offset = m_animtaion.add_track(Animation.TYPE_VALUE)
	var track_tex = m_animtaion.add_track(Animation.TYPE_VALUE)
	var f_index = 0;
	for f in frames:
		
		var im = f as Image
		m_animtaion.track_set_path(track_offset, "Sprite:offset")
		m_animtaion.track_insert_key(track_offset, f_index, Vector2(0, - im.get_height() / 2 + 10))
		
		m_animtaion.track_set_path(track_tex, "Sprite:texture")
		var tex = ImageTexture.new()
		tex.create_from_image(f)
		tex.flags = 1
		m_animtaion.track_insert_key(track_tex, f_index, tex)
		f_index += 0.125
	return m_animtaion


func addFightBackAnimMethod(anim: Animation):
	addMethod(anim, [], "fight_back_start", "fight_back_finish")
	pass


func addHitAnimMethod(anim: Animation):
	addMethod(anim, [], "hit_start", "hit_finish")


func addDodgeAnimMethod(anim: Animation):
	addMethod(anim, [], "dodge_start", "dodge_finish")


func addOneAtkMethod(anim: Animation, args: Array):
	addMethod(anim, args, "atk1_start_offset", "atk1_finish_offset")
func addTwoAtkMethod(anim: Animation, args: Array):
	addMethod(anim, args, "atk2_start_offset", "atk2_finish_offset")


func addMethod(anim: Animation, args: Array, method_name1: String, method_name2: String):
	var id = anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(id, ".")
	anim.track_insert_key(id, 0, {"args": args, "method": method_name1})
	anim.track_insert_key(id, anim.length, {"args": args, "method": method_name2})
