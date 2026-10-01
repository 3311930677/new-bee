extends "res://tools/VerifyThirdAct.gd"

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_frost_art.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	await _run()
	print("FROST_ART_OK" if _fails == 0 else "FROST_ART_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)

func _run() -> void:
	var done: Array = []
	for i in range(1, 29): done.append("s%02d" % i)
	G.prog.story = {"step": "", "done": done, "goals": {}}
	G.prog.level = 42
	G.ensure_starter_equip(true)
	var map := await _enter("frost_post")
	map.set_process(false)
	map.set_physics_process(false)
	var city: CityScene = map._city_content
	city.set_process(false)
	var rows := FrostCityArt.rows()
	_check(rows.size() == 3 and city._npcs.size() == 3, "三名居民完整接入")
	for npc in city._npcs:
		var id := String(npc.data.id)
		var frames: SpriteFrames = npc.frames
		_check(frames != null and frames.get_frame_count(&"idle") == 4, "四帧待机 " + id)
		_check(FrostCityArt.idle(id) == frames, "待机缓存 " + id)
		var sp := npc.get_node("Idle") as AnimatedSprite2D
		_check(sp != null and sp.material != null, "实际播放精灵和透明边缘 " + id)
		var row: Dictionary = rows[id]
		var canvas := Vector2(float(row.canvas[0]), float(row.canvas[1]))
		var source := (frames.get_frame_texture(&"idle", 0) as AtlasTexture).atlas
		var source_image := source.get_image()
		var height_min := 10000.0
		var height_max := 0.0
		for i in 4:
			var at := frames.get_frame_texture(&"idle", i) as AtlasTexture
			_check(at.get_size() == canvas, "统一逻辑画布 " + id)
			var r := at.region
			var min_x := int(r.end.x)
			var max_x := int(r.position.x)
			for y in range(int(r.end.y) - 7, int(r.end.y)):
				for x in range(int(r.position.x), int(r.end.x)):
					if source_image.get_pixel(x, y).a >= 0.5:
						min_x = mini(min_x, x)
						max_x = maxi(max_x, x)
			var foot_x := (min_x + max_x + 1) * 0.5 - r.position.x + at.margin.position.x
			_check(absf(foot_x - canvas.x * 0.5) < 0.01, "四帧左右脚中心登记 " + id)
			_check(absf(at.margin.position.y + r.size.y - canvas.y) < 0.01, "四帧脚底登记 " + id)
			_check(absf(sp.position.y + canvas.y * sp.scale.y * 0.5) < 0.01, "脚底落在实际NPC原点 " + id)
			height_min = minf(height_min, r.size.y * sp.scale.y)
			height_max = maxf(height_max, r.size.y * sp.scale.y)
		_check(height_max - height_min < 0.4, "呼吸身体尺度稳定 " + id)
		var portrait := city._npc_portrait_tex(id, false) as AtlasTexture
		_check(portrait != null and portrait.atlas == source, "对话头像同源 " + id)
		_check(portrait.region.position.y == (row.frames[0].region[1]), "头像裁切包含头部 " + id)
		city._open_dialog(npc.data, false)
		_check(city._panel != null, "原居民交互可打开 " + id)
		city._close_panel()
	for building in city._buildings:
		_check(building._reference_art and building.art != null and building.built(), "建筑素材实际接入 " + String(building.data.id))
		var shape := building.get_child(0) as CollisionShape2D
		_check((shape.shape as RectangleShape2D).size.is_equal_approx(Vector2(3.3 * 48 * 0.8, 2.7 * 48 * 0.3)), "原基座碰撞保持")
		_check(is_equal_approx(building._art_top() + 192.0 * building.art.get_height() / building.art.get_width(), 4.0), "建筑基座固定")
	var ground: Node = null
	for child in map.get_children():
		if child.get_script() == load("res://src/explore/ThirdActGround.gd"): ground = child
	_check(ground != null and ground._brazier_art != null and ground.use_reference_ground, "细雪背景及火盆接入")
	_check(not ground._brazier_lit(Vector2(365, 660)) and ground._brazier_lit(Vector2(595, 970)), "未修复风灯熄灭、普通火盆保持点亮")
	var wind_marker: Node = null
	for entity in map._quest_entities:
		if entity.eid == "a3_wind_lamp": wind_marker = entity
	_check(wind_marker != null and wind_marker._uses_ground_art, "支线标记不重复绘制占位火盆")
	_check(wind_marker.position == Vector2(365, 660), "修灯交互位置不变")
	for choice in ["coal", "shield"]:
		G.prog.get_or_add("flags", {})["act3_brazier_choice"] = choice
		ground._process(0.0)
		_check(ground._brazier_choice == choice, "修复选择仍驱动火盆 " + choice)
		_check(ground._brazier_lit(Vector2(365, 660)), "修复后风灯点亮 " + choice)
		_check(G.save_game() and G.reload_save(), "永久选择存读 " + choice)
		_check(G.prog.flags.act3_brazier_choice == choice, "永久选择保持 " + choice)
	for screen_height in [800, 1067]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(480, screen_height)
		add_child(viewport)
		map.reparent(viewport)
		map._player.position = Vector2(480, 910)
		await get_tree().process_frame
		city._open_dialog(G.city_npc("npc_frost_guard"), false)
		var panel := city._panel.get_child(0) as Control
		_check(is_equal_approx(panel.position.y, screen_height - 190.0), "对话随屏幕底部定位 %d" % screen_height)
		_check(panel.position.y + panel.size.y <= screen_height - 39.0, "对话底部可见 %d" % screen_height)
		city._toast("霜关显示检查")
		_check(is_equal_approx(city._toast_lbl.position.y, screen_height - 240.0), "提示位于对话上方 %d" % screen_height)
		city._close_panel()
		map.reparent(self)
		viewport.queue_free()
		await get_tree().process_frame
	map.queue_free()
	await get_tree().process_frame
