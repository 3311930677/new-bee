extends Node2D

signal tx_timeout

var animplayer: AnimationPlayer = null
var TXUtils


var play_animation_name = null
func _ready() -> void :
	TXUtils = Global.get("TXUtils")
	animplayer = TXUtils.get_all_txs()
	animplayer.connect("animation_started", self, "_on_animation_started")
	animplayer.connect("animation_finished", self, "_on_animation_finished")
	add_child(animplayer)
	if play_animation_name != null:
		animplayer.play(play_animation_name)
	pass


func play(anim_name):
	if animplayer != null:
		
		if animplayer.has_animation(anim_name):
			animplayer.play(anim_name)
		else:
			animplayer.play("0")


func _on_animation_started(anim_name: String) -> void :
	pass

func _on_animation_finished(anim_name: String) -> void :
	emit_signal("tx_timeout")
	queue_free()
