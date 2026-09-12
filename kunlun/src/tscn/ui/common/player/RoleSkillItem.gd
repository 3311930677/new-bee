extends TextureRect
signal item_click

onready var skill_name = $SkillName
onready var skill_level = $SkillLevel

var StaticGameData
var AssetsManage

var light_tex = null
var skill_icon_path = "res://assets/skill/pet/%s"
var skill_info

func _ready() -> void :
	StaticGameData = Global.get("StaticGameData")
	AssetsManage = Global.get("AssetsManage")
	
	light_tex = AssetsManage.get_ligth_tex()
	

func _on_TextureButton_pressed() -> void :
	var arr_skill_labels = Global.get_nodes_in_group("role_skill_label_item")
	for item in arr_skill_labels:
		if item != self:
			item.unchecked()
	checked()


func checked():
	self.texture = light_tex
	emit_signal("item_click", self)
	pass

func unchecked():
	self.texture = null
	pass

func set_skill_id(sk_id):
	skill_info = StaticGameData.get_skill_data(sk_id)
	var icon_name = skill_info["icon"]
	if icon_name == null or icon_name.length() < 2: icon_name = "cj_0.png"
	
	$TextureRect.texture = load(skill_icon_path % icon_name)
	
	$SkillName.text = skill_info["name"]
	
	$SkillLevel.text = str("LV", skill_info["skill_level"])
	pass

func get_skill_desc():
	return skill_info["_desc"]
	pass
