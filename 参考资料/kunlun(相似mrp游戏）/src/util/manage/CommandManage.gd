extends Node
class_name ComMandManage
const prefix = "ComMandManage->"

var ScreenUtils
var NetContext


var hot_data = {}

var confirm_key = "confirm"

func _init() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	NetContext = Global.get("NetContext")
	
	NetContext.set_handler("command_remote", "exec", self, "_on_exec")
	pass

func _on_exec(data):
	data = parse_json(data["data"])
	for c in data["commands"]:
		run_command(c)
	pass





func run_command(comm):
	call_deferred(str("command_", comm["name"]), comm["argMap"])
	pass




func command_change_map(args):
	var map_id = args["map_id"]
	var map_name = args.get("map_name", null)
	var role_x = args.get("x", - 1)
	var role_y = args.get("y", - 1)
	var isCommand = args.get("command", true)
	Global.get("MapInfoManage").change_map(map_id, true, map_name)
	
	if int(role_x) >= 0 and int(role_y) >= 0:
		Global.get("MapInfoManage").direction = - 1
		Global.get("MapInfoManage").p_target_point = Vector2(role_x, role_y)
	else:
		Global.get_nodes_in_group("map_scence")[0].player_entity.entrance_dir = 10


func command_change_scence(args):
	var scence = args.get("scence", "map")
	
	if scence == "map":
		var arr = Global.get_nodes_in_group("tb_battle_scence")
		if arr.size() > 0:
			arr[0]._on_EndTimer_timeout()
	pass

func command_update_role_info(args):
	
	Global.get("RoleInfoManage").role_reload_display = true
	Global.get("RoleInfoManage").update_role_info()
	pass

func command_update_task(args):
	Global.get("TaskInfoManage").request_task()
	pass

func command_refresh_task(args):
	Global.get("TaskInfoManage").request_refresh_task()
	pass


func command_flush_role_info(args):
	Global.get("RoleInfoManage").update_role_info()
	pass

func command_flush_role_condition_info(args):
	Global.get("RoleInfoManage").update_role_condition_info()

func command_flush_role_backpack_info(args):
	Global.get("RoleInfoManage").update_role_backpack_info()

func command_flush_role_display_vo_info(args):
	Global.get("RoleInfoManage").flush_role_bvo_info( - 1)

func command_flush_pet_info(args):
	Global.get("PetInfoManage").request_pet_details( - 1, false)
	pass


func command_flush_bag_info(args):
	Global.get("BagInfoManage").request_data()
	pass

func command_flush_backpack_data(args):
	Global.get("BagInfoManage").flush_backpack()


func command_flush_task(args):
	Global.get("TaskInfoManage").request_refresh_task()
	pass

func command_flush_role_skill(args):
	Global.get("RoleInfoManage").request_role_skill_learn()






func command_xb_tower_activity(args):
	Global.get("ActivityDataManage").flush_xb_data(false)






func command_open_forge_equi(args):
	Global.get("ScreenUtils").change_ui("res://src/tscn/ui/common/equi/ForgeEquiUi.tscn")
	pass





func command_open_ori_equi(args):
	Global.get("ScreenUtils").chage_ui_and_args("res://src/tscn/ui/common/equi/OperateEquUi.tscn", "open_mode", {"mod": 0})
	pass


func command_open_inlaid_equi(args):
	Global.get("ScreenUtils").chage_ui_and_args("res://src/tscn/ui/common/equi/OperateEquUi.tscn", "open_mode", {"mod": 1})
	pass


func command_open_op_equ(args):
	Global.get("ScreenUtils").chage_ui_and_args("res://src/tscn/ui/common/equi/OperateEquUi.tscn", "open_mode", {"mod": args["open_mode"]})
	pass


func command_open_dialog_txt(args):
	pass


func command_open_pet_trader(args):
	Global.get("ScreenUtils").chage_ui_and_args("res://src/tscn/ui/map/pet/PetTraderUi.tscn", "open_mode", args)
	pass



func command_open_create_faction_txt(args):
	Global.get("ScreenUtils").show_popup_menu_edit(self, "create_faction_callback", 0, "请输入帮派名称:")
	pass


func command_open_equ_dealer(args):
	Global.get("ShopInfoManage").dealer_index = args.get("index", 1)
	Global.get("ShopInfoManage").dealer_job_type = args.get("job_type", 0)
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/shop/CashShopping.tscn", "load_data", {"shop_type": 4})
	pass
	

func command_open_sell_equ(args):
	ScreenUtils.change_ui("res://src/tscn/ui/map/shop/SellShopping.tscn")
	pass

func command_open_bag_command(args):
	
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/bag/BagUi.tscn", "load_data", {"type": 0, "command": true})
	pass

func command_open_bank_command(args):
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/bag/StoreBankUi.tscn", "load_data", {"command": true})
	pass


func command_open_trade_buy(args):
	ScreenUtils.change_ui("res://src/tscn/ui/map/trade/TradeUi.tscn")
	pass

func command_open_trade_retrieve(args):
	ScreenUtils.change_ui("res://src/tscn/ui/map/trade/TradeRetrieveUi.tscn")
	pass

func command_open_trade_consignment(args):
	ScreenUtils.change_ui("res://src/tscn/ui/map/trade/TradeConsignmentUi.tscn")
	pass


func command_open_sneak_evil(args):
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/gae/GAEUi.tscn", "load_data", {"type": 2})
	pass

func command_open_sneak_good(args):
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/gae/GAEUi.tscn", "load_data", {"type": 1})
	pass


func command_open_ranking(args):
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/ranking/Ranking.tscn", "set_data", {"type": args.get("type", 0)})
	pass

func command_open_fish(args):
	var charge = args.get("charge", false)
	var data = {};
	data["charge"] = charge
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/fish/FishUi.tscn", "set_data", data)
	pass

func command_open_master_list(args):
	ScreenUtils.change_ui("res://src/tscn/ui/map/master/MasterListUi.tscn")

func command_open_master(args):
	ScreenUtils.change_ui("res://src/tscn/ui/map/master/MasterUi.tscn")


func command_open_ring(args):
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/ring/RingUi.tscn", "load_data", args)

func command_open_meritorious_shop(args):
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/shop/CashShopping.tscn", "load_data", {"shop_type": 5})
	pass

func command_set_role_attr(args):
	Global.get("RoleInfoManage").set_role_attr(args)
	pass

func command_set_pet_attr(args):
	Global.get("PetInfoManage").set_pet_attr(args)
	pass
func command_set_team_attr(args):
	Global.get("NTeamManage").set_team_attr(args)



func command_show_tips(args):
	ScreenUtils.show_tips(args.get("msg", "默认提示"))
	pass

func command_show_tips_plus(args):
	ScreenUtils.show_tips_plus(args.get("msg", "默认提示"))
	pass

func command_show_top_tips(args):
	ScreenUtils.show_top_tips(args.get("msg", "有重要消息提示"))

func command_show_dialog_message(args):
	ScreenUtils.show_message(args.get("msg", ""))
	pass
	

func command_show_dialog_plus_message(args):
	ScreenUtils.show_message_plus(args.get("msg", ""))
	pass

func command_show_dialog_confirm(args):
	var data = {}
	data["msg"] = args.get("msg", "默认提示")
	data["ok_dic"] = args.get("ok", {})
	data["cancel_dic"] = args.get("cancel", {})
	hot_data[confirm_key] = data
	
	ScreenUtils.show_message(data["msg"], self, "confirmation_ok", "confirmation_cancle")
	pass

func command_show_dialog_plus_confirm(args):
	var data = {}
	data["msg"] = args.get("msg", "默认提示")
	data["ok_dic"] = args.get("ok", {})
	data["cancel_dic"] = args.get("cancel", {})
	data["data"] = args.get("data", {})
	hot_data[confirm_key] = data
	ScreenUtils.show_message_plus(data["msg"], self, "confirmation_ok", "confirmation_cancle")
	pass


func confirmation_ok():
	if not hot_data.has(confirm_key): return
	var ok_dic = hot_data[confirm_key]["ok_dic"]
	if ok_dic.empty(): return
	var data = ok_dic.get("data", {})
	var remote_ = ok_dic["remote"]
	var method_ = ok_dic["method"]
	
	if ok_dic.get("forwardSF", 0) == 0:
		NetContext.request_service(remote_, method_, data, true)
	elif ok_dic.get("forwardSF", 0) == 1:
		NetContext.request_fight(remote_, method_, data, true)
		pass

func confirmation_cancle():
	if not hot_data.has(confirm_key): return
	var cancel_dic = hot_data[confirm_key]["cancel_dic"]
	if cancel_dic.empty(): return
	var data = cancel_dic["data"]
	var remote_ = cancel_dic["remote"]
	var method_ = cancel_dic["method"]
	
	if cancel_dic.get("forwardSF", 0) == 0:
		NetContext.request_service(remote_, method_, data, true)
	elif cancel_dic.get("forwardSF", 0) == 1:
		NetContext.request_fight(remote_, method_, data, true)
		pass
	pass









var remot
var method
var data = {}
	

func command_interface_confirmation_command(args):
	var text = args["text"]
	remot = args["remote"]
	method = args["method"]
	
	data = args.get("data", {})
	
	ScreenUtils.show_message_plus(text, self, "ok_interface_confirmation", "cancle_interface_confirmation")


func ok_interface_confirmation():
	NetContext.request_service(remot, method, data, true)
	
	

func cancle_interface_confirmation():
	pass
	

	
	
	
	

func create_faction_callback(id, txt):
	Global.log_info(str(txt))
	if txt.length() < 2 or txt.length() > 6:
		Global.get("ScreenUtils").show_message("帮派名称必须在2-6位字符之间")
		return
	Global.get("FactionInfoManage").create_faction(txt)

