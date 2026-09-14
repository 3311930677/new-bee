extends Control

const prefix = "LoginUi->"
onready var uname = $Background / Background2 / Panel2 / Username
onready var pword = $Background / Background2 / Panel2 / Password
onready var remember = $Background / Background2 / Panel2 / CheckBox
var passowrd_txt_path = "user://u.bin"
var password_key = "78/*998913413756"

var ScreenUtils
var NetContext
var StaticGameData
var FileHelper
var LocalInfo

func test():
	var ServerPageManage = Global.get("ServerPageManage")
	var data = {"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "bg_index": 0, "childrenList": [{"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "childrenList": [], "id": 76, "is_show": true, "margin": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "name": "XQTitle", "rect": {"size": {"x": 352.0, "y": 25.0}}, "style": {}, "title_text": "请选择商品", "type": "XQTitle"}, {"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "childrenList": [], "id": 77, "is_show": true, "margin": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 470.0}, "name": "LeftButton", "rect": {"size": {"x": 50.0, "y": 30.0}}, "style": {}, "text": "确定", "type": "LeftButton"}, {"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "childrenList": [], "id": 78, "is_show": true, "margin": {"bottom": 0.0, "left": 302.0, "right": 0.0, "top": 470.0}, "name": "BackButton", "rect": {"size": {"x": 50.0, "y": 30.0}}, "style": {}, "text": "返回", "type": "BackButton"}, {"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "bg_index": 0, "childrenList": [{"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "bg_index": 2, "childrenList": [], "id": 98, "is_show": true, "margin": {"bottom": 0.0, "left": 20.0, "right": 0.0, "top": 20.0}, "name": "XQBG", "rect": {"size": {"x": 312.0, "y": 400.0}}, "style": {}, "type": "XQBG"}, {"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "childrenList": [{"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "childrenList": [{"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "checked": false, "childrenList": [], "data": {}, "group": "ShowNodeItem", "hide_ids": [], "id": 80, "is_show": true, "margin": {"bottom": 0.0, "left": 76.0, "right": 0.0, "top": 3.0}, "name": "ShowNodeItem", "rect": {"size": {"x": 200.0, "y": 30.0}}, "show_ids": [82], "style": {}, "text": "狼蛛", "type": "ShowNodeItem"}, {"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "checked": false, "childrenList": [], "data": {}, "group": "ShowNodeItem", "hide_ids": [], "id": 81, "is_show": true, "margin": {"bottom": 0.0, "left": 76.0, "right": 0.0, "top": 36.0}, "name": "ShowNodeItem", "rect": {"size": {"x": 200.0, "y": 30.0}}, "show_ids": [82], "style": {}, "text": "梦瑶仙子", "type": "ShowNodeItem"}], "id": 79, "is_show": true, "margin": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "name": "Panel", "rect": {"size": {"x": 312.0, "y": 38.0}}, "style": {"bg_color": {"a": 0.0, "b": 0.0, "g": 0.0, "r": 0.0}}, "type": "Panel"}], "id": 99, "is_show": true, "margin": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 24.0}, "name": "ScrollContainer", "rect": {"size": {"x": 312.0, "y": 400.0}}, "style": {}, "type": "ScrollContainer"}], "id": 97, "is_show": true, "margin": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 25.0}, "name": "XQBG", "rect": {"size": {"x": 352.0, "y": 440.0}}, "style": {}, "type": "XQBG"}, {"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "bg_index": 1, "childrenList": [{"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "checked": false, "childrenList": [], "data": {}, "group": "ShowNodeItem", "hide_ids": [], "id": 83, "is_show": true, "margin": {"bottom": 0.0, "left": 10.0, "right": 0.0, "top": 10.0}, "name": "ShowNodeItem", "rect": {"size": {"x": 100.0, "y": 20.0}}, "show_ids": [86], "style": {}, "text": "寄卖", "type": "ShowNodeItem"}, {"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "childrenList": [], "id": 84, "is_show": true, "margin": {"bottom": 0.0, "left": 10.0, "right": 0.0, "top": 40.0}, "name": "SubmitInput", "rect": {"size": {"x": 100.0, "y": 20.0}}, "request_method": "", "request_remote": "", "style": {}, "type": "SubmitInput", "value": "查看"}, {"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "checked": false, "childrenList": [], "data": {}, "group": "ShowNodeItem", "hide_ids": [82], "id": 85, "is_show": true, "margin": {"bottom": 0.0, "left": 10.0, "right": 0.0, "top": 70.0}, "name": "ShowNodeItem", "rect": {"size": {"x": 100.0, "y": 20.0}}, "show_ids": [], "style": {}, "text": "取消", "type": "ShowNodeItem"}], "id": 82, "is_show": false, "margin": {"bottom": 0.0, "left": 116.0, "right": 0.0, "top": 200.0}, "name": "XQBG", "rect": {"size": {"x": 120.0, "y": 100.0}}, "style": {}, "type": "XQBG"}, {"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "childrenList": [{"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "childrenList": [], "hide_ids": [86], "id": 87, "is_show": true, "margin": {"bottom": 0.0, "left": 300.0, "right": 0.0, "top": 300.0}, "name": "HideButton", "rect": {"size": {"x": 50.0, "y": 30.0}}, "show_ids": [], "style": {}, "text": "取消", "type": "HideButton"}, {"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "bg_index": 0, "childrenList": [{"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "childrenList": [], "id": 89, "is_show": true, "margin": {"bottom": 0.0, "left": 60.0, "right": 0.0, "top": 0.0}, "name": "TextLabel", "rect": {"size": {"x": 80.0, "y": 30.0}}, "style": {}, "text": "寄卖数量", "type": "TextLabel"}, {"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "childrenList": [], "form_name": "shell", "id": 92, "input_name": "coin_num", "is_show": true, "margin": {"bottom": 0.0, "left": 60.0, "right": 0.0, "top": 30.0}, "name": "TextInput", "rect": {"size": {"x": 100.0, "y": 20.0}}, "style": {}, "type": "TextInput"}, {"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "childrenList": [], "id": 90, "is_show": true, "margin": {"bottom": 0.0, "left": 60.0, "right": 0.0, "top": 50.0}, "name": "TextLabel", "rect": {"size": {"x": 80.0, "y": 30.0}}, "style": {}, "text": "道具总价", "type": "TextLabel"}, {"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "childrenList": [], "form_name": "shell", "id": 93, "is_show": true, "margin": {"bottom": 0.0, "left": 60.0, "right": 0.0, "top": 80.0}, "name": "TextInput", "rect": {"size": {"x": 100.0, "y": 20.0}}, "style": {}, "type": "TextInput"}, {"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "childrenList": [], "id": 91, "is_show": true, "margin": {"bottom": 0.0, "left": 60.0, "right": 0.0, "top": 100.0}, "name": "TextLabel", "rect": {"size": {"x": 80.0, "y": 30.0}}, "style": {}, "text": "道具类型", "type": "TextLabel"}, {"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "checked": false, "childrenList": [], "data": {"coin_type": 1}, "form_name": "shell", "group": "coin_type", "id": 94, "is_show": true, "margin": {"bottom": 0.0, "left": 25.0, "right": 0.0, "top": 0.0}, "name": "TextItem", "rect": {"size": {"x": 50.0, "y": 30.0}}, "style": {}, "text": "金币", "type": "TextItem"}, {"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "checked": false, "childrenList": [], "data": {"coin_type": 2}, "form_name": "shell", "group": "coin_type", "id": 95, "is_show": true, "margin": {"bottom": 0.0, "left": 75.0, "right": 0.0, "top": 0.0}, "name": "TextItem", "rect": {"size": {"x": 50.0, "y": 30.0}}, "style": {}, "text": "银币", "type": "TextItem"}, {"anchor": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "checked": false, "childrenList": [], "data": {"coin_type": 3}, "form_name": "shell", "group": "coin_type", "id": 96, "is_show": true, "margin": {"bottom": 0.0, "left": 125.0, "right": 0.0, "top": 0.0}, "name": "TextItem", "rect": {"size": {"x": 50.0, "y": 30.0}}, "style": {}, "text": "元宝", "type": "TextItem"}], "id": 88, "is_show": true, "margin": {"bottom": 0.0, "left": 76.0, "right": 0.0, "top": 100.0}, "name": "XQBG", "rect": {"size": {"x": 200.0, "y": 300.0}}, "style": {}, "type": "XQBG"}], "id": 86, "is_show": false, "margin": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "name": "Panel", "rect": {"size": {"x": 352.0, "y": 500.0}}, "style": {"bg_color": {"a": 0.0, "b": 0.0, "g": 0.0, "r": 0.0}}, "type": "Panel"}], "id": 75, "is_show": true, "margin": {"bottom": 0.0, "left": 0.0, "right": 0.0, "top": 0.0}, "name": "XQBG", "rect": {"size": {"x": 352.0, "y": 500.0}}, "style": {}, "type": "XQBG"}

	var node = ServerPageManage.get_node(data)
	
	var tscn = node.get_tscn()
	
	add_child(tscn)


