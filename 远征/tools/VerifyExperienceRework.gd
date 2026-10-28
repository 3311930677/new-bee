extends Node
const OUT := "res://shots/experience_rework_20261026/"
const Market := preload("res://src/ui/HonorMarketPanel.gd")
const Activities := preload("res://src/ui/ActivityPanel.gd")
const Points := preload("res://src/world/WorldPoints.gd")
var checks := 0
var failures: Array[String] = []
var capture := false
var screenshots: Array[String] = []

func check(ok: bool,words: String) -> void:
	checks+=1
	if not ok:
		failures.append(words)
		push_error("EXPERIENCE_FAIL "+words)

func frames(n := 6) -> void:
	for i in n:await get_tree().process_frame

func drop(node: Node) -> void:
	node.queue_free()
	await frames(4)

func shot(id: String) -> void:
	if not capture:return
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(OUT+id+".png")
	check(result==OK,"capture "+id)
	screenshots.append(id)

func fixture() -> void:
	G.SAVE_PATH="res://tools/_logs/experience_rework_save.json"
	G.save_locked=false
	G._init_state_defaults()
	G.selected_role="zs"
	G.player_name="沈舟"
	G.gm_unlocked=true
	G.gm_unlock_all_features()
	G.gm_world_open=true
	G.prog.level=35
	G.wallet={"gold":128400,"expedition":2300,"soul":860,"honor":1240}
	G.ensure_starter_equip(true)
	G.ensure_starter_pets()
	G.prog.main_world={"map_id":"old_salt_road"}

