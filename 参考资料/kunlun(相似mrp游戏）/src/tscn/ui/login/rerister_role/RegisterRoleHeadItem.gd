extends Control

export (int) var index = 0

onready var selected = $SelectBg
onready var head = $Bg / Head
onready var bg = $Bg

signal item_click


var dl_light
var dl_black

var light_head
var black_head

var AssetsManage

func _ready() -> void :
	AssetsManage = Global.get("AssetsManage")
	dl_light = load(str(AssetsManage.get_prefix(), "assets/res/dl_0.png"))
	dl_black = load(str(AssetsManage.get_prefix(), "assets/res/dl_0_f.png"))
	
	if index > 0:
		light_head = load(str(str(AssetsManage.get_prefix(), "assets/res/%d.png") % index))
		black_head = load(str(str(AssetsManage.get_prefix(), "assets/res/%d_f.png") % index))
	
	if index != 0: unchecked()
	else: checked()


func checked():
	selected.show()
	bg.texture = dl_light
	head.texture = light_head
	emit_signal("item_click", self)
	
func unchecked():
	selected.hide()
	bg.texture = dl_black
	head.texture = black_head

func _on_TextureButton_pressed() -> void :
	var heads_arr = Global.get_nodes_in_group("register_role_head_item")
	for head in heads_arr:
		head.unchecked()
	checked()


func set_display():
	$TextureButton.hide()
	selected.show()
	bg.texture = dl_light
	head.texture = light_head

func set_show_index(ind):
	light_head = load(str(str(AssetsManage.get_prefix(), "assets/res/%d.png") % ind))
	black_head = load(str(str(AssetsManage.get_prefix(), "assets/res/%d_f.png") % ind))
	var ss = Global.get("StaticGameData")
	checked()
