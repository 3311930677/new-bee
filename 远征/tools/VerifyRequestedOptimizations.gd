extends Node
const Points := preload("res://src/world/WorldPoints.gd")
const Presentation := preload("res://src/world/WorldPresentation.gd")
const OUT := "res://shots/requested_optimizations_20261026/"
var errors: Array[String]=[]
var checks:=0
var capture:=false
var map_stats: Array=[]
var current: MapScene
var overview_count:=0
var closed_count:=0

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error("REQUESTED_FAIL "+message)

func frames(n:=6) -> void:
	for i in n:await get_tree().process_frame

func shot(id: String) -> void:
	if not capture:return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(OUT+id+".png")==OK,"screenshot "+id)

func click(control: Control,touch:=false) -> void:
	check(control!=null,"click target exists")
	if control==null:return
	var parent:=control.get_parent()
	while parent!=null:
		if parent is ScrollContainer:parent.ensure_control_visible(control)
		parent=parent.get_parent()
	await frames()
	var at:=control.get_global_rect().get_center()
	check(get_viewport().get_visible_rect().has_point(at),"button is onscreen "+str(control.name))
	if not touch:
		var motion:=InputEventMouseMotion.new()
		motion.position=at
		get_viewport().push_input(motion,true)
	for pressed in [true,false]:
		if touch:
			var event:=InputEventScreenTouch.new()
			event.index=0;event.position=at;event.pressed=pressed
			get_viewport().push_input(event,true)
		else:
			var event:=InputEventMouseButton.new()
			event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
			get_viewport().push_input(event,true)
		await get_tree().process_frame
	await frames()

func _ready() -> void:
	capture="--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUT)
	G.SAVE_PATH="res://tools/_logs/requested_optimizations_save.json"
	G._init_state_defaults();G.save_locked=false
	G.set_meta("ui_review_mode",true)
	G.selected_role="zs";G.player_name="沈舟"
	G.gm_unlocked=true;G.gm_grant_all();G.gm_unlock_all_features();G.gm_world_open=true
	G.prog.level=35
	get_window().unresizable=false
	get_window().size=Vector2i(480,1067)
	get_window().content_scale_size=Vector2i(480,1067)
	await inventory()
	await map_controls()
	if not "--ui-only" in OS.get_cmdline_user_args():await worlds()
	var f:=FileAccess.open(OUT+("results_ui.json" if "--ui-only" in OS.get_cmdline_user_args() else "results.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":errors,"maps":map_stats},"\t"));f.close()
	print("REQUESTED_OPTIMIZATIONS checks=%d failures=%d maps=%d"%[checks,errors.size(),map_stats.size()])
	Audio.stop_bgm();Audio.set_suspended(true)
	await frames()
	get_tree().quit(0 if errors.is_empty() else 1)

func inventory() -> void:
	G.items={"enhance_stone":23,"refine_stone":10,"lock_rune":4,"pet_food":12,"gem_atk_1":3,"gem_hp_5":1,"fish_salt":2,"salt_ledger":1}
	G.ensure_starter_equip(true)
	G.inv_grant_equip({"tpl":"tpl_sword_wolf","rarity":2,"n":24},false)
	var bag:=BagPanel.new()
	add_child(bag);await frames()
	await click(bag._item_buttons[0],true)
	check(bag._sel_uid>0 and bag._detail_body.get_child_count()>3,"touch equipment opens detailed comparison")
	await shot("bag_equipment")
	await click(bag._tab_buttons.mat,true)
	var selected:=bag._sel_supply
	for id in ["enhance_stone","pet_food","salt_ledger","fish_salt"]:
		var cell:=bag.find_child("Supply_"+id,true,false)
		await click(cell,true)
		check(bag._sel_supply==id,"touch supply selects "+id)
		var usage:=bag.find_child("ItemUsage",true,false) as Label
		check(usage!=null and usage.text==preload("res://src/ui/ItemDescriptions.gd").describe(id),"specific usage for "+id)
	await shot("bag_material")
	await click(bag._tab_buttons.gem,true)
	await click(bag.find_child("Supply_gem_hp_5",true,false),true)
	check(bag.find_child("ItemUsage",true,false).text.contains("生命 +190"),"gem displays actual attribute value")
	check(bag.find_child("ItemUsage",true,false).text.contains("最高等级"),"highest gem does not promise another synthesis")
	await shot("bag_gem")
	G.inv_grant_equip({"tpl":"tpl_sword_wolf","rarity":2,"n":G.inv_capacity()+1},false)
	await click(bag._tab_buttons.pending,true)
	var pending:=G.inv_pending().duplicate(true)
	check(not pending.is_empty(),"pending fixture exists")
	if not pending.is_empty():
		await click(bag.find_child("PendingPreview_"+str(pending[0].uid),true,false),true)
		check(bag._sel_uid==int(pending[0].uid) and bag._action_buttons.size()==1,"pending preview has details and one claim action")
		check(G.inv_pending()==pending,"preview leaves pending loot untouched")
		check(bag._action_buttons[0].disabled,"full bag disables claim")
		await shot("bag_pending")
	await click(bag._tab_buttons.equip,true)
	bag._scroll.scroll_vertical=0
	await frames()
	var before:=bag._sel_uid
	var at: Vector2=bag._item_buttons[0].get_global_rect().get_center()
	var down:=InputEventScreenTouch.new();down.index=0;down.position=at;down.pressed=true
	get_viewport().push_input(down,true);await frames(1)
	for i in range(1,7):
		var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=at-Vector2(0,i*18);drag.relative=Vector2(0,-18)
		get_viewport().push_input(drag,true);await frames(1)
	var up:=InputEventScreenTouch.new();up.index=0;up.position=at-Vector2(0,108);up.pressed=false
	get_viewport().push_input(up,true);await frames()
	check(bag._scroll.scroll_vertical>0 and bag._sel_uid==before,"drag from item scrolls without selecting")
	bag.queue_free();await frames()

