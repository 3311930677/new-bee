class_name NpcUtils


var npc_path = "res://assets/npc/"
var npc_pet_path = "res://assets/pet/"

var MapeUtils
var TXUtils
var FileHelper

var all_animations = {}

var anim_h = {}

func _init() -> void :
	MapeUtils = Global.get("MapeUtils")
	TXUtils = Global.get("TXUtils")
	FileHelper = Global.get("FileHelper")
	load_npc("cz_NPC")


func load_npc(file_name: String):


	
	var aef_name = str(npc_path, file_name, "/", file_name, ".aef")
	var pwd_name = str(npc_path, file_name, "/", file_name, ".pwd")
	var png_name = str(npc_path, file_name, "/", file_name, ".png")
	var anim_player = AnimationPlayer.new()
	if FileHelper.file_exits(aef_name):
		var all_pwds = MapeUtils.parseAllPathPwd(str(npc_path, file_name))
		if all_pwds.keys().size() <= 1:
			anim_h[file_name] = all_pwds[all_pwds.keys()[0]].pics[0].get_height()
		else: anim_h[file_name] = 150
		var aefs = MapeUtils.parseAef(str(npc_path, file_name), str(file_name, ".aef"))
		var anim = TXUtils.creatAnimations(all_pwds, aefs)
		anim_player.add_animation("idle", anim[0])
		pass
	
	elif FileHelper.file_exits(pwd_name):
		
		var all_pwds = MapeUtils.parseAllPathPwd(str(npc_path, file_name))
		var imgs = [all_pwds[0].pics[0]]
		anim_h[file_name] = imgs[0].get_height()
		var anim = imgToAnimation(imgs)
		anim_player.add_animation("idle", anim)
		pass
	elif FileHelper.file_exits(png_name):
		var img = load(png_name)
		if img == null: return null
		anim_h[file_name] = img.get_height()
		var imgs = [img]
		var anim = imgToAnimation(imgs)
		anim_player.add_animation("idle", anim)
		pass
	else:
		aef_name = str(npc_pet_path, file_name, "/", file_name, "_changgui.aef")
		
		if not FileHelper.file_exits(aef_name): return null
		
		var all_pwds = MapeUtils.parseAllPathPwd(str(npc_pet_path, file_name))
		if all_pwds.keys().size() <= 1:
			anim_h[file_name] = all_pwds[all_pwds.keys()[0]].pics[0].get_height()
		else: anim_h[file_name] = 150
		
		var aefs = MapeUtils.parseAef(str(npc_pet_path, file_name), str(file_name, "_changgui.aef"))
		var anim = TXUtils.creatAnimations(all_pwds, aefs)
		anim_player.add_animation("idle", anim[0])
		pass

	return anim_player

func get_height_npc(filename):
	if anim_h.has(filename):
		return anim_h[filename]
	else:
		return 150

func imgToAnimation(imgs: Array):
	var m_animtaion = Animation.new()
	m_animtaion.loop = false
	m_animtaion.length = imgs.size() * 0.1
	
	var track_offset = m_animtaion.add_track(Animation.TYPE_VALUE)
	var track_tex = m_animtaion.add_track(Animation.TYPE_VALUE)
	var f_index = 0;
	for f in imgs:
		
		var im = f
		m_animtaion.track_set_path(track_offset, "Sprite:offset")
		m_animtaion.track_insert_key(track_offset, f_index, Vector2(0, - im.get_height() / 2 + 10))
		
		m_animtaion.track_set_path(track_tex, "Sprite:texture")
		if f is StreamTexture:
			m_animtaion.track_insert_key(track_tex, f_index, f)
		else:
			var tex = ImageTexture.new()
			tex.create_from_image(f)
			tex.flags = 1
			m_animtaion.track_insert_key(track_tex, f_index, tex)
		f_index += 0.1
	if m_animtaion == null:
		pass
	return m_animtaion
