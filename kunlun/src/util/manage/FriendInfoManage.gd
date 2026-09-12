extends Node
class_name FriendInfoManage

signal _friend_item_change

var ScreenUtils
var StaticGameData
var NetContext


var list_friend = []

func _init() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	StaticGameData = Global.get("StaticGameData")
	NetContext = Global.get("NetContext")
	
	
	NetContext.set_handler("FriendRemote", "searchFriends", self, "_on_search_friend_result")
	NetContext.set_handler("FriendRemote", "delRelation", self, "_on_delete_friend_result")
	NetContext.set_handler("FriendRemote", "addRelation", self, "_on_add_friend_result")


func _on_search_friend_result(data):
	list_friend = data["data"]
	Global.log_info(str(list_friend))
	emit_signal("_friend_item_change")


func _on_add_friend_result(data):
	Global.log_info(str(data["data"]))
	ScreenUtils.show_message("添加成功！")
	request_friends()
	pass


func _on_delete_friend_result(data):
	Global.log_info(str(data["data"]))
	ScreenUtils.show_message("好友删除成功")
	request_friends()


func request_friends():
	NetContext.request_service("FriendRemote", "searchFriends", {}, true)
	pass

func get_friends():
	var temp_list = []
	for i in list_friend:
		if i["type"] == 1:
			temp_list.append(i)
	return temp_list

func get_black_list_friend():
	var temp_list = []
	for i in list_friend:
		if i["type"] == 3:
			temp_list.append(i)
	return temp_list

func get_foe_friend():
	var temp_list = []
	for i in list_friend:
		if i["type"] == 2:
			temp_list.append(i)
	return temp_list


func add_friend(fr_name, type):
	var request_dic = {
		"role_name": fr_name, 
		"type": type
	}
	NetContext.request_service("FriendRemote", "addRelation", request_dic, true)



func delete_friend(friend_id):
	var request_dic = {
		"friend_id": friend_id
	}
	NetContext.request_service("FriendRemote", "delRelation", request_dic, true)
	pass
