extends Node
var OUT := "res://shots/opus_round1_20261009/"
var failures := 0
var cases := 0
var capture := false
var page: Control

func check(ok: bool, reason: String) -> void:
	cases += 1
	if not ok:
		failures += 1
		push_error("ROUND1_FAIL: " + reason)

func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	for down in [true,false]:
		var e := InputEventMouseButton.new()
		e.position = point
		e.global_position = point
		e.pressed = down
		e.button_index = MOUSE_BUTTON_LEFT
		get_viewport().push_input(e,true)
		await get_tree().process_frame

func shot(name_text: String) -> void:
	for i in 3: await get_tree().process_frame
	if not capture: return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(OUT+name_text+".png") == OK,"截图保存 " + name_text)
	preload("res://tools/UITextAudit.gd").write(page,OUT+name_text+".text.json")

func gray_shot(name_text: String) -> void:
	if not capture: return
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var surface := ColorRect.new()
	surface.size = get_viewport().get_visible_rect().size
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform sampler2D screen : hint_screen_texture,filter_nearest; void fragment(){vec3 c=texture(screen,SCREEN_UV).rgb; float v=dot(c,vec3(0.2126,0.7152,0.0722)); COLOR=vec4(vec3(v),1.0);}"
	var material := ShaderMaterial.new()
	material.shader = shader
	surface.material = material
	layer.add_child(surface)
	await shot(name_text)
	layer.queue_free()
	await get_tree().process_frame

func close_page() -> void:
	page.queue_free()
	await get_tree().process_frame

func make_map(id: String, height: int = 800, mode: String = "main_world") -> MapScene:
	get_window().size = Vector2i(480,height)
	await get_tree().process_frame
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.player_name = "角色昵称"
	G.prog.level = 12
	G.wallet.gold = 12800
	G.collect_pet("pet_rockturtle")
	G.collect_pet("pet_thunderhawk")
	G.prog["main_world"] = {"map_id":id,"layout_version":3}
	var st := RunState.new()
	st.setup({"theme":"forest","role_id":"zs","level":12,"active_pet":"pet_rockturtle","bench_pet":"pet_thunderhawk","potions":2,"seed":18})
	MapScene.pending_cfg = {"mode":mode,"main_map_id":id,"run":st,"node":{"type":"normal","layer":0,"index":0}}
	var map := preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
	page = map
	add_child(map)
	await get_tree().process_frame
	return map

func check_hotspots(map: MapScene, safe: Rect2) -> void:
	var controls: Array[Control] = [map._main_gold_chip,map._minimap,map._round_fold,map._joy,map._round_potion,map._sprint_btn,map._pet_btn]
	for child in map._hud.get_children():
		if child is Button and child.name in ["Action_营帐","Action_撤离","Action_骑乘"]: controls.append(child)
	for task in map._round_tasks:
		if task.visible: controls.append(task)
	for i in controls.size():
		var a := controls[i]
		if not a.visible: continue
		check(safe.encloses(a.get_global_rect()),"安全区容纳 " + a.name)
		check(a.size.x >= 44 and a.size.y >= 44,"触控尺寸 " + a.name)
		for j in range(i+1,controls.size()):
			# The fold button now occupies a reserved part of its parent quest plate.
			if a.is_ancestor_of(controls[j]) or controls[j].is_ancestor_of(a):continue
			if controls[j].visible: check(not a.get_global_rect().intersects(controls[j].get_global_rect()),"热区不重叠 " + a.name + "/" + controls[j].name)

