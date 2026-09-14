extends GridContainer

signal double_click


var item_res = preload("res://src/tscn/ui/common/menu/ListMenuItem.tscn")

var check_node = null

func get_select():
	if check_node == null: return null
	return check_node.get_data()




func add_item(item_name, attach_data, cd = false):
	var item = item_res.instance()
	add_child(item)
	item.set_data(attach_data)
	item.set_name(item_name)
	
	item.set_click( not cd)
	
	item.connect("sigle_click", self, "_item_sigle_click")
	item.connect("double_click", self, "_item_double_click")


func add_items(items):
	clear()
	for i in items:
		add_item(i["name"], i["data"], i.get("cd", false))

func _item_sigle_click(node):
	check_node = node

func _item_double_click(node):
	check_node = node
	emit_signal("double_click")

func clear():
	for i in get_children():
		i.free()
