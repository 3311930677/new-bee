extends ScrollContainer


signal scroll_end

export (bool) var is_hor_auto_scroll = false
export (bool) var is_auto_expand = true
export (float) var scroll_speed = 0.2
var isDrag = false
var startPos = 0

var scroll_index = 0.0

func _ready() -> void :
	connect("gui_input", self, "m_gui_input")

func _process(delta: float) -> void :
	
	if is_hor_auto_scroll and get_h_scrollbar().max_value > rect_size.x + 2:
		set_h_scroll(scroll_index)
		scroll_index += scroll_speed
		if scroll_index >= get_h_scrollbar().max_value - rect_size.x + 5:
			scroll_index = - 5


func m_gui_input(event):
	if event is InputEventMouseButton and event.is_pressed():
		isDrag = true
		startPos = event.position.y
		pass
	if event is InputEventMouseButton and not event.is_pressed():
		isDrag = false
		startPos = 0
		pass
	var offset = event.position.y - startPos
	if isDrag:
		self.set_v_scroll(self.get_v_scroll() - offset)
		startPos = event.position.y
	
	
	if event is InputEventMouseButton and event.is_pressed():
		var current_va = round(get_v_scrollbar().value + rect_size.y)
		if current_va >= get_v_scrollbar().max_value:

			emit_signal("scroll_end")
