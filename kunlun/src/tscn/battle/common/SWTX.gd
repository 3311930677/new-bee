extends Node2D

signal animtaion_sw_finished_
signal animtaion_sw_start_

var anim_player: AnimationPlayer
var TXUtils
var flip = false

func _ready() -> void :
	TXUtils = Global.get("TXUtils")
	var sw_tx = TXUtils.get_sw_tx()
	add_child(sw_tx)
	sw_tx.connect("animation_started", self, "_on_animation_started")
	sw_tx.connect("animation_finished", self, "_on_animation_finished")
	anim_player = sw_tx
	pass



func hide_m():
	hide()
	$Sprite.hide()
	anim_player.stop()
	if (flip):
		$Sprite.flip_h = true
	else:
		$Sprite.flip_h = false

func start_m():
	show()
	$Sprite.show()
	if (flip):
		$Sprite.flip_h = true
	else:
		$Sprite.flip_h = false
	anim_player.play("0")
	pass


func fliph():
	$Sprite.flip_h = true
	flip = true
	pass

func _on_animation_started(anim_name: String) -> void :
	if int(anim_name) == 0:
		emit_signal("animtaion_sw_start_")
	pass

func _on_animation_finished(anim_name: String) -> void :
	if int(anim_name) == 0:
		anim_player.play("1")
		
		emit_signal("animtaion_sw_finished_")
