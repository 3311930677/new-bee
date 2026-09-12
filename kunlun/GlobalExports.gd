extends Node
var prefix = "GLOBAL->"


var export_compoments = true



var compoments_path = {
	"FileHelper": "res://src/util/common/FlleHelper.gd", 
	"MapeUtils": "res://src/util/MapeUtils.gd", 
	"RoleUtils": "res://src/util/RoleUtils.gd", 
	"ScreenUtils": "res://src/util/ScreenUtils.gd", 
	"GameData": "res://src/util/GameData.gd", 
	"PlayerOperate": "res://src/util/common/PlayerOperate.gd", 
	"MailOperate": "res://src/util/common/MailOperate.gd", 
	"TXUtils": "res://src/util/TXUtils.gd", 
	"NpcUtils": "res://src/util/NpcUtils.gd", 
	"NetContext": "res://src/util/common/NetContext.gd", 
	"StaticGameData": "res://src/util/manage/StaticGameData.gd", 
	"MapInfoManage": "res://src/util/manage/MapInfoManage.gd", 
	"RoleInfoManage": "res://src/util/manage/RoleInfoManage.gd", 
	"AroundRoleManage": "res://src/util/manage/AroundRoleManage.gd", 
	"NTeamManage": "res://src/util/manage/NTeamManage.gd", 
	"BagInfoManage": "res://src/util/manage/BagInfoManage.gd", 
	"MailInfoManage": "res://src/util/manage/MailInfoManage.gd", 
	"FriendInfoManage": "res://src/util/manage/FriendInfoManage.gd", 
	"ChatInfoManage": "res://src/util/manage/ChatInfoManage.gd", 
	"ShopInfoManage": "res://src/util/manage/ShopInfoManage.gd", 
	"PetInfoManage": "res://src/util/manage/PetInfoManage.gd", 
	"RichTextContentFormat": "res://src/util/common/RichTextContentFormat.gd", 
	"ServerPageManage": "res://src/util/manage/ServerPageManage.gd", 
	"DialogManage": "res://src/util/manage/DialogManage.gd", 
	"CombatManage": "res://src/util/manage/CombatManage.gd", 
	"TaskInfoManage": "res://src/util/manage/TaskInfoManage.gd", 
	"CommandManage": "res://src/util/manage/CommandManage.gd", 
	"LocalInfo": "res://src/util/common/LocalInfo.gd", 
	"FactionInfoManage": "res://src/util/manage/FactionInfoManage.gd", 
	"MemoManage": "res://src/util/manage/MemoManage.gd", 
	"TBBattleManage": "res://src/util/manage/TBBttleManage.gd", 
	"DicStaticGameData": "res://src/util/manage/DicStaticGameData.gd", 
	"GoodAndEvilManage": "res://src/util/manage/GoodAndEvilManage.gd", 
	"TradeInfoManage": "res://src/util/manage/TradeInfoManage.gd", 
	"RankingInfoManage": "res://src/util/manage/RankingInfoManage.gd", 
	"ActivityDataManage": "res://src/util/manage/ActivityDataManage.gd", 
	"MasterDataManage": "res://src/util/manage/MasterDataManage.gd", 
	"RingDataManage": "res://src/util/manage/RingDataManage.gd", 
	"CalculationManage": "res://src/util/manage/CalculationManage.gd", 
	"AssetsManage": "res://src/util/manage/AssetsManage.gd", 
}

var compoments = {
	
}


func init_start():
	log_info("compoments 加载完成！！！")
	var tx = Global.get("TXUtils")



	check_version()



func check_version():
	var flag_name = false
	for prop in Global.get_property_list():
		if prop["name"] == "start_version":
			flag_name = true
	if flag_name:
		
		Global.log_info(str(prefix, "启动器版本", Global.start_version))
		if Global.start_version == "1.1":
			
			Global.get("RoleInfoManage").hot_role_op["start_update"] = false
			return false
		else:
			
			Global.get("RoleInfoManage").hot_role_op["start_update"] = true
			Global.log_info(str(prefix, "需要更新启动器版本"))
			pass
	else:
		Global.get("RoleInfoManage").hot_role_op["start_update"] = true
		Global.log_info(str(prefix, "需要更新启动器版本"))
		
	return true


func _ready() -> void :
	init_compoments()
	init_start()


func init_compoments():
	for key in compoments_path.keys():
		if not compoments.has(key):
			compoments[key] = load(compoments_path[key]).new()
	


func get(ns: String):
	if compoments.has(ns):
		return compoments[ns];
	else:
		print(prefix, "组件：", ns, "不存在，请检查组件名称是否错误")
		return null


func add_compoments(coms_path: Dictionary):
	for key in coms_path.keys():
		if not compoments_path.has(key):
			compoments_path[key] = coms_path[key];
	init_compoments()


func get_compoments():
	return compoments
func get_compoments_path():
	return compoments_path
func get_main_tscn_path():
	return "res://src/tscn/scence/ScenceManage.tscn"

func log_info(msg):
	return

func get_nodes_in_group(node_name: String) -> Array:
	return get_tree().get_nodes_in_group(node_name)


