extends Node
const OUT := "res://shots/field_ui_20261004"

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_field_capture.json"
	G._init_state_defaults()
	G.save_locked = false
	G.player_name = "陆川愿"
	G.prog["level"] = 12
	G.wallet = {"gold":99159,"expedition":1011,"soul":979,"honor":9}
	G.prog["pets"] = ["pet_rockturtle","pet_thunderhawk","pet_foxfire","pet_winddeer","pet_moonhare"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for height in [800,1067]:
		get_window().size = Vector2i(480,height)
		await get_tree().process_frame
		for role_id in ["fs","zs","ck","fz"]:
			G.selected_role = role_id
			for name in ["home","growth","skill"]:
				var page: Control
				match name:
					"home": page = preload("res://src/ui/GameHome.tscn").instantiate()
					"growth": page = preload("res://src/ui/GrowthPanel.gd").new()
					"skill": page = preload("res://src/ui/SkillBookPanel.gd").new()
				add_child(page)
				await capture("%s_%s_%d" % [name,role_id,height])
				if name == "skill" and role_id == "fs" and height == 800:
					for i in range(1,5):
						page._deck.go(i,true)
						await capture("skill_fs_tab%d" % i)
					G.wallet["expedition"] = 0
					page._refresh(true)
					await capture("skill_insufficient")
					G.prog["skills"] = {"fs_yanmie":G.skill_max_level()}
					page._refresh(true)
					await capture("skill_maxed")
					G.prog["skills"] = {}
					G.wallet["expedition"] = 1011
				page.queue_free()
				await get_tree().process_frame
	G.wallet = {"gold":999999999,"expedition":999999999,"soul":999999999,"honor":999999999}
	G.player_name = "长昵称测试一二三四五六七八九十"
	var home := preload("res://src/ui/GameHome.tscn").instantiate()
	add_child(home)
	await capture("home_extreme")
	home.queue_free()
	await get_tree().process_frame
	print("FIELD_CAPTURE_OK 31 renders")
	get_tree().quit()

func capture(name: String) -> void:
	await get_tree().create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "/%s.png" % name)
