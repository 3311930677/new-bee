extends Panel

onready var reload_time = $ReloadInfoTimer
onready var pet = $"pet"
onready var role_head = $"role/Head/TextureRect"
onready var pet_head = $"pet/Head/TextureRect"

onready var role_hp_info = $"role/Info/Hp"
onready var role_mp_info = $"role/Info/Mp"

onready var pet_hp_info = $"pet/Info/Hp"
onready var pet_mp_info = $"pet/Info/Mp"


var source_data = null
var vo_data = null

var CombatManage
var RoleInfoManage
var RoleUtils
var StaticGameData
var PetInfoManage
var NTeamManage
var AssetsManage


var default_template = null
var role_head_path_template = ""

func _ready() -> void :
	AssetsManage = Global.get("AssetsManage")
	
	default_template = load(str(AssetsManage.get_prefix(), "assets/res/k_w.png"))
	role_head_path_template = str(AssetsManage.get_prefix(), "assets/res/1%d.png")
	
	
	CombatManage = Global.get("CombatManage")
	RoleInfoManage = Global.get("RoleInfoManage")
	RoleUtils = Global.get("RoleUtils")
	StaticGameData = Global.get("StaticGameData")
	PetInfoManage = Global.get("PetInfoManage")
	NTeamManage = Global.get("NTeamManage")
	load_role_pet_data()
	reload_time.start()
	pass




func set_data(data):
	
	source_data = data
	vo_data = NTeamManage.get_team_small_item_info(source_data["id"])
	
	load_role_pet_data()

	pass


func get_role_id():
	return source_data["id"]

func get_pet_fight_id():
	return vo_data["pet_id"]


func load_role_pet_data():
	if vo_data == null or vo_data.empty():
		hide()
		return
	else: show()
	
	role_head.texture = load(role_head_path_template % source_data["race_id"])
	
	role_hp_info.value = int(vo_data["hp"] / vo_data["max_hp"] * 100)
	role_mp_info.value = int(vo_data["mp"] / vo_data["max_mp"] * 100)
	
	
	if vo_data.get("pet_race", - 1) == - 1:
		pet.hide()
		return
	pet.show()
	
	var s_pet_data = StaticGameData.get_pet_data(vo_data.get("pet_race", null))
	var frame_heads = RoleUtils.parsePetHead(s_pet_data["img_dir"])
	if frame_heads != null and frame_heads.size() > 0:
		var tex = ImageTexture.new()
		tex.create_from_image(frame_heads[0])
		pet_head.texture = tex
	else:
		pet_head.texture = default_template
	
	pet_hp_info.value = int(vo_data["pet_hp"] / vo_data["pet_max_hp"] * 100)
	pet_mp_info.value = int(vo_data["pet_mp"] / vo_data["pet_max_mp"] * 100)
	pass


func _on_ReloadInfoTimer_timeout() -> void :
	vo_data = NTeamManage.get_team_small_item_info(source_data["id"])

	reload_time.wait_time = 5
	reload_time.start()
