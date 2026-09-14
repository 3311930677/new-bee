extends Node
class_name NTeamManage


signal team_data_update
signal team_disband
signal team_follow_result

const prefix = "TeamManage->"


var NetContext
var ScreenUtils
var AroundRoleManage
var RoleInfoManage


var current_team_info = {}

var current_team_data = {}

var current_team_invite_request = []
var op_invite_app_target_role_id = - 1
func _init() -> void :
	NetContext = Global.get("NetContext")
	ScreenUtils = Global.get("ScreenUtils")
	
	
	NetContext.set_handler("NTeamRemote", "createTeam", self, "_on_create_team_result")
	NetContext.set_handler("NTeamRemote", "agree", self, "_on_agree_result")
	NetContext.set_handler("NTeamRemote", "follow", self, "_on_follow_result")
	NetContext.set_handler("NTeamServerPush", "push", self, "_on_team_server_push")
	pass


func _on_create_team_result(data):
	ScreenUtils.show_message("创建成功！")
	pass

func _on_agree_result(data):
	if op_invite_app_target_role_id == - 1: return
	remove_invite_request(op_invite_app_target_role_id)
	op_invite_app_target_role_id = - 1;
	emit_signal("team_data_update")
	pass

func _on_follow_result(data):
	emit_signal("team_follow_result")
	pass



func _on_team_server_push(data):
	data = parse_json(data["data"])
	var type = data["type"]
	Global.log_info(str(data))
	match type:
		"DETAIL_DATA":
			Global.log_info(str("队伍数据"))
			current_team_data["data"] = data["data"]
			current_team_data["detail"] = data["detail"]
			pass
		"DISBAND":
			Global.log_info(str("队伍解散"))
			ScreenUtils.show_message("队伍已解散")
			disposse()
			emit_signal("team_disband")
			pass
		"KICK_OUT":
			Global.log_info(str("你被踢出队伍"))
			ScreenUtils.show_top_tips(str("[color=red]你被踢出队伍[/color]"))
			disposse()
			emit_signal("team_disband")
			pass
		"SELF_OUT":
			Global.log_info(str("队伍退出成功"))
			disposse()
			emit_signal("team_disband")
			pass
		"INVITE":
			ScreenUtils.show_top_tips(str("[color=red]玩家：" + data["role_name"] + "  邀请你进入队伍[/color]"))
			start_glimmer()
			
			var item_info = data["data"]
			item_info["invite"] = true
			current_team_invite_request.append(item_info)
			pass
		"APPLICATION":
			ScreenUtils.show_top_tips(str("[color=red]玩家：" + data["role_name"] + "  申请进入队伍[/color]"))
			start_glimmer()
			
			var item_info = data["data"]
			item_info["request"] = true
			current_team_invite_request.append(item_info)
			pass
		"LEADER_CHANGE":
			ScreenUtils.show_top_tips(str("[color=red]队长已发生更改[/color]"))
			current_team_data["data"] = data["data"]
			
		"TEAM_ITEM_ADD":
			ScreenUtils.show_top_tips(str("[color=red]玩家：" + data["role_name"] + "  进入队伍[/color]"))
			current_team_data["data"] = data["data"]
			current_team_data["detail"] = data["detail"]
			remove_invite_request(data["role_id"])
			pass
		"TEAM_ITEM_SUB":
			ScreenUtils.show_top_tips(str("[color=red]玩家：" + data["role_name"] + "  离开队伍[/color]"))
			current_team_data["data"] = data["data"]
			current_team_data["detail"] = data["detail"]
			remove_invite_request(data["role_id"])
			pass
		"FOLLOW":
			var bl = data["follow_op"]
			var rid = data["role_id"]
			var info = get_team_data().get("data", {}).get("itemInfoMap", {})[str(rid)]
			info["follow"] = bl
			pass
		"UNFOLLOW":
			var bl = data["follow_op"]
			var rid = data["role_id"]
			var info = get_team_data().get("data", {}).get("itemInfoMap", {})[str(rid)]
			info["follow"] = bl
			pass
		"TO_FOLLOW":
			ScreenUtils.show_message("队长通知全员跟随")
			pass
		"REJECT":
			var op_type = int(data["op_type"])
			if op_type == 0:
				ScreenUtils.show_message("队长拒绝你的入队申请")
			else:
				ScreenUtils.show_message("玩家拒绝你的邀请")
			pass
	emit_signal("team_data_update")













