extends SubViewport
const OUT := "res://shots/ledger_refinement_20261006"
var records: Array = []

func _ready() -> void:
	G.SAVE_PATH = OUT + "/panel_review_save.json"
	G.set_meta("ui_review_mode",true)
	render_target_update_mode = UPDATE_ALWAYS
	for height: int in [800,1067]:
		size = Vector2i(480,height)
		reset_state()
		var run := RunState.new()
		run.setup({"theme":"forest","role_id":"fs","level":13,"active_pet":"pet_rockturtle","potions":2,"seed":7})
		MapScene.pending_cfg = {"mode":"main_world","main_map_id":"broken_slope","run":run,
			"node":{"type":"normal","layer":0,"index":0}}
		var world := preload("res://src/explore/MapScene.tscn").instantiate()
		add_child(world)
		for i in 6: await get_tree().process_frame
		world.process_mode = PROCESS_MODE_DISABLED
		for case: String in ["slope_order","city_order","slope_active","slope_expired","frost_order","frost_contract","contracts","commission","commission_active"]:
			reset_state()
			var overlay := CanvasLayer.new()
			overlay.layer = 20
			add_child(overlay)
			var panel: Control
			if case in ["slope_order","city_order","slope_active","slope_expired","frost_order"]:
				if case in ["slope_active","slope_expired"]:
					G.economy_first_order_accept()
					if case == "slope_expired": G.economy_state()["day"] = 30
				panel = preload("res://src/ui/TradePanel.gd").new()
				overlay.add_child(panel)
				panel.call("open_site","city_market" if case == "city_order" else ("shenyuan_market" if case == "frost_order" else "slope_camp"))
				panel.set("_page",1)
				panel.call("_rebuild")
			elif case == "frost_contract":
				panel = preload("res://src/ui/FrostContractPanel.gd").new()
				overlay.add_child(panel)
				panel.call("open_contract","shenyuan_market")
			elif case == "contracts":
				panel = preload("res://src/ui/TradeContractsPanel.gd").new()
				overlay.add_child(panel)
				panel.call("open_contracts","city_market")
			else:
				if case == "commission_active":
					var offer: Dictionary = WorldCommission.offers(G,"zhaoyuan")[0]
					WorldCommission.accept(G,String(offer.posting),"zhaoyuan")
				panel = preload("res://src/ui/WorldCommissionPanel.gd").new()
				overlay.add_child(panel)
			for i in 6: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var path := OUT + "/" + case + "_" + str(height) + ".png"
			if get_texture().get_image().save_png(path) != OK:
				push_error("PANEL_CAPTURE_FAIL " + path)
				get_tree().quit(1)
				return
			preload("res://tools/UITextAudit.gd").write(panel,path.get_basename()+".text.json")
			records.append({"case":case,"height":height,"path":path})
			overlay.queue_free()
			for i in 3: await get_tree().process_frame
		world.queue_free()
		for i in 3: await get_tree().process_frame
	var index := FileAccess.open(OUT + "/panel_capture_index.json",FileAccess.WRITE)
	index.store_string(JSON.stringify(records,"\t"))
	print("LEDGER_PANELS_CAPTURE_OK images=%d" % records.size())
	get_tree().quit()

func reset_state() -> void:
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "fs"
	G.player_name = "行旅者"
	G.prog.level = 13
	G.prog["story"] = {"step":"s45","done":["s04","s13","s20","s21","s28","s34","s44"],"goals":{}}
	G.prog.main_world = {"map_id":"broken_slope"}
	G.act1_state()["side_quests"] = {"a1_trade_cart":{"status":"done"}}
	G.economy_state()["day"] = 10
	G.wallet = {"gold":101780,"expedition":240,"soul":36,"honor":900}
