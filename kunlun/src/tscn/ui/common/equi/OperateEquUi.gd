extends Control


onready var xq_title = $Head / XQTitle


onready var coins = $Panel2 / Coins / Label / HBoxContainer / YinLiang


onready var tips = $Panel2 / Tips


onready var bag_num = $"Panel2/Panel3/BagNum"


onready var popu_menu = $Control / PopupMenu


onready var equ_detail_gem_popu = $Control / EquDetailGem


onready var box = $"Panel2/Background/Background2/ScrollContainer/VBoxContainer"


var ScreenUtils
var BagInfoManage
var StaticGameData


var item_res = preload("res://src/tscn/ui/common/bag/ProLabelItem.tscn")














var op_mode = 0

var item_op_mode = 1
var current_equ_detail = {}
var check_node = null
var check_node_static_data = null
var check_node_data = null




func open_mode(data):
	op_mode = int(data["mod"])
	
	if op_mode == 3: item_op_mode = 2
	elif op_mode == 6: item_op_mode = 3
	
	init_data()
	pass
func clear_container():
	for i in box.get_children():
		i.queue_free()



func init_data():
	BagInfoManage.connect("_equ_detail_info", self, "_equ_detail_info")
	if op_mode == 0:
		tips.text = "请选择你要打孔的装备"
		xq_title.set_title("装备打孔")
	elif op_mode == 1:
		tips.text = "请选择你要镶嵌的装备"
		xq_title.set_title("装备镶嵌")
	elif op_mode == 2:
		tips.text = "请选择你要刻印的装备"
		xq_title.set_title("装备刻印")
	elif op_mode == 3:
		tips.text = "请选择你要练潜的装备"
		xq_title.set_title("装备练潜")
	elif op_mode == 4:
		tips.text = "请选择你要注潜的装备"
		xq_title.set_title("装备注潜")
	elif op_mode == 5:
		tips.text = "请选择你要绑定的装备"
		xq_title.set_title("装备绑定")
	elif op_mode == 6:
		tips.text = "请选择你要修复的装备"
		xq_title.set_title("装备修复")
	init_base_data()
	init_item_data()
	pass

func init_base_data():
	coins.text = str(BagInfoManage.get_coins())
	var max_bag_num = BagInfoManage.get_bag_max_amount()
	var bag_num_ = BagInfoManage.get_bag_amount_local()
	bag_num.text = str("（", bag_num_, "/", max_bag_num, "）")
	pass






func init_item_data():
	clear_container()
	var arr_equ = BagInfoManage.get_all_equs()
	
	
	for i in arr_equ:
		
		var static_data = StaticGameData.get_equi_data(i.equi_data_id)
		if static_data.wear_index == 12: continue
		
		
		if item_op_mode == 1 and i.is_wear: continue
		
		elif item_op_mode == 2 and not i.is_wear: continue
		
		elif item_op_mode == 3 and i.is_mar == 0: continue
		

		
		var item = item_res.instance()
		item.connect("item_click", self, "_on_item_click")
		box.add_child(item)
		item.set_data(i.duplicate())
		pass
	pass



func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	BagInfoManage = Global.get("BagInfoManage")
	StaticGameData = Global.get("StaticGameData")
	
	
	BagInfoManage.connect("_repair_equ_signal", self, "_repair_equ_handle")
	BagInfoManage.connect("_punching_equ_signal", self, "_dakong_equ_handle")
	BagInfoManage.connect("_counter_equ_signal", self, "_keying_equ_handle")
	BagInfoManage.connect("_bind_equ_signal", self, "_bind_equ_handle")
	BagInfoManage.connect("_add_max_potential_equ_signal", self, "_add_potential_equ_handle")
	BagInfoManage.connect("_inlaid_gem_equ_signal", self, "_inlaid_gem_equ_signal")
	BagInfoManage.connect("_bag_all_data", self, "_on_bag_all_data_loaded")
	BagInfoManage.request_bag_data()
	hide()
	pass

func _on_Cancle_pressed() -> void :
	queue_free()


