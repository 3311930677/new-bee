extends Node
class_name MemoManage


const prefix = "MemoManage->"

signal reset_role_display
signal reset_role_position

signal around_role_loaded

var player = preload("res://src/tscn/player/Player.tscn")

var ScreenUtils
var NetContext
var StaticGameData
var RoleInfoManage


var current_around_list_roles_ = {}
var is_load_around_role = true
var emit_around_signal = false

var current_map_role_ = {}

var memo_ui


func _init() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	NetContext = Global.get("NetContext")
	RoleInfoManage = Global.get("RoleInfoManage")
	
	NetContext.set_handler("MemoRemote", "getMemoData", self, "_memo_data_handler")
	NetContext.set_handler("MemoRemote", "getMemoInfo", self, "_memo_info_data_handler")


func set_memo_ui(memo_ui):
	self.memo_ui = memo_ui
	

func load_memo_data():
	NetContext.request_service("MemoRemote", "getMemoData", {}, true)
	

func get_memo_info(memo_type, id):
	var data = {
		"memo_type": memo_type, 
		"id": id
	}

	NetContext.request_service("MemoRemote", "getMemoInfo", data, true)



func _memo_info_data_handler(data):
	data = data["data"]
	
	ScreenUtils.show_message(data["text"])



func _memo_data_handler(data):
	data = data["data"]
	if memo_ui == null: return
	memo_ui.load_data(data)
	
	pass


