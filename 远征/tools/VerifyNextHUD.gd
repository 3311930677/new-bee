extends Node
const OUT:="res://shots/next_review_20261009/"
var failures:=0
var checks:=0
var map:MapScene
func check(ok:bool,msg:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("REVIEW_HUD_FAIL "+msg)
func frames() -> void:for i in 5:await get_tree().process_frame
func click(control:Control) -> void:
	var p:=control.get_global_rect().get_center()
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.position=p;e.global_position=p;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down
		get_viewport().push_input(e,true);await get_tree().process_frame
	await frames()
func shot(name:String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+name+".png")
func _ready() -> void:
	G.SAVE_PATH=OUT+"hud_isolated_save.json"
	G.set_meta("ui_review_mode",true)
	for height in [800,1067]:
		get_window().size=Vector2i(480,height);await frames()
		for id in ["lorin_wilds","maple_road"]:
			G._init_state_defaults();G.save_locked=false;G.selected_role="zs";G.player_name="行旅人";G.prog.level=12
			G.collect_pet("pet_rockturtle");G.collect_pet("pet_thunderhawk")
			var run:=RunState.new();run.setup({"role_id":"zs","theme":"forest","level":12,"active_pet":"pet_rockturtle","potions":2,"seed":17})
			MapScene.pending_cfg={"mode":"main_world","main_map_id":id,"run":run,"node":{"type":"normal","layer":0,"index":0}}
			map=preload("res://src/explore/MapScene.tscn").instantiate();add_child(map)
			await frames()
			check(map._pet_btn.is_visible_in_tree(),"单只伙伴同行时入口可见 "+id)
			var old_pet:=run.active_pet
			await click(map._pet_btn)
			check(G.modal_count()>0 and run.active_pet==old_pet,"单只伙伴点击查看，不改出战 "+id)
			var esc:=InputEventKey.new();esc.keycode=KEY_ESCAPE;esc.pressed=true;get_viewport().push_input(esc,true)
			await frames();check(G.modal_count()==0,"关闭伙伴说明 "+id)
			run.bench_pet="pet_thunderhawk";map._refresh_hud()
			await click(map._pet_btn)
			check(run.active_pet=="pet_thunderhawk" and run.bench_pet==old_pet,"有替补时保留原换宠 "+id)
			run.active_pet="pet_rockturtle";run.bench_pet="pet_thunderhawk";map._sync_world_companion();map._refresh_hud()
			await frames();await shot("hud_"+id+"_swap_feedback_%d"%height)
			await get_tree().create_timer(3.2).timeout
			await shot("hud_"+id+"_partner_%d"%height)
			var paths:Dictionary={}
			for pet in TableCache.pets():
				var tex:=G.res_tex(String(pet.id));paths[pet.id]={"size":tex.get_size() if tex!=null else Vector2.ZERO,"path":tex.resource_path if tex!=null else ""}
			var file:=FileAccess.open(OUT+"pet_source_index.json",FileAccess.WRITE);file.store_string(JSON.stringify(paths,"\t"))
			map.queue_free();await frames()
	print("REVIEW_HUD_%s checks=%d"%["OK" if failures==0 else "FAIL",checks]);get_tree().quit(0 if failures==0 else 1)
