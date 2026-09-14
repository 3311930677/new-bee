extends Node2D


var buff_data

var anim_player: AnimationPlayer = null

var TXUtils

var anim_name = "buff1"

var remain = 0

func _ready() -> void :
	TXUtils = Global.get("TXUtils")
	anim_player = TXUtils.get_buffs()
	add_child(anim_player)
	anim_player.play(anim_name)



func set_data(buff_info):
	buff_data = buff_info
	anim_name = Global.get("DicStaticGameData").buff_tx_dic[str(buff_data["buffId"])]
	remain = buff_data["remain"]
func refresh(buff_info):
	remain = buff_data["remain"]
	pass
func count_update():
	remain -= 1
