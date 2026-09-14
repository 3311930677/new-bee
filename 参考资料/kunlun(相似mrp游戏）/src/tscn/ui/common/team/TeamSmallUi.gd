extends Control

onready var follow_btn = $Follow
onready var container = $HBoxContainer


var team_item_res = preload("res://src/tscn/ui/common/team/TeamItem.tscn")

var ScreenUtils
var NTeamManage
var RoleInfoManage
var AroundRoleManage

var pre_follow = false


func _ready() -> void :
	
	ScreenUtils = Global.get("ScreenUtils")
	NTeamManage = Global.get("NTeamManage")
	RoleInfoManage = Global.get("RoleInfoManage")
	AroundRoleManage = Global.get("AroundRoleManage")
	
	
	NTeamManage.connect("team_data_update", self, "team_data_update")
	NTeamManage.connect("team_disband", self, "_on_team_dismiss")
	NTeamManage.connect("team_follow_result", self, "_on_follow_sucessed_loaded")
	team_data_update()
	pass


func _on_Follow_pressed() -> void :
	if not NTeamManage.self_is_follow():
		NTeamManage.follow()
		pre_follow = true
	else:
		NTeamManage.unfollow()
		pre_follow = false
	pass


func team_data_update():
	clear_container()
	
	if not NTeamManage.self_has_team(): return
	
	
	if NTeamManage.self_is_follow(): follow_btn.text = "取消"
	else: follow_btn.text = "跟随"
	
	
	if NTeamManage.self_is_leader():
		$Follow.hide()
	else:
		$Follow.show()
	
	
	var members = NTeamManage.get_team_members()
	for key in members.keys():
		var source_data = members[key]
		
		if int(key) == RoleInfoManage.get_role_id():
			continue
		
		var item = team_item_res.instance()
		$HBoxContainer.add_child(item)
		item.set_data(source_data)
	show()
	pass

func _on_team_dismiss():
	clear_container()
	hide()
	follow_btn.text = "跟随"
	pre_follow = false
	pass


func _on_follow_sucessed_loaded():
	if pre_follow: follow_btn.text = "取消"
	else: follow_btn.text = "跟随"
	
	var leader_role_id = NTeamManage.get_team_leader_id()
	
	
	var ps = Global.get_nodes_in_group("player")
	
	if ps.size() > 0:
		var player = Global.get_nodes_in_group("player")[0]
		
		var dic = AroundRoleManage.current_map_role_.get(str(leader_role_id), {})
		if dic != null and dic.has("points"):
			player.click_points.append_array(dic["points"])
	pass


func _on_unfollow_secessed_loaded(data):
	follow_btn.text = "跟随"
	pass

func clear_container():
	for i in container.get_children():
		if i is Panel:
			i.queue_free()
