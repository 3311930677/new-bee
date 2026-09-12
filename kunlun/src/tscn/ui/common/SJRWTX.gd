extends Node2D

signal animtaion_sjrw_finished_
signal animtaion_sjrw_start_

var anim_player: AnimationPlayer
var TXUtils

func _ready() -> void :
	TXUtils = Global.get("TXUtils")
	var sjrw_tx = TXUtils.get_sj_rw_tx()
	add_child(sjrw_tx)
	sjrw_tx.connect("animation_started", self, "_on_animation_started")
	sjrw_tx.connect("animation_finished", self, "_on_animation_finished")
	anim_player = sjrw_tx

func _on_animation_finished(anim_name: String):
	emit_signal("animtaion_sjrw_finished_")
	queue_free()


func _on_animation_started(anim_name: String):
	emit_signal("animtaion_sjrw_start_")


func _set_center():
	_set_position(Vector2(175, 200))


func _set_position(v2):
	position = v2
	pass



func play_anim(anim_name):
	anim_player.play(anim_name)
	pass