func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	NetContext = Global.get("NetContext")
	StaticGameData = Global.get("StaticGameData")
	FileHelper = Global.get("FileHelper")
	LocalInfo = Global.get("LocalInfo")
	StaticGameData.connect("_loaded_complete", self, "_loaded_complete")
	NetContext.set_handler("LoginController", "login", self, "_on_login_success")
	
	
	if not LocalInfo.is_read_notice():
		ScreenUtils.show_message_plus(LocalInfo.get_notice(), self, "read_notice")
	
	


	
	if FileHelper.file_exits(passowrd_txt_path):
		
		var dic = FileHelper.read_encrypted(passowrd_txt_path, password_key)
		if dic.get("remember", false):
			uname.text = dic["uname"]
			pword.text = dic["pword"]
		
			$Background / Background2 / Panel2 / CheckBox.pressed = true
	

	
	

func read_notice():
	LocalInfo.read()
	pass

func _on_Login_pressed() -> void :
	var username = uname.text
	var password = pword.text
	if verity(username, password): return
	
	var request_data = {
		"username": username, 
		"password": password
	}
	
	if $Background / Background2 / Panel2 / CheckBox.pressed:
		save_user_info()
	else:
		FileHelper.save_encrypted(passowrd_txt_path, {"remember": false}, password_key)
	NetContext.request_gate("LoginController", "login", request_data, true)
	pass
	

func _on_Register_pressed() -> void :
	ScreenUtils.change_ui("res://src/tscn/ui/login/RegisterUi.tscn")
	pass

func verity(username, password):
	if username == "": return true
	if password == "": return true
	return false


func _on_Cance_pressed() -> void :
	ScreenUtils.show_message("确定要退出游戏？", self, "quit_ok", "")
	pass

func quit_ok():
	get_tree().quit(0)

func save_user_info():
	FileHelper.save_encrypted(passowrd_txt_path, {
		"remember": true, 
		"uname": uname.text, 
		"pword": pword.text
	}, password_key)


func _on_login_success(data):
	Global.log_info(str(prefix, "登录成功"))
	ScreenUtils.hide_please_wait()
	if NetContext.List_wait_id.size() > 0:
		NetContext.List_wait_id.remove(0);
	StaticGameData.load_data()
	Global.get("RoleInfoManage").user_vo_data = data["data"]


func _loaded_complete():
	ScreenUtils.change_ui("res://src/tscn/ui/login/select_area/SelectAreaUi.tscn")
