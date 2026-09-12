extends Panel

export (int) var index = 1

onready var role_hp = $role / Info / Hp
onready var role_mp = $role / Info / Mp
onready var role_head = $role / Head / TextureRect

onready var pet_hp = $pet / Info / Hp
onready var pet_mp = $pet / Info / Mp
onready var pet_head = $pet / Head / TextureRect


onready var pet_infos = $pet

var TBBattleManage
var StaticGameData
var AssetsManage
var RoleUtils


var update_time = 0.2
var all_time = 0.0



var role_data = null
var pet_data = null


var role_head_path_template = ""
var default_template = null

func _ready():
	AssetsManage = Global.get("AssetsManage")
	TBBattleManage = Global.get("TBBattleManage")
	StaticGameData = Global.get("StaticGameData")
	RoleUtils = Global.get("RoleUtils")
	role_head_path_template = str(AssetsManage.get_prefix(), "assets/res/1%d.png")
	default_template = load(str(AssetsManage.get_prefix(), "assets/res/k_w.png"))
	analysis_other_role_info()
	update_info()


func _process(delta):
	all_time += delta
	if all_time >= update_time:
		all_time = 0.0
		update_info()

func update_info():
	
	if role_data == null and pet_data == null: queue_free()

	if role_data != null:
		role_hp.value = int(role_data["otherData"]["hp"])
		role_hp.max_value = int(role_data["otherData"]["maxHp"])
		
		role_mp.value = int(role_data["otherData"]["mp"])
		role_mp.max_value = int(role_data["otherData"]["maxMp"])
	
	if pet_data != null:
		pet_hp.value = int(pet_data["otherData"]["hp"])
		pet_hp.max_value = int(pet_data["otherData"]["maxHp"])
		
		pet_mp.value = int(pet_data["otherData"]["mp"])
		pet_mp.max_value = int(pet_data["otherData"]["maxMp"])
	pass




func analysis_other_role_info():
	
	var arr_info = TBBattleManage.get_role_camp()
	
	if arr_info == null:
		arr_info = {}
	var c_i = 1
	for info_key in arr_info.keys():
		var info = arr_info[info_key]
		if info["type"] == "role":
			if int(info["id"]) == Global.get("RoleInfoManage").get_role_id():
				continue
			else:
				if c_i == index:
					trace_other_info(info_key, info)
			c_i += 1
			pass
		pass
	pass


func trace_other_info(index_key, role_info):
	
	var pet_key = str(int(index_key) - 1)
	if int(index_key) % 2 != 0:
		
		pet_key = str(int(index_key) + 1)
	var arr_info = TBBattleManage.get_role_camp()
	role_data = role_info
	pet_data = arr_info.get(pet_key, null)
	
	
	role_head.texture = load(role_head_path_template % role_data["otherData"]["raceId"])
	
	if pet_data == null:
		pet_infos.hide()
	else:
		
		var s_pet_data = StaticGameData.get_pet_data(pet_data["otherData"]["raceId"])
		var frame_heads = RoleUtils.parsePetHead(s_pet_data["img_dir"])
		if frame_heads != null and frame_heads.size() > 0:
			var tex = ImageTexture.new()
			tex.create_from_image(frame_heads[0])
			pet_head.texture = tex
		else:
			pet_head.texture = default_template
		pass
		
