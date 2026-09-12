extends TextureRect

signal item_click
onready var scroll_container = $HBoxContainer / ScrollContainer
onready var vbox = $HBoxContainer / ScrollContainer / VBoxContainer
onready var name_ = $HBoxContainer / ScrollContainer / VBoxContainer / Name
onready var sex = $HBoxContainer / Sex
onready var is_vip = $HBoxContainer / Vip
onready var vip_num = $HBoxContainer / Vip / VipNum
onready var identity = $HBoxContainer / Identity
onready var team_tex = $HBoxContainer / Team

var show_team = true
var around_type = 0

var team_type = 0

var light_tex = null

var team_res = null

var oteam_res = null

var light_vip_res = null
var balck_vip_res = null


var StaticGameData
var RoleInfoManage
var NTeamManage
var AssetsManage


var data = {}

func _ready() -> void :
	StaticGameData = Global.get("StaticGameData")
	AssetsManage = Global.get("AssetsManage")
	RoleInfoManage = Global.get("RoleInfoManage")
	NTeamManage = Global.get("NTeamManage")
	
	light_tex = load(str(AssetsManage.get_prefix(), "assets/res/light.png"))
	team_res = load(str(AssetsManage.get_prefix(), "assets/res/team.png"))
	oteam_res = load(str(AssetsManage.get_prefix(), "assets/res/oteam.png"))
	light_vip_res = load(str(AssetsManage.get_prefix(), "assets/res/vip1.png"))
	balck_vip_res = load(str(AssetsManage.get_prefix(), "assets/res/vip2.png"))
	
	if not show_team: $HBoxContainer / Team.texture = null
	unchecked()



func chekced():
	texture = light_tex
	emit_signal("item_click", self)

func unchecked():
	texture = null

func set_name_color(color):
	name_["custom_colors/font_color"] = color
	pass
func set_all_color(color):
	name_["custom_colors/font_color"] = color
	sex["custom_colors/font_color"] = color


func set_data(data):
	self.data = data
	
	if data.get("identity", 0) == 100:
		$HBoxContainer / Gm.show()
	else:
		$HBoxContainer / Gm.hide()
	
	if data.get("team_leader", - 1) == - 1:
		team_tex.texture = null
	else:
		
		if int(data.get("team_leader", null)) == int(data["id"]):
			team_tex.texture = team_res
			team_type = 0
		else:
			team_type = 1
			team_tex.texture = oteam_res
	
	if data.has("race_id"):
		sex.text = StaticGameData.get_role_sex_text(data["race_id"])
	else:
		sex.text = "空"
	
	if data.has("vip_exp") and data["vip_exp"] > 0:
		vip_num.text = "1"
	else:
		is_vip.texture = null
		vip_num.text = ""
	
	var pup = set_name_p_color(data)
	
	if data.has("popularity"):
		identity.visible = true
		if pup.length() > 2:
			identity.text = pup
		else:
			identity.text = "平民"
			identity["custom_colors/font_color"] = StaticGameData.colors["black"]
	else:
		identity.visible = false
	
	if data.has("job_id") and data.has("division_id"):
		var job_name = StaticGameData.get_role_job_text_format(data["job_id"], data["division_id"])
		var level = data.get("level", null)
		if level == null: level = ""
		else: level = str("LV", level)
		if NTeamManage.team_role_is_follow(get_role_id()):
			name_.text = str(level, job_name, data["role_name"], "[跟随]")
		else:
			name_.text = str(level, job_name, data["role_name"])
		
	
	if data.get("invite", false):
		name_.text = str("[邀]", name_.text)
		team_type = 3
		pass
	if data.get("request", false):
		name_.text = str("[申]", name_.text)
		team_type = 2
	


func is_team_captain():
	var team_leader_id = int(data.get("team_name", "team_-1").split("_")[1])
	return team_leader_id == data.get("id", - 2)

func has_team():
	return data.get("team_name", "").length() > 1

func get_role_id():
	return data["id"]

func _on_TextureButton_pressed() -> void :
	var player_items = Global.get_nodes_in_group("player_label_item")
	for item in player_items:
		if item != self: item.unchecked()
	chekced()

func set_name_p_color(info):
	if not info.has("popularity"): return ""
	var p = int(info["popularity"])
	var d_n = $HBoxContainer / ScrollContainer / VBoxContainer / Name
	var pup_n = $HBoxContainer / Identity
	if p >= - 50 and p < 0:
		d_n["custom_colors/font_color"] = Color(210 / 255.0, 105 / 255.0, 30 / 255.0, 1);
		pup_n["custom_colors/font_color"] = Color(210 / 255.0, 105 / 255.0, 30 / 255.0, 1);
		return "[歹徒]"
	elif p >= - 100 and p < - 50:
		d_n["custom_colors/font_color"] = Color(255 / 255.0, 69 / 255.0, 0 / 255.0, 1);
		pup_n["custom_colors/font_color"] = Color(255 / 255.0, 69 / 255.0, 0 / 255.0, 1);
		return "[恶霸]"
	elif p <= - 100:
		d_n["custom_colors/font_color"] = Color(1, 0, 0, 1);
		pup_n["custom_colors/font_color"] = Color(1, 0, 0, 1);
		return "[魔头]"
	elif p > 0 and p <= 50:
		d_n["custom_colors/font_color"] = Color(144 / 255.0, 238 / 255.0, 144 / 255.0, 1);
		pup_n["custom_colors/font_color"] = Color(144 / 255.0, 238 / 255.0, 144 / 255.0, 1);
		return "[侠士]"
	elif p > 50 and p < 100:
		d_n["custom_colors/font_color"] = Color(0, 1, 0.5, 1);
		pup_n["custom_colors/font_color"] = Color(0, 1, 0.5, 1);
		return "[勇士]"
	elif p >= 100:
		d_n["custom_colors/font_color"] = Color(0, 1, 1, 1);
		pup_n["custom_colors/font_color"] = Color(0, 1, 1, 1);
		return "[英雄]"
	else:
		d_n["custom_colors/font_color"] = Color(0, 0, 0, 1);
		pup_n["custom_colors/font_color"] = Color(0, 0, 0, 1);
		return ""