func _on_Ok_pressed() -> void :
	if op_mode == 6:
		xiufu_btn_ok()
		return
	if op_mode == 1:
		xiangqian_btn_ok()
		return
	if op_mode == 0:
		dakong_btn_ok()
		return
	if op_mode == 2:
		keying_btn_ok()
		return
	if op_mode == 3:
		set_poemtial_btn_ok()
		pass
	if op_mode == 5:
		bind_btn_ok()
		return
	if op_mode == 4:
		add_potential_btn_ok()
		return
		pass
	pass


func _on_item_click(node):
	check_node_static_data = node.static_data
	check_node_data = node.data
	if check_node == node:
		_on_Ok_pressed()
		return
	check_node = node

func _on_bag_all_data_loaded(data):
	show()
	init_item_data()
	pass









func xiufu_btn_ok():
	if check_node.data.is_mar == 0:
		ScreenUtils.show_message("只能操作已损坏的装备")
		return
	
	var grade = check_node.static_data.grade
	
	var consolidate_level = check_node.data.consolidate_level
	
	var punch = check_node.data.punch
	
	var countermark = check_node.data.countermark
	
	var num_xiufu = punch + grade * (consolidate_level - 2) + countermark * 5
	if num_xiufu < 0: num_xiufu = 0
	var tip = str("[center]确定消耗:", num_xiufu, "个[color=green]修复宝石[/color]进行修复？")
	ScreenUtils.show_message_plus(tip, self, "_xiuf_btn_ok_callback")

func _xiuf_btn_ok_callback():
	BagInfoManage.repair_equ(check_node.data.id)
	pass

func _repair_equ_handle(data):
	check_node.set_data(data)
	ScreenUtils.show_message("装备修复成功！！")
	pass



func dakong_btn_ok():
	if check_node.data.is_mar == 1:
		ScreenUtils.show_message("无法操作已损坏的装备")
		return
	if check_node.data.punch >= 5:
		ScreenUtils.show_message("装备孔数已达上限")
		return
	if BagInfoManage.get_coins() < 1000:
		ScreenUtils.show_message("金币不足")
		return
	var tip = str("[center]确定消耗:1个[color=green]打孔器[/color]和[color=#FFA500]1000金币[/color]对装备进行打孔?", "[/center]")
	ScreenUtils.show_message_plus(tip, self, "_dakong_btn_ok_callback")
	pass

func _dakong_btn_ok_callback():
	BagInfoManage.punching_equipment(check_node.data.id)
	pass

func _dakong_equ_handle(data):
	check_node.set_data(data)
	ScreenUtils.show_message("装备打孔成功！！")
	
	BagInfoManage.set_gold_coins(1000)
	init_base_data()
	pass



func keying_btn_ok():
	if check_node.data.is_mar == 1:
		ScreenUtils.show_message("无法操作已损坏的装备")
		return
	if BagInfoManage.get_coins() < 10000:
		ScreenUtils.show_message("银两不足")
		return
	if check_node.data.countermark == 1:
		ScreenUtils.show_message("当前装备已刻印")
		return
	if check_node.data.consolidate_level < 15:
		ScreenUtils.show_message("锻造15星以下的装备无法刻印")
		return
	var tip = str("[center]确定消耗:1个[color=green]刻印宝石[/color]和[color=#FFA500]10000金币[/color]对装备进行刻印?刻印后装备无法交易，并且获得[color=green]1000最大潜力[/color]", "[/center]")
	ScreenUtils.show_message_plus(tip, self, "_keying_btn_ok_callback")
	pass

func _keying_btn_ok_callback():
	BagInfoManage.counter_equipment(check_node.data.id)
	pass


func _keying_equ_handle(data):
	check_node.set_data(data)
	ScreenUtils.show_message("装备刻印成功！！")
	
	BagInfoManage.set_gold_coins(10000)
	init_base_data()
	pass