func map_controls() -> void:
	G.prog.main_world={"map_id":"lorin_wilds","position":[480,900]}
	for dimensions in [Vector2i(480,1067),Vector2i(480,800),Vector2i(320,640)]:
		get_window().size=dimensions;get_window().content_scale_size=dimensions
		await frames()
		var panel:=preload("res://src/ui/WorldPointMap.gd").new()
		panel.standalone=true
		panel.region_requested.connect(func():overview_count+=1)
		panel.closed.connect(func():closed_count+=1)
		add_child(panel);await frames()
		check(G.ui_safe_rect(panel).encloses(panel._frame.get_global_rect()),"map fits "+str(dimensions))
		check(panel._canvas.size.y>=96,"map canvas retains space "+str(dimensions))
		for key in panel._filter_buttons:
			var button: Button=panel._filter_buttons[key]
			if button.disabled:continue
			await click(button,true)
			check(panel._filter==key and button.button_pressed,"filter works "+key)
			for marker in panel._canvas._markers():
				for id in marker.ids:check(key=="all" or Points.find(id).kind==key,"filter hides other categories")
		await click(panel._filter_buttons.all,true)
		await click(panel._zoom_in,true)
		check(panel._canvas.zoom>1,"zoom in works")
		await click(panel._zoom_out,true)
		check(is_equal_approx(panel._canvas.zoom,1),"zoom out returns to overview")
		await click(panel.find_child("LocatePlayer",true,false),true)
		check(panel._canvas.zoom>=1.8,"locate zooms to player")
		check(panel._canvas.screen_at(Vector2(480,900)).distance_to(panel._canvas.size*.5)<100,"locate centers real player")
		await click(panel.find_child("LocationList",true,false),true)
		check(is_instance_valid(panel._picker_frame),"location list opens")
		if is_instance_valid(panel._picker_frame):
			check(G.ui_safe_rect(panel).encloses(panel._picker_frame.get_global_rect()),"location list fits screen %s rect=%s safe=%s"%[dimensions,panel._picker_frame.get_global_rect(),G.ui_safe_rect(panel)])
			await shot("map_list_"+str(dimensions.x)+"x"+str(dimensions.y))
			var choices:=panel._picker_frame.find_children("*","Button",true,false)
			await click(choices[0],true)
			check(not panel._selected.is_empty(),"location list selects a real point")
			await click(panel._go,true)
			check(Points.target().get("id","")==panel._selected,"track persists the selected point")
			check(panel._go.disabled and not panel._cancel.disabled,"tracking prevents repeated submit and enables cancellation")
			await click(panel._cancel,true)
			check(Points.target().is_empty() and panel._cancel.disabled,"cancel really clears tracking")
		check(panel._canvas.route_points.is_empty(),"no route line on map")
		await shot("map_"+str(dimensions.x)+"x"+str(dimensions.y))
		var old:=overview_count
		await click(panel.find_child("WorldOverview",true,false),true)
		check(overview_count==old+1,"world overview is distinct action")
		old=closed_count
		await click(panel.find_child("ReturnFromMap",true,false),true)
		check(closed_count==old+1,"return exploration is distinct action")
		panel.queue_free();await frames()
	get_window().size=Vector2i(480,1067);get_window().content_scale_size=Vector2i(480,1067)
	await frames()
	for id in ["old_salt_road","shenyuan_port","maple_road"]:
		var panel:=preload("res://src/ui/WorldPointMap.gd").new()
		panel.map_id=id;add_child(panel);await frames()
		for key in ["fishing","station","shop"]:
			if panel._filter_buttons[key].disabled:continue
			await click(panel._filter_buttons[key],true)
			check(panel._filter==key,"populated category responds "+id+" "+key)
			var markers: Array=panel._canvas._markers()
			check(not markers.is_empty(),"category has visible markers "+id+" "+key)
			if markers.is_empty():continue
			var at: Vector2=panel._canvas.global_position+markers[0].at
			for pressed in [true,false]:
				var event:=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=pressed
				get_viewport().push_input(event,true);await frames(1)
			await frames()
			check(not panel._selected.is_empty() or is_instance_valid(panel._picker),"map marker responds to touch")
			panel._close_picker()
		await click(panel._zoom_in,true)
		var before: Vector2=panel._canvas.pan
		var at: Vector2=panel._canvas.get_global_rect().get_center()
		var press:=InputEventScreenTouch.new();press.index=0;press.position=at;press.pressed=true
		get_viewport().push_input(press,true);await frames(1)
		var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=at+Vector2(30,25);drag.relative=Vector2(30,25)
		get_viewport().push_input(drag,true);await frames(1)
		var release:=InputEventScreenTouch.new();release.index=0;release.position=at+Vector2(30,25);release.pressed=false
		get_viewport().push_input(release,true);await frames()
		check(panel._canvas.pan!=before,"touch drag pans enlarged map "+id)
		panel.queue_free();await frames()

