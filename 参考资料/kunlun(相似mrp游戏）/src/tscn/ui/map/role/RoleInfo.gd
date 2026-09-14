extends Panel

onready var vbox = $"Background/Background2/ScrollContainer/VBoxContainer"

var ScreenUtils
var RoleInfoManage
var StaticGameData
var self_ = false
var font = preload("res://assets/font/font-16.tres")

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	RoleInfoManage = Global.get("RoleInfoManage")
	StaticGameData = Global.get("StaticGameData")
	RoleInfoManage.connect("role_info_result", self, "_on_role_info_result")
	

func _on_role_info_result(data):
	
	var ins_id = $"../../..".inspect_id
	if ins_id == data["role"]["id"]:
		self_ = true
		pass
	clear()
	load_data(data)
	pass


func load_data(data):
	
	add_text(str("昵称：", data["role"]["role_name"]))
	
	add_text(str("等级：", data["role"]["level"]))
	
	add_text(str("分堂：", StaticGameData.role_job_division_name[str(data["role"]["division_id"])]))
	
	add_text(str("称号：无"))
	
	add_text(str("帮派：无"))
	
	add_text(str("身份：", StaticGameData.get_role_popularity_text(int(data["role"].get("popularity", 0)))))
	
	if data["roleMasterVo"].has("ts"):
		var arr = data["roleMasterVo"]["ts"]
		var index = 1
		for i in arr:
			add_text(str("徒弟", index, ": ", i["name"], "(情义值：", i["value"], ")"))
			index += 1
	
	if data["roleMasterVo"].has("master"):
		var d = data["roleMasterVo"]["master"]
		add_text(str("师傅: ", d["name"], "(情义值：", d["value"], ")"))
	pass








func add_text(txt):
	var lab = Label.new()
	lab["custom_fonts/font"] = font
	lab["custom_colors/font_color"] = Color(0, 0, 0, 1)
	lab.text = txt
	vbox.add_child(lab)
	pass

func clear():
	
	for item in vbox.get_children():
		item.queue_free()
