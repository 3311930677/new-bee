extends Node
const prefix = "TXUtils"



var buff_path = "res://assets/skill/tx/buff"
var buff_file_name = "buff.aef"
var anim_buffers_ = null



var atk_catch = "res://assets/skill/tx/atk_catch"
var atk_catch_file_name = "tx_015.aef"

var atk_normal = "res://assets/skill/tx/atk_normal"
var atk_file_name = "tx_014.aef"

var atk_fire = "res://assets/skill/tx/fire"
var atk_fire_file_name = "tx_013.aef"


var tx_pet = "res://assets/skill/tx/pet_tx"
var tx_pet_file_name = "pet_sjtx.aef"

var tx_fs = "res://assets/skill/tx/role_tx/fs"
var tx_fz = "res://assets/skill/tx/role_tx/fz"
var tx_zs = "res://assets/skill/tx/role_tx/zs"
var tx_role_name = "tx.aef"
var anim_tx_ = null


var sw_tx = "res://assets/skill/tx/sw_tx"
var sw_tx_file_name = "swtx.aef"
var anim_sw_tx = null


var sj_tx = "res://assets/sjtx"
var jqrw_tx = "res://assets/rw/jqrw"
var wcrw_tx = "res://assets/rw/wcrw"

var sj_tx_file_name = "sjtx.aef"
var jqrw_tx_file_name = "jqrw.aef"
var wcrw_tx_file_name = "wcrw.aef"

var anim_sj_rw_tx = null


func get_sj_rw_tx():
	if anim_sj_rw_tx != null:
		return anim_sj_rw_tx.duplicate(8)
	var sj_tx_arr = creatAnimations(Global.get("MapeUtils").parseAllPathPwd(sj_tx), Global.get("MapeUtils").parseAef(sj_tx, sj_tx_file_name))
	var jqrw_tx_arr = creatAnimations(Global.get("MapeUtils").parseAllPathPwd(jqrw_tx), Global.get("MapeUtils").parseAef(jqrw_tx, jqrw_tx_file_name))
	var wcrw_tx_arr = creatAnimations(Global.get("MapeUtils").parseAllPathPwd(wcrw_tx), Global.get("MapeUtils").parseAef(wcrw_tx, wcrw_tx_file_name))
	
	var anim_player = AnimationPlayer.new()
	anim_player.name = "sw_tx"
	
	
	
	if sj_tx_arr == null:
		anim_player.queue_free()
		return null
	sj_tx_arr[0].loop = false
	anim_player.add_animation("sj_tx", sj_tx_arr[0])
	
	if jqrw_tx_arr == null:
		anim_player.queue_free()
		return null
	jqrw_tx_arr[0].loop = false
	anim_player.add_animation("jqrw_tx", jqrw_tx_arr[0])
	
	if wcrw_tx_arr == null:
		anim_player.queue_free()
		return null
	wcrw_tx_arr[0].loop = false
	anim_player.add_animation("wcrw_tx", wcrw_tx_arr[0])
	
	anim_sj_rw_tx = anim_player
	return anim_sj_rw_tx.duplicate(8)

	

func get_sw_tx():
	if anim_sw_tx != null:
		return anim_sw_tx.duplicate(8)
	var pet_tx_arr = creatAnimations(Global.get("MapeUtils").parseAllPathPwd(sw_tx), Global.get("MapeUtils").parseAef(sw_tx, sw_tx_file_name))
	var anim_player = AnimationPlayer.new()
	anim_player.name = "sw_tx"
	
	if pet_tx_arr == null:
		anim_player.queue_free()
		return null
	for i in range(pet_tx_arr.size()):
		if i == 1: pet_tx_arr[i].loop = true
		anim_player.add_animation(str("%d" % i), pet_tx_arr[i])
	anim_sw_tx = anim_player
	return anim_sw_tx.duplicate(8)



