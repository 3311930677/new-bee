extends Control

const prefix = "TaskUi->"
var ScreenUtils
var TaskInfoManage
var RoleInfoManage
var MapInfoManage
var StaticGameData


var sort_map = {}

var task_list

var select_task = null

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	TaskInfoManage = Global.get("TaskInfoManage")
	RoleInfoManage = Global.get("RoleInfoManage")
	MapInfoManage = Global.get("MapInfoManage")
	StaticGameData = Global.get("StaticGameData")
	
	TaskInfoManage.connect("task_list_update", self, "loaded_task_list")
	MapInfoManage.connect("map_change_success", self, "_on_map_change_success")




func loaded_task_list():
	show()
	task_list = TaskInfoManage.list_task_info
	$Middle / Left / Tree.clear()
	var tr: Tree = $Middle / Left / Tree
	
	for it in task_list:
		if it == null: continue
		
		var p_item
		
		if sort_map.has(it["subject"]):
			p_item = it["subject"]
		else:
			p_item = tr.create_item()
			p_item.set_text(0, it["subject"])
		
		var item: TreeItem = tr.create_item(p_item)
		var t_name = str(it["task_name"])
		
		if it["type"] == 1:
			t_name = str("(主)", t_name)
		elif it["type"] == 2:
			t_name = str("(支)", t_name)
		elif it["type"] == 3:
			t_name = str("(副)", t_name)
		if it["is_complete"] == 1:
			t_name = str(t_name, "(完)")
			item.set_custom_color(0, Color(0, 1, 0))
		else:
			t_name = str(t_name, "(未)")
			item.set_custom_color(0, Color(1, 0, 0))
		item.set_text(0, t_name)
		item.set_metadata(0, it)
	
	ScreenUtils.hide_please_wait()
	
func load_data(data):
	$Middle / Right / Background4 / RichTextLabel.clear()
	
	TaskInfoManage.request_refresh_task()
	
	TaskInfoManage.request_list_task()
	hide()

func create_items():
	var tr: Tree = $Middle / Left / Tree
	var item: TreeItem = tr.create_item()
	item.set_text(0, "任务主题")
	var item_i1 = tr.create_item(item)
	item_i1.set_text(0, "任务名称")
	
	pass


func _on_Cance_pressed() -> void :
	queue_free()


func _on_Ok_pressed() -> void :
	if $Middle / Left / Tree.get_selected() == null: return
	var select_task_data = $Middle / Left / Tree.get_selected().get_metadata(0)
	Global.log_info(str("操作当前任务：", select_task_data))
	select_task = select_task_data
	if select_task_data != null:
		$Control / PopupMenu.popup_centered()


func _on_map_change_success(c_map):
	_on_Cance_pressed()

func _on_PopupMenu_index_pressed(index: int) -> void :
	var id = $Control / PopupMenu.get_item_id(index)
	match id:
		0:
			var npc_data = Global.get("StaticGameData").get_npc_id_data(select_task["finish_npc"])
			if npc_data == null:
				ScreenUtils.show_message("暂不支持自动前往")
			else:
				Global.get("MapInfoManage").change_map_to_npc(npc_data)

		1:
			cancle_task()

func automatic_go():
	ScreenUtils.show_message("你确定要消耗%s道具前往任务目的地？", self, "automatic_go_ok", "")
	pass

func automatic_go_ok():
	pass

func cancle_task():
	ScreenUtils.show_message("你确定要放弃当前任务？", self, "cancle_task_ok", "")

func cancle_task_ok():
	var select_task_data = $Middle / Left / Tree.get_selected().get_metadata(0)
	if select_task_data["is_complete"] == 1:
		ScreenUtils.show_message("已完成任务不可放弃")
	else:
		TaskInfoManage.request_abandon_task(select_task_data["task_id"])
		pass


func _on_Tree_item_selected() -> void :
	var select_task_data = $Middle / Left / Tree.get_selected().get_metadata(0)
	var rich_txt = $Middle / Right / Background4 / RichTextLabel
	$Middle / Right / Background4 / RichTextLabel.clear()
	if select_task_data == null: return
	
	Global.log_info(str(prefix, select_task_data))
	rich_txt.append_bbcode(str("[color=blue]任务目的：[/color]\n[color=black]", select_task_data["desc"], "[/color]"))
	if select_task_data["is_complete"] == 1:
		rich_txt.append_bbcode(str("[color=green](已完成)[/color]\n"))
	else:
		rich_txt.append_bbcode(str("[color=red](未完成)[/color]\n"))

	if select_task_data["conditions"].size() >= 1:
		
		rich_txt.newline()
		rich_txt.append_bbcode(str("[color=black]完成情况：[/color]\n"))
		for condi in select_task_data["conditions"]:
			rich_txt.append_bbcode(str("[color=black]", condi["desc"], "[/color]"))
			rich_txt.append_bbcode(str("[color=green](", condi["cur_num"], "/", condi["num"], ")[/color]"))
			rich_txt.append_bbcode("\n")
	
	rich_txt.newline()
	rich_txt.append_bbcode(str("[color=blue]奖励：[/color]\n"))


	
	
	rich_txt.append_bbcode(str("[color=black]经验：", select_task_data["exp"], "[/color]\n"))
	
	
	if select_task_data.get("gold_coin", 0) > 0:
		rich_txt.append_bbcode(str("[color=black]银两：", select_task_data["gold_coin"], "[/color]\n"))
	if select_task_data.get("silver_coin", 0) > 0:
		rich_txt.append_bbcode(str("[color=black]银票：", select_task_data["silver_coin"], "[/color]\n"))
	for rewards in select_task_data["rewards"]:
		var s_data = null
		var re_type = int(rewards["type"])
		
		if re_type >= 100:
			var j_id = int(re_type / 100)
			var d_id = int(re_type / 10) % 10
			
			var r_info = RoleInfoManage.get_role_info()
			var role_j_id = r_info["job_id"]
			var role_d_id = r_info["division_id"]
			
			
			if d_id == 0:
				if j_id != role_j_id:
					continue
			else:
				if not (d_id == role_d_id and j_id == role_j_id):
					continue
					
			
			re_type = re_type % 10
			pass
		if re_type == 3:
			s_data = Global.get("StaticGameData").get_equi_data(rewards["type_id"])
		elif re_type == 4:
			s_data = Global.get("StaticGameData").get_gem_data(rewards["type_id"])
		elif re_type == 5:
			s_data = Global.get("StaticGameData").get_article_data(rewards["type_id"])
		if s_data == null: continue
		
		
		rich_txt.newline()
		rich_txt.append_bbcode(str("[color=#", s_data["display_color"], "]LV", s_data["level"], " "))
		var bind = Global.get("StaticGameData").get_bind_text_format(rewards["bind"])
		
		
		if re_type == 3:
			var z_n = Global.get("StaticGameData").equi_job_name[str(s_data["entity_type"])]
			rich_txt.append_bbcode(str("[%s]" % z_n))
			pass
		rich_txt.append_bbcode(str(bind, s_data["name"], " x", rewards["num"]))
		pass





