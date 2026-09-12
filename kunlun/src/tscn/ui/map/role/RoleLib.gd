extends Panel

var ScreenUtils
var RoleInfoManage
func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	RoleInfoManage = Global.get("RoleInfoManage")
	RoleInfoManage.connect("role_info_result", self, "_on_role_info_result")
	

func _on_role_info_result(data):
	pass
