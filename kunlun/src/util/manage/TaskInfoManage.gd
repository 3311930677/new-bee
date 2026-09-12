extends Node
class_name TaskInfoManage

signal task_state_update
signal task_list_update

const prefix = "TaskInfoManage->"


var sjrwtx_res = load("res://src/tscn/ui/common/SJRWTX.tscn")

var ScreenUtils
var NetContext

var task_info = {}
var list_task_info = []



var accept_task = []
var full_task = []

func _init() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	NetContext = Global.get("NetContext")
	
	NetContext.set_handler("TaskRemote", "getTaskInfo", self, "_on_role_task_info")
	
	NetContext.set_handler("TaskRemote", "getDialogue", self, "_on_task_dialog_info")
	
	NetContext.set_handler("TaskRemote", "getTaskInfoList", self, "_on_role_task_info_list")
	
	NetContext.set_handler("TaskRemote", "finishTask", self, "_on_role_complete_task")
	
	NetContext.set_handler("TaskRemote", "acceptTask", self, "_on_role_accept_task")
	
	NetContext.set_handler("TaskRemote", "abandonTask", self, "_on_role_abandon_task")
	
	NetContext.set_handler("TaskRemote", "updateCondition", self, "_on_role_refresh_task")
	
	NetContext.set_handler("TaskRemote", "pickArt", self, "_on_pick_art_task")
	
	pass

func request_refresh_task():
	NetContext.request_service("TaskRemote", "updateCondition", {}, false)
	pass

func request_pick_art_task(task_id):
	NetContext.request_service("TaskRemote", "pickArt", {
		"task_id": task_id
	}, true)
	pass

func request_list_task():
	NetContext.request_service("TaskRemote", "getTaskInfoList", {}, true)
	pass

func request_task():
	NetContext.request_service("TaskRemote", "getTaskInfo", {}, false)
	pass


func request_abandon_task(task_id):
	NetContext.request_service("TaskRemote", "abandonTask", {
		"task_id": task_id
	}, true)
	pass


func request_task_details_dialog(task_data):
	var dialogue_phase = 0
	if task_data["complete"] == 1:
		dialogue_phase = 1
	NetContext.request_service("TaskRemote", "getDialogue", {
		"task_id": task_data["task_id"], 
		"dialogue_phase": dialogue_phase
	}, true)
	pass


func request_accept_task(task_id):
	NetContext.request_service("TaskRemote", "acceptTask", {
		"task_id": task_id
	}, true)
	pass

func request_complete_task(task_id):
	NetContext.request_service("TaskRemote", "finishTask", {
		"task_id": task_id
	}, true)
	pass


func _on_task_dialog_info(data):
	data = data["data"]
	Global.log_info(str(prefix, data))
	Global.get("ScreenUtils").show_npc_task_dialog(data)


func _on_role_task_info(data):
	data = data["data"]
	Global.log_info(str(prefix, data))
	task_info = data
	emit_signal("task_state_update")

func _on_pick_art_task(data):
	data = data["data"]
	task_info = data
	emit_signal("task_state_update")
	pass


func _on_role_task_info_list(data):
	data = data["data"]
	Global.log_info(str(prefix, data))
	list_task_info = data
	request_task()
	emit_signal("task_list_update")
	

func _on_role_refresh_task(data):
	data = data["data"]
	Global.log_info(str(prefix, data))
	task_info = data
	emit_signal("task_state_update")
	
	var full_arr_str_task = data["fulfill_condition_tasks"].split("&")
	










	
	
	var str_tasks = data["accepting_tasks"]
	var arr_str_task = str_tasks.split("&")
	
	accept_task.clear()
	accept_task.append_array(arr_str_task)
	full_task.clear()
	full_task.append_array(full_arr_str_task)
	
	pass


func _on_role_complete_task(data):
	data = data["data"]
	_preivate_show_rw_state(1)
	
	task_info = data
	emit_signal("task_state_update")
	
	
	
	
	

func _on_role_abandon_task(data):
	data = data["data"]
	task_info = data
	emit_signal("task_state_update")
	request_list_task()
	ScreenUtils.show_message("任务已放弃")
	

func _on_role_accept_task(data):
	if not data.has("data"):
		Global.log_info("没有实际数据")
		return
	data = data["data"]
	
	_preivate_show_rw_state(0)
	
	task_info = data
	emit_signal("task_state_update")
	




func _preivate_show_rw_state(type: int = 0):
	var ui = ScreenUtils.get_ui_container()
	var ren = sjrwtx_res.instance()
	
	ui.add_child(ren)
	if type == 0:
		ren.play_anim("jqrw_tx")
	elif type == 1:
		ren.play_anim("wcrw_tx")
	ren._set_center()
	pass



func has_available_task(id_npc):
	var tasks = private_get_tasks("available_tasks", id_npc)
	if tasks == null: return false
	else: return true

func has_accepting_tasks(id_npc):
	var tasks = private_get_tasks("accepting_tasks", id_npc)
	if tasks == null: return false
	else: return true

func has_fulfill_condition_tasks(id_npc):
	var tasks = private_get_tasks("fulfill_condition_tasks", id_npc)
	if tasks == null: return false
	else: return true

func has_accepting_task_id(task_id):
	var tasks = private_get_tasks("accepting_tasks", task_id, true)
	if tasks == null: return false
	return int(tasks.split(",")[0]) == task_id


func private_get_tasks(key, id_npc, pre = false):
	if not task_info.has(key): return null
	var task_line = task_info.get(key, "")
	if task_line.length() < 1: return null
	var arr_tasks = task_line.split("&")
	if arr_tasks.size() < 1: return null
	for t in arr_tasks:
		var arr_t = t.split(",")
		if pre:
			if int(arr_t[0]) == id_npc: return t
		else:
			if int(arr_t[1]) == id_npc: return t
	return null
