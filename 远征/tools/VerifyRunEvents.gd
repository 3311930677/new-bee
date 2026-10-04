extends Node
const Events := preload("res://src/run/RunEvents.gd")
var fails := 0
func check(ok: bool, line: String) -> void:
	if not ok:
		fails+=1
		push_error("FAIL: "+line)
func button(root: Node, text: String) -> Control:
	if root == null: return null
	if root is Button and String(root.text).replace(" ","")==text.replace(" ",""):return root as Control
	for c in root.get_children():
		if c is Label and String(c.text).replace(" ","")==text.replace(" ",""): return c.get_parent() as Control
		var found := button(c,text)
		if found!=null:return found
	return null
func click(c: Control) -> void:
	if c==null:return
	var e:=InputEventMouseButton.new()
	e.button_index=MOUSE_BUTTON_LEFT
	e.pressed=true
	c.gui_input.emit(e)
func _ready() -> void:
	G.SAVE_PATH="res://tools/_logs/save_verify_run_events.json"
	G._init_state_defaults()
	G.save_locked=false
	for theme in TableCache.maps_config().themes:
		check(not Events.row(String(theme)).is_empty(),"八个主题各有独立事件")
		for role in ["zs","ck","fs","fz"]:
			var st:=RunState.new()
			st.setup({"theme":theme,"role_id":role,"level":20,"seed":64})
			st.hp=roundi(st.max_hp()*.5)
			var progress:=st.map_progress(1,0)
			var oldhp:=st.hp
			check(bool(Events.apply(st,progress,"rest").ok) and st.hp>oldhp and st.gold==0,"休整回复生命不白拿工钱")
			var original:=st.snapshot()
			check(not bool(Events.apply(st,progress,"work").ok) and st.snapshot()==original,"重复选择不会重发")
			progress.interact_done=false
			st.hp=1
			check(not bool(Events.apply(st,progress,"work").ok) and st.hp==1,"残血行动不杀死角色")
			st.hp=st.max_hp()
			check(bool(Events.apply(st,progress,"work").ok) and st.gold==int(Events.row(String(theme)).gold) and st.hp<st.max_hp(),"行动承担体力成本并固定小额工钱")
	var st:=RunState.new()
	st.setup({"theme":"snow","role_id":"zs","level":20,"seed":1})
	st.run_id="verify_snow_event|1"
	var node:Dictionary=st.route.layers[0][1]
	node.type="event"
	check(G.run_checkpoint(st,node),"事件开局可写盘")
	MapScene.pending_cfg={"run":st,"node":node}
	var map:=preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	map.on_interactable(map._interactable)
	check(map._puzzle_panel!=null and not bool(map._prog.interact_done),"接触只打开真实选择")
	if OS.get_cmdline_user_args().has("--screens"):
		await get_tree().create_timer(.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://shots/body_content_20261004/run_event_snow.png")
	var before:=st.snapshot()
	var original:=G.SAVE_PATH
	G.SAVE_PATH="res://tools/_logs/missing_run_event_dir/save.json"
	var quiet:=Engine.print_error_messages
	Engine.print_error_messages=false
	click(button(map._puzzle_panel,String(Events.row("snow").choices.work)))
	Engine.print_error_messages=quiet
	G.SAVE_PATH=original
	await get_tree().process_frame
	# Position checkpoint fields are incidental; reward and object state must roll back.
	check(st.gold==int(before.gold) and st.hp==int(before.hp) and not bool(map._prog.interact_done),"真实写盘失败回滚体力报酬与选择")
	check(map._interactable!=null and not map._interactable.used,"失败后现场目标保留可重试")
	map.on_interactable(map._interactable)
	click(button(map._puzzle_panel,String(Events.row("snow").choices.work)))
	await get_tree().process_frame
	check(st.gold==110 and String(map._prog.event_choice)=="work" and map._interactable==null,"真实按钮重试一次成功")
	check(G.reload_save() and int(G.prog.active_run.state.gold)==110,"事件选择与本局报酬同一存档")
	st.hp=roundi(st.max_hp()*.5)
	st.potions=2
	st.active_pet="pet_rockturtle"
	st.bench_pet="pet_tide_gull"
	check(map._checkpoint_run(),"动作前状态可持久化")
	var health:=st.hp
	var stock:=st.potions
	G.SAVE_PATH="res://tools/_logs/missing_run_event_dir/save.json"
	quiet=Engine.print_error_messages
	Engine.print_error_messages=false
	map._use_potion()
	check(st.hp==health and st.potions==stock,"地图用药写盘失败返还药剂与生命")
	map._swap_pet()
	check(st.active_pet=="pet_rockturtle" and st.bench_pet=="pet_tide_gull","换伙伴写盘失败还原站位")
	Engine.print_error_messages=quiet
	G.SAVE_PATH=original
	map._use_potion()
	check(st.hp>health and st.potions==stock-1 and G.reload_save() and int(G.prog.active_run.state.potions)==st.potions,"成功用药即时跨进程保存")
	map._swap_pet()
	check(st.active_pet=="pet_tide_gull" and G.reload_save() and String(G.prog.active_run.state.active_pet)=="pet_tide_gull","成功换伙伴即时保存")
	print("RUN_EVENTS_OK" if fails==0 else "RUN_EVENTS_FAIL %d"%fails)
	get_tree().quit(0 if fails==0 else 1)
