extends Node
const OUT := "res://shots/craft_ui_20261005"
const Art := preload("res://src/world/WorldPropArt.gd")
const Craft := preload("res://src/ui/CraftUI.gd")

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_world_art_capture.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "fs"
	G.player_name = "陆川愿"
	G.prog.level=12
	G.prog.exp=100
	G.wallet={"gold":100789,"expedition":1011,"soul":979,"honor":9}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for map_id in ["lorin_wilds","maple_road","broken_slope","frost_post","old_salt_road","shenyuan_port","rift_mine_road"]:
		var run := RunState.new()
		run.setup({"theme":"forest","role_id":"fs","level":12,"active_pet":"pet_rockturtle","bench_pet":"","potions":2,"seed":19})
		MapScene.pending_cfg={"mode":"main_world","main_map_id":map_id,"run":run,"node":{"type":"normal","layer":0,"index":0}}
		var map: Control=preload("res://src/explore/MapScene.tscn").instantiate()
		add_child(map)
		map._player.position=Vector2(480,340)
		await capture("world_"+map_id)
		map.queue_free()
		await get_tree().process_frame
	await catalog([["指示牌","sign"],["修复路牌","restored"],["封锁路牌","sealed"],["矿脉","vein"],["碑灵祭坛","altar"],["藏宝箱","chest"],["草药","herb"],["驿亭","post"],["风铃","chime"],["风机","vent"],["讯号旗","flag"],["交互标记","marker"]],"world_props","世界道具精修")
	await catalog([["矿车","mine_cart"],["霜关火盆","frost_brazier"],["霜苔","frost_lichen"],["冰隙回响","frost_echo"],["绳索","rope"],["青羽","feather"],["断轴盐车","salt_cart"],["潮痕货堆","tide_cargo"]],"world_story_props","剧情道具精修")
	await catalog([["归途灯","lantern"],["归信","letter"],["潮芽","tidebud"],["雪花","snowflower"],["符石","rune"],["信箱","mailbox"],["路簿灯架","road_ledger"],["港务潮纸","tide_board"],["轮岗桌","watch_table"],["练习靶","dummy"],["钓鱼点","fishing"],["水闸隔堰","barrier"]],"world_return_props","归途与设施精修")
	await catalog([["灯火修复","lamp_beacon"],["石标路线","lamp_marker"],["未燃灯火","lamp_unlit"],["保留符痕","rune_trace"],["符石静默","rune_quiet"],["符石共鸣","rune_echo"],["边城托付","memory_zhaoyuan1"],["边城互信","memory_zhaoyuan2"],["港务托付","memory_shenyuan1"],["港务互信","memory_shenyuan2"],["霜关托付","memory_frost1"],["霜关互信","memory_frost2"]],"world_prop_states","剧情状态精修")
	await gate_catalog()
	print("WORLD_ART_CAPTURE_OK")
	get_tree().quit()

func catalog(entries: Array, filename: String, title: String) -> void:
	var catalog := Control.new()
	catalog.size=Vector2(480,800)
	add_child(catalog)
	var bg := ColorRect.new()
	bg.size=catalog.size
	bg.color=Color("23343c")
	catalog.add_child(bg)
	catalog.add_child(Craft.label(title,Vector2(24,20),Vector2(420,42),24,Craft.GOLD,true,true))
	for i in entries.size():
		var x := 24+(i%3)*152
		var y := 90+(i/3)*172
		var panel := Craft.panel(Vector2(x,y),Vector2(128,156),.85)
		catalog.add_child(panel)
		var prop := PropPreview.new()
		prop.key=entries[i][1]
		prop.position=Vector2(64,112)
		panel.add_child(prop)
		var name_l := Craft.label(entries[i][0],Vector2(4,127),Vector2(120,24),15,Craft.WHITE)
		name_l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(name_l)
	await capture(filename)
	catalog.queue_free()
	await get_tree().process_frame

func gate_catalog() -> void:
	var page := Control.new()
	page.size = Vector2(480,800)
	add_child(page)
	var bg := ColorRect.new()
	bg.size = page.size
	bg.color = Color("23343c")
	page.add_child(bg)
	page.add_child(Craft.label("水闸通行与封锁",Vector2(24,20),Vector2(432,42),24,Craft.GOLD,true,true))
	for i in 4:
		var route: String = ["sealed","bridge","cargo","both"][i]
		var y := 90+i*170
		page.add_child(Craft.label(["隔堰封锁","左侧栈桥开放","右侧暗渠开放","双侧均可通行"][i],Vector2(24,y),Vector2(432,30),16,Craft.WHITE))
		var gate := MapScene._TidalRoomGate.new()
		gate.route = route
		gate.position = Vector2(240,y+100)
		page.add_child(gate)
	await capture("world_gate_states")
	page.queue_free()
	await get_tree().process_frame

func capture(words: String) -> void:
	await get_tree().create_timer(.45).timeout
	await RenderingServer.frame_post_draw
	var err:=get_viewport().get_texture().get_image().save_png(OUT+"/%s.png" % words)
	if err!=OK:
		push_error("Capture failed: "+words)
		get_tree().quit(1)

class PropPreview extends Node2D:
	var key := "sign"
	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if key=="sealed": material = Art.muted_material()
	func _draw() -> void:
		match key:
			"sign": Art.signpost(self)
			"restored","sealed": Art.signpost(self,key)
			"vein": Art.vein(self)
			"altar": Art.altar(self)
			"chest": Art.chest(self)
			"herb": Art.herb(self)
			"post": Art.post(self)
			"chime": Art.chime(self)
			"vent": Art.vent(self)
			"flag": Art.signal_flags(self)
			"marker": Art.marker(self,Vector2(0,-48),Color("ffe096"))
			_:
				if key.begins_with("lamp_"): preload("res://src/explore/ReturnJourneyProps.gd").draw_prop(self,"return_lamp",key.trim_prefix("lamp_"))
				elif key.begins_with("rune_"): preload("res://src/explore/ReturnJourneyProps.gd").draw_prop(self,"return_rune",key.trim_prefix("rune_"))
				elif key.begins_with("memory_"): preload("res://src/explore/RegionalMemoryScenes.gd").draw_scene(self,key.trim_prefix("memory_").left(-1),int(key.right(1)))
				elif Art.STORY_REGIONS.has(key): Art.story(self,key,{"mine_cart":68,"frost_brazier":76,"frost_lichen":40,"frost_echo":76,"rope":48,"feather":44,"salt_cart":94,"tide_cargo":72}[key])
				else: Art.supplementary(self,key,{"letter":30,"tidebud":43,"snowflower":43,"fishing":68,"barrier":52}.get(key,72))
