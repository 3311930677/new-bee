extends Control


signal edit_sucess(dic)

onready var pop = $PopupPanel

onready var consignment_num = $PopupPanel / Panel / ConsignmentNum / TextEdit

onready var price_num = $PopupPanel / Panel / PriceNum / TextEdit


var coin_type = 2

var con_num = 1

var p_num = 0


func _on_coin_type_pressed(extra_arg_0: int) -> void :
	coin_type = extra_arg_0


func _on_Ok_pressed() -> void :
	if p_num <= 0:
		Global.get("ScreenUtils").show_message("单价不合理")
		return
	if con_num <= 0:
		Global.get("ScreenUtils").show_message("数量不合理")
		return
	var dic = {
		"coin_type": coin_type, 
		"con_num": con_num, 
		"price_num": p_num
	}
	emit_signal("edit_sucess", dic)
	_on_Cancle_pressed()


func _on_Cancle_pressed() -> void :
	pop.hide()
	pass

func show_pop():
	pop.popup_centered()


func _on_consignment_num_changed() -> void :
	con_num = int(consignment_num.text)



func _on_price_num_changed() -> void :
	p_num = int(price_num.text)
	pass
