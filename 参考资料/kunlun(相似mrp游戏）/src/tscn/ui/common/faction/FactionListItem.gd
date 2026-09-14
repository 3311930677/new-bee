extends TextureRect
signal item_click

onready var name_ = $Name
onready var num = $Num

var light_tex = null

func _ready() -> void :
	light_tex = Global.get("AssetsManage").get_ligth_tex()
	
	var info = get_meta("data")
	if info == null: return
	var index = info["index"]
	var level = info["faction_level"]
	var _name_ = info["name"]
	
	var curren_num = info["current_role_num"]
	var max_role_num = info["max_role_num"]
	
	var show_n = str("%d.【%d级】%s" % [index, level, _name_])
	var show_m = str("%d/%d" % [curren_num, max_role_num])
	
	name_.text = show_n
	num.text = show_m
	
	pass

func _on_TextureButton_pressed() -> void :
	var arr_skill_labels = Global.get_nodes_in_group("faction_list_label_item")
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

func set_all_color(color):
	name_["custom_colors/font_color"] = color
	num["custom_colors/font_color"] = color
	pass
