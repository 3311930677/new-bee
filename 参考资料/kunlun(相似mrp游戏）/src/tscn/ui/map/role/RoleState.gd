extends Panel


onready var vbox = $"Background/Background2/ScrollContainer/VBoxContainer"
onready var state_label = preload("res://src/tscn/ui/common/player/RoleSateLableItem.tscn")
var ScreenUtils
var RoleInfoManage
var AssetsManage
var role_condition

var check_node = null

var static_key = {
	"supply_pack": "补给包", 
	"enemy_magic_card": "诱敌魔卡", 
	"exorcism_card": "驱敌魔卡", 
	"thyme_magic_weed": "百里香魔草", 
	"magic_bell_magic_grass": "聚魔铃草", 
	"double_experience_potion": "双倍经验药剂", 
}

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	AssetsManage = Global.get("AssetsManage")
	RoleInfoManage = Global.get("RoleInfoManage")
	RoleInfoManage.connect("role_info_result", self, "_on_role_info_result")
	
	
	

func _on_role_info_result(data):
	clear()
	role_condition = data["role_condition"]
	for k in static_key.keys():
		var labe = state_label.instance()
		var temp = {"key": k, "value": static_key[k]}
		labe.set_data(temp, role_condition)
		labe.connect("item_click", self, "_item_click")
		vbox.add_child(labe)
	pass

func clear():
	for item in vbox.get_children():
		item.queue_free()

func _item_click(node):
	if node == check_node:
		_on_Ok_pressed()
		return
	check_node = node


func _on_Ok_pressed() -> void :
	if check_node == null: return
	
	
	var op = false
	
	if check_node.open_switch:
		
		check_node.close(true)
		pass
	else:
		op = true
		
		check_node.open(true)
		
		pass
	
	
