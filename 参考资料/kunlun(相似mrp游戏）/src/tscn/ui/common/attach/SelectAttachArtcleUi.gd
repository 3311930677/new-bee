extends Control


onready var title = $Head / XQTitle
onready var prop_item_res = preload("res://src/tscn/ui/common/bag/ProLabelItem.tscn")
onready var box = $Background / Background2 / ScrollContainer / VBoxContainer
var ScreenUtils
var BagInfoManage

var check_node


var dic_data = {
	"node": "具体节点[必须]", 
	"result_func": "具体方法[必须]", 
	"bind": "0[可选，是否加载绑定选项]，0表示不加载绑定的 1表示加载绑定的 -1表示无视不传是-1", 
	"article": "-1表示都加载,3表示加载装备，4表示加载宝石，5表示加载道具不传是-1", 
	"select_more": "-1表示无视，1表示需要多个道具，由用户指定,不传是-1", 
	"update": "是否需要网络进行刷新，默认不传是false", 
	"title": "标题，默认是XQ"
}

var result_data = {}


func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	BagInfoManage = Global.get("BagInfoManage")
	dic_data = get_meta("data")
	
	
	if dic_data.get("update", false):
		BagInfoManage.connect("_bag_all_data", self, "_bag_all_data")
		BagInfoManage.request(true)
		hide()
	else:
		load_data()

func _bag_all_data(data):
	show()
	load_data()
	pass

func _on_Cancle_pressed() -> void :
	queue_free()
	pass
func _on_Ok_pressed() -> void :
	if dic_data.get("select_more", - 1) == - 1:
		result_data["num"] = 1
		call_back_result()
	else: ScreenUtils.show_popup_menu_edit(self, "_menu_edit_num", 0, "请输入数量")

func _menu_edit_num(id, txt):
	if id != 0: return
	var num = int(txt)
	if num <= 0:
		ScreenUtils.show_message("道具数量必须大于0")
		return
	if num > 99:
		ScreenUtils.show_message("请输入合理范围的数值")
		return
	if check_node.data.get("count", 1) < num:
		ScreenUtils.show_message("道具数量不足")
		return
	
	result_data["num"] = num
	call_back_result()


func _item_click(node):
	if check_node == node:
		_on_Ok_pressed()
		return
	check_node = node
	pass


func load_data():
	
	set_title(dic_data.get("title", "XQ"))
	clear_container()
	var load_list_data = []
	var article_mode = dic_data.get("article", - 1)
	
	
	if article_mode == - 1: load_list_data = BagInfoManage.get_all_bag_datas()
	
	if article_mode == 3: load_list_data = BagInfoManage.get_all_equs()
	
	if article_mode == 4: load_list_data = BagInfoManage.get_gems()
	
	if article_mode == 5: load_list_data = BagInfoManage.get_arts()
	
	for item in load_list_data:
		if dic_data.get("bind", - 1) != - 1:
			if item.get("bind", 0) != dic_data.get("bind", 0): continue
		var i = prop_item_res.instance()
		box.add_child(i)
		i.set_data(item)
		i.connect("item_click", self, "_item_click")
		pass


func set_title(tit):
	title.set_title(tit)
	pass


func clear_container():
	for i in box.get_children():
		i.queue_free()

func call_back_result():
	result_data["data"] = check_node.data
	dic_data["node"].call(dic_data["result_func"], result_data)
	
	queue_free()
	pass
