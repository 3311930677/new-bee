extends Control

onready var sender_name = $Background / Background2 / Sender / SenderName
onready var title = $Background / Background2 / MailTitle / Title
onready var content = $Background / Background2 / MailContent / ScrollContainer / VBoxContainer / RichTextLabel
onready var time = $"Background/Background2/Sender2/Time"
onready var popup_menu = $"Control/PopupMenu"

onready var give_yin_liang = $"Background/Background2/Yingliang"
onready var give_yin_liang_num = $"Background/Background2/Yingliang/HBoxContainer/YinLiang"


onready var cost_yin_liang = $"Background/Background2/Price"
onready var cost_yin_liang_num = $"Background/Background2/Price/HBoxContainer/YinLiang"

onready var mail_attach = $"Background/Background2/MailAttach"
onready var attach_btn = $"Background/Background2/MailAttach/AttachOptionButton"
onready var attach_inspect = $"Background/Background2/MailAttach/InspectAttach"
onready var attach_state = $"Background/Background2/MailAttach/Label2"


var MailInfoManage
var MailOperate
var StaticGameData
var ScreenUtils
var RichTextContentFormat


var data
var data_details

func _ready() -> void :
	MailInfoManage = Global.get("MailInfoManage")
	StaticGameData = Global.get("StaticGameData")
	MailOperate = Global.get("MailOperate")
	ScreenUtils = Global.get("ScreenUtils")
	RichTextContentFormat = Global.get("RichTextContentFormat")
	MailInfoManage.connect("mail_content_detailed", self, "_mail_content_detailed")
	MailInfoManage.connect("mail_item_state_update", self, "reload")
	MailInfoManage.connect("mail_delete_successed", self, "_on_Cancle_pressed")
	


func _mail_content_detailed(data):
	data_details = data
	reload()
	show()
	
	


func _on_Cancle_pressed() -> void :
	queue_free()



func load_data(data):
	hide()
	self.data = data["mail_data"]
	MailInfoManage.get_mail_content(self.data)


func _on_PopupMenu_index_pressed(index: int) -> void :
	var id = popup_menu.get_item_id(index)
	MailOperate.menu_item_click(id)


func _on_Ok_pressed() -> void :
	var menu = {}
	menu["5"] = "回复邮件"
	if data["extract"] == 0:
		menu["2"] = "提取附件"
		if data["cost"] <= 0:
			menu["3"] = "删除邮件"
		pass
	else:
		menu["3"] = "删除邮件"
	MailOperate.data = data
	ScreenUtils.build_menu(popup_menu, menu)
	popup_menu.popup_centered()

func reload():
	sender_name.text = data_details["role_name"]
	title.text = str(data_details["title"])
	content.clear()
	content.append_bbcode(str("[color=black]", RichTextContentFormat.get_content_format(data_details["content"]), "[/color]"))
	
	var dic_time = OS.get_datetime_from_unix_time(int(data_details["create_time"]) / 1000 + 1 * 60 * 60 * 24 * 7)
	var time_hour = dic_time["hour"] + 8
	if time_hour >= 24:
		time_hour = time_hour - 24
	time.text = str(dic_time["year"], "-", dic_time["month"], "-", dic_time["day"], " ", time_hour, ":", dic_time["minute"], ":", dic_time["second"])
	
	attach_btn.clear()
	
	if int(self.data["extract"]) == - 1:
		mail_attach.hide()
		give_yin_liang.hide()
		cost_yin_liang.hide()
	elif int(self.data["extract"]) == 1:
		attach_state.text = "已提取"
		attach_btn.hide()
		attach_inspect.hide()
		give_yin_liang.hide()
		cost_yin_liang.hide()
		
		data_details["cost"] = 0
		data_details["give_gold_coins"] = 0
	else:
		
		if data_details["give_gold_coins"] <= 0:
			give_yin_liang.hide()
		else:
			give_yin_liang.show()
			give_yin_liang_num.text = str(data_details["give_gold_coins"])
		
		if data_details["cost"] <= 0:
			cost_yin_liang.hide()
		else:
			cost_yin_liang.show()
			cost_yin_liang_num.text = str(data_details["cost"])
		
		attach_state.text = "未提取"
		
		
		if data_details["attachs"].size() <= 0:
			attach_btn.hide()
			attach_inspect.hide()
		
		for attach_item in data_details["attachs"]:
			
			var static_data = StaticGameData.get_bag_artic_data_info(attach_item)
			
			var format_str = str("LV", static_data.get("level", attach_item.get("level", 1)), " ", static_data.get("name", static_data.get("race", attach_item.get("name", "无法显示"))), " x", attach_item.get("count", 1))
			
			if int(attach_item["item_type"]) == 2:
				format_str = str("LV", attach_item["level"], " ", static_data["race"], " x", attach_item.get("count", 1))
			else:
				format_str = str("LV", static_data["level"], " ", static_data["name"], " x", attach_item.get("count", 1))
			
			attach_btn.add_item(format_str, attach_item["id"])
		attach_btn.select(0)



func _on_InspectAttach_pressed() -> void :
	var id = attach_btn.get_selected_id()
	
	var attach_item = _get_attach_details(id)
	
	var type = int(attach_item["item_type"])
	
	match type:
		2:
			ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/pet/PetUi.tscn", "load_data", {"pet_type": 1, "id": id})
			pass
		3:
			Global.get("BagInfoManage").get_equipment_details(id)
			pass
		4:
			var static_data = StaticGameData.get_gem_data(attach_item["gemstone_id"])
			StaticGameData.show_art_data_info(static_data)
			pass
		5:
			var static_data = StaticGameData.get_article_data(attach_item["articles_data_id"])
			StaticGameData.show_art_data_info(static_data)
			pass
		_:
			ScreenUtils.show_message("未知物品类型")
			pass
	
	
	
	
	
	
	
	
	
	


func _get_attach_details(atid):
	for attach_item in data_details["attachs"]:
		if attach_item["id"] == atid: return attach_item
	return null
