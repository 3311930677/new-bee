extends Node
class_name NetContext

const prefix = "NextContext->"


export var websocket_url = "ws://8.137.13.144:10099/gate_s1"






















var websocket_urls = [
	"ws://127.0.0.1:8000/gate_s1", 
	"ws://127.0.0.1:8000/gate_s2", 
]


var is_multiended = false

var _client = WebSocketClient.new()

var handlerMap: Dictionary

var service_remote = "ServiceRemote"
var service_method = "requestForward"

var fight_remote = "FightRemote"
var fight_method = "requestForward"

var is_connected = false

var request_id = 1
var service_url_map: Dictionary = {}

var List_wait_id = []



func set_handler(r: String, m: String, node: Node, fun: String, before_fun: String = "", after_fun: String = ""):
	var url = r + ":" + m
	handlerMap[url] = [node, fun, before_fun, after_fun]


func sendData(r: String, m: String, data: Dictionary, wait_flag = false):
	var dic = {}
	var url = r + ":" + m
	
	dic["remote"] = r
	dic["method"] = m
	dic["id"] = request_id
	request_id += 1
	
	
	dic["data"] = data
	Global.log_info(str(prefix, "请求", dic))
	var yu = to_json(dic).to_utf8()
	var pool = encrypt(to_json(dic).to_utf8())
	var s = encrypt(pool)

	_client.get_peer(1).put_packet(pool)
	
	if (wait_flag):
		List_wait_id.append(request_id - 1)
		Global.get("ScreenUtils").show_please_wait()



func request_service(r: String, m: String, data: Dictionary, wait_flag = false):
	data["remote"] = r
	data["method"] = m
	
	
	service_url_map[request_id] = r + ":" + m;

	sendData(service_remote, service_method, data, wait_flag)
	

func request_fight(r: String, m: String, data: Dictionary, wait_flag = false):
	data["remote"] = r
	data["method"] = m
	
	
	service_url_map[request_id] = r + ":" + m;
	
	sendData(fight_remote, fight_method, data, wait_flag)
	

func request_gate(r: String, m: String, data: Dictionary, wait_flag = false):
	sendData(r, m, data, wait_flag)


func game_close():
	Global.get_tree().quit()
	pass

func encrypt(poobytearr):
	var pool_byte_arr = poobytearr
	var password = "Qa/*s+55v./,ajK;[;soxjbd"
	var arr_byte = password.to_utf8()
	var index = pool_byte_arr.size() % 10

	for i in pool_byte_arr.size():
		
		if index >= password.length():
			index = 0
		
		var res = pool_byte_arr[i] ^ arr_byte[index]
		pool_byte_arr[i] = res
		index = index + 1
	return pool_byte_arr

func _ready():
	_client.connect("connection_closed", self, "_closed")
	_client.connect("connection_error", self, "_closed")
	_client.connect("connection_established", self, "_connected")
	_client.connect("server_close_request", self, "_server_close_request")
	_client.connect("data_received", self, "_on_data")
	Global.get("ScreenUtils").show_please_wait("连接服务器中")
	
	randomize()
	var wu = websocket_urls[randi() % websocket_urls.size()]
	
	if not is_multiended: wu = websocket_url
	Global.log_info(str(prefix, websocket_urls))
	Global.log_info(str(prefix, "连接目标：", wu))
	
	var err = _client.connect_to_url(wu)
	
	if err != OK:
		print("Unable to connect")
		set_process(false)

func _closed(was_clean = false):
	Global.log_info(str("网络链接状态：", was_clean))
	_client.get_peer(1).close()
	if not was_clean:
		
		_client.disconnect_from_host()
	Global.log_info(str(prefix, "Next连接失败"))
	Global.get("ScreenUtils").hide_please_wait()
	set_process(false)
	is_connected = false
	Global.get("ScreenUtils").show_message("网络连接失败", self, "game_close", "game_close")
	


func _server_close_request(code, msg):
	print(code)
	print(msg)
	pass
func _connected(proto = ""):
	Global.log_info(str(prefix, "Next连接成功"))
	Global.get("ScreenUtils").hide_please_wait()
	is_connected = true
	




func _on_data():
	
	var pool_byte_arr = _client.get_peer(1).get_packet()
	var sss = encrypt(pool_byte_arr)

	var sourece_data = sss.get_string_from_utf8()
	
	var v = validate_json(sourece_data)
	if v:
		if sourece_data == "pong":
			Global.log_info(str(prefix, "服务心跳回复：", sourece_data))
		else:
			Global.log_info(str(prefix, "json格式无效：", sourece_data))
		return
	var data = parse_json(sourece_data)
	var id = int(data.get("id"))
	if List_wait_id.find(id) != - 1:
		List_wait_id.erase(id)
	if List_wait_id.size() <= 0:
		Global.get("ScreenUtils").hide_please_wait()
	
	if data["code"] != 0:
		Global.get("ScreenUtils").hide_please_wait()
		Global.get("ScreenUtils").show_message(str(data["data"]))
		Global.get("CombatManage").fighting = false
		Global.get("TBBattleManage").current_fighting = false
		Global.get("MapInfoManage").yuguaiing = false
		Global.get("MapInfoManage").probability = 0
		return
	var r = data.get("remote")
	var m = data.get("method")
	
	var url = r + ":" + m
	
	
	
	if r == service_remote and m == service_method:
		url = service_url_map[id]
		service_url_map.erase(id)
		
	
	if r == fight_remote and m == fight_method:
		url = service_url_map[id]
		service_url_map.erase(id)
	
	var handler = handlerMap.get(url)
	if handler != null and is_instance_valid(handler[0]):
		if handler[2] != "":
			handler[0].call(handler[2])
		
		handler[0].call(handler[1], data)
		if handler[3] != "":
			handler[0].call(handler[3])
	else:
		Global.log_info(data)
		Global.log_info(str("[warn]:", "url ", url, "没有对应处理的NetHandler"))

func _process(delta):
	_client.poll()


func _on_heart():
	Global.log_info(str(prefix, "心跳数据包"))
	_client.get_peer(1).put_packet(encrypt("ping".to_utf8()))
	pass
