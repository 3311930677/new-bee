extends Node
class_name PlayerOperate

const prefix = "PlayerOperate->"


var role_id = - 1
var team_name = null


var current_player_info

var team_changed = false


var menu_dic = {
	"1": "查看信息", 
	"2": "查看宠物", 
	"3": "邀请组队", 
	"4": "添加好友", 
	"5": "发起私聊", 
	"6": "发送邮件", 
	"7": "拜师", 
	"8": "收徒", 

	"10": "申请入帮", 
	"11": "偷袭", 
	"12": "切磋", 
	"27": "移入黑名单", 
}

var friend_feo_menu = {
	"1": "查看信息", 
	"2": "查看宠物", 
	"14": "一键传送", 
}

var friend_black_list_menu = {
	"4": "添加好友", 
	"15": "移除黑名单"
}

var friend_add_menu = {
	"25": "添加好友"
}
var friend_no_onloine_menu = {
	"25": "添加好友", 
	"26": "删除好友", 
	"27": "移入黑名单", 
	"6": "发送邮件"
}

var temp_friend_name
var temp_friend_id
var temp_friend_data


var team_o_dic_menu = {
	"1": "查看信息", 
	"2": "查看宠物", 
	"4": "添加好友", 
	"5": "发起私聊", 
	"6": "发送邮件", 
}
var team_m_o_menu_dic = {
	"19": "解散队伍", 
}
var team_create_dic = {
	"20": "创建队伍"
}
var team_quit_dic = {
	"22": "退出队伍"
}

var faction_menu_dic = {
	"1": "查看信息", 
	"16": "瞬间传送", 
	"4": "添加好友", 
	"6": "发送邮件", 
	"5": "发起私聊"
}


func inspect_player_info():
	Global.log_info(str(prefix, "查看玩家信息", current_player_info))
	Global.get("ScreenUtils").chage_ui_and_args("res://src/tscn/ui/map/role/RoleUi.tscn", "load_data", {"role_type": current_player_info["id"]})


func inspect_player_pet():
	
	var role_id = max(current_player_info.get("id", - 1), current_player_info.get("role_id", - 1))
	Global.get("RoleInfoManage").get_target_role_fight_pet_id(role_id, true)
	








func add_friends():
	Global.log_info(str(prefix, "添加这个玩家为好友", current_player_info))
	Global.get("FriendInfoManage").add_friend(current_player_info["role_name"], 1)

func invite_private_chat():
	Global.log_info(str(prefix, "邀请这个玩家私聊", current_player_info))
	Global.get("ScreenUtils").chage_ui_and_args("res://src/tscn/ui/map/chat/SendMessageUi.tscn", "load_data", current_player_info)

func send_mail():
	Global.log_info(str(prefix, "对这个玩家发送邮件", current_player_info))
	Global.get("ScreenUtils").chage_ui_and_args("res://src/tscn/ui/map/mail/SendMailUi.tscn", "load_data", {"name": current_player_info["role_name"]})


func raid_role():

	Global.get("TBBattleManage").request_sneak(current_player_info["id"])
	pass


func _on_add_friend(id, txt_name):
	Global.get("FriendInfoManage").add_friend(txt_name, id)


func delete_friend():
	Global.get("ScreenUtils").show_message(str("确定删除好友：", current_player_info["role_name"], "?"), self, "_ok_delete_friend")
	pass

func add_friend_black_list():
	Global.get("ScreenUtils").show_message(str("确定将其添加进黑名单？", current_player_info["role_name"]), self, "_ok_add_friend_black_list")
	pass

func remove_black_list():
	Global.get("ScreenUtils").show_message(str("确定将其移除黑名单？"), self, "_ok_remove_friend_black_list")
	pass


func _ok_delete_friend():
	Global.get("FriendInfoManage").delete_friend(current_player_info["id"])

func _ok_add_friend_black_list():
	_on_add_friend(3, current_player_info["role_name"])

func _ok_remove_friend_black_list():
	_on_add_friend(1, current_player_info["role_name"])
	


func invite_in_team():
	
	if not Global.get("NTeamManage").self_has_team():
		Global.get("ScreenUtils").show_message("你当前没有队伍，请先创建")
		return
	Global.get("NTeamManage").invite_role(current_player_info["id"])

func apply_join_team():
	
	Global.get("NTeamManage").application(current_player_info["id"])


func create_team():
	Global.get("NTeamManage").create_team()
	Global.log_info(str(prefix, "创建队伍操作"))

func quit_team():
	Global.get("NTeamManage").quit_team()
	Global.log_info(str(prefix, "退出队伍操作"))

