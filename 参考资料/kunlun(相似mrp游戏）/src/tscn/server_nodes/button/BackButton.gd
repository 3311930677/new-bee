extends "res://src/tscn/server_nodes/button/RightButton.gd"



var ScreenUtils = Global.get("ScreenUtils")

var DialogManage = Global.get("DialogManage")

func init_data(data):
	.init_data(data)
	
	

func click():
	print("点击了返回")
	ScreenUtils.del_last_page_ui()

