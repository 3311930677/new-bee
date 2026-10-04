extends Node
const OUT := "res://shots/craft_ui_20261005"

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_craft_capture.json"
	G._init_state_defaults()
	G.save_locked = false
	G.player_name = "陆川愿"
	G.prog["level"] = 12
	G.wallet = {"gold":99159,"expedition":1011,"soul":979,"honor":9}
	G.prog["pets"] = ["pet_rockturtle","pet_thunderhawk","pet_foxfire","pet_winddeer","pet_moonhare"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var pages := ["home"] if OS.get_cmdline_user_args().has("home") else ["home","growth","skill"]
	for height in [800,1067]:
		get_window().size = Vector2i(480,height)
		await get_tree().process_frame
		for role_id in ["fs","zs","ck","fz"]:
			G.selected_role = role_id
			for page_name in pages:
				var page: Control
				match page_name:
					"home": page = preload("res://src/ui/GameHome.tscn").instantiate()
					"growth": page = preload("res://src/ui/GrowthPanel.gd").new()
					"skill": page = preload("res://src/ui/SkillBookPanel.gd").new()
				add_child(page)
				await capture("%s_%s_%d" % [page_name,role_id,height])
				if page_name=="skill" and role_id=="fs" and height==800:
					for i in range(1,5):
						page._deck.go(i,true)
						await capture("skill_fs_tab%d" % i)
					G.wallet.expedition=0
					page._refresh(true)
					await capture("skill_insufficient")
					G.prog["skills"]={"fs_yanmie":G.skill_max_level()}
					page._refresh(true)
					await capture("skill_maxed")
					G.prog["skills"]={}
					G.wallet.expedition=1011
				page.queue_free()
				await get_tree().process_frame
	print("CRAFT_CAPTURE_OK")
	get_tree().quit()

func capture(words: String) -> void:
	await get_tree().create_timer(.45).timeout
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(OUT+"/%s.png" % words)
	if err != OK:
		push_error("Capture failed: "+words)
		get_tree().quit(1)
