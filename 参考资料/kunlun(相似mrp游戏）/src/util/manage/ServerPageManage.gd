extends Node
class_name ServerPageManage



var NodeMap = {
	"XQBG": load("res://src/tscn/server_nodes/XQBG.gd"), 
	"XQTitle": load("res://src/tscn/server_nodes/XQTitle.gd"), 
	"Input": load("res://src/tscn/server_nodes/form/Input.gd"), 
	"TextInput": load("res://src/tscn/server_nodes/Form/TextInput.gd"), 
	"SubmitInput": load("res://src/tscn/server_nodes/Form/SubmitInput.gd"), 
	"LeftButton": load("res://src/tscn/server_nodes/button/LeftButton.gd"), 
	"RightButton": load("res://src/tscn/server_nodes/button/RightButton.gd"), 
	"TextButton": load("res://src/tscn/server_nodes/button/TextButton.gd"), 
	"BackButton": load("res://src/tscn/server_nodes/button/BackButton.gd"), 
	"TextItem": load("res://src/tscn/server_nodes/item/TextItem.gd"), 
	"Form": load("res://src/tscn/server_nodes/form/Form.gd"), 
	"Panel": load("res://src/tscn/server_nodes/Panel.gd"), 
	"JumpTextItem": load("res://src/tscn/server_nodes/item/JumpTextItem.gd"), 
	"ShowNodeItem": load("res://src/tscn/server_nodes/item/ShowNodeItem.gd"), 
	"TextLabel": load("res://src/tscn/server_nodes/label/TextLabel.gd"), 
	"HideButton": load("res://src/tscn/server_nodes/button/HideButton.gd"), 
	"ScrollContainer": load("res://src/tscn/server_nodes/container/ScrollContainer.gd"), 
	"SubmitItem": load("res://src/tscn/server_nodes/item/SubmitItem.gd"), 
}





func get_node(node_data, parent = null):
	var node = NodeMap[node_data["type"]].new()
	node.parent = parent
	node.load_data(node_data)
	
	return node
	

