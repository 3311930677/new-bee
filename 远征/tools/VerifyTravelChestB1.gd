extends Node
const UI := preload("res://src/ui/TravelChestUI.gd")
var OUT := "res://shots/travel_chest_b1_20261009/"
var page: Control
var failures := 0
var checks := 0
var capture := false
func check(ok: bool, words: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("B1_FAIL: "+words)
func click(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.pressed = down
		event.button_index = MOUSE_BUTTON_LEFT
		get_viewport().push_input(event,true)
		await get_tree().process_frame
func shot(file: String) -> void:
	for i in 3: await get_tree().process_frame
	if not capture: return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(OUT+file+".png")==OK,"截图保存 "+file)
	preload("res://tools/UITextAudit.gd").write(page,OUT+file+".text.json")
func drop() -> void:
	page.queue_free()
	await get_tree().process_frame
func inspect(safe: Rect2) -> void:
	var view: Control = page._chest_view
	var controls: Array[Control] = [view._avatar,view._settings,view._quest,view._hero]
	for entry in page._wallet_labels: controls.append(entry.button)
	for entry in view._rail: controls.append(entry)
	for entry in view._nav: controls.append(entry)
	for i in controls.size():
		check(safe.encloses(controls[i].get_global_rect()),"安全区包含 "+controls[i].name)
		check(controls[i].size.x>=44 and controls[i].size.y>=44,"热区不小于44 "+controls[i].name)
		for j in range(i+1,controls.size()): check(not controls[i].get_global_rect().intersects(controls[j].get_global_rect()),"热区无重叠 "+controls[i].name+"/"+controls[j].name)
	check(page._anim.scale==Vector2(2,2),"角色整数倍率")
	check(is_equal_approx(page._anim.position.y+118,view._hero.position.y-56),"角色脚底与主行动关系固定")
	check(view._hero.size.y==72,"主行动高72")
	check(view._nav[0].selected==false,"营帐不伪造底栏选中态")
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir=res://shots/"):OUT=arg.trim_prefix("--out-dir=").trim_suffix("/")+"/"
	capture = "--capture" in OS.get_cmdline_user_args()
	G.SAVE_PATH = OUT+"isolated_save.json"
	G.set_meta("ui_review_mode",true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for height in [800,1067]:
		get_window().size = Vector2i(480,height)
		await get_tree().process_frame
		G._init_state_defaults()
		G.save_locked = false
		G.selected_role = "zs"
		G.player_name = "行旅人"
		G.prog.level = 12
		G.prog.exp = 340
		G.wallet = {"gold":12800,"expedition":240,"soul":36,"honor":900}
		page = preload("res://src/ui/GameHome.tscn").instantiate()
		add_child(page)
		await get_tree().process_frame
		var hub: Control = page._chest_view
		inspect(page.get_viewport_rect())
		check(hub._rail.size()==5,"五个旅签槽始终可发现")
		check(hub._rail[4].locked,"实际未完成支线的小聚为锁定态")
		check(UI.texture("hero_normal")!=null and UI.texture("tray_rim")!=null,"实用美术资产而非临时平涂")
		await shot("home_%d"%height)
		if height==800:
			G.prog.level=1
			G.prog.exp=0
			G.wallet={"gold":0,"expedition":0,"soul":0,"honor":0}
			hub.refresh()
			await shot("home_new_player")
			G.prog.level=12
			G.prog.exp=340
			G.wallet={"gold":12800,"expedition":240,"soul":36,"honor":900}
			G.items["ticket_ten"]=1
			hub.refresh()
			check(hub._rail[2].hint_dot and hub._rail[3].hint_dot,"真实召唤券与荣誉同时产生提醒")
			await shot("home_multiple_badges")
			G.items.erase("ticket_ten")
			hub.refresh()
		await click(hub._rail[4])
		check(page._gathering==null,"未解锁小聚不绕过剧情条件")
		await get_tree().create_timer(1.8).timeout
		await click(page._wallet_labels[0].button)
		check(page._chest_dialog!=null,"实际货币点击打开共享弹窗")
		await shot("currency_modal_%d"%height)
		var esc := InputEventKey.new()
		esc.pressed = true
		esc.keycode = KEY_ESCAPE
		get_viewport().push_input(esc,true)
		await get_tree().process_frame
		check(page._chest_dialog==null and page._settings==null,"ESC只关闭当前弹窗")
		await click(hub._settings)
		check(page._settings!=null,"实际设置入口")
		page._settings.closed.emit()
		await get_tree().process_frame
		for i in hub._nav.size():
			await click(hub._nav[i])
			var panel: Control = page.get(["_worlds","_bag","_growth","_codex"][i])
			check(panel!=null,"实际底栏入口 "+hub._nav[i].text)
			if panel!=null: panel.closed.emit()
			await get_tree().process_frame
		check(hub.content.visible,"关闭浮层恢复营帐")
		G.player_name = "这是一个很长的旅人名字测试"
		G.wallet = {"gold":999999999,"expedition":999999999,"soul":999999999,"honor":999999999}
		page._refresh_wallet()
		for entry in page._wallet_labels: check(entry.label.text=="9.99亿","大货币缩写")
		check(hub._name.text.ends_with("…"),"长昵称省略")
		await shot("home_stress_%d"%height)
		G.quest = {"day":G.today_key(),"offer":["q_clear_forest"],"active":{"q_clear_forest":1},"claimed":[]}
		hub.refresh()
		await get_tree().process_frame
		check(hub._quest.claimable and hub._quest.caption.text=="可交付","真实委托进度可交付提示")
		await shot("home_claimable_%d"%height)
		await click(hub._quest)
		check(page._quests!=null,"任务签打开原有任务窗口")
		if page._quests!=null: page._quests.closed.emit()
		await get_tree().process_frame
		# Use the service state that the original entry condition actually reads.
		var act1 := G.act1_state()
		act1.side_quests["a4_rel_nighttable"] = {"status":QuestService.SIDE_DONE,"progress":99}
		hub.refresh()
		check(not hub._rail[4].locked,"真实支线完成后小聚解锁")
		await shot("home_reunion_%d"%height)
		await click(hub._rail[4])
		check(page._gathering!=null,"解锁入口打开原小聚页面")
		if page._gathering!=null: page._gathering.closed.emit()
		await get_tree().process_frame
		var safe := Rect2(8,44,464,height-78)
		hub.layout(safe)
		await get_tree().process_frame
		inspect(safe)
		await shot("home_safe_%d"%height)
		if hub._compact:
			await click(hub._rail[4])
			check(page._chest_dialog!=null,"短安全区更多抽屉可达")
			await shot("more_drawer_%d"%height)
			if page._chest_dialog!=null: page._close_chest_dialog()
		await drop()
	await catalog()
	print("TRAVEL_CHEST_B1_OK checks=%d"%checks if failures==0 else "TRAVEL_CHEST_B1_FAIL failures=%d checks=%d"%[failures,checks])
	get_tree().quit(0 if failures==0 else 1)
func catalog() -> void:
	get_window().size = Vector2i(480,800)
	await get_tree().process_frame
	page = Control.new()
	page.size = Vector2(480,800)
	add_child(page)
	var tray := UI.Tray.new()
	tray.size = Vector2(480,800)
	page.add_child(tray)
	var title := UI.label("共享组件 · 灯下行箧","title")
	title.position = Vector2(20,20)
	title.size = Vector2(440,36)
	page.add_child(title)
	for i in 6:
		var state := i%3
		var b := UI.action(["主行动","按下","不可用"][state],"primary" if i<3 else "secondary")
		b.position = Vector2(20 if i<3 else 252,72+state*76)
		b.size = Vector2(208,56)
		page.add_child(b)
		if state==1:
			b.toggle_mode=true
			b.set_pressed_no_signal(true)
		if state==2: b.disabled=true
	var tabs := HBoxContainer.new()
	tabs.position=Vector2(20,320)
	tabs.size=Vector2(440,44)
	page.add_child(tabs)
	for i in 3:
		var b := UI.action(["装备","材料","宝石"][i],"tab")
		b.selected=i==0
		b.custom_minimum_size=Vector2(142,44)
		tabs.add_child(b)
	var slip := UI.QuestSlip.new()
	slip.position=Vector2(20,390)
	slip.size=Vector2(248,68)
	slip.goal.text="沿路牌前往枫林古道"
	page.add_child(slip)
	var back := UI.action("","back","back")
	back.position=Vector2(396,396)
	back.size=Vector2(44,44)
	page.add_child(back)
	var hero := UI.action("继续旅程","hero","journey")
	hero.position=Vector2(40,530)
	hero.size=Vector2(400,72)
	hero.subtitle.text="昭元边城"
	page.add_child(hero)
	hero.grab_focus()
	await shot("components")
	UI.toast(page,"行囊已整备","success")
	await shot("components_toast")
	var dialog := UI.Modal.new()
	dialog.heading="行旅提示"
	dialog.lines=["箱沿、内格、文字与操作共用一套规范。"]
	dialog.choices=["确认"]
	page.add_child(dialog)
	await shot("components_modal")
	await drop()
