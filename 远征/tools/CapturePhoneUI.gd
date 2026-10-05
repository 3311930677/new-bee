extends Node
const OUT := "res://shots/phone_ui_20261005"

func _ready() -> void:
	G.SAVE_PATH = "user://phone_ui_capture.json"
	G._init_state_defaults()
	G.save_locked = false
	G.player_name = "沈舟"
	G.selected_role = "zs"
	G.prog.level = 12
	G.wallet = {"gold":101376,"expedition":1011,"soul":259,"honor":580}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for height in [800,1067]:
		get_window().size = Vector2i(480,height)
		await get_tree().process_frame
		var home := preload("res://src/ui/GameHome.tscn").instantiate()
		add_child(home)
		await capture("home_%d" % height)
		home._open_activities()
		await capture("activities_empty_%d" % height)
		home._activities.closed.emit()
		home.queue_free()
		await get_tree().process_frame
		var activities := preload("res://src/ui/ActivityPanel.gd").new()
		activities.events_override = [{"id":"layout_preview","title":"行旅告示 · 排版示例","summary":"仅用于检查活动页的布局和长文本。","starts_at":0,"ends_at":0,"body":["此页面是活动排版预览，正式配置中没有开放任何活动。","开启不同活动时，这里可以展示活动时间、玩法规则与参与说明。".repeat(12)]}]
		add_child(activities)
		await capture("activities_preview_list_%d" % height)
		activities.show_event("layout_preview")
		await capture("activities_preview_detail_%d" % height)
		activities.queue_free()
		await get_tree().process_frame
		for multi in [false,true]:
			BattleScene.pending_cfg = {"ally":{"role_id":"zs","level":12,"traits":[],"active_pet":"pet_rockturtle","potions":2},"enemy":{"theme":"forest","node_type":"normal","layer":1,"lead_mon":"mon_wolf","solo":not multi},"presentation":"classic_inline","seed":17}
			var battle := preload("res://src/battle/BattleScene.tscn").instantiate()
			battle.speed = 1.0
			add_child(battle)
			battle.set_process(false)
			battle._refresh_hud()
			await capture("battle_%s_%d" % ["group" if multi else "solo",height])
			if not multi:
				battle._show_command_skills()
				await capture("battle_skills_%d" % height)
				battle._show_command_items()
				await capture("battle_items_%d" % height)
			battle.queue_free()
			await get_tree().process_frame
	print("PHONE_UI_CAPTURE_OK")
	get_tree().quit()

func capture(words: String) -> void:
	await get_tree().create_timer(.35).timeout
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(OUT+"/"+words+".png")
	if err!=OK:
		push_error("Capture failed: "+words)
		get_tree().quit(1)
