extends Control

onready var ctime = $CTime
onready var round_ = $Round
onready var timer = $Timer

var TBBattleManage

var tb_battle_scence

func _ready() -> void :
	TBBattleManage = Global.get("TBBattleManage")
	tb_battle_scence = Global.get_nodes_in_group("tb_battle_scence")[0]
	tb_battle_scence.connect("round_show_hourglass_", self, "round_show_hourglass_")
	tb_battle_scence.connect("battle_round_start_", self, "hide_tips")
	show_count_down()
	show_current_round()


func show_count_down():
	timer.start()
	ctime.show()
	ctime.text = str(timer.time_left)


func show_current_round():
	round_.show()
	round_.text = str("回合:", TBBattleManage.get_battle_round())

func round_show_hourglass_():
	show_count_down()
	show_current_round()
	pass


func hide_tips():
	timer.stop()
	ctime.hide()
	round_.hide()
	pass


func _process(delta: float) -> void :
	ctime.text = str(int(timer.time_left))


