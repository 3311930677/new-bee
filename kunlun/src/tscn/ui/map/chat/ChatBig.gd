extends Node

const prefix = "ChatText->"

onready var vbox = $Background2 / ScrollContainer / VBoxContainer


var font = preload("res://assets/font/font-16.tres")
var face_template_res = ""

var first_init = true
var tab_model = 0

var ChatInfoManage
var StaticGameData

func _init():
	face_template_res = str(Global.get("AssetsManage").get_prefix(), "assets/res/emoji/%d.png")

func _ready() -> void :
	ChatInfoManage = Global.get("ChatInfoManage")
	StaticGameData = Global.get("StaticGameData")
	ChatInfoManage.connect("chat_single_info", self, "_on_recive_message")
	ChatInfoManage.connect("chat_remove_msg", self, "_remove_last_msg")


func _remove_last_msg(data: Dictionary):
	for i in vbox.get_children():
		var temp_data = i.get_meta("data")
		if temp_data == null: continue
		if temp_data["time"] == data["time"] and temp_data["role_id"] == data["role_id"]:
			i.queue_free()






func _on_recive_message(data):
	var bb_str = ""
	match int(data["type"]):
		0:
			Global.log_info(str(prefix, "游戏世界消息->", data))
			if tab_model == 0:
				bb_str = ChatInfoManage.show_world_msg(data)
			pass
		1:
			Global.log_info(str(prefix, "游戏系统消息->", data))
			if tab_model == 0:
				bb_str = ChatInfoManage.show_system_msg(data)
			pass
		2:
			Global.log_info(str(prefix, "游戏区消息->", data))
			if tab_model == 2 or tab_model == 0:
				bb_str = ChatInfoManage.format_area_msg(data)
			pass
		3:
			Global.log_info(str(prefix, "游戏密消息->", data))
			if tab_model == 3 or tab_model == 0:
				bb_str = ChatInfoManage.show_sm_msg(data)
			pass
		4:
			Global.log_info(str(prefix, "游戏队伍消息->", data))
			if tab_model == 4 or tab_model == 0:
				bb_str = ChatInfoManage.show_team_msg(data)
			pass
		5:
			Global.log_info(str(prefix, "游戏帮派消息->", data))
			if tab_model == 5 or tab_model == 0:
				bb_str = ChatInfoManage.format_area_msg(data, "帮")
			pass
		6:
			Global.log_info(str(prefix, "游戏战斗消息->", data))
			if tab_model == 6:
				bb_str = ChatInfoManage.show_zhan_msg(data)
			pass
	if bb_str.length() >= 1:
		add_rich_txt_item(bb_str, data)

func add_rich_txt_item(bb_str, data):
	var rich_txt: RichTextLabel = RichTextLabel.new()
	rich_txt.set_fit_content_height(true)
	rich_txt["custom_fonts/normal_font"] = font
	rich_txt.append_bbcode(bb_str)
	rich_txt.connect("meta_clicked", $"..", "_on_RichTextLabel_meta_clicked")
	rich_txt.mouse_filter = 1
	rich_txt.meta_underlined = true
	rich_txt.set_meta("data", data)
	vbox.add_child(rich_txt)
	pass


func reload_msg(tab_model):
	clear_container()
	self.tab_model = tab_model
	var list_load_msg = []
	match tab_model:
		0: list_load_msg = ChatInfoManage.get_all_msg()
		2: list_load_msg = ChatInfoManage.get_area_msg()
		3: list_load_msg = ChatInfoManage.get_sm_msg()
		4: list_load_msg = ChatInfoManage.get_team_msg()
		5: list_load_msg = ChatInfoManage.get_bang_msg()
		6: list_load_msg = ChatInfoManage.get_zhan_msg()
	for msg in list_load_msg:
		_on_recive_message(msg)

func clear_container():
	for i in vbox.get_children():
		i.queue_free()
