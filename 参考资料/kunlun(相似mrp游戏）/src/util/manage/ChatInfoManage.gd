extends Node
class_name ChatInfoManage
const prefix = "ChatInfoManage->"

signal chat_single_info
signal chat_remove_msg

var ScreenUtils
var NetContext
var RoleInfoManage

var max_msg_size = 25



var msg_map_list = {
	
}

var filter_char = ["爸", "妈", "母", "父", "爹", "娘", "操", "艹", "日", "死", "系", "统", "猪", "狗", "逼", "儿", "奸", "屌", "鸡", "贱", "草", "废", "B", "巴"]
func _init() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	NetContext = Global.get("NetContext")
	RoleInfoManage = Global.get("RoleInfoManage")
	
	NetContext.set_handler("ServicePush", "MessagePush", self, "_on_receive_message_result")
	NetContext.set_handler("MessageRemote", "sendMessage", self, "_on_send_message_result")
	pass


func _on_receive_message_result(data):
	data = parse_json(data["data"])
	
	for t in filter_char:
		data["text"] = data["text"].replacen(t, "*")

	match int(data["type"]):
		0:
			Global.log_info(str(prefix, "游戏综合（世界）消息->", data))
			pass
		1:
			Global.log_info(str(prefix, "游戏系统（综合）消息->", data))
			var prefix_txt_name = "[color=#FF0000][系] [/color]"
			ScreenUtils.show_top_tips(str(prefix_txt_name, data["text"]))
			pass
		2:
			Global.log_info(str(prefix, "游戏区消息->", data))
			pass
		3:
			Global.log_info(str(prefix, "游戏密消息->", data))
			var arr_icons = Global.get_nodes_in_group("chat_icon")
			if arr_icons.size() > 0 and data["role_id"] != RoleInfoManage.get_role_id(): arr_icons[0].start_glimmer()
		4:
			Global.log_info(str(prefix, "游戏队伍消息->", data))
			pass
		5:
			Global.log_info(str(prefix, "游戏帮派消息->", data))
			pass
		6:
			Global.log_info(str(prefix, "游戏战斗消息->", data))
			pass
	
	push(data)
	







	
	emit_signal("chat_single_info", data)

func _on_send_message_result(data):
	Global.log_info(str(prefix, "消息发送成功", data))
	pass



func send_message(dic: Dictionary):
	NetContext.request_service("MessageRemote", "sendMessage", dic, true)


func push(msg):
	
	var all = msg_map_list.get("all", [])
	all.push_back(msg)
	msg_map_list["all"] = all
	check_list(all)
	
	var temp = msg_map_list.get(str(msg["type"]), [])
	temp.push_back(msg)
	msg_map_list[str(msg["type"])] = temp
	check_list(temp)
	

func check_list(msg_list):
	if msg_list.size() >= max_msg_size:
		var temp = msg_list.pop_front()
		emit_signal("chat_remove_msg", temp)
	pass


func get_all_msg():
	var temp_msg = []
	for msg in msg_map_list.get("all", []):
		if msg["type"] != 6:
			temp_msg.append(msg)
	return temp_msg


func get_area_msg():
	return msg_map_list.get(str(2), [])


func get_sm_msg():
	return msg_map_list.get(str(3), [])


func get_team_msg():
	return msg_map_list.get(str(4), [])


func get_bang_msg():
	return msg_map_list.get(str(5), [])


func get_zhan_msg():
	return msg_map_list.get(str(6), [])










func private_get_role_name_format(role_name, role_id, area_id):
	var role_info = {
		"role_name": role_name, 
		"id": role_id, 
		"area_id": area_id, 
		"chat_type": 0
	}
	var url = str("[url=%s]" % to_json(role_info))
	return "[color=#FF00FF]%s %s [/url][/color]" % [url, role_name]



func private_get_content_format(content: String):
	var format_content = content
	var face_template_res = str(Global.get("AssetsManage").get_prefix(), "assets/res/emoji/%d.png")
	for i in range(14):
		var tm = str("[img]", face_template_res % i, "[/img]")
		format_content = format_content.replacen("{m%d}" % i, tm)
	return format_content

func private_get_attachs_format(arr_attachs):
	var all_bbcode_txt = ""
	for attach in arr_attachs:
		attach["chat_type"] = 1
		attach["item_type"] = attach["type"]
		var static_data = Global.get("StaticGameData").get_bag_artic_data_info(attach)
		var bind = Global.get("StaticGameData").get_bind_text_format(attach.get("bind", 0))
		bind = str("[color=#%s]%s[/color]" % [static_data["display_color"], bind])
		var type = Global.get("StaticGameData").get_articles_item_type(attach)
		var name_
		var level
		if attach["item_type"] == 2:
			name_ = attach["name"]
			level = attach["level"]

			name_ = str("【%s[color=#%s]LV%s " % [bind, static_data["display_color"], level], "[url=%s]" % to_json(attach), name_, "[/url][/color]】")
		elif attach["item_type"] == 3:
			level = str(static_data.get("level", "1"))
			var counter = Global.get("StaticGameData").get_countermark_text_format(attach.get("countermark", 0))
			
			var job = Global.get("StaticGameData").get_euqi_job_text_format(attach["equi_data_id"])
			if counter != null and counter.length() > 1:
				bind = counter
			
			var consolid_level = ""
			if attach.get("consolidate_level", 0) > 0:
				consolid_level = str("+", attach.get("consolidate_level", 1))
				if attach.get("punch", 0) > 0:
					consolid_level = str("%s[%d]" % [consolid_level, int(attach.get("punch"))])
			var color__ = static_data["display_color"]
			var mar = ""
			if attach.get("is_mar", 0):
				color__ = "B3B3B3"
				mar = "[损坏]"
				pass
			name_ = static_data["name"]

			name_ = str("[url=%s]" % to_json(attach), "【%s[color=#%s]  LV%s %s" % [bind, color__, level, job], name_, consolid_level, mar, "[/color]】[/url]")
			
			pass
		else:
			level = str(static_data.get("level", "1"))
			name_ = static_data["name"]

			name_ = str("[url=%s]" % to_json(attach), "【%s[color=#%s]LV%s " % [bind, static_data["display_color"], level], name_, " x%d[/color]】[/url]" % attach.get("num", 1))
		
		all_bbcode_txt = str(all_bbcode_txt, name_)
	return str("[color=#000000]", all_bbcode_txt, "[/color]")


func show_system_msg(data):
	var content = private_get_content_format(data["text"])
	content.replacen("\n", "")
	content.replacen("\r", "")
	var attach = private_get_attachs_format(data.get("attachs", []))
	var prefix_txt_name = "[color=#FF0000][系] [/color]"
	return str(prefix_txt_name, content, attach)

func show_world_msg(data):
	var prefix_txt_name = "[color=#FF00FF][世] [/color]"
	var sender_name = private_get_role_name_format(data["role_name"], data["role_id"], data.get("area_id", 0))
	var content = private_get_content_format(data["text"])
	content.replacen("\n", "")
	content.replacen("\r", "")
	
	
	if data["role_id"] != 0:
		content = str("[color=#FF00FF] %s[/color]" % content)
	else:
		prefix_txt_name = "[color=#FF0000]"
		sender_name = str("[%s]" % data["role_name"])
		content = str("[color=#FF0000] %s[/color]" % content)
	
	var attach = private_get_attachs_format(data.get("attachs", []))
	if data["role_id"] != 0:
		sender_name = str(sender_name, "[color=#FF00FF] 说:[/color]")
	
	return str(prefix_txt_name, sender_name, content, attach)


func format_area_msg(data, txt = "区"):
	var prefix_txt_name = str("[color=#000000][", txt, "] [/color]")
	var sender_name = private_get_role_name_format(data["role_name"], data["role_id"], data.get("area_id", 0))
	sender_name = str(sender_name, "[color=#000000] 说:[/color]")
	var content = private_get_content_format(data["text"])
	content.replacen("\n", "")
	content.replacen("\r", "")
	content = str("[color=#000000] %s[/color]" % content)
	var attach = private_get_attachs_format(data.get("attachs", []))
	return str(prefix_txt_name, sender_name, content, attach)

func show_sm_msg(data):
	var prefix_txt_name = "[color=#000000][密] [/color]"
	var sender_name = private_get_role_name_format(data["role_name"], data["role_id"], data["area_id"])
	var recive_name = private_get_role_name_format(data["recipient_name"], data["recipient_id"], data["area_id"])
	var content = private_get_content_format(data["text"])
	content.replacen("\n", "")
	content.replacen("\r", "")
	content = str("[color=#000000] %s[/color]" % content)
	var attach = private_get_attachs_format(data.get("attachs", []))
	return str(prefix_txt_name, sender_name, "[color=#000000] 对 [/color]", recive_name, "[color=#000000] 说: [/color]", content, attach)

func show_team_msg(data):
	var prefix_txt_name = "[color=#000000][队] [/color]"
	var sender_name = private_get_role_name_format(data["role_name"], data["role_id"], data["area_id"])
	sender_name = str(sender_name, "[color=#000000] 说:[/color]")
	var content = private_get_content_format(data["text"])
	content.replacen("\r", "")
	content.replacen("\n", "")
	content = str("[color=#000000] %s[/color]" % content)
	var attach = private_get_attachs_format(data.get("attachs", []))
	return str(prefix_txt_name, sender_name, content, attach)

func show_zhan_msg(data):
	var prefix_txt_name = "[color=#000000][战]  "
	return str(prefix_txt_name, data["text"], "[/color]")


func clear():
	msg_map_list.clear()
	pass
