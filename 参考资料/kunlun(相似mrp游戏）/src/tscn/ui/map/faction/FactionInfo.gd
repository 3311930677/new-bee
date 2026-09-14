extends Control

onready var fac_name = $"Background/Background2/ScrollContainer/VBoxContainer/GHName/GHNameLabel"
onready var fac_role_name = $"Background/Background2/ScrollContainer/VBoxContainer/GHLeader/GHLeaderLabel"
onready var fac_level = $"Background/Background2/ScrollContainer/VBoxContainer/GHLevel/GHLevelLabel"
onready var fac_num = $"Background/Background2/ScrollContainer/VBoxContainer/GHMemberNum/GHMemberNumLabel"
onready var fac_coin = $"Background/Background2/ScrollContainer/VBoxContainer/GHConis/GHCoinsLabel"
onready var fac_desc = $"Background/Background2/ScrollContainer/VBoxContainer/GHInfo/RichTextLabel"


var FactionInfoManage
var RoleInfoManage
var ScreenUtils

func _ready() -> void :
	FactionInfoManage = Global.get("FactionInfoManage")
	RoleInfoManage = Global.get("RoleInfoManage")
	ScreenUtils = Global.get("ScreenUtils")
	FactionInfoManage.connect("faction_union_data_loaded", self, "_on_faction_union_data_loaded")
	

func _on_Cancle_pressed() -> void :
	queue_free()

func _on_faction_union_data_loaded(data):
	var arr_keys = data.keys()
	if arr_keys.size() <= 0:
		if FactionInfoManage.has_faction():
			FactionInfoManage.get_faction_union_data(RoleInfoManage.get_role_faction_id())
			hide()
			return
		else:
			ScreenUtils.show_message("你当前没有任何帮派")
			queue_free()
		pass
	load_data(data)
	pass


func load_data(data):
	show()
	if data.empty(): return
	fac_name.text = data["name"]
	fac_role_name.text = data["president_role_name"]
	fac_level.text = str(data["faction_level"], "/6")
	fac_num.text = str("%d/%d" % [data["current_role_num"], data["max_role_num"]])
	fac_coin.text = str(data["faction_coins"])
	fac_desc.clear()
	fac_desc.append_bbcode(str("[color=black]", data["_desc"]))
	pass
