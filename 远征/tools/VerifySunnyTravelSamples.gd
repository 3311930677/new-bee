extends Node
const Art:=preload("res://src/world/SunnyTravelArt.gd")
var checks:=0
var failures:=0
func check(ok:bool,words:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("SUNNY_SAMPLE_FAIL "+words)
func frames() -> void:for i in 6:await get_tree().process_frame
func click(control:Control) -> void:
	var point:=control.get_global_rect().get_center()
	for pressed in [true,false]:
		var e:=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed
		get_viewport().push_input(e,true);await get_tree().process_frame
	await frames()
func fixture() -> void:
	G._init_state_defaults();G.save_locked=false;G.selected_role="zs";G.player_name="行旅人";G.prog.level=12
	G.collect_pet("pet_rockturtle");G.prog.tips_seen={"deploy":true}
func labelled(root:Node,words:String) -> Control:
	for child in root.get_children():
		if child is Label and child.text==words:return child.get_parent() as Control
		var found:=labelled(child,words)
		if found!=null:return found
	return null
func create_map(id:String) -> MapScene:
	var run:=RunState.new();run.setup({"role_id":"zs","theme":"forest","level":12,"active_pet":"pet_rockturtle","potions":2,"seed":17})
	MapScene.pending_cfg={"mode":"main_world","main_map_id":id,"run":run,"node":{"type":"normal","layer":0,"index":0}}
	var map:=preload("res://src/explore/MapScene.tscn").instantiate();add_child(map);return map
func colliders(root:Node) -> Array[String]:
	var result:Array[String]=[]
	for child in root.get_children():
		if child is StaticBody2D:
			for part in child.get_children():
				if part is CollisionShape2D:result.append(str(child.position)+str(part.position)+str(part.shape.size) if part.shape is RectangleShape2D else str(part.shape))
		result.append_array(colliders(child))
	result.sort();return result
func _ready() -> void:
	G.SAVE_PATH="res://shots/world_art_samples_20261010/verify_isolated_save.json"
	G.set_meta("ui_review_mode",true)
	for id in ["steward","guard"]:
		var image:=Art.texture(id).get_image()
		check(image.get_size()==Vector2i(512,128),id+" 帧条规格")
		var first:=image.get_region(Rect2i(0,0,128,128))
		for i in 4:
			var frame:=image.get_region(Rect2i(i*128,0,128,128))
			check(frame.get_used_rect().end.y==124,id+" 第%d帧脚底"%i)
			check(frame.get_region(Rect2i(0,76,128,52)).get_data()==first.get_region(Rect2i(0,76,128,52)).get_data(),id+" 下半身固定")
		check(image.get_region(Rect2i(128,0,128,76)).get_data()!=first.get_region(Rect2i(0,0,128,76)).get_data(),id+" 有局部呼吸")
	var atlas:=Art.texture("terrain").get_image()
	for row in 2:
		for n in 48:
			check(atlas.get_pixel(47,row*48+n)==atlas.get_pixel(48,row*48+n),"基础瓦片横向接缝")
			check(atlas.get_pixel(n,row*48)==atlas.get_pixel(n,row*48+47),"基础瓦片纵向接缝")
	for id in ["lorin_wilds","maple_road"]:
		fixture();G.set_meta("sunny_sample_disabled",true)
		var old:=create_map(id);await frames();var base:=colliders(old._world)
		var base_cfg:Dictionary=old._main_cfg.duplicate(true);var old_scale:=old._player_anim.scale
		old.queue_free();await frames()
		fixture();G.set_meta("sunny_sample_disabled",false)
		var map:=create_map(id);await frames()
		check(colliders(map._world)==base,id+" 原有静态碰撞完整保留")
		check(map._main_cfg==base_cfg,id+" 出口、道路、实体配置不变")
		check(map._player_anim.scale==old_scale,id+" 主角缩放不变")
		check(map._flat_ground.routes==base_cfg.flat_routes,id+" 地表对应真实中心线")
		var start:=map._player.position
		Input.action_press("move_up")
		for n in 18:await get_tree().physics_frame
		Input.action_release("move_up")
		check(map._player.position.y<start.y-8,id+" 模拟按键沿通路正常移动")
		if id=="lorin_wilds":
			var steward:Node2D
			for npc in map._city_content._npcs:
				if npc.data.id=="npc_steward":steward=npc
			map._player.position=steward.position+Vector2(24,18)
			await frames()
			check(map._city_content.has_modal(),"靠近执事保留原自动交谈")
			var leave:=labelled(map._city_content._panel,"离开") if map._city_content._panel!=null else null
			check(leave!=null,"执事对话有离开入口")
			if leave!=null:await click(leave)
			check(not map._city_content.has_modal(),"真实点击离开对话")
			await frames()
			check(not G.is_built("archive") and G.is_built("hall"),"工地没有冒充已落成")
		else:
			check(map._world.get_children().any(func(n):return n is Art.Scenery),"枫林有独立景观件")
		map.queue_free();await frames()
	print("SUNNY_SAMPLE_%s checks=%d failures=%d"%["OK" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)
