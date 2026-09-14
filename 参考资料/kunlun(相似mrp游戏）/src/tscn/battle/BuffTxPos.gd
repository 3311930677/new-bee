extends Position2D

onready var buff_tx_res = preload("res://src/tscn/battle/common/BuffTx.tscn")

var CombatManage
var buff_data
var real_index

func _ready() -> void :
	CombatManage = Global.get("CombatManage")
	CombatManage.connect("fight_round_line_", self, "check_buff_state")



func add_buff(buff_data):
	self.buff_data = buff_data
	
	
	if not check_buff_exist(buff_data):
		
		if buff_data["type"] == 1 or buff_data["type"] == 2 or buff_data["type"] == 7:
			var tx = buff_tx_res.instance()
			tx.set_data(buff_data)
			add_child(tx)
	pass

func check_buff_state(data):
	count_refresh()
	var end_data = data["data"]["round_end_data"]
	var c_end_data = null
	for item in end_data:
		if item["entity_index"] == real_index:
			c_end_data = item
			break
	if c_end_data == null: return
	
	var result = c_end_data["buff_result"]
	
	for del_name in result.get("del_buffs", []):
		del_buff(del_name)
		pass

func count_refresh():
	for i in get_children():
		i.count_update()
	pass


func check_buff_exist(buff_data):
	if get_buff_entity(buff_data["name"]) != null: return true
	else: return false

func del_buff(buff_name):
	var entity = get_buff_entity(buff_name)
	if entity != null: entity.queue_free()


func get_buff_entity(buff_name):
	for i in get_children():
		if i.get_name() == buff_name:
			return i
	return null
