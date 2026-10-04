extends Node
var fails:=0
func check(ok:bool,line:String)->void:
	if not ok:
		fails+=1
		push_error("FAIL: "+line)
func find_button(root:Node,label:String)->Control:
	if root is Label and root.text.replace(" ","")==label.replace(" ",""):return root.get_parent() as Control
	for child in root.get_children():
		var found:=find_button(child,label)
		if found!=null:return found
	return null
func click(control:Control)->void:
	var e:=InputEventMouseButton.new()
	e.button_index=MOUSE_BUTTON_LEFT
	e.pressed=true
	control.gui_input.emit(e)
func _ready()->void:
	G.SAVE_PATH="res://tools/_logs/save_verify_camp_gathering.json"
	G._init_state_defaults()
	G.save_locked=false
	var home:=preload("res://src/ui/GameHome.tscn").instantiate()
	add_child(home)
	await get_tree().process_frame
	check(find_button(home,"归路小聚")==null,"未完成邀约不会提前出现小聚")
	home.queue_free()
	await get_tree().process_frame
	G.act1_state()["side_quests"]={"a4_rel_nighttable":{"status":QuestService.SIDE_DONE}}
	home=preload("res://src/ui/GameHome.tscn").instantiate()
	add_child(home)
	await get_tree().process_frame
	var entry:=find_button(home,"归路小聚")
	check(entry!=null,"已交付邀约显示营帐入口")
	var before:=JSON.stringify({"prog":G.prog,"items":G.items,"wallet":G.wallet})
	if entry!=null:click(entry)
	await get_tree().process_frame
	check(home._gathering!=null,"实际按钮打开三城小聚")
	if home._gathering!=null:
		var panel:Control=home._gathering
		var actors:=0
		for child in panel.get_children():
			if child.get_meta("gathering_actor",false):actors+=1
		check(actors==3,"场景中有三位旧识")
		for story in panel.stories:
			var button:=find_button(panel,String(story.speaker)+" · "+String(story.title))
			check(button!=null,"三位都能点选")
			if button!=null:click(button)
			check(String(story.text) in panel.page.text,"点选后显示对应完整故事")
		check(panel.seen.size()==3,"故事顺序不漏掉任何一位")
		click(find_button(panel,"回到营帐"))
	check(home._gathering==null and not home._home_content_hidden,"返回后恢复营帐操作")
	home._open_gathering()
	await get_tree().process_frame
	check(home._close_overlay_with_escape() and home._gathering==null and home._settings==null,"营帐返回键关闭小聚且不打开背后设置")
	check(JSON.stringify({"prog":G.prog,"items":G.items,"wallet":G.wallet})==before,"重看小聚不发重复报酬、不改任务")
	home.queue_free()
	await get_tree().process_frame
	print("CAMP_GATHERING_OK" if fails==0 else "CAMP_GATHERING_FAIL fails=%d"%fails)
	get_tree().quit(0 if fails==0 else 1)
