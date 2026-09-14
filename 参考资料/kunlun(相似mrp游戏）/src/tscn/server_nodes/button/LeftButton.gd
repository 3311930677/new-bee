extends "res://src/tscn/server_nodes/button/TextButton.gd"

var left_btn = preload("res://src/tscn/ui/common/button/LeftButton.tscn")



	

func init_tscn():
	instance_tscn = left_btn.instance()
	instance_tscn.set_text(get_text())
	instance_tscn.set_click_handler(self, "click")
	
func click():
	print("点击左部")

