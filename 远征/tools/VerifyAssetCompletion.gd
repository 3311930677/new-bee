extends Node
## Resource/export lookup and real rendered map state checks. Always use isolated APPDATA.
const Art := preload("res://src/world/AssetCompletion.gd")
const Review := preload("res://src/ui/ReviewFixUI.gd")
const Icons := preload("res://src/ui/UIIcons.gd")
const OUT := "res://shots/asset_completion_20261024/"
const EQUIPMENT := ["tpl_sword_starfall","tpl_spear_windpiercer","tpl_staff_glacierheart",
	"tpl_hammer_dawnlight","tpl_armor_expedition","tpl_acc_archery_ring"]
var checks := 0
var failures := 0
var records: Array = []
var capture := false

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("ASSET_COMPLETION_FAIL " + detail)

func frames(n := 4) -> void:
	for i in n: await get_tree().process_frame

func photo(id: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(OUT+id+".png")==OK,"capture "+id)

func discard(node: Node) -> void:
	remove_child(node)
	node.queue_free()
	await frames(2)

func fixture() -> void:
	G.SAVE_PATH = "res://tools/_logs/asset_completion_save.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.player_name = "素材验收"
	G.set_meta("ui_review_mode", true)
	G.gm_unlock_all_features()
	G.prog.level = 32
	G.wallet = {"gold":125480,"expedition":120,"soul":3860,"honor":900}