func get_all_txs():
	if anim_tx_ != null:
		return anim_tx_.duplicate(8)
	
	var pet_tx_arr = creatAnimations(Global.get("MapeUtils").parseAllPathPwd(tx_pet), Global.get("MapeUtils").parseAef(tx_pet, tx_pet_file_name))
	var fs_tx_Arr = creatAnimations(Global.get("MapeUtils").parseAllPathPwd(tx_fs), Global.get("MapeUtils").parseAef(tx_fs, tx_role_name))
	var fz_tx_Arr = creatAnimations(Global.get("MapeUtils").parseAllPathPwd(tx_fz), Global.get("MapeUtils").parseAef(tx_fz, tx_role_name))
	var zs_tx_Arr = creatAnimations(Global.get("MapeUtils").parseAllPathPwd(tx_zs), Global.get("MapeUtils").parseAef(tx_zs, tx_role_name))
	
	var atk_normal_tx_arr = creatAnimations(Global.get("MapeUtils").parseAllPathPwd(atk_normal), Global.get("MapeUtils").parseAef(atk_normal, atk_file_name))
	
	var atk_catch_tx_arr = creatAnimations(Global.get("MapeUtils").parseAllPathPwd(atk_catch), Global.get("MapeUtils").parseAef(atk_catch, atk_catch_file_name))
	
	var atk_fire_tx_arr = creatAnimations(Global.get("MapeUtils").parseAllPathPwd(atk_fire), Global.get("MapeUtils").parseAef(atk_fire, atk_fire_file_name))
	
	var anim_player = AnimationPlayer.new()
	anim_player.name = "tx"
	
	var txs = []
	txs.append_array(pet_tx_arr)
	txs.append_array(fs_tx_Arr)
	txs.append_array(fz_tx_Arr)
	txs.append_array(zs_tx_Arr)
	
	
	for i in range(txs.size()):
		if txs[i] != null:
			anim_player.add_animation(str("%d" % i), txs[i])
	anim_tx_ = anim_player
	
	anim_tx_.remove_animation("0")
	anim_player.add_animation("0", atk_normal_tx_arr.front())
	
	anim_player.add_animation("-1", atk_catch_tx_arr.front())
	anim_player.add_animation("atk_z_fire", atk_fire_tx_arr.front())
	
	return anim_tx_.duplicate(8)



func get_buffs():
	if anim_buffers_ != null:
		return anim_buffers_.duplicate(8)
	
	var all_pwds: Dictionary = Global.get("MapeUtils").parseAllPathPwd(buff_path)
	var aef = Global.get("MapeUtils").parseAef(buff_path, buff_file_name)
	
	var animations = []
	
	for i in range(5):
		var anim = createAnimationsWithAef(i, aef, all_pwds)
		animations.append(anim)
	var anim_player = AnimationPlayer.new()
	anim_player.name = "buff"
	
	for i in range(5):
		animations[i].loop = true
		anim_player.add_animation(str("buff%d" % i), animations[i])
	anim_buffers_ = anim_player
	return anim_buffers_.duplicate(8);


func creatAnimations(all_pwds, aefs):
	
	var animations = []
	
	if aefs == null: return animations
	
	for i in range(int(aefs["animations"].size())):
		var anim = createAnimationsWithAef(i, aefs, all_pwds)
		animations.append(anim)
	return animations


func createAnimationsWithAef(anim_index, role_aef, all_pwds) -> Animation:
	var anim = role_aef["animations"][anim_index]
	var frames = []
	for frame_id in anim["serise"]:
		var frame = role_aef["frame_ids"][str(frame_id)]
		var frame_png = pwdToImg(all_pwds, frame)
		frames.append(frame_png)
	
	var m_animtaion = Animation.new()
	m_animtaion.loop = false
	m_animtaion.length = frames.size() * 0.1
	
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
		f_index += 0.1
	if m_animtaion == null:
		pass
	return m_animtaion

func pwdToImg(all_pwds: Dictionary, _frame: Array) -> Image:
	




	var rec2 = Rect2(125, 140, 250, 150)
	
	var temp_img: Image = Image.new()
	temp_img.create(rec2.size.x, rec2.size.y, false, Image.FORMAT_RGBA8)
	
	for r in _frame:
		if not all_pwds.has(r.pwd_id):
			continue
		var dic_pwd = all_pwds[r.pwd_id]
		
		if r.img_id - 1 >= dic_pwd.pics.size(): continue
		var img_pic = dic_pwd.pics[r.img_id - 1]
		temp_img.blend_rect(img_pic, Rect2(0, 0, img_pic.get_width(), img_pic.get_height()), Vector2(r.x + rec2.position.x, r.y + rec2.position.y))
	return temp_img
