extends Node
const OUT := "res://shots/ledger_refinement_20261006"
const Trade := preload("res://src/ui/TradePanel.gd")
const Ground := preload("res://src/world/BuildingGrounding.gd")
const Field := preload("res://src/ui/FieldUI.gd")
var failures := 0

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_trade_shadow_capture.json"
	G._init_state_defaults()
	G.save_locked = false
	G.set_meta("ui_review_mode",true)
	G.selected_role = "fs"
	G.player_name = "陆川愿"
	G.prog.level = 12
	G.wallet["gold"] = 101522
	for day in range(6,11):
		var economy := G.economy_state()
		economy["day"] = day
		EconomyService.record_history(TableCache.economy_config(),economy)
	G.side_accept("a1_trade_cart")
	G.side_entity_interact("deliver","a1_postrider","maple_road","a1_trade_cart")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for height in [800,1067]:
		get_window().size = Vector2i(480,height)
		await get_tree().process_frame
		for site in ["slope_camp","city_market","maple_post","shenyuan_market","frost_market"]:
			var panel := Trade.new()
			add_child(panel)
			panel.open_site(site)
			for page in 3:
				panel._page = page
				panel._rebuild()
				await settle()
				check_layout(panel)
				if site in ["slope_camp","city_market","shenyuan_market"]: await capture("%s_page%d_%d" % [site,page,height])
				panel._help = true
				panel._rebuild()
				await settle()
				check_layout(panel)
				if site == "slope_camp" and page == 0: await capture("rules_%d" % height)
				panel._help = false
			panel.queue_free()
			await get_tree().process_frame
	# The panel must surface names while a failed transaction preserves all state.
	var panel := Trade.new()
	add_child(panel)
	panel.open_site("slope_camp")
	panel.selected_good = "trade_salt"
	panel.quantity = 5
	var before := JSON.stringify([G.wallet,G.items,G.economy_state()])
	panel._trade("sell")
	check("盐" in panel._message and not "trade_salt" in panel._message,"缺货提示必须显示中文")
	check(before == JSON.stringify([G.wallet,G.items,G.economy_state()]),"失败交易不可扣钱或改货物")
	await capture("missing_salt")
	panel.quantity = 1
	panel._rebuild()
	await settle()
	var buy := find_action(panel,"买入")
	check(buy != null,"买入操作应可点击")
	if buy != null: buy.emit_signal("activated")
	check(G.item_count("trade_salt") == 1,"新版界面买货应入包")
	panel._trade("sell")
	check(G.item_count("trade_salt") == 0,"新版界面卖货应扣货")
	panel._page = 2
	panel._work("road")
	check("完成" in panel._message,"差事可完成")
	var day := int(G.economy_state().day)
	panel._rest()
	check(int(G.economy_state().day) == day+1,"歇脚必须推进一天")
	panel._page = 1
	panel._rebuild()
	await capture("order_available")
	check(bool(G.economy_first_order_accept().get("ok",false)),"运单可接取")
	panel._rebuild()
	await capture("order_active")
	panel.queue_free()
	await get_tree().process_frame
	get_window().size = Vector2i(480,800)
	for map_id in ["maple_road","broken_slope"]:
		var run := RunState.new()
		run.setup({"theme":"forest","role_id":"fs","level":12,"active_pet":"pet_rockturtle","bench_pet":"","potions":2,"seed":19})
		MapScene.pending_cfg = {"mode":"main_world","main_map_id":map_id,"run":run,"node":{"type":"normal","layer":0,"index":0}}
		var map := preload("res://src/explore/MapScene.tscn").instantiate()
		add_child(map)
		map._player.position = Vector2(480,340)
		if map_id == "broken_slope": map._player.position = Vector2(475,790)
		await capture("world_"+map_id)
		map.queue_free()
		await get_tree().process_frame
	var catalog := Control.new()
	add_child(catalog)
	var bg := ColorRect.new()
	bg.color = Color("69754a")
	bg.size = Vector2(480,800)
	catalog.add_child(bg)
	var descriptions := ["商路摊位","古道路牌","议事厅","驿仓"]
	for i in 4:
		var prop := ShadowPreview.new()
		prop.key = ["trade_stall","signpost","hall","storehouse"][i]
		prop.position = Vector2(120+(i%2)*240,300+(i/2)*330)
		catalog.add_child(prop)
		var label := Trade.Craft.label(descriptions[i],prop.position+Vector2(-80,54),Vector2(160,32),19,Color("ede2be"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		catalog.add_child(label)
	await capture("building_shadows")
	catalog.queue_free()
	await get_tree().process_frame
	Ground._cache.clear()
	preload("res://src/world/WorldPropArt.gd")._ground_sources.clear()
	print("TRADE_SHADOW_OK" if failures == 0 else "TRADE_SHADOW_FAIL")
	get_tree().quit(0 if failures == 0 else 1)

func check(ok: bool, words: String) -> void:
	if not ok: failures += 1; push_error(words)

func find_action(node: Node, words: String) -> Control:
	if node is Field.Action and node.caption.text == words: return node
	for child in node.get_children():
		var found := find_action(child,words)
		if found != null: return found
	return null

func check_layout(panel: Control) -> void:
	var paper := panel._body.get_node("LedgerLayout").get_child(3) as Control
	if paper == null: return
	var stack := paper.get_child(0) as Control
	check(stack.get_global_rect().end.y <= paper.get_global_rect().end.y,"内容不得超出纸页")
	check(panel._body.get_node("LedgerLayout").get_global_rect().end.y <= get_viewport().get_visible_rect().end.y+.1,"布局必须在可见范围内")

func settle() -> void:
	await get_tree().create_timer(.18).timeout
	await RenderingServer.frame_post_draw

func capture(words: String) -> void:
	await settle()
	if DisplayServer.get_name() == "headless": return
	check(get_viewport().get_texture().get_image().save_png(OUT+"/"+words+".png") == OK,"截图必须成功")

class ShadowPreview extends Node2D:
	var key := "trade_stall"
	var art: Texture2D
	var row: Dictionary
	var extent: Vector2
	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if key in ["hall","storehouse"]: art = load("res://image/main_world/city_%s_reference_v2.png" % key)
		elif key == "signpost": art = load("res://image/main_world/art_v2/signpost.png")
		else: art = G.res_tex(key)
		if art == null: return
		extent = Vector2(art.get_size())
		if key == "signpost": extent = Vector2(92,96)
		elif key != "trade_stall": extent = Vector2(180,180.0*art.get_height()/art.get_width())
		if key in ["hall","storehouse"]:
			row = Ground.prepare(art,roundi(extent.x),roundi(extent.y))
			Ground.attach(self,row,-extent.y,false)
		else: row = Ground.silhouette(art,roundi(extent.x),roundi(extent.y))
	func built() -> bool: return true
	func _draw() -> void:
		if art == null: return
		var at := Vector2(-extent.x*.5,-extent.y)
		if key not in ["hall","storehouse"]: Ground.draw_prop(self,row,at,extent.x)
		draw_texture_rect(art,Rect2(at,extent),false)
