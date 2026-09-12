extends Control

onready var chat_mode_area = $"Background/ChatModel"
onready var chat_mode_sm = $"Background/ChatModelSm"
onready var attach_btn = $"Background/Attach/OptionButton"
onready var recive_name = $"Background/ChatModelSm/ReciveName"
onready var edit = $Background / Message / TextEdit


var type = 2

var ScreenUtils
var ChatInfoManage
var StaticGameData
var RoleInfoManage

var data
var recipient_id = - 1

var attach_list_source = []
var attach_list = []

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	ChatInfoManage = Global.get("ChatInfoManage")
	StaticGameData = Global.get("StaticGameData")
	RoleInfoManage = Global.get("RoleInfoManage")


func _on_emoji_pressed(extra_arg_0: int) -> void :
	extra_arg_0 = extra_arg_0 - 1
	edit.insert_text_at_cursor(str("{M%d}" % extra_arg_0))



func _on_add_attach(data, num):
	var item_type = StaticGameData.get_articles_item_type(data)
	
	if attach_list.size() > 5:
		ScreenUtils.show_message("最多只能添加5件物品")
		return
	
	for i in attach_list:
		if i["id"] == data["id"]:
			ScreenUtils.show_message("不能添加相同物品，请重试")
			return
	data["item_type"] = item_type
	var temp = {
		"type": item_type, 
		"id": data["id"], 
		"num": num, 
	}
	data["temp_attach_num"] = num
	attach_list.append(temp)
	attach_list_source.append(data)
	reload_attaches()


func _on_AddAttach_pressed() -> void :
	ScreenUtils.show_select_attach_ui(self, "_on_add_attach", true)


func _on_RemoveAttach_pressed() -> void :
	var id = attach_btn.get_selected_id()
	if id == 0: return
	var index = 0
	for i in attach_list:
		if int(i["id"]) == id:
			attach_list.remove(index)
			break
		index += 1
	for i in attach_list_source:
		if int(i["id"]) == id:
			attach_list_source.remove(index)
			break
		index += 1
	
	reload_attaches()


func _on_Cancle_pressed() -> void :
	if edit.text.length() > 0:
		ScreenUtils.show_message("确定放弃当前已编辑内容？", self, "_ok_cancle_press")
	else:
		_ok_cancle_press()

func _ok_cancle_press():
	queue_free()


func _on_Ok_pressed() -> void :
	if edit.text.length() < 1:
		ScreenUtils.show_message("消息长度过短")
		return
	if edit.text.length() > 50:
		ScreenUtils.show_message("超过消息长度最大50字符")
		return
	if attach_list.size() >= 6:
		ScreenUtils.show_message("携带附件最多5件")
		return
	var request_msg = {
			"type": type, 
			"text": edit.text.replace("\n", ""), 
			"attachs": attach_list
	}
	
	var role_info = RoleInfoManage.get_role_info()
	if role_info.get("faction_id", 0) <= 0 and type == 5:
		ScreenUtils.show_message("你当前没有帮派")
		return
	
	if recipient_id != - 1: request_msg["recipient_id"] = recipient_id
	
	ChatInfoManage.send_message(request_msg)
	queue_free()

func _on_CheckBox_pressed(extra_arg_0: int) -> void :
	type = extra_arg_0
	pass

func load_data(data):
	self.data = data
	if data.has("role_name"):
		chat_mode_sm.show()
		recive_name.text = data["role_name"]
		chat_mode_area.hide()
		recipient_id = data["id"]
		type = 3
	else:
		chat_mode_sm.hide()
		chat_mode_area.show()


func reload_attaches():
	attach_btn.clear()
	for item in attach_list_source:
		
		var item_type = StaticGameData.get_articles_item_type(item)
		var data = StaticGameData.get_bag_artic_data_info(item)
		var format_txt = ""
		if item_type == 2:
			format_txt = str("LV", item["level"], " ", item["name"], " x", item["temp_attach_num"])
		else:
			format_txt = str("LV", data["level"], " ", data["name"], " x", item["temp_attach_num"])
		attach_btn.add_item(format_txt, item["id"])
	attach_btn.select(0)
	pass

