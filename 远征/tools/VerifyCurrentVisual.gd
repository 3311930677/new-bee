extends Node
## Exercise the responsive layouts and real pointer events changed by this audit.
const Page:=preload("res://src/ui/ChestPageUI.gd")
const OUT:="res://shots/visual_audit_20261027/acceptance/"
var checks:=0
var failures:Array[String]=[]
var current:Control

func check(ok:bool,note:String)->void:
	checks+=1
	if not ok:
		failures.append(note)
		push_error("CURRENT_VISUAL_FAIL "+note)

func frames(n:=8)->void:
	for i in n:await get_tree().process_frame

func attach(node:Control)->void:
	if is_instance_valid(current):
		current.queue_free()
		await frames(4)
	current=node
	add_child(current)
	await frames(12)

func touch(at:Vector2,pressed:bool)->void:
	var e:=InputEventScreenTouch.new()
	e.index=0;e.position=at;e.pressed=pressed
	get_viewport().push_input(e,true)
	await frames(1)

func _ready()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	G.SAVE_PATH=ProjectSettings.globalize_path(OUT+"isolated_save.json")
	G._init_state_defaults();G.save_locked=false
	G.set_meta("ui_review_mode",true)
	G.gm_unlocked=true;G.gm_grant_all();G.gm_unlock_all_features()
	G.player_name="沈舟";G.selected_role="zs";G.prog.level=35
	G.prog.tips_seen={"deploy":true,"pet_raise":true}
	G.ensure_starter_equip(true);G.ensure_starter_pets()
	get_window().unresizable=false
	get_window().min_size=Vector2i(300,480)
	for dimensions in [Vector2i(320,640),Vector2i(480,640),Vector2i(480,800),Vector2i(480,1067)]:
		get_window().size=dimensions;get_window().content_scale_size=dimensions
		await frames()
		await attach(preload("res://src/ui/CreateRole.tscn").instantiate())
		var role=current
		check(role._chest.shell.scroll.get_global_rect().encloses(role._name_edit.get_global_rect()),"required nickname visible at "+str(dimensions))
		for index in G.roles.size():
			role._switch_role(index,true)
			await get_tree().create_timer(.35).timeout
			var sprite:AnimatedSprite2D=role._anim
			var frame:=sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
			var body:Rect2=sprite.get_global_transform()*Rect2(-frame.get_size()*.5,frame.get_size())
			check(role._chest.shell.stage.get_global_rect().grow(1).encloses(body),"role preview stays in stage after switch "+str(index)+" "+str(dimensions))
		var inset:=Rect2(8,32,dimensions.x-16,dimensions.y-52)
		G.set_meta("test_safe_rect",inset)
		await get_tree().create_timer(.2).timeout
		await frames(3)
		check(inset.encloses(role._chest._confirm.get_global_rect()),"open role form follows changed system insets")
		G.remove_meta("test_safe_rect")
		await attach(QuestPanel.new())
		var quest=current as QuestPanel
		for card in quest._list.get_children():
			if not card.has_meta("info_row"):continue
			var info:Control=card.get_meta("info_row").get_child(1)
			check(info.size.x>=180,"quest text column readable "+str(dimensions))
		G.set_meta("test_safe_rect",inset)
		await get_tree().create_timer(.2).timeout
		await frames(3)
		check(inset.encloses(quest._panel.get_global_rect()),"open quest journal follows changed system insets")
		G.remove_meta("test_safe_rect")
		await attach(EquipPanel.new())
		if dimensions.y==1067:check(current._view._scroll.size.y>=400,"long equipment screen gives extra space to workshop")
		G.set_meta("test_safe_rect",inset)
		await get_tree().create_timer(.2).timeout
		await frames(3)
		check(inset.encloses(current._view._actions.get_global_rect()),"open workshop follows changed system insets")
		G.remove_meta("test_safe_rect")
		await attach(ArcheryPanel.new())
		current.set_process(false)
		for i in 60:
			current._process(.1)
			var p:Vector2=current._target_pos
			check(p.x>=68 and p.x<=current._range.size.x-68,"moving archery target within phone range "+str(dimensions))
		await popup(dimensions)
	await gestures()
	if is_instance_valid(current):current.queue_free()
	await frames(4)
	Audio.stop_bgm();Audio.set_suspended(true)
	var report:=FileAccess.open(OUT+"results.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"));report.close()
	print("CURRENT_VISUAL_OK checks=%d failures=%d"%[checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func popup(dimensions:Vector2i)->void:
	await attach(Control.new())
	current.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer:=G.show_info_popup(current,"出征教学与长文阅读",DeployPanel.TIPS,current)
	await frames()
	var paper:=layer.find_child("InfoPopupPaper",true,false) as Control
	check(get_viewport().get_visible_rect().encloses(paper.get_global_rect()),"tutorial paper fits "+str(dimensions))
	var deck:=layer.find_child("ReadingPages",true,false) as PageDeck
	check(deck!=null and deck.page_count>1,"long tutorial retains all reading pages")
	if deck!=null:
		deck.next_page();await frames(24)
		check(deck.current==1,"tutorial can reach second page")
	var safe:=Rect2(8,32,dimensions.x-16,dimensions.y-52)
	G.set_meta("test_safe_rect",safe)
	await get_tree().create_timer(.2).timeout
	await frames(4)
	check(safe.grow(1).encloses(paper.get_global_rect()),"open tutorial follows safe inset changes")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+"tutorial_%dx%d.png"%[dimensions.x,dimensions.y])
	G.remove_meta("test_safe_rect")
	G.close_info_popup(layer)
	await frames(4)
	check(not G.ui_blocked,"closing tutorial releases modal input")

func gestures()->void:
	get_window().size=Vector2i(320,640);get_window().content_scale_size=Vector2i(320,640)
	await attach(Control.new())
	current.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll:=Page.scroll()
	scroll.position=Vector2(20,100);scroll.size=Vector2(280,300)
	current.add_child(scroll)
	var list:=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var presses:={"count":0}
	for i in 20:
		var b:=Page.UI.action("可点击条目 %d"%i)
		b.custom_minimum_size.y=56
		b.pressed.connect(func():presses.count+=1)
		list.add_child(b)
	await frames()
	var at:Vector2=list.get_child(2).get_global_rect().get_center()
	await touch(at,true)
	for i in 5:
		var e:=InputEventScreenDrag.new()
		e.index=0;e.position=at-Vector2(0,20*(i+1));e.relative=Vector2(0,-20)
		get_viewport().push_input(e,true)
		await frames(1)
	await touch(at-Vector2(0,100),false)
	check(scroll.scroll_vertical>=90,"shared page scroll follows a drag started on a button")
	check(presses.count==0,"scrolling does not activate the touched action")
	scroll._velocity=0;scroll.scroll_vertical=0
	await frames(15)
	at=list.get_child(0).get_global_rect().get_center()
	await touch(at,true);await touch(at,false)
	check(presses.count==1,"a normal tap still activates the action once")
