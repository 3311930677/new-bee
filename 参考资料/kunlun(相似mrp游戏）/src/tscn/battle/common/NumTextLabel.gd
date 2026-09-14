extends Control

const prefix = "NumTextLabel"

var hurt_num_temp = "res://src/tscn/ui/battle/res/num/hurt%s.tres"
var jia_hp_temp = "res://src/tscn/ui/battle/res/num/jiahp%s.tres"
var mp_temp = "res://src/tscn/ui/battle/res/num/lan%s.tres"

var states = [
	load("res://src/tscn/ui/battle/res/num/hurtbj.tres"), 
	load("res://src/tscn/ui/battle/res/num/jiahpbj.tres"), 
	load("res://src/tscn/ui/battle/res/num/sidestep.tres")
]


var mode = 0
var number = 0
var is_b = false

var velocity = Vector2(0, 45)
var gravity = Vector2(0, - 1.2)
var mass = 150

func _ready() -> void :
	set_num_text(number, mode, is_b)
	$Tween.interpolate_property(self, "modulate", 
	Color(modulate.r, modulate.g, modulate.b, modulate.a), 
	Color(modulate.r, modulate.g, modulate.b, 0), 
	0.3, Tween.TRANS_LINEAR, Tween.EASE_OUT, 0.5)
	$Tween.start()
	pass

func set_num_data(num, mod, is_bj):
	number = num
	mode = mod
	is_b = is_bj
	pass

func _process(delta: float) -> void :
	velocity += gravity * mass * delta
	rect_position += velocity * delta
	pass




func set_num_text(num, mod, is_bj):
	private_clear_box()
	if num == null:
		$HBoxContainer.add_child(private_get_state(3))
		
		return
	
	if num < 0:
		$HBoxContainer.add_child(private_get_tex("-", mod))
	else:
		$HBoxContainer.add_child(private_get_tex("+", mod))
	num = abs(int(num))
	for c in str(num):
		$HBoxContainer.add_child(private_get_tex(c, mod))
	
	if mod == 2: return
	
	if is_bj:
		$state.texture = private_get_state(mod).texture


func private_get_tex(st, mod):
	var tex = TextureRect.new()
	tex.rect_min_size = Vector2(10, 16)
	tex.expand = true
	if mod == 0:
		tex.texture = load(hurt_num_temp % str(st))
	elif mod == 1:
		tex.texture = load(jia_hp_temp % str(st))
	elif mod == 2:
		tex.texture = load(mp_temp % str(st))
	return tex


func private_get_state(mod):
	var tex = TextureRect.new()
	tex.rect_min_size = Vector2(25, 16)
	tex.expand = true
	if mod == 3:
		tex.texture = states[mod - 1]
	else:
		tex.texture = states[mod]
	return tex
func private_clear_box():
	for b in $HBoxContainer.get_children():
		b.queue_free()


func _on_Tween_tween_all_completed() -> void :
	queue_free()
	pass
