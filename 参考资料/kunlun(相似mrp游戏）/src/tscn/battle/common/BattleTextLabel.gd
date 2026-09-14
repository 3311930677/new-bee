extends Control





onready var label = $Label
onready var time = $Timer

var purple = Color(1, 0, 1, 1)
var red = Color(1, 0, 0, 1)
var green = Color(0, 1, 0, 1)
var model = 0

func _ready() -> void :
	if model == 0:
		label["custom_colors/font_color"] = purple
	elif model == 1:
		label["custom_colors/font_color"] = red
	else:
		label["custom_colors/font_color"] = green
	time.start();
	rect_scale = Vector2(0.5, 0.5)

func set_m_text(s):
	$Label.text = s;
	$RichTextLabel.clear()

func set_bbcode_txt(bb_txt):
	$Label.text = ""
	$RichTextLabel.clear()
	$RichTextLabel.append_bbcode(bb_txt)

func set_m_color_model(model = 0):
	self.model = model


func _on_Timer_timeout() -> void :
	queue_free()
