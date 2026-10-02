# Staged visual QA. This is not real-input completion evidence.
extends SubViewport

const Surface = preload("res://src/explore/TerrainSurface.gd")
const Icons = preload("res://src/ui/UIIcons.gd")

var shot := "avatar_contact"
var output := "res://shots/fourth_back_20261002"
var role := "zs"
var clip := false

func _enter_tree() -> void:
	size=Vector2i(480,800)
	render_target_update_mode=SubViewport.UPDATE_ALWAYS
	canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="): shot=arg.trim_prefix("--shot=")
		if arg.begins_with("--out="): output=arg.trim_prefix("--out=")
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
		if arg=="--clip": clip=true
		if arg.begins_with("--size="):
			var dims:=arg.trim_prefix("--size=").split("x")
			if dims.size()==2: size=Vector2i(int(dims[0]),int(dims[1]))

func _ready() -> void:
	G.set_meta("ui_review_mode",true)
	G.SAVE_PATH="res://tools/_logs/save_capture_fourth_back_%s_%s.json" % [shot,role]
	var group:="zs_fs" if role in ["zs","fs"] else "ck_fz"
	var source:="res://tools/_logs/fourth_front_verified_%s_20261002/save_playthrough_%s_a.json" % [group,role]
	var file:=FileAccess.open(G.SAVE_PATH,FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(source))
	file.close()
	if not G.reload_save() or G.save_locked:
		push_error("FOURTH_SHOT_SOURCE_LOAD_FAILED")
		get_tree().quit(1)
		return
	G.story_event("visit","stele_entry","stele_entry")
	var mid:="stele_entry"
	if shot!="entry":
		G.world_puzzle_interact("stele_entry","return_anchor")
		mid="stele_resonance"
		G.world_puzzle_interact("stele_resonance","forest_voice")
	if shot not in ["entry","hall"]:
		G.world_puzzle_interact("stele_resonance","tide_voice")
		G.world_puzzle_interact("stele_resonance","snow_voice")
		G.story_event("observe","aligned_voices","stele_resonance")
		mid="stele_core"
	if shot.begins_with("warden") or shot.begins_with("ending"):
		G.story_event("defeat","mon_abyss_avatar","stele_core")
		mid="lorin_wilds"
		if shot!="ending_choices":
			G.story_event("talk","npc_steward","lorin_wilds",true,{"method":"echo" if shot=="ending_echo" else "seal"})
		if shot.begins_with("warden"): mid="abyss_ring"
	var run:=RunState.new()
	run.setup({"theme":"abyss","role_id":role,"level":int(G.prog.level),"active_pet":G.companion_active(),"potions":2,"seed":417})
	run.growth_bonus=G.growth_bonuses(role)
	MapScene.pending_cfg={"mode":"main_world","main_map_id":mid,"run":run,"node":{"type":"normal","layer":0,"index":0}}
	var world: MapScene=load("res://src/explore/MapScene.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	world._player.position=Vector2(480,740) if shot=="entry" else Vector2(480,650)
	if shot.begins_with("ending"):
		world._city_content._close_panel()
		world._city_content._open_dialog(G.city_npc("npc_steward"),false)
	elif shot=="codex":
		pass
	elif shot not in ["entry","hall","core"]:
		var boss_id:="mon_nameless_warden" if shot.begins_with("warden") else "mon_abyss_avatar"
		for m in world._monsters:
			if m.mon_id==boss_id:
				world._start_battle(m)
				break
		await get_tree().process_frame
		var battle:=world._battle
		if battle==null:
			push_error("FOURTH_SHOT_BATTLE_MISSING")
			get_tree().quit(1)
			return
		battle.speed=0
		var enemy: Combatant=battle.sim.alive_units("enemy")[0]
		if shot.ends_with("windup"):
			SkillSystem.enqueue_cast(battle.sim,enemy,enemy.skills[0].def)
			battle._consume_events()
			battle._refresh_omens()
		elif shot=="avatar_phase":
			enemy.hp=int(enemy.get_max_hp()*.54)
			battle.sim._apply_phases()
			SkillSystem.resolve_cast(battle.sim,{"uid":enemy.uid,"skill":enemy.skills[1].def})
			battle._consume_events()
			battle._sync_views()
		else:
			for i in 8: await get_tree().process_frame
			var hero:=battle.sim.role_unit()
			battle._on_event({"t":"basic","src":hero.uid,"uid":enemy.uid})
			battle._on_event({"t":"dmg","src":hero.uid,"uid":enemy.uid,"amount":128,"crit":true,"dot":false})
			if not clip:
				await get_tree().create_timer(.17).timeout
				await _save()
				return
	if clip:
		DirAccess.make_dir_recursive_absolute(output)
		for i in 45:
			await RenderingServer.frame_post_draw
			if i%2==0:
				var err:=get_texture().get_image().save_png(output.path_join("frame_%03d.png" % i))
				if err!=OK: push_error("FOURTH_CLIP_SAVE_FAILED")
		print("FOURTH_CLIP_SAVED ",output)
		await _finish(0)
	else:
		for i in 12: await get_tree().process_frame
		await _save()

func _save() -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var err:=get_texture().get_image().save_png(output)
	if err!=OK: push_error("FOURTH_SHOT_SAVE_FAILED")
	else: print("FOURTH_SHOT_SAVED ",output)
	await _finish(0 if err==OK else 1)

func _finish(code: int) -> void:
	# Release render resources while the rendering server is still alive.
	for child in get_children(): child.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	MonsterArt._textures.clear()
	BattleScene._battle_frames_cache.clear()
	FrostCityArt._frames.clear()
	FrostCityArt._portraits.clear()
	FrostCityArt._props.clear()
	Surface._textures.clear()
	Icons._cache.clear()
	await get_tree().process_frame
	get_tree().quit(code)
