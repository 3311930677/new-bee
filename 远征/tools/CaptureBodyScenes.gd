extends Node

func _ready()->void:
	G.SAVE_PATH="res://tools/_logs/save_body_visual_qa.json"
	G._init_state_defaults()
	G.save_locked=false
	G.prog.story={"step":"s29","done":[],"goals":{}}
	for i in range(1,29):G.prog.story.done.append("s%02d"%i)
	G.wallet.gold=5000
	G.prog.main_world={"map_id":"lorin_wilds"}
	for dimensions in [Vector2i(480,800),Vector2i(480,1067)]:
		get_window().size=dimensions
		await get_tree().process_frame
		var panel:=preload("res://src/ui/TradeContractsPanel.gd").new()
		add_child(panel)
		panel.open_contracts("city_market")
		await capture("contract_offer_%d"%dimensions.y)
		panel.queue_free()
		await get_tree().process_frame
		var gathering:=preload("res://src/ui/CampGatheringPanel.gd").new()
		add_child(gathering)
		gathering.listen(2)
		await capture("camp_gathering_%d"%dimensions.y)
		gathering.queue_free()
		await get_tree().process_frame
		for id in ["shelter","conquest","harvest"]:G.prog.flags["oath_pattern_"+id]=true
		var oaths:=preload("res://src/ui/OathPanel.gd").new()
		add_child(oaths)
		await capture("oath_patterns_%d"%dimensions.y)
		oaths.queue_free()
		await get_tree().process_frame
		for room in ["stele_cavern","tidal_gate","rift_mine_vault"]:
			G.prog.flags={"act1_stele_rooms_v1":true,"act2_tidal_rooms_v1":true,"act3_mine_rooms_v1":true}
			G.prog.main_world={"map_id":room}
			var run:=RunState.new()
			run.setup({"theme":"tomb","role_id":"zs","level":20,"seed":5})
			MapScene.pending_cfg={"mode":"main_world","main_map_id":room,"run":run,"node":{"type":"boss","layer":1,"index":0}}
			var map:=preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
			add_child(map)
			await get_tree().process_frame
			map.set_process(false)
			map.set_physics_process(false)
			for mon in map._monsters:mon.set_process(false)
			map._player.position=Vector2(480,920)
			for child in map._player.get_children():
				if child is Camera2D:child.reset_smoothing()
			await capture("room_%s_%d"%[room,dimensions.y])
			map.queue_free()
			await get_tree().process_frame
		var records:Dictionary={}
		for quest in G.side_quest_rows():records[String(quest.id)]={"status":QuestService.SIDE_DONE}
		G.act1_state()["side_quests"]=records
		for city in ["lorin_wilds","shenyuan_port","frost_post"]:
			G.prog.main_world={"map_id":city}
			var run:=RunState.new()
			run.setup({"theme":"forest","role_id":"zs","level":20,"seed":5})
			MapScene.pending_cfg={"mode":"main_world","main_map_id":city,"run":run,"node":{"type":"normal","layer":1,"index":0}}
			var map:=preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
			add_child(map)
			await get_tree().process_frame
			map.set_physics_process(false)
			map.set_process(false)
			for child in map._world.get_children():child.set_process(false)
			map._player.position={"lorin_wilds":Vector2(520,775),"shenyuan_port":Vector2(550,765),"frost_post":Vector2(510,1030)}[city]
			for entity in map._quest_entities:
				if entity.kind=="feedback":entity._process(0)
			for child in map._player.get_children():
				if child is Camera2D:child.reset_smoothing()
			await capture("trust_%s_%d"%[city,dimensions.y])
			map.queue_free()
			await get_tree().process_frame
	print("BODY_VISUAL_QA_OK")
	get_tree().quit()

func capture(name:String)->void:
	await get_tree().create_timer(.35).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://shots/body_content_20261004/%s.png"%name)
