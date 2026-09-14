extends TextureRect

signal item_click

onready var title = $HBoxContainer / ScrollContainer / TitleContainer / Title
onready var time = $HBoxContainer / ScrollContainer2 / TitleContainer / Time
onready var extract = $HBoxContainer / Extract

var light_tex = null

var MailInfoManage


var data

func _ready() -> void :
	light_tex = Global.get("AssetsManage").get_ligth_tex()
	MailInfoManage = Global.get("MailInfoManage")
	set_all_color(Global.get("GameData").colors["blue"])
	MailInfoManage.connect("mail_item_state_update", self, "_reload")

func checked():
	texture = light_tex
	emit_signal("item_click", self)

func set_all_color(color):
	title["custom_colors/font_color"] = color
	time["custom_colors/font_color"] = color
	pass

func unckecked():
	texture = null




func set_data(data):
	self.data = data
	_reload()

func _reload():
	title.text = data["title"]
	
	if data["extract"] != 0:
		extract.texture = null
	
	if data["state"] == 0:
		if data["role_id"] == 0:
			set_all_color(Global.get("StaticGameData").colors["red"])
		else:
			set_all_color(Global.get("StaticGameData").colors["blue"])
	else:
		
		set_all_color(Global.get("StaticGameData").colors["black"])
	var dic_time = OS.get_datetime_from_unix_time(int(data["create_time"]) / 1000 + 1 * 60 * 60 * 24 * 7)
	var time_hour = dic_time["hour"] + 8
	if time_hour >= 24:
		time_hour = time_hour - 24
	time.text = str(dic_time["year"], "-", dic_time["month"], "-", dic_time["day"], " ", time_hour, ":", dic_time["minute"], ":", dic_time["second"])
	pass

func _on_TextureButton_pressed() -> void :
	var arr_props = Global.get_nodes_in_group("mail_label_item")
	for item in arr_props:
		if item != self:
			item.unckecked();
	checked()
