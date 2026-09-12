extends Control

const prefix = "DialogNpc->"



onready var rich_text = $PanelContainer / VBoxContainer / RichTextLabel
onready var item_list = $PanelContainer / VBoxContainer / ScrollContainer / VBoxContainer / ItemList
onready var scoll_container = $PanelContainer / VBoxContainer / ScrollContainer
onready var vbox = $PanelContainer / VBoxContainer


var mode_npc_task = 0

var private_size_init = false




var source_data = null
var task_id = 0
var task_name = null

var task_read_index = 0

var response

var title = null
var text = null
var url = null
var data_item = []
var current_select_index = - 1

var ScreenUtils
var DialogManage
var TaskInfoManage
var RichTextContentFormat


var command_filter = {"close_dialogue": []}


func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	DialogManage = Global.get("DialogManage")
	TaskInfoManage = Global.get("TaskInfoManage")
	RichTextContentFormat = Global.get("RichTextContentFormat")

func _on_Cance_pressed() -> void :
	if mode_npc_task == 0:
		if source_data.get("mode", 0) == 0:
			
			source_data["mode"] = 1
			ScreenUtils.show_npc_dialog(source_data)
	
	queue_free()


func _on_ItemList_item_selected(index: int) -> void :
	if current_select_index == index:
		_on_Ok_pressed()
	else:
		current_select_index = index
	pass


func _ok_pressed_npc():
	if source_data.get("mode", 0) == 1:
		var select_items = item_list.get_selected_items()
		var index = current_select_index
		if select_items.size() > 0:
			index = select_items[0]
		if url != null and data_item.size() > 0:
			DialogManage.item_click(url, index)
	else:
		
		var task_data = item_list.get_item_metadata(current_select_index)
		Global.log_info(str(prefix, "当前选中任务", task_data))
		TaskInfoManage.request_task_details_dialog(task_data)
		pass

func _ok_pressed_task():
	
	task_read_index += 1
	rich_text.clear()
	if task_read_index >= source_data.size():
		
		if source_data[0]["dialogue_phase"] == 1:
			
			TaskInfoManage.request_complete_task(source_data[0]["task_id"])
		else:
			
			TaskInfoManage.request_accept_task(source_data[0]["task_id"])
		queue_free()
	else:
		var text = source_data[task_read_index]["text"]
		rich_text.append_bbcode(text)
	pass

func _on_Ok_pressed() -> void :
	
	if mode_npc_task == 0:
		_ok_pressed_npc()
		queue_free()
	else:
		_ok_pressed_task()
	



func set_data(data):
	set_npc_data({"response": data})


func set_task_data(data):
	
	parse_command(data)
	mode_npc_task = 1
	self.source_data = data
	if data.size() <= task_read_index: return
	var text = data[task_read_index]["text"]
	rich_text.append_bbcode(RichTextContentFormat.get_content_format(text))


func set_npc_data(data):
	
	parse_command(data)
	mode_npc_task = 0
	self.source_data = data
	if private_has_task() and data.get("mode", 0) == 0:
		
		var arr_full = data.get("fulfill_condition_tasks", [])
		var arr_available = data.get("available_tasks", [])
		var arr_accepting = data.get("accepting_tasks", [])
		
		var item_index_c = 0
		for i in arr_full:
			var task_name = str(i["task_name"], "(完成)")
			if i["type"] == 1:
				task_name = str("(主)", task_name)
			elif i["type"] == 2:
				task_name = str("(副)", task_name)
			else:
				task_name = str("(支)", task_name)
			i["complete"] = 1
			item_list.add_item(task_name)
			item_list.set_item_metadata(item_index_c, i)
			item_index_c += 1
			pass
		for i in arr_available:
			var task_name = str(i["task_name"], "(可接取)")
			if i["type"] == 1:
				task_name = str("(主)", task_name)
			elif i["type"] == 2:
				task_name = str("(副)", task_name)
			else:
				task_name = str("(支)", task_name)
			i["complete"] = 2
			item_list.add_item(task_name)
			item_list.set_item_metadata(item_index_c, i)
			item_index_c += 1
			pass
		for i in arr_accepting:
			
			var task_name = str(i["task_name"], "(未完成)")
			if i["type"] == 1:
				task_name = str("(主)", task_name)
			elif i["type"] == 2:
				task_name = str("(副)", task_name)
			else:
				task_name = str("(支)", task_name)
			i["complete"] = 3
			item_list.add_item(task_name)
			item_list.set_item_metadata(item_index_c, i)
			item_index_c += 1

	else:
		
		source_data["mode"] = 1
		response = data.get("response", {})
		if task_id != 0: task_name = data.get("task_name", "默认任务名")
		title = response.get("title", null)
		text = response.get("text", null)
		url = response.get("url", null)
		data_item = response.get("dialogItems", [])
		
		if title != null:
			rich_text.append_bbcode("[center] %s [/center]" % title)
			rich_text.newline()
			rich_text.newline()
		
		if text != null:
			rich_text.append_bbcode(RichTextContentFormat.get_content_format(text))
		
		var index = 1
		for i in data_item:
			item_list.add_item(str(index, ".", i))
			index += 1
		
	
	
	if item_list.get_item_count() > 0:
		scoll_container.visible = true
		item_list.select(0)
		current_select_index = 0
	else:
		scoll_container.visible = false
	
	
	if rich_text.text.length() <= 1:
		rich_text.visible = false
	else:
		rich_text.visible = true

func _process(delta: float) -> void :
	
	if not private_size_init:
		private_size_init = true
		var max_v = scoll_container.get_v_scrollbar().max_value
		if max_v < 250:
			if max_v > scoll_container.rect_size.y:
				scoll_container.rect_min_size.y = max_v
		else:
			scoll_container.rect_min_size.y = 250
			
		if not scoll_container.visible:
			scoll_container.rect_min_size.y = 0
		$PanelContainer.rect_size.y = scoll_container.rect_min_size.y + rich_text.rect_size.y
		$PanelContainer / VBoxContainer.rect_size.y = $PanelContainer.rect_size.y



func _on_PanelContainer_resized() -> void :
	$PanelContainer.rect_position.y = 500 / 2 - $PanelContainer.rect_size.y / 2


func private_has_task():
	if source_data.get("accepting_tasks", []).size() > 0 or source_data.get("available_tasks", []).size() > 0 or source_data.get("fulfill_condition_tasks", []).size() > 0:
		return true
	return false



func parse_command(data):
	if not data.has("response"): return false
	if not data["response"].has("commands"): return false
	
	var commands = data["response"]["commands"]
	var current_command = []
	
	for c in commands:
		
		if has_current_command(c):
			current_command.append(c)
			continue
		
		Global.get("CommandManage").run_command(c)
	
	for c in current_command:
		filter_command(c)
	
	return false
func has_current_command(command_info):
	for key in command_filter.keys():
		if key == command_info["name"]:
			return true
	return false

func filter_command(command_info):
	for key in command_filter.keys():
		if key == command_info["name"]:
			command_close_dialog()
			return true
	return false

func command_close_dialog():
	call_deferred("queue_free")
	pass
