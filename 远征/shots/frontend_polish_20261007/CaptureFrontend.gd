extends SubViewport
const OUT := "res://shots/frontend_polish_20261007"
var records: Array = []

func _ready() -> void:
	G.SAVE_PATH = OUT + "/review_save.json"
	G.set_meta("ui_review_mode",true)
	render_target_update_mode = UPDATE_ALWAYS
	for height: int in [800,1067]:
		size = Vector2i(480,height)
		for key: String in ["title","login","load_0","load_71","load_100","intro_world","intro_party","intro_journey","home","avatar"]:
			reset_state()
			var page: Control
			if key.begins_with("intro_"):
				page = preload("res://src/ui/IntroductionPanel.gd").new()
				add_child(page)
				page.get("_deck").call("go",["intro_world","intro_party","intro_journey"].find(key),true)
			elif key.begins_with("load_"):
				page = preload("res://src/ui/LoadScreen.tscn").instantiate()
				page.set("auto_advance",false)
				add_child(page)
				page.set_process(false)
				var ratio := float(key.trim_prefix("load_"))/100.0
				page.call("_set_bar_ratio",ratio)
				(page.get("_bar_l") as Label).text = "整备完成" if ratio == 1 else "准备启程……"
			elif key == "avatar":
				page = preload("res://src/ui/AvatarPanel.gd").new()
				add_child(page)
			else:
				var scene: String = {"title":"Title","login":"Login","home":"GameHome"}[key]
				page = load("res://src/ui/%s.tscn" % scene).instantiate()
				add_child(page)
			for i in 12: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var path := OUT + "/" + key + "_" + str(height) + ".png"
			if get_texture().get_image().save_png(path) != OK: push_error("FRONTEND_CAPTURE_FAIL " + path); get_tree().quit(1); return
			preload("res://tools/UITextAudit.gd").write(page,path.get_basename()+".text.json")
			records.append({"case":key,"size":[480,height],"path":path})
			page.queue_free()
			for i in 3: await get_tree().process_frame
	var index := FileAccess.open(OUT+"/capture_index.json",FileAccess.WRITE)
	index.store_string(JSON.stringify(records,"\t"))
	print("FRONTEND_CAPTURE_OK images=%d" % records.size())
	get_tree().quit()

func reset_state() -> void:
	G._init_state_defaults()
	G.save_locked = false
	G.account = "界面检查"
	G.player_name = "沈舟"
	G.selected_role = "zs"
	G.prog.level = 13
	G.prog.exp = roundi(G.exp_to_next(13)*.5)
	G.prog.main_world = {"map_id":"lorin_wilds"}
	G.prog["story"] = {"step":"s04","done":["s01","s02","s03"],"goals":{}}
	G.wallet = {"gold":100174,"expedition":1011,"soul":599,"honor":560}
	G.avatar_use_custom = false
	G.avatar_custom = ""
	G._avatar_tex_done = false
	G._avatar_tex = null
