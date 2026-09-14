extends TextureRect

export (int) var atk_type = 1

onready var tex = $TextureRect

var CombatManage
var TBBattleManage
var RoleInfoManage
var StaticGameData
var jn_icon_path = "res://assets/skill/pet/%s"

func _ready() -> void :
	CombatManage = Global.get("CombatManage")
	TBBattleManage = Global.get("TBBattleManage")
	RoleInfoManage = Global.get("RoleInfoManage")
	StaticGameData = Global.get("StaticGameData")
	
	CombatManage.connect("hot_info_update", self, "hot_info_update")
	TBBattleManage.connect("hot_info_update", self, "hot_info_update")
	hot_info_update()

func hot_info_update():
	var c_op = RoleInfoManage.hot_role_op
	var atk_id = - 1
	if atk_type == 1: atk_id = c_op.get("role_atk", - 1)
	else: atk_id = c_op.get("pet_atk", - 1)
	
	if atk_id == - 1:
		tex.texture = null
	else:
		var info = StaticGameData.get_skill_data_temp(atk_id)
		if info.get("icon", "").length() < 2:
			tex.texture = null
			pass
		else:
			tex.texture = load(str(jn_icon_path % info["icon"]))
		
	pass