func _ready() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--outdir="): OUT = arg.trim_prefix("--outdir=").trim_suffix("/")+"/"
	G.SAVE_PATH = OUT + "isolated_save.json"
	G.set_meta("ui_review_mode",true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for height in [800,1067]:
		get_window().size = Vector2i(480,height)
		await get_tree().process_frame
		page = preload("res://src/ui/Title.tscn").instantiate()
		add_child(page)
		await get_tree().process_frame
		check(page._btns.size()==4,"四个启动动作保留")
		check(page._btns[0].has_focus(),"开始游戏默认焦点")
		var key := InputEventKey.new()
		key.keycode = KEY_DOWN
		key.pressed = true
		get_viewport().push_input(key,true)
		await get_tree().process_frame
		check(page._btns[1].has_focus(),"真实向下键进入次级入口")
		key = InputEventKey.new()
		key.keycode = KEY_RIGHT
		key.pressed = true
		get_viewport().push_input(key,true)
		await get_tree().process_frame
		check(page._btns[2].has_focus(),"真实向右键移到设置")
		page._update_focus(0,false)
		for i in page._btns.size():
			for j in range(i+1,page._btns.size()): check(not page._btns[i].get_global_rect().intersects(page._btns[j].get_global_rect()),"菜单热区不重叠")
		await shot("title_%d" % height)
		if OUT.contains("opus_review"):
			check(page._subtitle.text=="昭元行旅录","副标题为原生可修改文字")
			check(page._brand.size.is_equal_approx(Vector2(300,120)),"正式字标显示尺寸 " + str(page._brand.size))
			check(page._separators.size()==2,"次级入口两处分隔点")
			page._btns[0].release_focus()
			await shot("title_normal_%d" % height)
			page._update_focus(0,false)
		var safe := Rect2(8,44,464,height-78)
		page._layout_page(safe)
		for b in page._btns: check(safe.encloses(b.get_global_rect()),"菜单安全区")
		await shot("title_safe_%d" % height)
		page._layout_page()
		page._update_focus(2,false)
		await shot("title_focus_settings_%d" % height)
		await click(page._btns[2])
		check(page._settings != null,"实际点击菜单设置打开现有面板")
		page._settings.queue_free()
		page._settings = null
		await get_tree().process_frame
		await click(page._btns[1])
		check(page._intro_panel != null,"实际点击介绍打开现有手记")
		await close_page()
		var map := await make_map("lorin_wilds",height)
		map._player.position = Vector2(480,930)
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = map._joy.get_global_rect().get_center()
		touch.pressed = true
		get_viewport().push_input(touch,true)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = touch.position + Vector2(30,0)
		get_viewport().push_input(drag,true)
		check(map._joy.vector.x > 0.5,"真实触控拖动摇杆")
		var other := InputEventScreenTouch.new()
		other.index = 1
		other.position = touch.position
		other.pressed = false
		get_viewport().push_input(other,true)
		check(map._joy.vector.x > 0.5,"第二触点释放不会打断移动")
		touch.pressed = false
		get_viewport().push_input(touch,true)
		check(map._joy.vector == Vector2.ZERO,"摇杆主触点释放停止移动")
		map._refresh_hud()
		check_hotspots(map,map.get_viewport_rect())
		check(map._round_potion.get_node("ActionIcon").texture != null,"药剂纹理已接入")
		if OUT.contains("opus_review"):
			check(map._round_potion.get_node("ActionIcon").size==Vector2(28,28),"药剂可见图标占28px画框")
			check(map._potion_badge.get_parent().size.y==18,"药剂角标底高18px")
			check(map._round_fold.get_node("ActionIcon").texture!=null and not map._round_fold.get_node("Glyph").visible,"卷轴替代菜单字符")
			var terrain := map._minimap._cartography.terrain_thumbnail(map)
			check(terrain.get_width()>96,"地形缩略数据独立于96px显示区域")
			check(map._minimap._project(map._player.position).is_equal_approx(map._minimap._map_rect().get_center()),"小地图玩家固定居中")
		await shot("town_%d" % height)
		if OUT.contains("opus_review"): await gray_shot("town_gray_%d" % height)
		await click(map._sprint_btn)
		check(map._sprint and map._sprint_btn.get_node("Caption").text == "疾行中","实际点击疾行开启，文字与图形均变化")
		await shot("sprint_on_%d" % height)
		if OUT.contains("opus_review"): await gray_shot("sprint_on_gray_%d" % height)
		await click(map._sprint_btn)
		check(not map._sprint,"实际点击疾行关闭")
		await click(map._round_fold)
		check(map._round_expanded,"实际点击任务展开")
		await shot("tasks_expanded_%d" % height)
		await click(map._round_fold)
		check(map._round_collapsed,"实际点击任务收起")
		await shot("tasks_collapsed_%d" % height)
		map._round_collapsed = false
		map._layout_round_tasks()
		map._layout_round1_hud(safe)
		check_hotspots(map,safe)
		await shot("town_safe_%d" % height)
		map._layout_round1_hud()
		G.wallet.gold = 999999999
		G.player_name = "这是一个十二字长昵称测试"
		map._refresh_hud()
		check(map._main_gold_l.text == "9.99亿","金币九位缩写正确")
		check(int(map._main_gold_l.get_meta("hud_amount"))==999999999,"完整金币数保留")
		var words := "主线需要穿过城门与执事闻叔交谈然后继续前往古道驿亭调查"
		preload("res://src/ui/WorldHUD.gd").update_task(map._main_story_l,words)
		preload("res://src/ui/WorldHUD.gd").update_task(map._city_content._quest_lbl,words)
		map._layout_round_tasks()
		for task in map._round_tasks:
			if task.visible: check(task.position.y+task.size.y<=190 if height==800 else task.position.y+task.size.y<=236,"长任务不侵占保证净空区域")
		await shot("stress_%d" % height)
		await click(map._main_gold_chip)
		check(G.modal_count()==1,"缩写金币点击仍可查看完整详情")
		if G.modal_count()>0: G.close_info_popup(G._modals.back().layer)
		map.st.hp = roundi(map.st.max_hp()*0.2)
		map._refresh_hud()
		await shot("low_hp_%d" % height)
		var before := map.st.hp
		await click(map._round_potion)
		check(map.st.hp>before and map.st.potions==1,"真实点击药剂治疗并扣除数量")
		map.st.potions=0
		map._refresh_hud()
		await shot("potion_zero_%d" % height)
		await click(map._minimap)
		check(map._big_map!=null,"真实点击小地图展开")
		await shot("map_expanded_%d" % height)
		if OUT.contains("opus_review"):
			check(map.get_meta("terrain_thumbnail")==map._minimap._cartography.terrain_thumbnail(map),"展开与局部地图共享同一地形纹理")
		map._close_big_map()
		if OUT.contains("opus_review"):
			# Freeze only the automatic contact step to photograph the same eligible state.
			await get_tree().create_timer(2.0).timeout
			map.set_physics_process(false)
			map._city_content.set_physics_process(false)
			var npc: Node2D = map._city_content._npcs[0]
			npc.set("cooled",false)
			map._player.position=npc.position+Vector2(0,70)
			map._tick_round_interaction()
			check(map._round_interact.visible and map._round_interact.disabled,"超出原交互距离时只提示靠近")
			await shot("interaction_near_%d" % height)
			map._player.position=npc.position+Vector2(0,38)
			map._tick_round_interaction()
			check(map._round_interact.visible and not map._round_interact.disabled,"原交互距离内显示可用圆盘")
			await shot("interaction_ready_%d" % height)
			await click(map._round_interact)
			check(map._city_content.has_modal(),"实际点击情境圆盘打开原NPC对话")
		await close_page()
	for id in ["maple_road","frost_post"]:
		var map := await make_map(id)
		check_hotspots(map,map.get_viewport_rect())
		await shot("field_"+id)
		await close_page()
	var run_map := await make_map("",800,"expedition")
	check_hotspots(run_map,run_map.get_viewport_rect())
	check(run_map._hud.get_node("Action_撤离").get("warning"),"历练使用明确撤离态")
	await shot("expedition_exit")
	await close_page()
	print("ROUND1_UI_OK cases=%d failures=%d" % [cases,failures] if failures==0 else "ROUND1_UI_FAIL cases=%d failures=%d" % [cases,failures])
	get_tree().quit(0 if failures==0 else 1)
