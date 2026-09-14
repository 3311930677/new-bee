extends TextureRect

signal operate_time_out

onready var tao_pao_sucess_res = preload("res://src/tscn/ui/battle/res/tao_pao_sucess.tres")

onready var tao_pao_faild_res = preload("res://src/tscn/ui/battle/res/tao_pao_faild.tres")

onready var catch_sucess_res = preload("res://src/tscn/ui/battle/res/catch_sucess.tres")

onready var catch_faild_res = preload("res://src/tscn/ui/battle/res/catch_faild.tres")

func _on_Timer_timeout() -> void :
	emit_signal("operate_time_out")
	queue_free()


func show_taopao(flag = false):
	if flag:
		texture = tao_pao_sucess_res
	else:
		texture = tao_pao_faild_res
	pass

func show_catch(falg = false):
	if falg:
		texture = catch_sucess_res
	else:
		texture = catch_faild_res
	pass
