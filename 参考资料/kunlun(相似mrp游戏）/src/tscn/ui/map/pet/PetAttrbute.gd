extends Panel

onready var power = $"Background/Background2/Private/Left/Panel/VBoxContainer/PetAttrItem1"
onready var agile = $"Background/Background2/Private/Left/Panel/VBoxContainer/PetAttrItem2"
onready var intelligence = $"Background/Background2/Private/Left/Panel/VBoxContainer/PetAttrItem3"
onready var endurance = $"Background/Background2/Private/Left/Panel/VBoxContainer/PetAttrItem4"
onready var spirit = $"Background/Background2/Private/Left/Panel/VBoxContainer/PetAttrItem5"

var source_data
var attribute
var add_point
var checked_node
var attr_desc = {
	"power": "力量(影响物理攻击，少量影响命中)", 
	"agile": "敏捷(影响出手速，少量影响闪避)", 
	"intelligence": "智力(影响法术攻击,少量影响暴击值)", 
	"endurance": "耐力(主要影响生命值上限，少量影响物理防御和法术防御)", 
	"spirit": "精神(主要影响魔法值上限，少量影响生命值上限)", 
}

var attr_change = {
	"power": 0, 
	"agile": 0, 
	"intelligence": 0, 
	"endurance": 0, 
	"spirit": 0, 
}
var ScreenUtils
var PetInfoManage

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	PetInfoManage = Global.get("PetInfoManage")
	
	PetInfoManage.connect("pet_point_add_success", self, "pet_point_add_success")
	
	power.connect("add_click", self, "add_click")
	power.connect("sub_click", self, "sub_click")
	power.connect("item_checked", self, "item_checked")
	
	agile.connect("add_click", self, "add_click")
	agile.connect("sub_click", self, "sub_click")
	agile.connect("item_checked", self, "item_checked")
	
	intelligence.connect("add_click", self, "add_click")
	intelligence.connect("sub_click", self, "sub_click")
	intelligence.connect("item_checked", self, "item_checked")
	
	endurance.connect("add_click", self, "add_click")
	endurance.connect("sub_click", self, "sub_click")
	endurance.connect("item_checked", self, "item_checked")
	
	spirit.connect("add_click", self, "add_click")
	spirit.connect("sub_click", self, "sub_click")
	spirit.connect("item_checked", self, "item_checked")
	

func set_data(data):
	source_data = data
	attribute = Global.get("CalculationManage").caculate_pet(data)
	
	set_private_data()
	set_public_data()
	pass


func set_private_data():
	var attr = attribute["normal"]
	var base_attr = attribute["basic"]
	$"Background/Background2/Private/Right/ScrollContainer/VBoxContainer/Atk".text = str("物攻 ", int(attr["physical_atk"]))
	$"Background/Background2/Private/Right/ScrollContainer/VBoxContainer/LAtk".text = str("法攻 ", int(attr["law_atk"]))
	$"Background/Background2/Private/Right/ScrollContainer/VBoxContainer/Def".text = str("物防 ", int(attr["physical_def"]))
	$"Background/Background2/Private/Right/ScrollContainer/VBoxContainer/LDef".text = str("法防 ", int(attr["law_def"]))
	$"Background/Background2/Private/Right/ScrollContainer/VBoxContainer/Dodge".text = str("闪避 ", int(attr["dodge"]))
	$"Background/Background2/Private/Right/ScrollContainer/VBoxContainer/Speed".text = str("速度 ", int(attr["shot_speed"]))
	$"Background/Background2/Private/Right/ScrollContainer/VBoxContainer/Crit".text = str("暴击 ", int(attr["bash"]))
	$"Background/Background2/Private/Right/ScrollContainer/VBoxContainer/Hp".text = str("生命 ", int(attr["max_hp"]))
	$"Background/Background2/Private/Right/ScrollContainer/VBoxContainer/Mp".text = str("魔法 ", int(attr["max_mp"]))
	$"Background/Background2/Private/Right/ScrollContainer/VBoxContainer/ShotSpeed".text = str("出手速 ", int(attr["shot_speed"]))
	$"Background/Background2/Private/Right/ScrollContainer/VBoxContainer/Hit".text = str("命中 ", int(attr["hit"]))
	
	var _point = {}
	add_point = source_data["petAddPoint"]["point"]
	_point["add_point"] = add_point
	
	set_private_left()
	power.set_data(base_attr, _point)
	agile.set_data(base_attr, _point)
	intelligence.set_data(base_attr, _point)
	endurance.set_data(base_attr, _point)
	spirit.set_data(base_attr, _point)
	pass


func set_public_data():
	var base_attr = attribute["basic"]
	var attr = attribute["normal"]
	$"Background/Background2/Public/ScrollContainer/VBoxContainer/Atk".text = str("物攻 ", int(attr["physical_atk"]))
	$"Background/Background2/Public/ScrollContainer/VBoxContainer/LAtk".text = str("法攻 ", int(attr["law_atk"]))
	$"Background/Background2/Public/ScrollContainer/VBoxContainer/Def".text = str("物防 ", int(attr["physical_def"]))
	$"Background/Background2/Public/ScrollContainer/VBoxContainer/LDef".text = str("法防 ", int(attr["law_def"]))
	$"Background/Background2/Public/ScrollContainer/VBoxContainer/Dodge".text = str("闪避 ", int(attr["dodge"]))
	$"Background/Background2/Public/ScrollContainer/VBoxContainer/Speed".text = str("速度 ", int(attr["shot_speed"]))
	$"Background/Background2/Public/ScrollContainer/VBoxContainer/Crit".text = str("暴击 ", int(attr["bash"]))
	$"Background/Background2/Public/ScrollContainer/VBoxContainer/Hp".text = str("生命 ", int(attr["max_hp"]))
	$"Background/Background2/Public/ScrollContainer/VBoxContainer/Mp".text = str("魔法 ", int(attr["max_mp"]))
	$"Background/Background2/Public/ScrollContainer/VBoxContainer/ShotSpeed".text = str("出手速 ", int(attr["shot_speed"]))
	$"Background/Background2/Public/ScrollContainer/VBoxContainer/Power".text = str("力量 ", round(base_attr["power"]))
	$"Background/Background2/Public/ScrollContainer/VBoxContainer/Agile".text = str("敏捷 ", round(base_attr["agile"]))
	$"Background/Background2/Public/ScrollContainer/VBoxContainer/Intelligence".text = str("智力 ", round(base_attr["intelligence"]))
	$"Background/Background2/Public/ScrollContainer/VBoxContainer/Endurance".text = str("耐力 ", round(base_attr["endurance"]))
	$"Background/Background2/Public/ScrollContainer/VBoxContainer/Spirit".text = str("精神 ", round(base_attr["spirit"]))
	$"Background/Background2/Public/ScrollContainer/VBoxContainer/Spirit".text = str("命中 ", int(attr["hit"]))

func set_private_left():
	$"Background/Background2/Private/Left/Remain".text = str("剩余点数：", add_point)
	pass

func add_click(node):
	var key = node.key
	attr_change[key] += 1
	add_point -= 1
	set_private_left()
	pass

func sub_click(node):
	var key = node.key
	attr_change[key] -= 1
	add_point += 1
	set_private_left()
	pass

func item_checked(node):
	clear_red()
	checked_node = node
	
	if node.key == "power":
		var labe1 = $"Background/Background2/Private/Right/ScrollContainer/VBoxContainer/Atk"
		labe1["custom_colors/font_color"] = Color(1, 0, 0, 1)
		pass
	elif node.key == "agile":
		var labe1 = $"Background/Background2/Private/Right/ScrollContainer/VBoxContainer/Dodge"
		var labe2 = $"Background/Background2/Private/Right/ScrollContainer/VBoxContainer/ShotSpeed"
		labe1["custom_colors/font_color"] = Color(1, 0, 0, 1)
		labe2["custom_colors/font_color"] = Color(1, 0, 0, 1)
		pass
	elif node.key == "intelligence":
		var labe1 = $"Background/Background2/Private/Right/ScrollContainer/VBoxContainer/LAtk"

		labe1["custom_colors/font_color"] = Color(1, 0, 0, 1)

		pass
	elif node.key == "endurance":
		var labe1 = $"Background/Background2/Private/Right/ScrollContainer/VBoxContainer/Hp"
		var labe2 = $"Background/Background2/Private/Right/ScrollContainer/VBoxContainer/Def"
		var labe3 = $"Background/Background2/Private/Right/ScrollContainer/VBoxContainer/LDef"
		labe1["custom_colors/font_color"] = Color(1, 0, 0, 1)
		labe2["custom_colors/font_color"] = Color(1, 0, 0, 1)
		labe3["custom_colors/font_color"] = Color(1, 0, 0, 1)
		pass
	elif node.key == "spirit":
		var labe1 = $"Background/Background2/Private/Right/ScrollContainer/VBoxContainer/Mp"
		var labe2 = $"Background/Background2/Private/Right/ScrollContainer/VBoxContainer/Hp"
		labe1["custom_colors/font_color"] = Color(1, 0, 0, 1)
		labe2["custom_colors/font_color"] = Color(1, 0, 0, 1)
		pass
	else:
		checked_node = null
	pass
func clear_red():
	var vbox = $"Background/Background2/Private/Right/ScrollContainer/VBoxContainer"
	for item in vbox.get_children():
		item["custom_colors/font_color"] = Color(0, 0, 0, 1)
	pass

func _on_Save_pressed() -> void :
	for key in attr_change.keys():
		if attr_change[key] > 0:
			ScreenUtils.show_message("确定保存加点？", self, "ok_save_point")
			return
	pass

func ok_save_point():
	PetInfoManage.add_pet_point(source_data["petHold"]["id"], attr_change)
	pass

func pet_point_add_success():
	ScreenUtils.show_message("宠物点数保存成功")

	
	
	
	for k in attr_change.keys():

		attr_change[k] = 0

	set_private_data()
	pass


func _on_Ok_pressed() -> void :
	if checked_node == null: return
	ScreenUtils.show_message(attr_desc[checked_node.key])