func bind_btn_ok():
	if check_node.data.is_mar == 1:
		ScreenUtils.show_message("无法操作已损坏的装备")
		return
	if BagInfoManage.get_coins() < 5000:
		ScreenUtils.show_message("银两不足")
		return
	if check_node.data.bind == 1:
		ScreenUtils.show_message("当前装备已绑定")
		return
	var tip = str("[center]确定消耗:[color=#FFA500]5000银两[/color]对装备进行绑定?绑定后装备无法交易，并且获得[color=green]500最大潜力[/color]", "[/center]")
	ScreenUtils.show_message_plus(tip, self, "_bind_btn_ok_callback")
	pass

func _bind_btn_ok_callback():
	BagInfoManage.bind_equipment(check_node.data.id)
	pass


func _bind_equ_handle(data):
	check_node.set_data(data)
	ScreenUtils.show_message("装备绑定成功！！")
	
	BagInfoManage.set_gold_coins(5000)
	init_base_data()
	pass


func set_poemtial_btn_ok():
	if check_node.data.is_mar == 1:
		ScreenUtils.show_message("无法操作已损坏的装备")
		return
	if check_node.data.is_wear == 0:
		ScreenUtils.show_message("当前装备未穿戴，无法设置")
		return
	var tip = str("[center]确定设置选择装备为练潜装备？[/center]")
	ScreenUtils.show_message_plus(tip, self, "_set_poemtial_btn_ok_callback")
	pass

func _set_poemtial_btn_ok_callback():
	BagInfoManage.set_poemtial_equipment(check_node.data.id)
	pass



func add_potential_btn_ok():
	if check_node.data.is_mar == 1:
		ScreenUtils.show_message("无法操作已损坏的装备")
		return
	if BagInfoManage.get_coins() < 500:
		ScreenUtils.show_message("银两不足")
		return
	var tip = str("[center]确定消耗:[color=#FFA500]500银两[/color]和1个[color=green]潜力符石[/color]对增加装备最大100潜力", "[/center]")
	ScreenUtils.show_message_plus(tip, self, "_add_potential_btn_ok_callback")
	pass

func _add_potential_btn_ok_callback():
	BagInfoManage.add_potential_equipment(check_node.data.id)
	pass


func _add_potential_equ_handle(data):
	check_node.set_data(data)
	var tip = str("增加成功！装备当前最大潜力:", data.max_potential)
	ScreenUtils.show_message(tip)
	
	BagInfoManage.set_gold_coins(500)
	init_base_data()
	pass


func xiangqian_btn_ok():
	if BagInfoManage.get_coins() < 500:
		ScreenUtils.show_message("金币不足")
		return
	if check_node.data.is_mar == 1:
		ScreenUtils.show_message("无法操作已损坏的装备")
		return
	if check_node.data.punch <= 0:
		ScreenUtils.show_message("装备孔数不足")
		return
	
	
	
	
	
	BagInfoManage.get_equipment_details(check_node.data.id, true)
	pass


func _equ_detail_info(data):
	current_equ_detail = data
	equ_detail_gem_popu.set_data(data)
	equ_detail_gem_popu.popup_centered()
	pass

var inlaid_index = - 1

func _on_RichTextLabel_meta_clicked(meta) -> void :
	Global.log_info(meta)
	inlaid_index = parse_json(meta).index
	var arg = {
		"node": self, 
		"result_func": "attach_ui_call_back", 
		"article": 4, 
		"update": true, 
		"title": "请选择宝石"
	}
	$Control / EquDetailGem.hide()
	ScreenUtils.show_select_attach_article_ui(arg)
	pass

func attach_ui_call_back(data):
	
	var ststic_d = StaticGameData.get_gem_data(data.data.gemstone_id)
	var wears = ststic_d.inlaid_pos
	var wear_in = check_node_static_data.wear_index
	if wears.find(wear_in) == - 1:
		ScreenUtils.show_message("当前装备不可镶嵌此类宝石")
		return
	
	var hold_id = check_node_data.id
	var index = inlaid_index
	var gem_id = data.data.id
	BagInfoManage.inlaid_gem_equipment(hold_id, index, gem_id)

	pass


func _inlaid_gem_equ_signal(data):

		
	BagInfoManage.set_gold_coins(500)
	init_base_data()
	ScreenUtils.show_message("宝石镶嵌成功！\n通过练潜可将宝石属性转化为战斗时使用")
	pass
