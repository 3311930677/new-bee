extends Position2D

var buff_tx_res = preload("res://src/tscn/battle/common/BuffTx.tscn")


var DicStaticGameData

var buffids = {
	
}

func _ready() -> void :
	DicStaticGameData = Global.get("DicStaticGameData")
	var tb_battle_scence = Global.get_nodes_in_group("tb_battle_scence")[0]
	tb_battle_scence.connect("round_show_hourglass_", self, "round_show_hourglass_")


func add_buff(buff_info):
	
	if not DicStaticGameData.buff_tx_dic.has(str(buff_info["buffId"])):
		Global.log_info(str("buff_id:", buff_info, "没有对应的buff_tx 不予添加"))
		return
	
	if buffids.has(str(buff_info["buffId"])):
		
		buffids[str(buff_info["buffId"])].refresh(buff_info)
	else:
		
		var tx = buff_tx_res.instance()
		tx.set_data(buff_info)
		buffids[str(buff_info["buffId"])] = tx
		add_child(tx)
		Global.log_info(str("添加buff的特效", buff_info))
	pass


func remove_buff(buff_id):
	if buffids.has(str(buff_id)):
		Global.log_info(str("移除buff", buff_id))
		var entity = buffids[str(buff_id)]
		buffids.erase(str(buff_id))
		if entity != null and is_instance_valid(entity):
			entity.queue_free()

func round_show_hourglass_():
	for i in buffids.keys():
		if is_instance_valid(buffids.get(i)):
			buffids[i].count_update()
