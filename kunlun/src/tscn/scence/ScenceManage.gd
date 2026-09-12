extends Node2D

onready var current_scence = $CurrentScence
onready var current_ui = $ScrenceUi
onready var request = $HTTPRequest

var assets_version_path = "user://assets_version.json"
var assets_dic = {}

var NetContext

func _ready() -> void :
	NetContext = Global.get("NetContext")
	request.connect("request_completed", self, "_on_request_completed")
	set_process_unhandled_input(true)
	if NetContext.is_multiended:
		init_server_list()
	else:
		add_child(Global.get("NetContext"))
	
	
	if Global.get("RoleInfoManage").hot_role_op["start_update"]:
		Global.log_info(str("更新"))

	else:
		Global.log_info(str("无更新"))
func u_exit():
	Global.get_tree().quit()




func _on_HeartTimer_timeout():
	if NetContext.is_connected:
		NetContext._on_heart()
		

func init_server_list():
	assets_dic = _private_get_local_version()
	if request.request(str("http://", assets_dic.ip, "/serverList"), [], true, HTTPClient.METHOD_GET, "") != OK:
		Global.log_info("场景管理器：请求失败")
		add_child(Global.get("NetContext"))
		pass
	else:
		Global.log_info("场景管理器：请求成功")
	

func _private_get_local_version():
	var file = File.new()
	if not file.file_exists(assets_version_path):
		return {"version": "1.0.0"}
	file.open(assets_version_path, File.READ)
	var data = file.get_line()
	file.close()
	return parse_json(data)
	



func _on_request_completed(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray) -> void :
	if response_code != 200:
		
		pass
	var json = JSON.parse(body.get_string_from_utf8()).result
	NetContext.websocket_urls.clear()
	if json.has("data"):
		for item in json["data"]:
			
			var ww = str("ws://", item["address"], ":", item["port"], "/", item["serverName"])
			NetContext.websocket_urls.append(ww)
	
	
	
	add_child(Global.get("NetContext"))
