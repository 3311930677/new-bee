extends Control

onready var chat_label = $"Background4/ScrollContainer/VBoxContainer/RichTextLabel"
onready var scorller_container = $"Background4/ScrollContainer"

var ScreenUtils


var ChatInfoManage

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	ChatInfoManage = Global.get("ChatInfoManage")
	
	ChatInfoManage.connect("chat_single_info", self, "_chat_single_info")
	
	chat_label.reload_msg(0)
	pass


func _on_Task_item_click() -> void :
	
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/task/TaskUi.tscn", "load_data", {})


func _on_Bag_item_click() -> void :
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/bag/BagUi.tscn", "load_data", {"type": 0})
	pass

func _on_Around_item_click() -> void :
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/around/AroundUi.tscn", "load_data", {})
	pass


func _on_Team_item_click() -> void :
	ScreenUtils.change_ui("res://src/tscn/ui/map/team/NewTeamUi.tscn")

	pass


func _on_Chat_item_click() -> void :
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/chat/ChatUi.tscn", "load_data", {})
	pass


func _on_Mail_item_click() -> void :
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/mail/MailUi.tscn", "load_data", {})
	pass


func _on_Menu_pressed() -> void :
	ScreenUtils.change_ui("res://src/tscn/ui/map/menu/Menu.tscn")


func _on_Forget_pressed() -> void :
	ScreenUtils.change_ui("res://src/tscn/ui/map/memo/memoUi.tscn")

func _chat_single_info(data):
	$Timer.start()

func _on_chat_pressed() -> void :
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/chat/ChatUi.tscn", "load_data", {})
	pass


func _on_Timer_timeout() -> void :
	scorller_container.set_v_scroll(scorller_container.get_v_scrollbar().max_value)
	pass
