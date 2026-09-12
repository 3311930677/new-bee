extends Control


onready var container = $"Background/Background2/ScrollContainer/VBoxContainer"
onready var popupmenu = $Control / PopupMenu

var player_item_res = preload("res://src/tscn/ui/common/player/PlayerLabelItem.tscn")
var model = 0
var ScreenUtils
var NTeamManage
var RoleInfoManage
var PlayerOperate


var check_node = null

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	NTeamManage = Global.get("NTeamManage")
	RoleInfoManage = Global.get("RoleInfoManage")
	PlayerOperate = Global.get("PlayerOperate")
	
	NTeamManage.connect("team_data_update", self, "_load_team_ui_data")
	_load_team_ui_data()
	pass


func _on_Cancle_pressed() -> void :
	queue_free()
	pass

func _on_Ok_pressed() -> void :
	
	if check_node != null:
		PlayerOperate.role_id = check_node.data["id"]
		if check_node.team_type >= 2:
			
			Global.get("ScreenUtils").build_menu(popupmenu, PlayerOperate.get_team_menu_dic(check_node))
			popupmenu.popup_centered()
			return
	
	
	if not NTeamManage.self_has_team():
		ScreenUtils.build_menu(popupmenu, PlayerOperate.team_create_dic)
		popupmenu.popup_centered()
		return
	
	
	
	if check_node == null: return
	PlayerOperate.role_id = check_node.data["id"]
	
	Global.get("ScreenUtils").build_menu(popupmenu, PlayerOperate.get_team_menu_dic(check_node))
	popupmenu.popup_centered()


func _on_Member_tab_click(node) -> void :
	model = 0
	if container != null: _load_team_ui_data()
	pass


func _on_MemberReq_tab_click(node) -> void :
	model = 1
	if container != null: _load_team_ui_data()
	pass


func _on_PopupMenu_index_pressed(index: int) -> void :
	var id = popupmenu.get_item_id(index)
	Global.get("PlayerOperate").menu_item_click(id)
	if id == 21:
		check_node.queue_free()
		check_node = null
	pass


func _item_click(node):
	if check_node == node:
		_on_Ok_pressed()
		return
	check_node = node
	PlayerOperate.current_player_info = check_node.data


func _load_team_ui_data():
	Global.log_info(str("加载队伍信息，队伍信息由系统进行推送"))
	clear_container()
	if model == 0:
		_load_member_ui();
	else:
		_load_ReqInvite_ui();
	pass

func _load_member_ui():
	var team_data = NTeamManage.get_team_data()
	if team_data.empty(): return
	Global.log_info(str("有队员信息需要进行加载"))
	
	
	for item in team_data["data"]["itemInfoMap"].keys():
		
		var iteam_info_detail = team_data["detail"][item]
		
		iteam_info_detail["team_leader"] = NTeamManage.get_team_leader_id()
		var item_ = player_item_res.instance()
		item_.connect("item_click", self, "_item_click")
		container.add_child(item_)
		item_.set_data(iteam_info_detail)
		pass
	
	pass

func _load_ReqInvite_ui():
	var arr_detail_data = NTeamManage.get_team_req_invite_data()
	if arr_detail_data.size() <= 0: return
	Global.log_info(str("有组队的申请等信息，进行加载"))
	
	for item in arr_detail_data:
		
		var iteam_info_detail = item
		var item_ = player_item_res.instance()
		item_.connect("item_click", self, "_item_click")
		container.add_child(item_)
		item_.set_data(iteam_info_detail)
		pass
	
	pass


func clear_container():
	for item in container.get_children():
		item.queue_free()
	check_node = null
	pass
