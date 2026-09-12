extends PopupPanel

onready var rich_txt = $RichTextLabel

var ScreenUtils
var StaticGameData


func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	StaticGameData = Global.get("StaticGameData")
	pass


func set_data(data):
	rich_txt.clear()
	rich_txt.rect_size = Vector2(228, 0)
	rect_size = Vector2(228, 0)
	var bb_code_name = str(StaticGameData.get_equ_all_name(data), "\n")
	
	var static_data = StaticGameData.get_equi_data(data.equi_data_id)
	
	
	var txt_color = static_data["display_color"]
	if txt_color == "000000": txt_color = "ffffff"
	
	bb_code_name = str("[center][color=#%s]" % txt_color, bb_code_name, "[/color][/center]")
	bb_code_name = str(bb_code_name, "当前孔洞如下，请选择对应孔洞进行镶嵌，已镶嵌的位置无法再次镶嵌，每次镶嵌需要消耗500金币[center]\n")
	
	var mosaics = data.get("equipmentMosaics", {})
	for i in data.punch:
		var gem_id = mosaics.get("gemstone_id_%d" % (i + 1), 0)
		var temp_data = {}
		temp_data["index"] = i + 1
		if gem_id == 0:
			bb_code_name = str(bb_code_name, "[url=%s]" % to_json(temp_data), i + 1, ".宝石镶嵌槽", "[/url]\n")
			pass
		else:
			var gem_static_data = StaticGameData.get_gem_data(gem_id)
			var tip_color = gem_static_data["display_color"]
			if tip_color == "000000": tip_color = "ffffff"
			var tip = str("[color=#%s]LV%d %s" % [tip_color, gem_static_data["level"], gem_static_data["name"]], "[/color]")
			bb_code_name = str(bb_code_name, "%d.%s" % [i + 1, tip], "\n")
			pass
		pass
	rich_txt.append_bbcode(bb_code_name)
	pass
