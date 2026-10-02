# Production panels and props staged from a real ending save; visual evidence only.
extends "res://tools/CaptureFourthBack.gd"

func _ready() -> void:
	G.set_meta("ui_review_mode",true)
	G.SAVE_PATH="res://tools/_logs/save_capture_return_jobs_%s.json" % shot
	var source:="res://shots/fourth_back_20261002/evidence/final_zs/save_playthrough_zs_a.json"
	var file:=FileAccess.open(G.SAVE_PATH,FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(source))
	file.close()
	if not G.reload_save():
		push_error("RETURN_SHOT_LOAD_FAILED")
		get_tree().quit(1)
		return
	var qid:="a4_rel_waylight"
	if shot.begins_with("tide"): qid="a4_eco_tidebuds"
	elif shot.begins_with("snow"): qid="a4_eco_snowflowers"
	elif shot.begins_with("mail"): qid="a4_trade_reply"
	elif shot.begins_with("rune"): qid="a4_secret_runes"
	elif shot.begins_with("letter"): qid="a4_rel_letter"
	var row:=QuestService.side_row(G.side_quest_rows(),qid)
	var panel:=shot in ["offer","active","choice","rune_choice"]
	if shot!="offer":
		G.side_accept(qid)
		G.side_track(qid)
		if shot!="active" and not shot.ends_with("_target"):
			for eid in row.objective.get("target_entities",[row.objective.get("target_entity","")]):
				G.side_entity_interact(String(row.objective.kind),String(eid),String(row.map),qid)
		if not panel and not shot.ends_with("_target"):
			var choice:="marker" if shot=="lamp_marker" else ("beacon" if qid=="a4_rel_waylight" else ("quiet" if shot=="rune_quiet" else "trace"))
			G._side_complete(qid,true,choice)
	var mid:=String(row.turn_in_map) if panel else String(row.map)
	var run:=RunState.new()
	run.setup({"theme":"abyss","role_id":role,"level":60,"active_pet":G.companion_active(),"potions":2,"seed":417})
	run.growth_bonus=G.growth_bonuses(role)
	MapScene.pending_cfg={"mode":"main_world","main_map_id":mid,"run":run,"node":{"type":"normal","layer":0,"index":0}}
	var world:MapScene=load("res://src/explore/MapScene.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	if panel:
		world._city_content._close_panel()
		world._city_content._open_dialog(G.city_npc(String(row.giver)),false)
	else:
		var eid:=String(row.objective.get("target_entity",row.objective.get("target_entities",[""])[0]))
		var at:Array=TableCache.main_world_map(mid).entities[eid].at
		world._player.position=Vector2(float(at[0])-65,float(at[1])+45)
	for i in 30: await get_tree().process_frame
	await _save()