func worlds() -> void:
	for id in TableCache.main_world_config().get("maps",{}):
		G.prog.main_world={"map_id":id}
		var run:=RunState.new()
		run.setup({"role_id":"zs","theme":String(TableCache.main_world_map(id).get("theme","forest")),"level":35,"seed":71})
		MapScene.pending_cfg={"mode":"main_world","main_map_id":id,"run":run,"node":{"type":"normal","layer":1,"index":0}}
		current=preload("res://src/explore/MapScene.tscn").instantiate()
		add_child(current);await frames(10)
		current.set_physics_process(false)
		for monster in current._monsters:monster.set_physics_process(false)
		if current._city_content!=null:
			current._city_content.set_physics_process(false)
			if current._city_content._panel!=null:current._city_content._close_panel()
		var layer:=current._world.get_node_or_null("WorldDressing")
		check(layer!=null,"map dressing exists "+id)
		var count:=int(layer.get_meta("prop_count",0)) if layer!=null else 0
		check(count>0,"map gains scenery "+id)
		var npcs:=0
		if current._city_content!=null:
			for npc in current._city_content._npcs:
				var idle:=npc.get_node_or_null("Idle") as AnimatedSprite2D
				if idle==null:continue
				npcs+=1
				if npc.frames.get_meta("foot_registered",false):
					var base:=float(npc.frames.get_meta("world_height"))/float(npc.frames.get_meta("canvas_height"))
					check(is_equal_approx(idle.scale.x,base*Presentation.NPC_ENLARGEMENT),"NPC enlarged "+String(npc.data.id))
					check(absf(idle.position.y+float(npc.frames.get_meta("canvas_height"))*idle.scale.y*.5)<.1,"NPC foot stays registered")
		for point in Points.rows(id):
			check(Rect2(Vector2.ZERO,current._map_extent()).has_point(Points.position(point)),"point coordinate stays valid "+String(point.id))
		var bg:=current.get_node_or_null("IllustratedMapGround") as TextureRect
		if bg==null:bg=current.get_node_or_null("MapBackground") as TextureRect
		if bg!=null:check(bg.texture.resource_path==Presentation.background_path(String(current._main_cfg.background)),"background uses original file "+id)
		map_stats.append({"id":id,"new_scenery":count,"npcs":npcs})
		await frames();await shot("world_"+id)
		if id in ["old_salt_road","red_sand_route"]:
			current._player.position=Vector2(480,560);await frames();await shot("world_"+id+"_middle")
			if bg!=null and capture:
				var original:=bg.texture
				bg.texture=load(String(current._main_cfg.background))
				await frames();await shot("world_"+id+"_processed_comparison")
				bg.texture=original
		current.queue_free();current=null;await frames()
