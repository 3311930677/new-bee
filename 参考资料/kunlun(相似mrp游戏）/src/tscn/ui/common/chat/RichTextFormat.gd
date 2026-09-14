extends RichTextLabel
const prefix = "ChatText->"

export (bool) var sort_msg_length = false




var face_template_res = ""

var first_init = true
var tab_model = 0

var ChatInfoManage
var StaticGameData
var AssetsManage


func _ready() -> void :
	ChatInfoManage = Global.get("ChatInfoManage")
	StaticGameData = Global.get("StaticGameData")
	AssetsManage = Global.get("AssetsManage")
	
	face_template_res = str(AssetsManage.get_prefix(), "assets/res/emoji/%d.png")
	clear()
	ChatInfoManage.connect("chat_single_info", self, "_on_recive_message")
	ChatInfoManage.connect("chat_remove_msg", self, "_remove_last_msg")


func _remove_last_msg():
	reload_msg(tab_model)

	rect_size.y = 0



func _on_recive_message(data):
	if first_init: first_init = false
	else: newline()
	
	if sort_msg_length:
		
		if get_line_count() >= 5:
			remove_line(0)
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
	
	append_bbcode(bb_str)


func reload_msg(tab_model):
	clear()
	first_init = true
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