func _ready() -> void:
	capture="--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUT)
	fixture()
	get_window().unresizable=false
	get_window().min_size=Vector2i(300,480)
	for height in [640,800,1067]:
		get_window().size=Vector2i(480,height)
		get_window().content_scale_size=Vector2i(480,height)
		G.set_meta("test_safe_rect",Rect2(8,36,464,height-76))
		await frames()
		await market(height)
		await activities(height)
		await fishing_layout(height)
		await poi_layout(height)
	G.remove_meta("test_safe_rect")
	get_window().size=Vector2i(480,1067)
	get_window().content_scale_size=Vector2i(480,1067)
	await frames()
	await bag_drag()
	await world_flow()
	var f := FileAccess.open(OUT+"results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"screenshots":screenshots},"\t"))
	f.close()
	print("EXPERIENCE_REWORK checks=%d failures=%d"%[checks,failures.size()])
	Audio.stop_bgm()
	Audio.set_suspended(true)
	await frames(5)
	get_tree().quit(0 if failures.is_empty() else 1)

func market(height: int) -> void:
	var p := Market.new()
	add_child(p)
	await frames()
	var safe := G.ui_safe_rect(p)
	check(safe.encloses(p._panel.get_global_rect()),"market safe "+str(height))
	check(p._grid.get_child_count()==5,"all configured products")
	check(p._honor_l.get_line_count()==1,"balance stays on a single readable line")
	p._set_category("material")
	await frames()
	check(p._grid.get_child_count()==3,"material category")
	p._set_category("gem")
	await frames()
	check(p._grid.get_child_count()==2,"gem category")
	p._set_category("all")
	await frames()
	check(p._grid.size.x<=p._scroll.size.x+1,"market has no horizontal overflow")
	await shot("market_"+str(height))
	if height==800:
		p.open_product("enhance_stone")
		await frames()
		check(safe.encloses(p._detail.get_global_rect()),"product detail fits safe rect")
		var honor := int(G.wallet.honor)
		var count := G.item_count("enhance_stone")
		p.confirm_purchase()
		p.confirm_purchase()
		check(G.wallet.honor==honor-80 and G.item_count("enhance_stone")==count+3,"one confirmation exactly once")
		await shot("market_detail")
		p.close_product()
		honor=int(G.wallet.honor)
		count=G.item_count("enhance_stone")
		G.save_locked=true
		check(not p.do_exchange("enhance_stone"),"save failure rejects exchange")
		G.save_locked=false
		check(G.wallet.honor==honor and G.item_count("enhance_stone")==count,"failed exchange rolls back")
		var before := p.entries().size()
		for i in 20:
			var entry: Dictionary=p.entries()[0].duplicate(true)
			entry.id="long_"+str(i)
			entry.name="长名称商品可读性验证材料 "+str(i)
			p._entries.append(entry)
		p._set_category("all")
		await frames()
		p._scroll.scroll_vertical=99999
		await frames()
		check(p._grid.get_child_count()==before+20 and p._scroll.scroll_vertical>0,"twenty extra products remain scrollable")
	await drop(p)

func activities(height: int) -> void:
	var p := Activities.new()
	var before := JSON.stringify([G.wallet,G.prog])
	add_child(p)
	await frames()
	check(p._events.size()==2,"two real configured activities retained")
	check(G.ui_safe_rect(p).encloses(p._frame.get_global_rect()),"activity safe "+str(height))
	await shot("activities_"+str(height))
	p.show_event("arena_practice")
	await frames()
	check(p._detail_id=="arena_practice","activity opens own detail")
	check(JSON.stringify([G.wallet,G.prog])==before,"activity viewing is read-only")
	if height==1067:await shot("activity_detail")
	p.go_back()
	check(p._detail_id.is_empty(),"activity returns to list")
	check(Activities.event_status({"starts_at":100,"ends_at":200},99)=="即将开启","upcoming activity")
	check(Activities.event_status({"starts_at":100,"ends_at":200},200)=="已结束","finished activity")
	await drop(p)

func fishing_layout(height: int) -> void:
	var p := FishingPanel.new()
	add_child(p)
	p.open_spot("fish_salt_spring")
	await frames()
	check(G.ui_safe_rect(p).encloses(p._page.get_global_rect()),"fishing safe "+str(height))
	check(p._water.size.y>=60,"fishing stage has usable space")
	await shot("fishing_"+str(height))
	if height==1067:
		p._act()
		await frames()
		await shot("fishing_cast")
	p.close()
	await frames()

func poi_layout(height: int) -> void:
	var p := preload("res://src/ui/WorldPointMap.gd").new()
	p.map_id="old_salt_road"
	add_child(p)
	await frames()
	check(G.ui_safe_rect(p).encloses(p._frame.get_global_rect()),"point map safe "+str(height))
	p.select_point("old_salt_road:fish_salt_spring")
	await frames()
	check(p._selected.ends_with("fish_salt_spring") and not p._go.disabled,"real fishing point is selectable")
	await shot("poi_map_"+str(height))
	var old := String(G.prog.get("map_destination",""))
	G.save_locked=true
	check(not bool(Points.track(p._selected).ok),"destination save failure reports rejection")
	G.save_locked=false
	check(String(G.prog.get("map_destination",""))==old,"failed tracking rolls back")
	await drop(p)

func bag_drag() -> void:
	for row in TableCache._load("res://data/exchange.json").get("entries",[]):
		for key in row.give:G.items[String(key).trim_prefix("item_")]=99
	for key in TableCache._load("res://data/resource_manifest.json"):
		if String(key).begins_with("itm_"):G.items[String(key).trim_prefix("itm_").trim_suffix(".png")]=99
	var p := BagPanel.new()
	add_child(p)
	await frames()
	p._select_tab("mat")
	await frames()
	var start := p._item_buttons[0].get_global_rect().get_center()
	var press := InputEventScreenTouch.new()
	press.index=0
	press.position=start
	press.pressed=true
	Input.parse_input_event(press)
	await frames(2)
	for i in range(1,9):
		var drag := InputEventScreenDrag.new()
		drag.index=0
		drag.position=start-Vector2(0,i*25)
		drag.relative=Vector2(0,-25)
		Input.parse_input_event(drag)
		await frames(1)
	var release := InputEventScreenTouch.new()
	release.index=0
	release.position=start-Vector2(0,200)
	release.pressed=false
	Input.parse_input_event(release)
	await frames()
	check(p._scroll.scroll_vertical>100,"touch drag from a real item scrolls bag")
	check(p._sel_supply.is_empty(),"touch drag does not select an item")
	await shot("bag_scrolled")
	var grid := p._scroll.get_child(0) as GridContainer
	var cols := grid.columns
	check(p._item_buttons[0].focus_neighbor_bottom==p._item_buttons[cols].get_path(),"focus uses actual column count")
	await drop(p)

func world_flow() -> void:
	var destination := "old_salt_road:fish_salt_spring"
	check(bool(Points.track(destination).ok),"track real destination")
	check(G.reload_save() and String(Points.target().get("id",""))==destination,"destination survives save reload")
	var cfg := TableCache.main_world_map("old_salt_road")
	check(Points.position(Points.find(destination))==Vector2(cfg.entities.fish_salt_spring.at[0],cfg.entities.fish_salt_spring.at[1]),"map and interaction use identical authored coordinates")
	var run := RunState.new()
	run.setup({"role_id":"zs","theme":"forest","level":35,"seed":71})
	MapScene.pending_cfg={"mode":"main_world","main_map_id":"old_salt_road","run":run,"node":{"type":"normal","layer":1,"index":0}}
	var map := preload("res://src/explore/MapScene.tscn").instantiate()
	add_child(map)
	await frames(10)
	check(map._hud_target_info().get("poi_id","")==destination,"explicit destination takes priority in HUD")
	check(is_equal_approx(map._player_anim.scale.x,.70),"walking hero uses shared scale")
	G.mount_buy("horse")
	G.mount_set_riding(true,false)
	map._sync_mount_visual()
	await frames()
	check(is_equal_approx(map._mount_anim.scale.x,.86),"mounted scale is calibrated")
	await shot("world_mounted")
	map._toggle_big_map()
	await frames()
	check(map._big_map!=null and map._modal_open(),"world geographic map freezes gameplay")
	map._big_map.select_point(destination)
	await frames()
	await shot("world_route")
	map._close_big_map()
	await frames()
	map._on_compass_tapped()
	for tick in 600:
		await get_tree().physics_frame
		if map._player.position.distance_to(Points.position(Points.find(destination)))<44:break
		if not map._auto_walk:break
	check(map._player.position.distance_to(Points.position(Points.find(destination)))<44,"actual mounted navigation reaches selected fishing point")
	check(map._fishing_panel==null,"arriving alone does not start fishing remotely or automatically")
	var actual: Node2D=null
	for entity in map._quest_entities:
		if entity.eid=="fish_salt_spring":actual=entity;break
	check(actual!=null,"destination has a real scene interaction")
	if actual!=null:
		map._player.position=actual.position+Vector2(0,20)
		map._tick_round_interaction()
		map._round_interact_pressed()
		await frames()
		check(map._fishing_panel!=null,"arrive and explicitly interact opens matching fishing scene")
		if map._fishing_panel!=null:
			check(map._fishing_panel.spot_id=="fish_salt_spring","fishing scene matches selected destination")
			map._fishing_panel.close()
			await frames()
	check(Points.cancel() and Points.target().is_empty(),"cancel clears shared destination")
	await drop(map)