func create_team():
	NetContext.request_service("NTeamRemote", "createTeam", {}, true)
	pass

func change_leader(target_role_id):
	if not self_is_leader():
		ScreenUtils.show_message("你不是队长，无权操作")
		return
	
	NetContext.request_service("NTeamRemote", "changeTeamLeader", {
		"team_leader_id": target_role_id, 
	}, true)
	pass

func disband_team():
	
	NetContext.request_service("NTeamRemote", "disbandTeam", {}, true)
	pass

func quit_team():
	NetContext.request_service("NTeamRemote", "removeRole", {
		"op_type": 0, 
		"team_name": get_team_name(), 
		"target_id": get_team_leader_id()
	}, true)
	pass

func kick_team(kick_role_id):
	NetContext.request_service("NTeamRemote", "removeRole", {
		"op_type": 1, 
		"team_name": get_team_name(), 
		"target_id": kick_role_id
	}, true)
	pass

func invite_role(role_id):
	if not self_has_team():
		ScreenUtils.show_message("你当前没有队伍，请先创建")
		return
	ScreenUtils.show_message("邀请成功，等待对方回应")
	NetContext.request_service("NTeamRemote", "invite", {
		"invite_role_id": role_id
	}, false)
	pass


func application(role_id):
	if self_has_team():
		ScreenUtils.show_message("你当前已有队伍，请先退出后再试")
		return
	ScreenUtils.show_message("申请成功，等待对方回应")
	NetContext.request_service("NTeamRemote", "application", {
		"request_role_id": role_id
	}, false)
	pass


func agree_invite_application(target_id, op_type):
	if op_type == 1 and self_has_team():
		ScreenUtils.show_message("你当前没有队伍，请先创建")
		return
	if op_type == 0 and not self_has_team():
		ScreenUtils.show_message("你当前已有队伍，请先退出后再试")
		return
	
	op_invite_app_target_role_id = target_id
	
	NetContext.request_service("NTeamRemote", "agree", {
		"target_id": target_id, 
		"op_type": op_type
	}, true)
	pass


func follow():
	NetContext.request_service("NTeamRemote", "follow", {
		"team_name": get_team_name(), 
		"follow_op": true
	}, true)
	pass

func unfollow():
	NetContext.request_service("NTeamRemote", "follow", {
		"team_name": get_team_name(), 
		"follow_op": false
	}, true)
	pass


func reject(role_id, optype):
	
	NetContext.request_service("NTeamRemote", "reject", {
		"target_id": role_id, 
		"op_type": optype
	}, false)
	remove_invite_request(role_id)
	pass


















func remove_invite_request(id):
	
	for item in current_team_invite_request:
		if item["id"] == id:
			current_team_invite_request.erase(item)
	pass




func get_team_data():
	return current_team_data
func get_team_req_invite_data():
	return current_team_invite_request
func get_team_name():
	return current_team_data.get("data").get("team_name", null)
	pass
func get_team_leader_id():
	return current_team_data.get("data").get("leader", - 1)

func get_team_members():
	return get_team_data().get("detail", {})

func self_is_follow():
	return get_team_data().get("data", {}).get("itemInfoMap", {}).get(str(Global.get("RoleInfoManage").get_role_id()), {}).get("follow", false)
	pass

func self_is_leader():
	return Global.get("RoleInfoManage").get_role_id() == current_team_data.get("data", {}).get("leader", - 1)

func self_has_team():
	return not current_team_data.empty()

func member_has_team(role_id):
	
	return not get_team_data().get("data", {}).get("itemInfoMap", {}).get(str(role_id), {}).empty()
	pass

func team_role_is_follow(role_id):
	return get_team_data().get("data", {}).get("itemInfoMap", {}).get(str(role_id), {}).get("follow", false)

func disposse():
	current_team_data.clear()
	current_team_invite_request.clear()
	current_team_info.clear()
	pass
func start_glimmer():
	var arr_team_icon = Global.get_nodes_in_group("team_icon")
	if arr_team_icon.size() > 0:
		var team_icon = arr_team_icon[0]
		team_icon.start_glimmer()


func set_team_attr(args):
	for k in args.keys():
		args[k]["id"] = int(k)
		current_team_info[str(k)] = args[k]
	emit_signal("team_data_update")
	pass


func get_team_small_item_info(id):
	return current_team_info.get(str(id), {})
