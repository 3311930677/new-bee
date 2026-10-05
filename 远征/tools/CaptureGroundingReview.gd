extends Node

const OUT := "res://shots/grounding_review_20261005"
const Ground := preload("res://src/world/BuildingGrounding.gd")
var failures := 0
var stage := "after"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="): stage = arg.trim_prefix("--stage=")
	G.SAVE_PATH = "res://tools/_logs/save_grounding_review.json"
	G._init_state_defaults()
	G.save_locked = false
	G.set_meta("ui_review_mode", true)
	G.selected_role = "fs"
	G.player_name = "陆川愿"
	G.prog.level = 12
	G.city["built"] = ["hall", "gate", "archive", "kennel", "barracks", "storehouse", "stable", "shrine", "forge"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if stage != "before": check_masks()
	get_window().size = Vector2i(480,800)
	var catalog := Node2D.new()
	add_child(catalog)
	var grass := ReviewGrass.new()
	catalog.add_child(grass)
	for i in 4:
		var building := CityScene._Building.new()
		var id: String = ["gate", "storehouse", "hall", "forge"][i]
		building.setup({"id":id, "name":["城门","仓廪","议事厅","锻坊"][i], "port_built":true})
		building.position = Vector2(120 + (i % 2) * 240, 240 + (i / 2) * 245)
		catalog.add_child(building)
	var stall := MapScene._QuestEntity.new()
	stall.art = "trade_stall"
	stall.position = Vector2(112, 705)
	catalog.add_child(stall)
	for i in 2:
		var zombie := MapScene._MapMonster.new()
		zombie.mon_id = "mon_zombie"
		zombie.tier = "boss" if i == 0 else "normal"
		zombie.position = Vector2(315 + i * 90, 705)
		catalog.add_child(zombie)
	await capture("catalog", [Rect2i(18,92,205,185),Rect2i(260,92,205,185),Rect2i(230,588,235,152)])
	catalog.queue_free()
	await get_tree().process_frame
	for group in [["archive","kennel","barracks","shrine"],["frost_lodge","frost_supply","frost_guardhouse","stable"]]:
		var page := Node2D.new()
		add_child(page)
		var ground := ReviewGrass.new()
		ground.snow = String(group[0]).begins_with("frost")
		page.add_child(ground)
		for i in group.size():
			var building := CityScene._Building.new()
			building.setup({"id":group[i], "name":"建筑检视", "port_built":true})
			building.position = Vector2(120 + (i % 2) * 240, 320 + (i / 2) * 300)
			page.add_child(building)
		await capture("catalog_"+String(group[0]))
		page.queue_free()
		await get_tree().process_frame
	var run := RunState.new()
	run.setup({"theme":"forest","role_id":"fs","level":12,"active_pet":"pet_rockturtle","bench_pet":"","potions":2,"seed":19})
	MapScene.pending_cfg = {"mode":"main_world","main_map_id":"lorin_wilds","run":run,"node":{"type":"normal","layer":0,"index":0}}
	var town := preload("res://src/explore/MapScene.tscn").instantiate()
	add_child(town)
	await get_tree().process_frame
	town.set_physics_process(false)
	town._city_content.set_physics_process(false)
	town._city_content._close_panel()
	for id in ["gate", "storehouse"]:
		for building in town._city_content._buildings:
			if String(building.data.id) == id:
				town._player.position = building.global_position + Vector2(-85,50)
				break
		await get_tree().create_timer(.5).timeout
		await capture("town_"+id)
	for monster in town._monsters: monster.set_physics_process(false)
	if not town._monsters.is_empty():
		town._player.position = town._monsters[0].position + Vector2(-110,10)
		await capture("world_zombie")
	town.queue_free()
	await get_tree().process_frame
	MapScene.pending_cfg = {"mode":"main_world","main_map_id":"broken_slope","run":run,"node":{"type":"normal","layer":0,"index":0}}
	var wilds := preload("res://src/explore/MapScene.tscn").instantiate()
	add_child(wilds)
	wilds.set_physics_process(false)
	for monster in wilds._monsters: monster.set_physics_process(false)
	for entity in wilds._quest_entities:
		if entity.art != "trade_stall": continue
		entity.set_process(false)
		wilds._player.position = entity.position + Vector2(130,10)
		await capture("world_stall")
		break
	wilds.queue_free()
	await get_tree().process_frame
	Ground._cache.clear()
	print("GROUNDING_REVIEW_OK" if failures == 0 else "GROUNDING_REVIEW_FAIL")
	get_tree().quit(0 if failures == 0 else 1)

func check(ok: bool, words: String) -> void:
	if ok: return
	failures += 1
	push_error("FAIL: "+words)

func check_masks() -> void:
	var gate: Texture2D = load("res://image/main_world/city_gate_reference_v2.png")
	var row := Ground.prepare(gate,192,roundi(192.0*gate.get_height()/gate.get_width()))
	var contact: Image = row.contact.get_image()
	check(row.feet[96] == -1,"城门中央拱桥不能成为接地底座")
	check(contact.get_pixel(96+row.padding,row.visible_floor+row.padding+1).a < .01,"城门门洞不得铺连续接触影")
	var feet := Image.create(40,24,false,Image.FORMAT_RGBA8)
	feet.fill(Color.TRANSPARENT)
	feet.fill_rect(Rect2i(6,2,5,15),Color.WHITE)
	feet.fill_rect(Rect2i(26,2,5,15),Color.WHITE)
	# Low-alpha export residue must not move the detected floor.
	feet.set_pixel(20,23,Color(1,1,1,.2))
	var texture := ImageTexture.create_from_image(feet)
	var actor := Ground.actor(texture,40,24)
	check(actor.visible_floor == 16,"低透明度留白不可抬高实际脚点")
	var mask: Image = actor.contact.get_image()
	var pad: int = actor.padding
	check(mask.get_pixel(8+pad,17+pad).a > .3 and mask.get_pixel(28+pad,17+pad).a > .3,"接触影必须紧贴两只脚底的下一像素")
	check(mask.get_pixel(20+pad,17+pad).a < .01,"两脚之间必须保持空隙")
	check(mask.get_pixel(8+pad,17+pad).a > mask.get_pixel(8+pad,19+pad).a,"接触影必须向外减弱")
	var cast: Image = actor.cast.get_image()
	check(cast.get_pixel(32+pad,17+pad).a > cast.get_pixel(34+pad,18+pad).a,"投影末端必须渐弱")
	var padded := Image.create(80,50,false,Image.FORMAT_RGBA8)
	padded.fill(Color.TRANSPARENT)
	padded.blit_rect(feet,Rect2i(0,0,40,24),Vector2i(7,5))
	var padded_texture := ImageTexture.create_from_image(padded)
	var padded_row := Ground.actor(padded_texture,80,50)
	var padded_mask: Image = padded_row.contact.get_image()
	check(padded_row.cast_length == actor.cast_length,"透明画布不能改变投影长度")
	check(is_equal_approx(mask.get_pixel(8+pad,17+pad).a,padded_mask.get_pixel(15+pad,22+pad).a),"透明画布边距不能让接触影脱离脚点")
	var atlas_image := Image.create(80,24,false,Image.FORMAT_RGBA8)
	atlas_image.fill(Color.TRANSPARENT)
	atlas_image.blit_rect(feet,Rect2i(0,0,40,24),Vector2i.ZERO)
	var mirrored := feet.duplicate()
	mirrored.flip_x()
	atlas_image.blit_rect(mirrored,Rect2i(0,0,40,24),Vector2i(40,0))
	var atlas := ImageTexture.create_from_image(atlas_image)
	var first := AtlasTexture.new()
	first.atlas = atlas
	first.region = Rect2(0,0,40,24)
	var second := AtlasTexture.new()
	second.atlas = atlas
	second.region = Rect2(40,0,40,24)
	var first_row := Ground.actor(first,40,24)
	var second_row := Ground.actor(second,40,24)
	check(first_row.feet[6] == 16 and second_row.feet[6] == -1,"同尺寸图集区域不可复用另一物件的阴影")

func capture(name: String, crops: Array = []) -> void:
	await get_tree().create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	if frame.save_png(OUT+"/"+stage+"_"+name+".png") != OK: failures += 1
	for i in crops.size():
		var detail := frame.get_region(crops[i])
		detail.resize(detail.get_width()*3, detail.get_height()*3, Image.INTERPOLATE_NEAREST)
		if detail.save_png(OUT+"/"+stage+"_"+name+"_detail%d.png" % i) != OK: failures += 1

class ReviewGrass extends Node2D:
	var snow := false
	func _draw() -> void:
		draw_rect(Rect2(0,0,480,800), Color("d0d9d7") if snow else Color("69754a"))
		var rng := RandomNumberGenerator.new()
		rng.seed = 17
		for i in 950:
			var at := Vector2(rng.randi_range(0,478),rng.randi_range(0,798))
			draw_rect(Rect2(at,Vector2(2,2)),Color("a7b6b7",.35) if snow else Color("778056",.55))
