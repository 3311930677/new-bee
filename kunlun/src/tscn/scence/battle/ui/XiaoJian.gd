extends Control

onready var left = $LeftItem
onready var right = $RightItem



func select(arr_index):
	for i in arr_index:
		if i < 7: _left_select(i)
		else: _right_select(i)


func get_select_arr():
	var select_arr = []
	var index = 1
	
	for i in left.get_children():
		if i.visible: select_arr.append(index)
		index += 1
	
	for i in right.get_children():
		if i.visible: select_arr.append(index)
		index += 1
	
	return select_arr

func _left_select(index):
	left.get_child(index - 1).visible = true
	pass

func _right_select(index):
	right.get_child(index - 7).visible = true
	pass

func all_hide():
	for i in left.get_children():
		i.visible = false
	for i in right.get_children():
		i.visible = false
	pass
