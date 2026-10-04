extends Node
const Safe:=preload("res://src/ui/UiSafeArea.gd")
func _ready()->void:
	G.SAVE_PATH="res://tools/_logs/save_safe_visual.json"
	G._init_state_defaults()
	G.save_locked=false
	G.selected_role="zs"
	DirAccess.make_dir_recursive_absolute("res://shots/body_safe_pages_20261004")
	for height in [800,1067]:
		get_window().size=Vector2i(480,height)
		await get_tree().process_frame
		var safe:=Rect2(8,36,464,height-60)
		for name in ["Login","GameHome"]:
			var page:Control=load("res://src/ui/%s.tscn"%name).instantiate()
			add_child(page)
			await get_tree().process_frame
			Safe.fit_page(page,safe,get_viewport().get_visible_rect().size)
			await capture("%s_%d"%[name,height],safe)
			page.queue_free()
			await get_tree().process_frame
		BattleScene.pending_cfg={"presentation":"classic_inline","seed":881,"ally":{"role_id":"zs","level":5,"traits":[],"potions":2},"enemy":{"theme":"forest","node_type":"normal","layer":1}}
		var battle:=preload("res://src/battle/BattleScene.tscn").instantiate() as BattleScene
		add_child(battle)
		await get_tree().process_frame
		battle.speed=0
		var base:=get_viewport().get_visible_rect().size
		Safe.fit_page(battle,safe,base)
		Safe.fit_page(battle._cmd_root,safe,base)
		await capture("Battle_%d"%height,safe)
		battle._show_command_skills()
		battle._page_panel.set_meta("safe_base_position",battle._page_panel.position)
		Safe.fit_page(battle,safe,base)
		await capture("Skills_%d"%height,safe)
		battle.queue_free()
		await get_tree().process_frame
		var fishing:=preload("res://src/ui/FishingPanel.gd").new()
		add_child(fishing)
		fishing.open_spot("fish_frost_pool")
		Safe.fit_page(fishing,safe,base)
		await capture("Fishing_%d"%height,safe)
		fishing.queue_free()
		await get_tree().process_frame
		G.fishing_state().discoveries=["fish_frost"]
		var journal:=preload("res://src/ui/FieldJournalPanel.gd").new()
		add_child(journal)
		await get_tree().process_frame
		Safe.fit_page(journal,safe,base)
		await capture("FishJournal_%d"%height,safe)
		journal.queue_free()
		await get_tree().process_frame
	print("SAFE_VISUAL_QA_OK twelve_actual_renders")
	get_tree().quit()
func capture(name:String,safe:Rect2)->void:
	var outline:=Panel.new()
	outline.position=safe.position
	outline.size=safe.size
	outline.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style:=StyleBoxFlat.new()
	style.bg_color=Color.TRANSPARENT
	style.border_color=Color("35dfb7")
	style.set_border_width_all(1)
	outline.add_theme_stylebox_override("panel",style)
	add_child(outline)
	await get_tree().create_timer(.35).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://shots/body_safe_pages_20261004/%s.png"%name)
	outline.queue_free()
