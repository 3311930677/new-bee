extends Node
## Layout and interaction acceptance for the visual review fixes; saves remain isolated.
var OUT := "res://shots/visual_fixes_20261027/acceptance_final/"
const PointMap := preload("res://src/ui/WorldPointMap.gd")
const Points := preload("res://src/world/WorldPoints.gd")
var checks := 0
var failures: Array[String] = []
var current: Node

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)
		push_error("VISUAL_POLISH_FAIL " + note)

func frames(n := 8) -> void:
	for i in n:await get_tree().process_frame

func clear() -> void:
	if is_instance_valid(current):
		current.queue_free()
		await frames(4)
	current = null

func attach(node: Node) -> void:
	await clear()
	current = node
	add_child(node)
	await frames(12)

func shot(id: String) -> void:
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(OUT+id+".png")==OK,"capture "+id)

func click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index=0;event.position=at;event.pressed=pressed
		get_viewport().push_input(event,true)
		await frames(1)
	await frames()

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):OUT=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(OUT)
	G.SAVE_PATH=ProjectSettings.globalize_path(OUT+"isolated_save.json")
	G._init_state_defaults();G.save_locked=false
	G.set_meta("ui_review_mode",true)
	G.gm_unlocked=true;G.gm_grant_all();G.gm_unlock_all_features();G.gm_world_open=true
	G.selected_role="zs";G.player_name="沈舟";G.prog.level=35
	G.ensure_starter_equip(true)
	G.ensure_starter_pets()
	G.inv_grant_equip({"tpl":"tpl_sword_wolf","rarity":2,"n":24},false)
	get_window().unresizable=false
	get_window().min_size=Vector2i(300,480)
	for dimensions in [Vector2i(480,800),Vector2i(480,1067),Vector2i(320,640)]:
		await clear()
		get_window().size=dimensions
		get_window().content_scale_size=dimensions
		await frames()
		var tag:="%dx%d"%[dimensions.x,dimensions.y]
		await inventory(tag)
		await points_map(tag)
		await region(tag)
		await battle(tag)
	await clear()
	get_window().size=Vector2i(480,1067)
	get_window().content_scale_size=Vector2i(480,1067)
	await attach(preload("res://src/ui/GameHome.tscn").instantiate())
	var view: Control=current._chest_view
	var gap: float=view._quest.get_global_rect().position.y-view._hero_plate.get_global_rect().end.y
	check(gap>=16 and gap<=80,"tall home keeps the quest close to the hero without overlap")
	for id in view._plaques:check(get_viewport().get_visible_rect().encloses(view._plaques[id].get_global_rect()),"tall home landmark stays onscreen "+String(id))
	await shot("home_tall")
	await clear()
	var report := FileAccess.open(OUT+"results.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	report.close()
	Audio.stop_bgm();Audio.set_suspended(true)
	print("VISUAL_POLISH checks=%d failures=%d"%[checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func inventory(tag: String) -> void:
	var bag:=BagPanel.new()
	await attach(bag)
	await click(bag._item_buttons[0])
	for amount in [0,128400,999999999]:
		G.wallet.gold=amount
		bag._refresh()
		await frames()
		check(bag._gold_bg.get_global_rect().encloses(bag._gold.get_global_rect()),"gold text rectangle stays inside its plate "+tag)
		var font:=bag._gold.get_theme_font("font")
		var px:=bag._gold.get_theme_font_size("font_size")
		check(font.get_string_size(bag._gold.text,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x<=bag._gold.size.x,"full displayed balance fits without clipping "+tag+" "+str(amount))
		check(bag._gold.tooltip_text=="金币 %d"%amount,"full balance remains available "+tag)
	for button in bag._action_buttons:
		check(button.size.x>=44 and button.size.y>=44,"inventory action touch size "+tag)
		check(get_viewport().get_visible_rect().encloses(button.get_global_rect()),"inventory action stays onscreen "+tag)
	G.wallet.gold=128400;bag._refresh()
	await frames()
	await shot("bag_"+tag)
	await click(bag._gold_hit)
	check(is_instance_valid(bag._toast),"touching the compact balance opens its full value "+tag)
	check(bag._toast.words=="金币 128400","balance feedback displays the exact amount "+tag)
	check(get_viewport().get_visible_rect().encloses(bag._toast.get_global_rect()),"full balance feedback fits the narrow screen "+tag)
	check(bag._gold_hit.size.y>=44,"full balance has a usable touch target "+tag)

func points_map(tag: String) -> void:
	G.prog.main_world={"map_id":"lorin_wilds","position":[600,1520]}
	var panel:=PointMap.new()
	panel.standalone=true
	await attach(panel)
	check(get_viewport().get_visible_rect().encloses(panel._frame.get_global_rect()),"map frame fits "+tag)
	check(panel._canvas.scenery.size()>=9,"geographic map includes authored buildings "+tag)
	check(panel._canvas.extent.x*panel._canvas._scale()>=panel._canvas.size.x-1,"default map uses its full width "+tag)
	check(Rect2(Vector2.ZERO,panel._canvas.size).has_point(panel._canvas.screen_at(Vector2(600,1520))),"default map shows the real player "+tag)
	await shot("map_local_"+tag)
	panel._canvas.set_zoom(panel._canvas.overview_zoom())
	await frames()
	var map_rect: Rect2=panel._canvas._rect()
	check(Rect2(Vector2(-1,-1),panel._canvas.size+Vector2(2,2)).encloses(map_rect),"zooming out fits the entire map "+tag)
	await shot("map_overview_"+tag)
	panel._canvas.locate_player()
	await frames()
	var markers: Array=panel._canvas._markers()
	check(not markers.is_empty(),"local map has selectable visible markers "+tag)
	if not markers.is_empty():
		var at: Vector2=panel._canvas.global_position+markers[0].at
		for pressed in [true,false]:
			var event:=InputEventScreenTouch.new()
			event.index=0;event.position=at;event.pressed=pressed
			get_viewport().push_input(event,true)
			await frames(1)
		await frames()
		check(not panel._selected.is_empty() or is_instance_valid(panel._picker),"real touch selects a visible marker "+tag)
		panel._close_picker()
	panel.select_point("lorin_wilds:archive")
	await frames()
	check(not panel._go.disabled,"real place can be tracked "+tag)
	await click(panel._go)
	check(String(Points.target().get("id",""))=="lorin_wilds:archive","tracking uses the real place id "+tag)
	await click(panel._cancel)
	check(Points.target().is_empty(),"cancel clears the saved target "+tag)

func region(tag: String) -> void:
	var panel:=RegionMapPanel.new()
	await attach(panel)
	check(get_viewport().get_visible_rect().encloses(panel._details_button.get_global_rect()),"region detail entrance is fully onscreen without scrolling "+tag)
	check(panel._details_button.size.y>=44,"region detail touch target "+tag)
	await shot("region_"+tag)
	await click(panel._details_button)
	check(is_instance_valid(panel._point_map),"region fixed entrance opens the geographical map "+tag)

func battle(tag: String) -> void:
	BattleScene.pending_cfg={"ally":{"role_id":"zs","level":35,"active_pet":"pet_rockturtle"},"enemy":{"theme":"forest","node_type":"normal","layer":1},"presentation":"classic_inline","seed":7}
	await clear()
	var scene:=preload("res://src/battle/BattleScene.tscn").instantiate() as BattleScene
	current=scene
	add_child(scene)
	scene.set_process(false)
	while scene.sim.alive_units("enemy").size()<6:scene.sim._spawn_monster("mon_wolf",Combatant.ROW_FRONT,3)
	scene._sync_views()
	await frames(12)
	scene._chest.refresh()
	await frames()
	var deck: Control=scene._chest
	check(deck._enemy_strip.get_child_count()==6,"six enemies retain six real target cards "+tag)
	check(scene._cast_tip.get_global_rect().end.y<=deck.tray.get_global_rect().position.y,"battle warnings do not overlap the target deck "+tag)
	for button in deck._buttons.values():
		check(get_viewport().get_visible_rect().encloses(button.get_global_rect()),"battle command stays onscreen "+tag+" "+str(button.get_meta("command")))
	for enemy in scene.sim.alive_units("enemy"):
		var view=scene._views[enemy.uid]
		check(view.hp_bg.visible and view.hp_fg.visible,"every enemy retains a visible health bar "+tag)
		check(get_viewport().get_visible_rect().encloses(view._actor_rect()),"enemy stays inside narrow battlefield "+tag)
	await shot("battle_six_"+tag)
	var focus_before: int=scene.sim.role_focus_target_uid
	var at: Vector2=deck._enemy_strip.get_child(0).get_global_rect().get_center()
	var down:=InputEventScreenTouch.new()
	down.index=0;down.position=at;down.pressed=true
	get_viewport().push_input(down,true)
	await frames(1)
	for i in range(1,6):
		var drag:=InputEventScreenDrag.new()
		drag.index=0;drag.position=at-Vector2(i*24,0);drag.relative=Vector2(-24,0)
		get_viewport().push_input(drag,true)
		await frames(1)
	var up:=InputEventScreenTouch.new()
	up.index=0;up.position=at-Vector2(120,0);up.pressed=false
	get_viewport().push_input(up,true)
	await frames()
	check(deck._enemy_scroll.scroll_horizontal>0,"real touch drag scrolls the target cards "+tag)
	check(scene.sim.role_focus_target_uid==focus_before,"dragging target cards does not select an enemy "+tag)
	await get_tree().create_timer(.25).timeout
	deck._enemy_scroll.scroll_horizontal=100000
	await frames()
	var last=deck._enemy_strip.get_child(5)
	await click(last)
	check(scene.sim.role_focus_target_uid==last.unit.uid,"last target remains touch-selectable after scrolling "+tag)
	await shot("battle_selected_last_"+tag)
	var previous=deck._enemy_strip.get_child(4)
	var mouse_at: Vector2=previous.get_global_rect().get_center()
	for pressed in [true,false]:
		var mouse:=InputEventMouseButton.new()
		mouse.position=mouse_at;mouse.global_position=mouse_at;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=pressed
		get_viewport().push_input(mouse,true)
		await frames(1)
	await frames()
	check(scene.sim.role_focus_target_uid==previous.unit.uid,"mouse selection still works after a touch gesture "+tag)
