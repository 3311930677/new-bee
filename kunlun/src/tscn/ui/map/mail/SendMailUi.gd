extends Control

onready var recive_name = $Background / Background2 / Sender / ReciveName

onready var mail_title = $"Background/Background2/CMailTitle/MailTitle"
onready var mail_content = $"Background/Background2/MailContent/MailContent"

onready var give_yin_liang = $"Background/Background2/GiveYingLiang/HBoxContainer/YinLiang"
onready var price = $"Background/Background2/Price/HBoxContainer/YinLiang"
onready var attach_btn = $Background / Background2 / MailAttach / AttachOptionButton

var ScreenUtils
var MailOperate
var MailInfoManage
var RoleInfoManage
var BagInfoManage
var StaticGameData


var cost = 0

var give_coins = 0

var attaches = []
var attaches_source = []


func load_data(data):
	if data == null or data.empty(): return
	recive_name.text = data.get("name", "")


func reload_attaches():
	attach_btn.clear()
	for item in attaches_source:
		
		var data = StaticGameData.get_bag_artic_data_info(item)
		var format_txt
		if int(item["item_type"]) == 2:
			format_txt = str("LV", item["level"], " ", data["race"], " x", item["attach_num"])
		else:
			format_txt = str("LV", data["level"], " ", data["name"], " x", item["attach_num"])
		attach_btn.add_item(format_txt, item["id"])
	attach_btn.select(0)

func _on_removeAttach_pressed() -> void :
	var id = attach_btn.get_selected_id()
	if id == 0: return
	var index = 0
	for i in attaches:
		if int(i["id"]) == id:
			attaches.remove(index)
			break
		index += 1
	for i in attaches_source:
		if int(i["id"]) == id:
			attaches_source.remove(index)
			break
		index += 1
	
	reload_attaches()
	pass

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	MailOperate = Global.get("MailOperate")
	MailInfoManage = Global.get("MailInfoManage")
	BagInfoManage = Global.get("BagInfoManage")
	RoleInfoManage = Global.get("RoleInfoManage")
	StaticGameData = Global.get("StaticGameData")
	
	MailInfoManage.connect("mail_send_successed", self, "_on_mail_send_successed")


func _on_Cancle_pressed() -> void :
	if mail_title.text.length() > 0 and recive_name.text.length() > 1:
		ScreenUtils.show_message("确定放弃已经编辑好的邮件？", self, "_cancle_ok")
	else: _cancle_ok()
func _cancle_ok():
	queue_free()


func _on_add_attach(data, num):
	if data.has("pet_race_id"):
		if data["id"] == Global.get("PetInfoManage").get_fight_pet_id():
			ScreenUtils.show_message("不能选择已出战的宠物")
			return
	Global.log_info(str(data, num))
	var item_type = StaticGameData.get_articles_item_type(data)
	
	
	for i in attaches:
		if i["id"] == data["id"]:
			ScreenUtils.show_message("不能添加相同物品，请重试")
			return
	data["item_type"] = item_type
	data["attach_num"] = num
	var temp = {
		"type": item_type, 
		"id": data["id"], 
		"num": num, 
	}
	attaches.append(temp)
	attaches_source.append(data)
	if attaches.size() > 3:
		ScreenUtils.show_message("最多只能添加3件物品")
		return
	reload_attaches()

func _on_Ok_pressed() -> void :
	ScreenUtils.show_message("确定发送邮件？", self, "_send_mail_ok")
	pass

func _send_mail_ok():
	var dic_data = {
		"title": mail_title.text, 
		"content": mail_content.text, 
		"recipient_name": recive_name.text, 
		"cost": cost, 
		"give_gold_coins": give_coins, 
		"attachs": attaches
	}
	if mail_title.text.length() > 15:
		ScreenUtils.show_message("邮件标题过长")
		return
	
	if mail_title.text.length() <= 1:
		ScreenUtils.show_message("邮件标题过短(1个以上)")
		return
	MailInfoManage.send_mail(dic_data)
	
	for att in attaches_source:
		BagInfoManage.sub_data(att, att["attach_num"])





func _on_mail_send_successed():
	
	BagInfoManage.set_gold_coins(give_coins)
	queue_free()

func _on_AddAttach_pressed() -> void :
	ScreenUtils.show_select_attach_ui(self, "_on_add_attach")


func _on_SetPrice_pressed() -> void :
	ScreenUtils.show_popup_menu_edit(self, "_set_price", 0, "请输入价格")


func _set_price(id, txt):
	var num = int(txt)
	if num >= 0:
		cost = num
		price.text = str(cost)
		pass
	else:
		ScreenUtils.show_message("输入值无效")

func _on_GiveCoin_pressed() -> void :
	ScreenUtils.show_popup_menu_edit(self, "_give_coin", 0, "请输入赠送银两")
	pass

func _give_coin(id, txt):
	var num = int(txt)
	if num >= 0:
		give_coins = num
		give_yin_liang.text = str(give_coins)
		pass
	else:
		ScreenUtils.show_message("输入值无效")



