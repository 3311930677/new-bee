extends TextureRect
signal item_click

var skill_info
var StaticGameData
var AssetsManage
var skill_id_ = - 1
var path_template = "res://assets/skill/pet/%s"
var light_tex = null

func _ready() -> void :
	StaticGameData = Global.get("StaticGameData")
	AssetsManage = Global.get("AssetsManage")

	light_tex = AssetsManage.get_ligth_tex()
	pass


func set_skill_id(skill_id):
	skill_id_ = skill_id
	if skill_id == - 1:
		normal()
		return
	if skill_id == 0:
		disable()
		return
	skill_info = StaticGameData.get_skill_data(skill_id)
	$SkillName.text = skill_info["name"]
	$SkillName["custom_colors/font_color"] = Color(0, 0, 1, 1)
	if skill_info["icon"].length() < 1:
		$SkillIcon.texture = load(path_template % "cj_0.png")
	else:
		$SkillIcon.texture = load(path_template % skill_info["icon"])
	if skill_info["type"] == 1:
		$SkillType.text = "（主动）"
	else:
		$SkillType.text = "（被动）"

func normal():
	$SkillName.text = "普通技能槽"
	$SkillName["custom_colors/font_color"] = Color(0.5, 0.5, 0.5, 1)
	$SkillIcon.texture = load(path_template % "cj_0.png")
	$SkillType.text = ""
	skill_info = null
	pass
func disable():
	$SkillName.text = "未开启"
	$SkillName["custom_colors/font_color"] = Color(0.5, 0.5, 0.5, 1)
	$SkillIcon.texture = load(path_template % "cj_0.png")
	$SkillType.text = ""
	skill_info = null
	pass

func checked():
	self.texture = light_tex
	emit_signal("item_click", self)
	pass

func unchecked():
	self.texture = null
	pass

func _on_TextureButton_pressed() -> void :
	var arr_skill_labels = Global.get_nodes_in_group("pet_skill_label_item")
	for item in arr_skill_labels:
		if item != self:
			item.unchecked()
	checked()
	pass

func get_skill_desc():
	return skill_info.get("_desc", null)
