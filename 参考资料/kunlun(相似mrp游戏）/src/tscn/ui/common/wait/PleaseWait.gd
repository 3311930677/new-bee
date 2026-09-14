extends Control

export (String) var txt = "请稍后"
export (float) var time_speed = 0.2

var strs = [
	"", 
	".", 
	"..", 
	"..."
]

var index = 0
var current_time = 0.0
func _ready() -> void :
	m_hide()
	pass
	

func _process(delta: float) -> void :
	current_time += delta
	if current_time >= time_speed:
		$Panel / Label.text = txt + strs[index % strs.size()]
		index += 1
		current_time = 0.0
	pass


func _input(event: InputEvent) -> void :
	get_tree().set_input_as_handled()
	pass

func m_show(msg: String = "请稍后"):
	show()
	txt = msg
	set_process(true)
	set_process_input(true)
	
func m_hide():
	hide()
	set_process(false)
	set_process_input(false)
