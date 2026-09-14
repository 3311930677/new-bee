extends Control


export (bool) var fighting = false


onready var role = $Role
onready var pet = $Pet


onready var role_hp = $Role / RoleInfo / Hp
onready var role_mp = $Role / RoleInfo / Mp
onready var role_level = $Role / RoleHead / Level
onready var role_exp = $Role / RoleHead / Precent
onready var role_head = $Role / RoleHead / Head

onready var pet_hp = $Pet / PetInfo / Hp
onready var pet_mp = $Pet / PetInfo / Mp
onready var pet_level = $Pet / PetHead / Level
onready var pet_exp = $Pet / PetHead / Precent
onready var pet_head = $Pet / PetHead / Head

var str_light_template = ""


var ScreenUtils
var RoleInfoManage
var PetInfoManage
var CombatManage
var RoleUtils
var AssetsManage

var c_role_mp = 0

var c_pet_mp = 0

func _ready() -> void :
	AssetsManage = Global.get("AssetsManage")
	ScreenUtils = Global.get("ScreenUtils")
	RoleInfoManage = Global.get("RoleInfoManage")
	PetInfoManage = Global.get("PetInfoManage")
	CombatManage = Global.get("CombatManage")
	RoleUtils = Global.get("RoleUtils")
	
	str_light_template = str(AssetsManage.get_prefix(), "assets/res/%d.png")
	
	RoleInfoManage.connect("reload_head_ui", self, "_on_reload_head_ui")
	PetInfoManage.connect("pet_info", self, "_on_pet_loaded_ui")
	PetInfoManage.connect("fight_pet", self, "_on_reset_pet")
	PetInfoManage.connect("main_head_no_pet", self, "_on_reset_pet")
	PetInfoManage.connect("pet_reload_show", self, "_on_reset_pet")
	


func set_show_index(ind):
	role_head.texture = load(str(str_light_template % ind))

func set_pet_head():
	var heads = RoleUtils.parsePetHead(PetInfoManage.get_pet_img_dir())
	if heads == null or heads.size() <= 0:
		pet_head.texture = null
		return
	
	var tex = ImageTexture.new()
	tex.create_from_image(heads[0])
	pet_head.texture = tex
	pass

func _on_reload_head_ui():
	if fighting: return
	load_role_data()



func _on_pet_loaded_ui(id, data):
	if fighting: return
	load_pet_data()
	pass

func _on_reset_pet():
	
	load_pet_data()
	pass

func load_role_data():
	
	set_show_index(RoleInfoManage.get_role_race_id())
	
	role_level.text = str(RoleInfoManage.get_role_level())
	
	var exp_b = RoleInfoManage.get_role_exp() * 1.0 / RoleInfoManage.get_role_max_exp() * 100
	if exp_b > 100: exp_b = 100
	role_exp.text = str(int(exp_b))
	
	
	
	var hp_b = RoleInfoManage.get_role_hp() * 1.0 / RoleInfoManage.get_role_max_hp() * 100
	if hp_b > 100: hp_b = 100
	role_hp.value = hp_b
	
	var mp_b = RoleInfoManage.get_role_mp() * 1.0 / RoleInfoManage.get_role_max_mp() * 100
	if mp_b > 100: mp_b = 100
	role_mp.value = mp_b
	
	c_role_mp = RoleInfoManage.get_role_mp()
	pass


func load_pet_data():
	
	
	if PetInfoManage.get_fight_pet_id() <= 0:
		$Pet.visible = false
		return
	else:
		$Pet.visible = true
	
	
	set_pet_head()
	
	pet_level.text = str(PetInfoManage.get_pet_level())
	
	var exp_b = PetInfoManage.get_pet_exp() * 1.0 / PetInfoManage.get_pet_max_exp() * 100
	if exp_b > 100: exp_b = 100
	pet_exp.text = str(int(exp_b))
	
	var hp_b = PetInfoManage.get_pet_hp() * 1.0 / PetInfoManage.get_pet_max_hp() * 100
	if hp_b > 100: hp_b = 100
	pet_hp.value = hp_b
	
	var mp_b = PetInfoManage.get_pet_mp() * 1.0 / PetInfoManage.get_pet_max_mp() * 100
	if mp_b > 100: mp_b = 100
	pet_mp.value = mp_b
	
	c_pet_mp = PetInfoManage.get_pet_mp()
	pass


func set_role_hp(c_v, m_v):
	var hp_b = c_v * 1.0 / m_v * 100
	if hp_b > 100: hp_b = 100
	role_hp.value = hp_b
	pass

func set_role_mp(c_v, m_v):
	var mp_b = c_v * 1.0 / m_v * 100
	if mp_b > 100: mp_b = 100
	role_mp.value = mp_b
	
	c_role_mp = c_v
	pass

func set_pet_hp(c_v, m_v):
	var hp_b = c_v * 1.0 / m_v * 100
	if hp_b > 100: hp_b = 100
	pet_hp.value = hp_b
	pass

func set_pet_mp(c_v, m_v):
	var mp_b = c_v * 1.0 / m_v * 100
	if mp_b > 100: mp_b = 100
	pet_mp.value = mp_b
	
	c_pet_mp = c_v
	pass

func _on_RoleBtnInfo_pressed() -> void :
	if fighting: return
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/role/RoleUi.tscn", "load_data", {"role_type": 0})
	pass


func _on_PetBtnInfo_pressed() -> void :
	if fighting: return
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/pet/PetUi.tscn", "load_data", {"pet_type": 0})
	pass
