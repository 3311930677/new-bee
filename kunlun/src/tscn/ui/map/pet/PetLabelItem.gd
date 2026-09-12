extends TextureRect


signal item_click

onready var grade = $Grade
onready var name_ = $Name
onready var level = $Level

var light_tex = null
var data
var static_data

var type = 2

var StaticGameData
var PetInfoManage
var AssetsManage
func _ready() -> void :
	StaticGameData = Global.get("StaticGameData")
	PetInfoManage = Global.get("PetInfoManage")
	AssetsManage = Global.get("AssetsManage")
	light_tex = AssetsManage.get_ligth_tex()
	
	PetInfoManage.connect("reset_pet", self, "_on_reset_pet")
	PetInfoManage.connect("fight_pet", self, "_on_fight_pet")
	pass


func _on_reset_pet():
	reload()
	pass
func _on_fight_pet():
	reload()
	pass

func checked():
	texture = light_tex
	emit_signal("item_click", self)

func set_all_color(color):
	level["custom_colors/font_color"] = color
	name_["custom_colors/font_color"] = color
	grade["custom_colors/font_color"] = color
	pass

func unckecked():
	texture = null

func reload():
	$Name.text = str(data.get("name", static_data.get("name", "宠物名称")))
	$Level.text = str("LV", data.get("level", "1"))
	$Grade.text = str(StaticGameData.get_pet_grade_text(data.get("grade", 1)))
	
	
	if data.get("bind", 1) == 1:
		$Bind2.hide()
	elif data.get("bind", 1) == 2:
		$Bind.hide()
	else:
		$Bind2.hide()
		$Bind.hide()

	if PetInfoManage.get_fight_pet_id() != data.get("id"):
		$Zhan.hide()

func set_data(data):
	self.data = data
	static_data = StaticGameData.get_pet_data(data.get("pet_race_id", "1"))
	if data.has("count"):
		if data["count"] <= 0:
			queue_free()
			return
	reload()
	

func get_pet_name():
	return $Name.text

func _on_TextureButton_pressed() -> void :
	var arr_pet_labels = Global.get_nodes_in_group("pet_label_item")
	for item in arr_pet_labels:
		if item != self:
			item.unckecked()
	checked()

func _on_reload_data():
	if (data.get("count", 1) <= 0): queue_free()
	pass
