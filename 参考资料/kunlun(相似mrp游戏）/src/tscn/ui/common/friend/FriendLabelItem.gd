extends TextureRect

signal item_click
onready var scroll_container = $HBoxContainer / ScrollContainer
onready var vbox = $HBoxContainer / ScrollContainer / VBoxContainer

onready var name_ = $HBoxContainer / ScrollContainer / VBoxContainer / Name
onready var sex = $HBoxContainer / Sex
onready var is_vip = $HBoxContainer / Vip
onready var vip_num = $HBoxContainer / Vip / VipNum
onready var level = $HBoxContainer / Level

var friend_type = 0

var data
var light_tex = null


var light_vip_res = null
var balck_vip_res = null

var StaticGameData

func _ready() -> void :
	StaticGameData = Global.get("StaticGameData")
	light_tex = Global.get("AssetsManage").get_ligth_tex()
	light_vip_res = load(str(Global.get("AssetsManage").get_prefix(), "assets/res/vip1.png"))
	balck_vip_res = load(str(Global.get("AssetsManage").get_prefix(), "assets/res/vip2.png"))
	
	unchecked()



func _on_TextureButton_pressed() -> void :
	var player_items = Global.get_nodes_in_group("friend_label_item")
	for item in player_items:
		if item != self: item.unchecked()
	chekced()

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
	level["custom_colors/font_color"] = color

func set_data(data):
	self.data = data
	var zhiye = StaticGameData.get_role_job_text_format(data["job_id"], data["division_id"])
	name_.text = str(zhiye, data["role_name"])
	sex.text = StaticGameData.get_role_sex_text(data["race_id"])
	level.text = str("LV", data["level"])
	
	if data.has("vip_exp"):
		vip_num.text = "1"
		pass
	else:
		is_vip.texture = null
		vip_num.text = ""
		pass
	if data["type"] == 1 or data["type"] == 2:
		if data["isOnline"] == 1:
			
			set_all_color(Global.get("StaticGameData").colors["black"])
			pass
		else:
			set_all_color(Global.get("StaticGameData").colors["grey"])
			
			pass
	else:
		set_all_color(Global.get("StaticGameData").colors["grey"])
		pass

func is_online():
	return data["isOnline"] == 1
