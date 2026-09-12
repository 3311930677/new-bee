extends Control

export (int) var timeout = 20

onready var uname = $Background / Background2 / VBoxContainer / Control / Username
onready var pword1 = $Background / Background2 / VBoxContainer / Control2 / Password1
onready var pword2 = $Background / Background2 / VBoxContainer / Control3 / Password2
onready var email = $Background / Background2 / VBoxContainer / Control4 / Email
onready var code = $Background / Background2 / VBoxContainer / Control5 / Code
onready var get_code_btn = $Background / Background2 / VBoxContainer / Control5 / GetCode
onready var tips = $Background / Background2 / Tips
onready var timer = $Timer

var is_get_code = false
var private_delta = 0.0


var ScreenUtils
var NetContext

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	NetContext = Global.get("NetContext")
	timer.wait_time = timeout
	
	NetContext.set_handler("RegisterController", "getMailCode", self, "_on_mail_code_result")
	NetContext.set_handler("RegisterController", "register", self, "_on_register_role_result")
	pass

func _process(delta: float) -> void :
	if is_get_code:
		private_delta += delta
		if private_delta >= 1.0:
			get_code_btn.text = str(int(timer.time_left))
			private_delta = 0.0
	pass


func _on_Ok_pressed() -> void :
	var pd1 = pword1.text
	var pd2 = pword2.text
	if pd1 != pd2:
		ScreenUtils.show_message("两次密码不匹配")
		return
	if pd1.length() < 6:
		ScreenUtils.show_message("密码长度小于6位")
		return
	if uname.text.length() < 6:
		ScreenUtils.show_message("用户名长度小于6")
		return
	
	if not uname.text.is_valid_identifier():
		ScreenUtils.show_message("用户名中包含无效字符")
		return
	if not pd1.is_valid_identifier():
		ScreenUtils.show_message("密码只允许字母，数字，下划线")
		return
	
	var request_data = {
		"username": uname.text, 
		"password": pd1, 
		"email": email.text, 
		"code": code.text
	}
	NetContext.request_gate("RegisterController", "register", request_data, true)
	


func _on_GetCode_pressed() -> void :
	if email.text.empty():
		ScreenUtils.show_message("邮箱不能为空！")
		return
	NetContext.request_gate("RegisterController", "getMailCode", {"email": email.text}, true)


func _on_Timer_timeout() -> void :
	is_get_code = false
	timer.wait_time = timeout
	get_code_btn.disabled = false
	get_code_btn.text = "获取验证码"
	pass


func _on_Cance_pressed() -> void :
	queue_free()


func _on_mail_code_result(data):
	ScreenUtils.show_message("验证码发送成功")
	timer.start()
	get_code_btn.disabled = true
	is_get_code = true
	get_code_btn.disabled = true
	tips.text = "验证码发送成功！！"
	ScreenUtils.hide_please_wait()
	Global.get("NetContext").List_wait_id.clear()

func _on_register_role_result(data):
	ScreenUtils.show_message("账号注册成功", self, "_change_login_ui", "_change_login_ui")
	

func _change_login_ui():
	ScreenUtils.hide_please_wait()
	Global.get("NetContext").List_wait_id.clear()
	queue_free()


func _on_Username_text_changed(new_text: String) -> void :
	
	pass
