extends Control

var StaticGameData
var ScreenUtils

func _ready() -> void :
	StaticGameData = Global.get("StaticGameData")
	ScreenUtils = Global.get("ScreenUtils")
	StaticGameData.connect("_loaded_complete", self, "_loaded_complete")
	
func load_data(data):
	pass


func _on_Button_pressed() -> void :
	StaticGameData.load_data()

func _loaded_complete():
	ScreenUtils.show_tips("数据重载成功")
	pass
