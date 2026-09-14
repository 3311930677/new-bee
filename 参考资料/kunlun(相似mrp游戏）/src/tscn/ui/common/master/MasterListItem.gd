extends TextureRect

signal item_click

var light_tex = null

var StaticGameData
var data
func _ready():
	light_tex = Global.get("AssetsManage").get_ligth_tex()
	StaticGameData = Global.get("StaticGameData")
	pass


func _on_TextureButton_pressed():
	var player_items = Global.get_nodes_in_group("master_list_label_item")
	for item in player_items:
		if item != self: item.unchecked()
	chekced()

func chekced():
	texture = light_tex
	emit_signal("item_click", self)

func unchecked():
	texture = null

func set_data(data):
	self.data = data
	var sex = StaticGameData.get_role_sex_text(data.get("race_id", 0))
	var txt = str("LV", data.get("level", 1), " (%s) " % sex, data.get("role_name", "角色昵称"))
	var job = StaticGameData.get_role_job_text_format(data.get("job_id", 0), data.get("division_id", 0))
	$HBoxContainer / ScrollContainer / VBoxContainer / Name.text = txt
	$HBoxContainer / Division.text = job
	$HBoxContainer / Graduation.text = str("出师:", data.get("count", 0))
	

func set_all_color(color):
	$HBoxContainer / ScrollContainer / VBoxContainer / Name["custom_colors/font_color"] = color
	$HBoxContainer / Division["custom_colors/font_color"] = color
	$HBoxContainer / Graduation["custom_colors/font_color"] = color