func _ready() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUT)
	fixture()
	get_window().size = Vector2i(480,800)
	get_window().content_scale_size = Vector2i(480,800)
	await frames()
	for key in Art.manifest():
		var tex := Art.texture(String(key))
		check(tex != null,"texture exists "+String(key))
		if tex != null:
			check(tex.get_width()>0 and tex.get_height()>0,"nonempty texture "+String(key))
			check(tex.get_image()!=null and not tex.get_image().is_invisible(),"visible alpha "+String(key))
	# Simulate export lookup: bypass filesystem enumeration entirely.
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/resource_manifest.json"))
	G._res_index = manifest.duplicate()
	G._res_indexed = true
	G._tex_cache.clear()
	for id in EQUIPMENT:
		check(G.equip_tpl(id).icon==id,"dedicated equipment identity "+id)
		check(G.res_tex(id)!=null and Review.item(id)!=null,"export equipment lookup "+id)
		check(Review.item(id).get_meta("pixel_art",false),"pixel rendering hint "+id)
	var all_equip: Dictionary = TableCache._load("res://data/equip.json")
	for row in all_equip.templates:
		check(Review.item(String(row.id))!=null,"all equipment icons "+String(row.id))
	for id in ["frost_letter","mine_record","gate_stamp","frost_reply","veil_seal","frost_nameplate","frost_parcel","return_old_letter","return_mailbag"]:
		var key: String = "itm_"+String(id)
		check(G.res_path(key).ends_with(".png") and G.res_tex(key)!=null,"task bitmap export lookup "+key)
	for key in Art.HOME_KEYS:
		check(Icons.refined_path(key)==Art.home_path(key),"shared home resolver "+key)
		check(Icons.texture(key)!=null,"home texture "+key)
	var fish_paths: Dictionary={}
	for id in ["fish_salt","fish_port","fish_tide","fish_frost"]:
		var key: String=G.item_icon(id)
		check(key=="itm_"+id and G.res_tex(key)!=null,"dedicated fish inventory icon "+id)
		fish_paths[G.res_path(key)]=true
	check(fish_paths.size()==4,"four fish species have distinct art")
	for key in ["gold","expedition","soul","honor"]:
		check(G.res_path("cur_"+key)==Art.home_path("coin" if key=="gold" else key),"currency panel uses home art "+key)
	for mid in TableCache.main_world_config().maps:
		for eid in TableCache.main_world_config().maps[mid].get("entities",{}):
			var row: Dictionary = TableCache.main_world_config().maps[mid].entities[eid]
			if String(row.get("art",""))=="salt_marks":
				check(Art.SALT_PROPS.has(eid),"explicit salt prop semantic "+String(eid))
			if String(row.get("art",""))=="tracks":
				check(Art.TRACK_PROPS.has(eid),"explicit track semantic "+String(eid))
	for template in TableCache._load("res://data/world_commissions.json").templates:
		for step in template.steps:
			if step.get("art","")=="tracks" and step.get("kind","")!="defeat":
				check(Art.TRACK_PROPS.has(step.id),"commission meaning "+String(step.id))
	check(not Art.TRACK_PROPS.has("wc_watch_2"),"combat commission remains a monster")
	# Production home and bag render the completed icons.
	var home := preload("res://src/ui/GameHome.tscn").instantiate()
	add_child(home)
	await frames(8)
	await photo("home_480x800")
	await discard(home)
	for id in EQUIPMENT: G.inv_grant_equip({"tpl":id,"rarity":4,"n":1},false)
	var bag := preload("res://src/ui/BagPanel.gd").new()
	add_child(bag)
	await frames(6)
	check(bag._item_buttons.size()>=6,"production bag contains dedicated items")
	await photo("bag_equipment")
	G.items.clear()
	for id in ["frost_letter","mine_record","gate_stamp","frost_reply","veil_seal","frost_nameplate","frost_parcel","return_old_letter","return_mailbag"]:
		G.items[id] = 1
	for id in ["fish_salt","fish_port","fish_tide","fish_frost"]:G.items[id]=1
	bag._tab = "mat"
	bag._refresh()
	await frames(5)
	await photo("bag_task_items")
	await discard(bag)
	get_window().size = Vector2i(480,1067)
	get_window().content_scale_size = Vector2i(480,1067)
	var tall_home := preload("res://src/ui/GameHome.tscn").instantiate()
	add_child(tall_home)
	await frames(6)
	await photo("home_480x1067")
	await discard(tall_home)
	get_window().size = Vector2i(480,800)
	get_window().content_scale_size = Vector2i(480,800)
	for mid in TableCache.main_world_config().maps:
		await map_case(String(mid),false)
	# Dynamic visual branches are explicitly rendered, not inferred from map existence.
	for mid in ["stele_cavern","tidal_gate","rift_mine_vault","stele_entry","stele_resonance","stele_core","shenyuan_port"]:
		await map_case(mid,true)
	# Branches can be saved independently; verify partial mechanisms as well.
	await map_case("tidal_gate",false,{"act2_tide_gate_1":true},"upper_released")
	await map_case("tidal_gate",false,{"act2_tide_gate_1":true,"act2_tide_gate_2":true,"act2_tide_bridge_open":true},"bridge_only")
	await map_case("tidal_gate",false,{"act2_tide_gate_1":true,"act2_tide_gate_2":true,"act2_tide_cargo_saved":true},"cargo_only")
	await map_case("tidal_gate",false,{"act2_tide_gate_2":true},"legacy_drained")
	await map_case("rift_mine_vault",false,{"act3_mine_second_wind":true},"ventilated_only")
	await map_case("rift_mine_vault",false,{"act3_mine_switch":true},"rescue_restored")
	await map_case("stele_resonance",false,{"act4_forest_voice":true},"forest_only")
	await map_case("stele_resonance",false,{"act4_forest_voice":true,"act4_tide_voice":true},"two_voices")
	await map_case("stele_cavern",false,{"act1_stele_seat_1":true,"act1_echo_crack_left":true},"partial_channels")
	var summary := {"checks":checks,"failures":failures,"textures":Art.manifest().size(),"maps":records}
	var file := FileAccess.open("res://tools/_logs/asset_completion_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(summary,"\t"))
	file.close()
	print("ASSET_COMPLETION_OK checks=%d failures=%d textures=%d map_cases=%d"%[checks,failures,Art.manifest().size(),records.size()])
	get_tree().quit(0 if failures==0 else 1)

func map_case(mid: String, completed: bool, overrides: Dictionary={}, label: String="") -> void:
	fixture()
	G.prog.flags.merge({"act1_stele_rooms_v1":true,"act2_tidal_rooms_v1":true,
		"act3_mine_rooms_v1":true,"act3_supply_choice":"merchant"},true)
	for flag in ["act1_stele_clue","act1_echo_crack_left","act1_echo_crack_middle","act1_echo_crack_right",
		"act1_stele_seat_1","act1_stele_seat_2","act1_stele_shadow_avoided",
		"act2_tide_gate_1","act2_tide_gate_2","act2_tide_bridge_open","act2_tide_cargo_saved",
		"act3_mine_second_wind","act3_mine_switch","act4_return_anchor","act4_forest_voice",
		"act4_tide_voice","act4_snow_voice","act4_voices_aligned","act4_avatar_down"]:
		G.prog.flags.erase(flag)
	if completed:
		for flag in ["act1_stele_clue","act1_echo_crack_left","act1_echo_crack_middle","act1_echo_crack_right",
			"act1_stele_seat_1","act1_stele_seat_2","act1_stele_shadow_avoided",
			"act2_tide_gate_1","act2_tide_gate_2","act2_tide_bridge_open","act2_tide_cargo_saved",
			"act3_mine_second_wind","act3_mine_switch","act4_return_anchor","act4_forest_voice",
			"act4_tide_voice","act4_snow_voice","act4_voices_aligned","act4_avatar_down"]:
			G.prog.flags[flag] = true
		G.prog.flags["act2_pier_rope"] = "replace"
	G.prog.flags.merge(overrides,true)
	# Rebuild from serialized save data instead of relying on a live ground node.
	G.prog = JSON.parse_string(JSON.stringify(G.prog))
	G.economy_state()["port_event"] = "embank" if completed else "dredge"
	var row: Dictionary = TableCache.main_world_map(mid)
	var run := RunState.new()
	run.setup({"role_id":"zs","theme":String(row.get("theme","forest")),"level":32,"seed":71})
	G.prog.main_world = {"map_id":mid}
	G.mount_set_riding(false,false)
	MapScene.pending_cfg = {"mode":"main_world","main_map_id":mid,"run":run,"node":{"type":"normal","layer":1,"index":0}}
	var scene := preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
	add_child(scene)
	await frames(5)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	check(scene._world!=null and scene._player!=null,"map builds "+mid)
	scene._player.position = Vector2(480,650)
	for child in scene._player.get_children():
		if child is Camera2D:
			child.reset_smoothing()
			child.force_update_scroll()
	if mid=="rift_mine_vault":
		check(scene._mine_ground!=null,"mine visual is enabled")
		check(scene._mine_ground.get("ventilated")==bool(G.prog.flags.get("act3_mine_second_wind",false)) and scene._mine_ground.get("rescued")==bool(G.prog.flags.get("act3_mine_switch",false)),"mine state retained")
	if mid=="tidal_gate":
		check(scene._tidal_ground.dynamic_water and scene._tidal_ground.bridge_drained==bool(G.prog.flags.get("act2_tide_gate_2",false)),"tidal state retained")
		check(scene._tidal_ground.upper_released==bool(G.prog.flags.get("act2_tide_gate_1",false)),"upper water state retained")
		check(scene._tidal_ground.passages==scene._tidal_passages(),"saved passage branch retained")
		if label=="bridge_only":check(scene._tidal_ground.passages=="bridge","bridge branch remains distinct")
		if label=="cargo_only":check(scene._tidal_ground.passages=="cargo","cargo branch remains distinct")
	var state_before := G.prog.duplicate(true)
	var wallet_before := G.wallet.duplicate(true)
	for ground in scene._world.get_children():
		if ground is CanvasItem: ground.queue_redraw()
	await frames(5)
	var id := mid + ("_"+label if not label.is_empty() else "_completed" if completed else "_initial")
	await photo(id)
	check(G.prog==state_before and G.wallet==wallet_before,"render does not mutate gameplay "+id)
	# Conditional port feedback and the rescued mine cart are outside the center view.
	if mid=="shenyuan_port" or (mid=="rift_mine_vault" and completed):
		var at := Vector2(780,490) if completed else Vector2(230,470)
		if mid=="rift_mine_vault": at = Vector2(540,410)
		for child in scene._player.get_children():
			if child is Camera2D:
				child.top_level = true
				child.global_position = at
				child.reset_smoothing()
				child.force_update_scroll()
		await frames(3)
		await photo(id+"_detail")
	records.append({"id":id,"rendered":capture,"flags":G.prog.flags.duplicate(true)})
	await discard(scene)
