extends Control

onready var pet = $Pet

onready var role_hp = $Role / RoleInfo / Hp
onready var role_mp = $Role / RoleInfo / Mp
onready var role_head = $Role / RoleHead / Head
onready var role_level = $Role / RoleHead / Level

onready var pet_hp = $Pet / PetInfo / Hp
onready var pet_mp = $Pet / PetInfo / Mp
onready var pet_head = $Pet / PetHead / Head
onready var pet_level = $Pet / PetHead / Level

var TBBattleManage
var RoleInfoManage
var PetInfoManage
var RoleUtils
var AssetsManage

var role_entity_data = null
var pet_enetity_data = null

var str_light_template = ""

var refresh = 0.5

var all_delta = 0.5

func _ready() -> void :
	TBBattleManage = Global.get("TBBattleManage")
	AssetsManage = Global.get("AssetsManage")
	RoleInfoManage = Global.get("RoleInfoManage")
	PetInfoManage = Global.get("PetInfoManage")
	RoleUtils = Global.get("RoleUtils")
	
	str_light_template = str(AssetsManage.get_prefix(), "assets/res/%d.png")
	role_entity_data = TBBattleManage.get_role_entity_data()
	pet_enetity_data = TBBattleManage.get_pet_entity_data()
	
	if pet_enetity_data != null:
		set_pet_head()
		pet.show()
	
	set_role_head(RoleInfoManage.get_role_race_id())


func _process(delta: float) -> void :
	all_delta += delta
	if all_delta >= refresh:
		all_delta = 0.0
		reload_entity_data()


func reload_entity_data():
	reload_role_data()
	reload_pet_data()
	pass

func reload_role_data():
	if role_entity_data == null: return
	
	var map_other = role_entity_data["otherData"]
	
	var hp_p = map_other["hp"] / map_other["maxHp"] * 100
	var mp_p = map_other["mp"] / map_other["maxMp"] * 100
	
	role_hp.value = hp_p
	role_mp.value = mp_p
	role_level.text = str(map_other["level"])
	
	pass
func reload_pet_data():
	if pet_enetity_data == null: return
	
	var map_other = pet_enetity_data["otherData"]
	
	var hp_p = map_other["hp"] / map_other["maxHp"] * 100
	var mp_p = map_other["mp"] / map_other["maxMp"] * 100
	
	pet_hp.value = hp_p
	pet_mp.value = mp_p
	pet_level.text = str(map_other["level"])
	
	pass



func set_role_head(ind):
	role_head.texture = load(str(str_light_template % ind))

func set_pet_head():
	if PetInfoManage.get_pet_img_dir() == null:
		pet_head.texture = null
		return
	var heads = RoleUtils.parsePetHead(PetInfoManage.get_pet_img_dir())
	if heads == null or heads.size() <= 0:
		pet_head.texture = null
		return
	
	var tex = ImageTexture.new()
	tex.create_from_image(heads[0])
	pet_head.texture = tex
	pass
