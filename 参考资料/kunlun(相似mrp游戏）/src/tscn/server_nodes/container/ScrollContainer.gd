extends "res://src/tscn/server_nodes/ServerNode.gd"


var NetContext = Global.get("NetContext")


func init_tscn():
	instance_tscn = ScrollContainer.new()
	
	

func init_after():
	for child in childrenList:
		var child_tscn = child.get_tscn()
		
		child_tscn.rect_min_size = child_tscn.rect_size
	




