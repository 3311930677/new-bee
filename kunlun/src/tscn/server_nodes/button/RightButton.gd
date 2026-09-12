extends "res://src/tscn/server_nodes/button/TextButton.gd"

var right_btn = preload("res://src/tscn/ui/common/button/RightButton.tscn")



func _init():
	instance_tscn = right_btn.instance()
	

func init_tscn():
	instance_tscn.set_text(get_text())
	instance_tscn.set_click_handler(self, "click")
	


func click():
	print("点击右部")


