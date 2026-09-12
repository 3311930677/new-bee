class_name ServerNode

extends Node






var type: String
var node_name: String
var path: String



var form_data = {}

var childrenList = []

var ServerPageManage = Global.get("ServerPageManage")

var instance_tscn

var parent

var is_show: bool

var style


var id




func load_data(data: Dictionary):
	
	init_data(data)
	init_tscn()
	
	var tscn = get_tscn()
	
	
	if tscn != null:
		
		tscn.anchor_left = data["anchor"]["left"]
		tscn.anchor_right = data["anchor"]["right"]
		tscn.anchor_top = data["anchor"]["top"]
		tscn.anchor_bottom = data["anchor"]["bottom"]
		
		tscn.margin_left = data["margin"]["left"]
		tscn.margin_right = data["margin"]["right"]
		tscn.margin_top = data["margin"]["top"]
		tscn.margin_bottom = data["margin"]["bottom"]
		
		
		tscn.rect_size.x = data["rect"]["size"]["x"]
		tscn.rect_size.y = data["rect"]["size"]["y"]
	
	
	if not is_show:
		tscn.hide()
		
	
	var childs = data["childrenList"]
	var cnt = 0
	for child in childs:
		var node = ServerPageManage.get_node(child, self)
		self.childrenList.append(node)
		cnt += 1
		tscn.add_child(node.get_tscn())
	
	init_after()
	
	


func init_data(data: Dictionary):
	type = data["type"]
	node_name = data["name"]
	is_show = data["is_show"]
	id = data["id"]
	style = data["style"]




func init_after():
	pass


func init_tscn():
	pass
	
	
	


func get_tscn():
	return instance_tscn



func get_root():
	if self.parent == null: return self
	else: return self.parent.get_root()


func search_node_by_type(tp: String):
	var list = []
	
	for child in self.childrenList:
		var flag = false
		
		if child.type == tp:
			list.append(child)
		list.append_array(child.search_node_by_type(tp))
		
	return list


func search_node_by_id(id):
	var list = []
	
	for child in self.childrenList:
		var flag = false
		if child.id == id:
			list.append(child)
		list.append_array(child.search_node_by_id(id))
		
	return list
	

func show():
	is_show = true
	get_tscn().show()

func hide():
	is_show = false
	get_tscn().hide()
	
