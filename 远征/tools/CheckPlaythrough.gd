extends Node
func _ready()->void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=1 or not String(args[0]).begins_with("res://tools/Playthrough"):
		push_error("PLAY_CHECK_FAIL invalid script path")
		get_tree().quit(2)
		return
	var script:=load(String(args[0])) as GDScript
	if script==null or not script.can_instantiate():
		push_error("PLAY_CHECK_FAIL script did not compile")
		get_tree().quit(1)
		return
	print("PLAY_CHECK_OK script="+String(args[0]))
	get_tree().quit(0)
