extends Control

onready var timer = $Timer
onready var left_time = $Time / Label
onready var animtion = $AnimationPlayer
onready var uptimer = $UpTimer

var isCharge = false
var press_count = 0


var level = 3

var ScreenUtils
var NetContext

func set_data(data):
	isCharge = data.get("charge", false)

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	NetContext = Global.get("NetContext")
	NetContext.set_handler("FishActivityRemote", "upload", self, "_on_upload_successed")
	pass

func _process(delta: float) -> void :
	
	if not timer.is_stopped():
		left_time.text = str("倒计时:", int(timer.time_left))


func _on_Ok_pressed() -> void :
	if not uptimer.is_stopped(): return
	press_count += 1
	if press_count == 1:
		animtion.play("start")
		timer.start()
	elif press_count == 2:
		
		animtion.stop()
		timer.stop()
		uptimer.start()
		pass



func _on_Cancle_pressed() -> void :
	queue_free()



func _on_Timer_timeout() -> void :
	_on_Ok_pressed()


func _on_Level1_body_entered(body: Node) -> void :
	if body is KinematicBody2D:
		level = 1


func _on_Level1_body_exited(body: Node) -> void :
	if body is KinematicBody2D:
		level = 2
	pass


func _on_Level2_body_entered(body: Node) -> void :
	if body is KinematicBody2D:
		level = 2


func _on_Level2_body_exited(body: Node) -> void :
	if body is KinematicBody2D:
		level = 3




func _on_UpTimer_timeout() -> void :
	print("当前等级：", level)
	print("charge:", isCharge)
	NetContext.request_service("FishActivityRemote", "upload", {
		"level": level, 
		"charge": isCharge
	}, true)
func _on_upload_successed(data):
	_on_Cancle_pressed();
