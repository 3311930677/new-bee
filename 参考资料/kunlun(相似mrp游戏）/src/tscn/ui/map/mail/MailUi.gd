extends Control
const prefix = "MailUi->"

onready var container = $"Background/Background2/ScrollContainer/VBoxContainer"
onready var item_res = preload("res://src/tscn/ui/map/mail/MailItem.tscn")

var MailOperate
var ScreenUtils
var MailInfoManage

var checked_node = null


func _ready() -> void :
	MailOperate = Global.get("MailOperate")
	ScreenUtils = Global.get("ScreenUtils")
	MailInfoManage = Global.get("MailInfoManage")
	MailInfoManage.connect("mail_item_ui_update", self, "_on_mail_reload")

func _on_Cancle_pressed() -> void :
	queue_free()

func _on_mail_reload():
	show()
	clear_container()
	var list_mails = MailInfoManage.get_mails()
	
	
	
	
	
	list_mails.sort_custom(MyCustomSorter, "sort_ascending")
	var a = []
	
	$Background / MailCount.text = str("邮件列表（%d/50）" % list_mails.size())
	for mail_item_data in list_mails:
		var mail_item = item_res.instance()
		container.add_child(mail_item)
		mail_item.set_data(mail_item_data)
		mail_item.connect("item_click", self, "_item_click")
		pass

func _item_click(node):
	if checked_node == node:
		_on_Ok_pressed()
		return
	checked_node = node
	MailOperate.data = checked_node.data
	pass

func _on_Ok_pressed() -> void :
	var data
	if checked_node == null:
		data = null
	else:
		data = checked_node.data
	ScreenUtils.build_menu($Control / PopupMenu, MailOperate.get_menu_dic(data))
	
	if checked_node != null:
		MailOperate.data = checked_node.data
	$Control / PopupMenu.popup_centered()

func _on_PopupMenu_index_pressed(index: int) -> void :
	var id = $Control / PopupMenu.get_item_id(index)
	MailOperate.menu_item_click(id)
	


func load_data(data):
	hide()
	MailInfoManage.request_all_mails()
	pass

func clear_container():
	for i in container.get_children():
		i.queue_free()


class MyCustomSorter:
	static func sort_ascending(a, b):
		if a["state"] == 0:
			return true
		if b["state"] == 0:
			return false
		if a["extract"] == 0:
			return true
		if b["extract"] == 0:
			return false
		return false
