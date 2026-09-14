extends Node
class_name AssetsManage




func _ready():
	pass


func get_prefix():
	return "res://"

func get_ligth_tex():
	return load(str(get_prefix(), "assets/res/light.png"))