func disband_team():
	Global.get("NTeamManage").disband_team()
	Global.log_info(str(prefix, "解散队伍操作"))

func kiout_role():
	Global.get("NTeamManage").kick_team(current_player_info["id"])
	Global.log_info(str(prefix, "踢出队伍", current_player_info["id"]))
	pass

func change_team_leader():
	Global.get("NTeamManage").change_leader(current_player_info["id"])
	Global.log_info(str(prefix, "队长移交", current_player_info["id"]))

func agree_invite():
	Global.get("NTeamManage").agree_invite_application(current_player_info["id"], 1)
	pass

func agree_request():
	Global.get("NTeamManage").agree_invite_application(current_player_info["id"], 0)
	pass

func team_neglect():
	if current_player_info.get("request"): Global.get("NTeamManage").reject(current_player_info["id"], 0)
	if current_player_info.get("invite"): Global.get("NTeamManage").reject(current_player_info["id"], 1)



func invite_join_faction():
	
	Global.get("ScreenUtils").show_message("暂时不可邀请，只能通过申请")
	pass


func request_join_faction():
	var role_id = max(current_player_info.get("id", - 1), current_player_info.get("role_id", - 1))
	Global.get("FactionInfoManage").request_join_faction_with_role(role_id)
	pass


func deliver_role():
	
	var role_id = max(current_player_info.get("id", - 1), current_player_info.get("role_id", - 1))
	Global.get("RoleInfoManage").deliver_target_role(role_id, 0)
	pass

func key_deliver_role():
	var role_id = max(current_player_info.get("id", - 1), current_player_info.get("role_id", - 1))
	Global.get("RoleInfoManage").deliver_target_role(role_id, 1)
	pass


func get_menu_dic(player_info):
	current_player_info = player_info
	if player_info == null: return menu_dic
	
	var temp_menu = menu_dic.duplicate(true)
	temp_menu["13"] = "申请入队"


func get_team_menu_dic(role_node):
	var self_id = Global.get("RoleInfoManage").get_role_id()
	
	match role_node.team_type:
		0:
			if role_node.get_role_id() == self_id:
				return team_m_o_menu_dic.duplicate(true)
			else:
				var temp_menu = team_o_dic_menu.duplicate(true)
				temp_menu["16"] = "瞬间移动"
				return temp_menu
			
			pass
		1:
			
			if role_node.get_role_id() == self_id:
				return team_quit_dic.duplicate(true)
			else:
				var temp_menu = team_o_dic_menu.duplicate(true)
				
				if Global.get("NTeamManage").get_team_leader_id() == self_id:
					
					
					
					temp_menu["17"] = "踢出队伍"
					temp_menu["23"] = "移交队长"
					pass
				else:
					
					temp_menu["22"] = "踢出队伍"
					temp_menu["16"] = "瞬间移动"
					pass
				return temp_menu
			
			pass
		2:
			
			var temp_menu = team_o_dic_menu.duplicate(true)
			temp_menu["18"] = "同意申请"
			temp_menu["21"] = "忽略请求"
			return temp_menu
			pass
		3:
			
			var temp_menu = team_o_dic_menu.duplicate(true)
			temp_menu["24"] = "加入队伍"
			temp_menu["21"] = "忽略邀请"
			return temp_menu



func menu_item_click(id):
	match id:
		1:
			inspect_player_info()
		2:
			inspect_player_pet()
		3:
			invite_in_team()
		4:
			add_friends()
		5:
			invite_private_chat()
		6:
			send_mail()
		7:
			
			Global.get("MasterDataManage").request_master(current_player_info["id"])

			pass
		8:
			Global.get("MasterDataManage").request_apprentice(current_player_info["id"])

			
			pass
		9:
			invite_join_faction()
			
			pass
		10:
			request_join_faction()
			
			pass
		11:
			raid_role()
			
			pass
		12:
			

			Global.get("TBBattleManage").request_pk(current_player_info["id"])
			pass
		13:
			apply_join_team()
		14:
			
			key_deliver_role()
			pass
		15:
			
			remove_black_list()
			pass
		16:
			deliver_role()
			
			pass
		17:
			kiout_role()
		18:
			agree_request()
			pass
		19:
			disband_team()
		20:
			create_team()
		21:
			team_neglect()
			pass
		22:
			quit_team()
		23:
			change_team_leader()
			
			pass
		24:
			agree_invite()
			pass
		25:
			pass
		26:
			delete_friend()
			pass
		27:
			add_friend_black_list()
			pass
	pass

