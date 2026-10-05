extends Node
## Real focused-key events must reveal results without charging an extra summon.
var failures := 0
var checks := 0

func _check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("SUMMON_UI: "+message)

func _frames() -> void:
	for i in 5: await get_tree().process_frame

func _enter() -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = down
		get_viewport().push_input(event,true)
		await get_tree().process_frame
	await _frames()

func _named_action(root: Node,text: String) -> Control:
	for child in root.get_children():
		if child is Label and child.text==text:
			var parent := child.get_parent()
			while parent!=null:
				if parent is Control and parent.focus_mode==Control.FOCUS_ALL: return parent
				parent=parent.get_parent()
		var found := _named_action(child,text)
		if found!=null: return found
	return null

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_summon_ui.json"
	G._init_state_defaults()
	G.save_locked = false
	G.set_meta("ui_review_mode",false)
	G.wallet.soul = 80
	G.items = {}
	var panel := preload("res://src/ui/GachaPanel.gd").new()
	add_child(panel)
	await _frames()
	var single := _named_action(panel,"单次结缘")
	var ten := _named_action(panel,"十连召唤")
	_check(single!=null and ten!=null,"summon actions accept keyboard focus")
	if single==null or ten==null:
		get_tree().quit(1)
		return
	_check(single.size.y>=44 and ten.size.y>=44 and panel._free_btn.size.y>=44,"all summon actions have usable touch targets")
	ten.grab_focus()
	await _enter()
	_check(not panel._result.visible and int(G.wallet.soul)==80,"insufficient tenfold does not settle or display success")
	_check(not panel._hint.text.is_empty(),"failed summon has a visible reason")
	G.wallet.soul = 1000
	panel._refresh_top()
	single.grab_focus()
	await _enter()
	_check(panel._result.visible and panel._arriving,"Enter begins the real summon ceremony")
	_check(int(G.wallet.soul)==920,"single summon charges exactly once")
	_check(get_viewport().gui_get_focus_owner()==panel._flip_all_btn,"result focus moves to the reveal action")
	_check(panel._again_btn.focus_mode==Control.FOCUS_NONE,"repeat is not focusable while results are arriving")
	await _enter()
	await get_tree().create_timer(.9).timeout
	await _frames()
	_check(int(G.wallet.soul)==920,"revealing from the keyboard never charges another summon")
	_check(panel._can_repeat(),"revealing completes before repeat becomes available")
	_check(get_viewport().gui_get_focus_owner()==panel._again_btn,"finished reveal selects the repeat action")
	G.wallet.soul = 0
	await _enter()
	_check(int(G.wallet.soul)==0 and not panel._arriving,"unaffordable repeat leaves the settled result intact")
	var close_count := {"n":0}
	panel.closed.connect(func(): close_count.n+=1)
	var back := _named_action(panel._result,"返回")
	_check(back!=null,"results expose a focused return action")
	if back!=null:
		back.grab_focus()
		await _enter()
		_check(close_count.n==1,"Enter returns from the result layer")
	panel.queue_free()
	await _frames()
	print("SUMMON_UI_%s checks=%d failures=%d" % ["OK" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)
