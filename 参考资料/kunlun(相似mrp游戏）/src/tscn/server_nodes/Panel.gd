extends "res://src/tscn/server_nodes/ServerNode.gd"


var NetContext = Global.get("NetContext")





	
func init_tscn():
	instance_tscn = Panel.new()
	var panel_style = instance_tscn.get_stylebox("panel").duplicate()
	
	var bg_color = style.get("bg_color")
	if bg_color != null:
		panel_style.modulate_color = Color(bg_color["r"], bg_color["g"], bg_color["b"], bg_color["a"])
	instance_tscn.add_stylebox_override("panel", panel_style)
		




