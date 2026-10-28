extends Control
## Exported only in Android Deep Audit. Production presets exclude src/qa.
const OUT="user://android_full_audit/"
const Bag=preload("res://src/ui/BagPanel.gd")
const Currency=preload("res://src/ui/CurrencyPanel.gd")
const Mount=preload("res://src/world/MountVisual.gd")
var busy=false
var wait=0.0
var active_id="idle"
var current:Node
var checks:Array=[]
var photos:Array=[]
var records:Array=[]
var lifecycle:Array=[]
var capture_effect:AudioEffectCapture
var capture_frames=PackedVector2Array()
var capturing=false
var telemetry:Array=[]

func frames(n=8):
	for i in n: await get_tree().process_frame

func pause(seconds:float): await get_tree().create_timer(seconds).timeout

func _ready():
	if OS.get_name()!="Android" or not OS.has_feature("android_deep_audit"):
		get_tree().quit(1);return
	process_mode=Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(OUT)
	fixture()
	write_json(OUT+"ready.json",device())
	print("ANDROID_DEEP_READY ",device())

func fixture():
	G.SAVE_PATH="user://android_full_audit_save.json"
	G.save_locked=false
	G._init_state_defaults()
	G.selected_role="zs";G.player_name="安卓全量巡检"
	G.set_meta("ui_review_mode",true)
	G.gm_unlocked=true
	G.gm_grant_all()
	G.gm_unlock_all_features()
	G.wallet={"gold":1234567,"expedition":234567,"soul":34567,"honor":4567}
	G.ensure_starter_equip(true)
	G.inv_grant_equip({"tpl":"tpl_sword_wolf","rarity":2,"n":28},false)
	G.mount_buy("horse");G.mount_buy("bear")
	G.mount_set_riding(false,false)
	Audio.set_suspended(false);Audio.set_mute(false)
	Audio.set_bgm_vol(.7);Audio.set_sfx_vol(.8)

func _process(delta):
	if capturing and capture_effect!=null:
		var count=capture_effect.get_frames_available()
		if count>0: capture_frames.append_array(capture_effect.get_buffer(count))
	wait-=delta
	if wait>0 or busy:return
	wait=.2
	if not FileAccess.file_exists(OUT+"request.json"):return
	var request=JSON.parse_string(FileAccess.get_file_as_string(OUT+"request.json"))
	DirAccess.remove_absolute(OUT+"request.json")
	if request is Dictionary:execute(request)

func execute(request:Dictionary):
	busy=true
	active_id=String(request.get("id","run"))
	if not active_id.is_valid_identifier(): busy=false;return
	DirAccess.make_dir_recursive_absolute(OUT+active_id)
	checks=[];photos=[];records=[]
	print("ANDROID_DEEP_BEGIN ",active_id," ",request)
	var suite=String(request.get("suite","probe"))
	if request.has("live"):G.set_meta("ui_review_mode",not bool(request.live))
	match suite:
		"pages":await pages_suite()
		"resources":await resources_suite()
		"maps":await maps_suite()
		"mounts":await mounts_suite(request)
		"issue_fix":await issue_fix_suite()
		"audio":await audio_suite()
		"audio_catalog":await audio_catalog()
		"page":await open_page(String(request.get("page","home")),request)
		"probe":records.append(probe())
		"shot":await photo(String(request.get("label","manual")))
		"scroll":
			if is_instance_valid(current):
				for node in current.find_children("*","ScrollContainer",true,false):
					node.scroll_vertical=100000 if bool(request.get("bottom",true)) else 0
			await frames();await photo("scroll")
		"battle":await battle_suite()
		"inventory_full":
			await clean();fixture()
			G.inv_grant_equip({"tpl":"tpl_sword_wolf","rarity":1,"n":G.inv_capacity()+3},false)
			await attach(Bag.new());current._select_tab("pending");await frames()
			check(not current._item_buttons.is_empty(),"M01 pending inventory fixture exists")
			check(current._item_buttons.all(func(button):return button.disabled),"full bag disables pending claim")
			await photo("pending_full")
		"motion":await motion_suite(request)
		"audio_events":
			Audio.event_log.clear();Audio._last_events.clear()
			for voice in Audio._sfx_pool:voice.stop()
			for name in request.get("events",[]):Audio.sfx(String(name),0)
			await frames(3);records.append(probe())
	write_json(OUT+active_id+"/result.json",{"id":active_id,"suite":suite,"device":device(),"checks":checks,"photos":photos,"records":records,"final":probe()})
	print("ANDROID_DEEP_COMPLETE ",active_id," checks=",checks.size()," failed=",checks.filter(func(row):return not row.ok).size()," photos=",photos.size())
	busy=false

func write_json(path:String,value):
	var file=FileAccess.open(path,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(value,"\t"));file.close()

func device():
	return {"os":OS.get_name(),"version":OS.get_version(),"model":OS.get_model_name(),"window":str(get_window().size),"viewport":str(get_viewport_rect()),"safe":str(G.ui_safe_rect(self)),"system_safe":str(DisplayServer.get_display_safe_area()),"cutouts":str(DisplayServer.get_display_cutouts()),"mix_rate":AudioServer.get_mix_rate()}

func check(ok:bool,label:String,detail:Variant=null):
	checks.append({"ok":ok,"label":label,"detail":detail})
	if not ok: print("ANDROID_DEEP_CHECK_FAIL ",label," ",detail)

func clean():
	for action in ["move_up","move_down","move_left","move_right"]:Input.action_release(action)
	DisplayServer.virtual_keyboard_hide()
	while not G._modals.is_empty():G.close_info_popup_by_id(int(G._modals.back().id))
	if is_instance_valid(current):
		remove_child(current);current.queue_free()
	current=null
	await frames(4)

func attach(node:Node):
	current=node;add_child(node);await frames(16)

func photo(label:String):
	await RenderingServer.frame_post_draw
	var path=OUT+active_id+"/"+label+".png"
	var rendered=get_viewport().get_texture().get_image()
	rendered.save_png(path)
	var colors={}
	for sy in range(0,rendered.get_height(),maxi(1,rendered.get_height()/24)):
		for sx in range(0,rendered.get_width(),maxi(1,rendered.get_width()/16)):
			colors[rendered.get_pixel(sx,sy).to_rgba32()]=true
	if is_instance_valid(current):check(colors.size()>16,"rendered frame has visible detail "+label,colors.size())
	var geometry:Array=[]
	if is_instance_valid(current):collect_controls(current,geometry)
	photos.append({"name":label,"safe":str(G.ui_safe_rect(self)),"controls":geometry,"sample_colors":colors.size()})
	print("ANDROID_DEEP_PHOTO ",active_id,"/",label)

func collect_controls(node:Node,output:Array):
	if node is CanvasItem and not node.is_visible_in_tree():return
	if node is BaseButton and node.size.x>1 and node.size.y>1:
		var rect=node.get_global_rect()
		var clipped=false
		var parent=node.get_parent()
		while parent!=null:
			if parent is Control and parent.clip_contents and not parent.get_global_rect().encloses(rect):clipped=true
			parent=parent.get_parent()
		output.append({"path":str(node.get_path()),"text":node.text if node is Button else node.name,"tooltip":node.tooltip_text,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"disabled":node.disabled,"clipped":clipped,"safe":G.ui_safe_rect(self).grow(1).encloses(rect),"touch_under44":minf(rect.size.x,rect.size.y)<44})
	for child in node.get_children():collect_controls(child,output)

func probe():
	var controls:Array=[]
	if is_instance_valid(current):collect_controls(current,controls)
	var modals:Array=[]
	for modal in G._modals:
		if not is_instance_valid(modal.layer):continue
		collect_controls(modal.layer,controls)
		for panel in modal.layer.get_children():
			modals.append({"name":str(panel.name),"script":panel.get_script().resource_path if panel.get_script()!=null else "","currency":panel.currency_id if panel is Currency else ""})
	var labels:Array=[]
	if is_instance_valid(current):
		for label in current.find_children("*","Label",true,false):
			if not label.is_visible_in_tree():continue
			var box=label.get_global_rect()
			labels.append({"path":str(label.get_path()),"text":label.text,"rect":[box.position.x,box.position.y,box.size.x,box.size.y],"minimum":str(label.get_minimum_size()),"font":label.get_theme_font_size("font_size")})
	var state={"tick_ms":Time.get_ticks_msec(),"page":str(current.name) if is_instance_valid(current) else "","device":device(),"audio":{"suspended":Audio._suspended,"bgm":Audio.current_bgm(),"playing":Audio._bgm.playing,"paused":Audio._bgm.stream_paused,"position":Audio._bgm.get_playback_position(),"mute":Audio.muted(),"voices":Audio.sfx_playing_count(),"events":Audio.event_log.duplicate(true)},"controls":controls,"labels":labels,"focus":str(get_viewport().gui_get_focus_owner()),"keyboard_height":DisplayServer.virtual_keyboard_get_height()}
	if current is MapScene:
		state["map"]={"id":current._main_map_id,"position":str(current._player.position),"velocity":str(current._player.velocity),"joy":str(current._joy.vector) if current._joy!=null else "none","joy_rect":str(current._joy.get_global_rect()) if current._joy!=null else "none","riding":G.mount_riding(),"mount_frame":current._mount_anim.frame if current._mount_anim!=null else -1}
	state["modals"]=modals
	return state

func _notification(what):
	if OS.get_name()!="Android":return
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_FOCUS_IN]:
		var row={"what":what,"tick_ms":Time.get_ticks_msec(),"suspended":Audio._suspended,"bgm_paused":Audio._bgm.stream_paused if Audio._bgm!=null else false,"bgm":Audio.current_bgm(),"voices":Audio.sfx_playing_count()}
		lifecycle.append(row);write_json(OUT+"lifecycle.json",lifecycle)
		print("ANDROID_DEEP_LIFECYCLE ",row)

func open_page(page:String,request:Dictionary={}):
	await clean()
	match page:
		"home":await attach(preload("res://src/ui/GameHome.tscn").instantiate())
		"login":await attach(preload("res://src/ui/Login.tscn").instantiate())
		"title":await attach(preload("res://src/ui/Title.tscn").instantiate());await pause(.7)
		"loading":
			var node=preload("res://src/ui/LoadScreen.gd").new();node.auto_advance=false;await attach(node)
		"bag":
			await attach(Bag.new());current._select_tab(String(request.get("tab","equip")));await frames()
		"currency":
			var node=Currency.new();node.currency_id=String(request.get("currency","gold"));await attach(node)
		"curio":
			await attach(preload("res://src/ui/CurioLorePanel.gd").new())
			current.navigate(String(request.get("section","overview")));await frames()
		"exchange":await attach(preload("res://src/ui/ExchangePanel.gd").new())
		"gathering":await attach(preload("res://src/ui/CampGatheringPanel.gd").new())
		"settings":await attach(preload("res://src/ui/SettingsPanel.gd").new())
		"map":await attach(make_map(String(request.get("map","lorin_wilds")),String(request.get("role","zs")),String(request.get("mount",""))))
		"modal":
			var node=preload("res://src/ui/TravelChestUI.gd").Modal.new();node.heading="长标题与多段文字：远征安卓阅读检查";node.lines=["边城的灯火照着旅人归路，请确认行囊与补给。".repeat(18)];node.choices=["查看行囊","继续出发"];await attach(node)
		_:
			await attach(preload("res://src/ui/GameHome.tscn").instantiate());current.open_gm_feature(page);await frames(20)
	await photo(page)

func issue_fix_suite():
	await clean();fixture()
	await open_page("login")
	check(current._chest._backdrop.material==null,"P01 crisp full-height login background")
	check(G.ui_safe_rect(self).encloses(current._paper.get_global_rect()),"P01 login form safe on Android")
	check(current._account.size.y>=56 and current._password.size.y>=56,"P01 fields retain touch size")
	var before=JSON.stringify([G.wallet,G.items,G.prog])
	for id in ["gold","expedition","soul","honor"]:
		await open_page("currency",{"currency":id})
		check(current._tabs.is_empty(),"P03 independent currency card "+id)
		check(str(G.wallet[id]) in current._balance.text,"P03 exact balance "+id)
		check(current._frame.size.y<=650.5,"P03 compact card height "+id)
		await photo("currency_"+id)
	check(before==JSON.stringify([G.wallet,G.items,G.prog]),"P03 reading four cards never mutates state")
	for owned in [false,true]:
		G.prog.pets=[]
		if owned:
			for row in TableCache.pets():G.prog.pets.append(String(row.id))
		await clean();await attach(preload("res://src/ui/CodexPanel.gd").new())
		for index in current._pets.size():
			current._deck.go(index,true);await frames(4)
			var view=current._chest
			var anchor=view._art.position+view._pet_anchor/view._anchor_canvas*view._art.size
			check(absf(anchor.x-(view._pedestal.position.x+view._pedestal.size.x*.5))<=1.1,"P02 body pedestal support "+str(index))
			check(absf(anchor.x-(view._shadow.position.x+view._shadow.size.x*.5))<=1.1,"P02 shared shadow support "+str(index))
			await photo("pet_"+str(index)+("_owned" if owned else "_silhouette"))
	await open_page("exchange")
	check(current.entries().size()==5,"P06 five original products")
	for row in current.entries():
		before=JSON.stringify([G.wallet,G.items,G.prog])
		current.open_product(String(row.id));await frames()
		check(before==JSON.stringify([G.wallet,G.items,G.prog]),"P06 viewing product does not purchase "+String(row.id))
		check(G.ui_safe_rect(self).encloses(current._detail.get_global_rect()),"P06 product detail safe")
		await photo("market_detail_"+String(row.id));current.close_product()
	current.open_product("enhance_stone");await frames()
	var honor=int(G.wallet.honor);var amount=G.item_count("enhance_stone")
	current.confirm_purchase();current.confirm_purchase()
	check(int(G.wallet.honor)==honor-80 and G.item_count("enhance_stone")==amount+3,"P06 one confirmation one transaction")
	await open_page("curio")
	before=JSON.stringify([G.wallet,G.items,G.prog])
	for section in ["overview","lore","appraise","history"]:
		current.navigate(section);await frames()
		check(G.ui_safe_rect(self).encloses(current._frame.get_global_rect()),"P09 safe "+section)
		check(G.ui_safe_rect(self).encloses(current._back.get_global_rect()),"P09 accessible return "+section)
		await photo("curio_"+section)
	check(before==JSON.stringify([G.wallet,G.items,G.prog]),"P09 navigation has no rewards or charges")
	current.navigate("appraise");var gold=int(G.wallet.gold)
	current.appraise();current.appraise();await frames()
	check(int(G.wallet.gold)==gold-260,"P09 appraise charges exactly once")
	await photo("curio_result")
	before=JSON.stringify([G.wallet,G.items,G.prog]);current.back();await frames()
	check(before==JSON.stringify([G.wallet,G.items,G.prog]),"P09 result confirmation never repeats reward")
	await resources_suite()
	await clean()

func resources_suite():
	await clean();fixture()
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/resource_manifest.json"))
	var missing:Array=[];var loaded=0
	for key in manifest:
		var texture=load(String(manifest[key]))
		if not texture is Texture2D or texture.get_width()<2:missing.append({"id":key,"path":manifest[key]})
		else:loaded+=1
		if loaded%20==0:await frames(1)
	check(missing.is_empty(),"M01 resource manifest loads on Android",missing)
	var supplies:Array=[]
	for id in G.items:
		var texture=G.res_tex(G.item_icon(id))
		supplies.append({"id":id,"icon":G.item_icon(id),"loaded":texture!=null})
	check(supplies.all(func(row):return row.loaded),"M01 all fixture materials and gems have textures",supplies)
	records.append({"manifest_entries":manifest.size(),"loaded":loaded,"missing":missing,"supplies":supplies})
	check(GmConsole._bar_layer==null,"M05 default GM overlay absent")

func pages_suite():
	fixture()
	for page in ["loading","title","login","home"]:await open_page(page)
	await open_page("bag")
	for tab in ["equip","mat","gem","pending"]:
		current._select_tab(tab);await frames();await photo("bag_"+tab)
		for button in current._item_buttons:
			if button.get("item_image")!=null:check(button.item_image.texture!=null,"M01 bag texture "+tab+" "+str(button.get_meta("supply_id",button.get_meta("gear_uid",0))))
		if tab=="equip" and current._item_buttons.size()>6:
			var first=current._item_buttons[0];var below=first.get_node_or_null(first.focus_neighbor_bottom)
			records.append({"focus_columns":current._scroll.get_child(0).columns,"first_row_down_actual":current._item_buttons.find(below),"expected":current._scroll.get_child(0).columns})
		current._scroll.scroll_vertical=100000;await frames();await photo("bag_"+tab+"_bottom")
	var before=G.wallet.duplicate(true)
	for id in ["gold","expedition","soul","honor"]:
		await open_page("currency",{"currency":id})
		check(current.currency_id==id and str(G.wallet[id]) in current._balance.text,"M07 correct currency and full balance "+id)
		await photo("currency_"+id);current._scroll.scroll_vertical=100000;await frames();await photo("currency_"+id+"_bottom")
	check(before==G.wallet,"M07 reading never changes balance")
	await open_page("gathering")
	for i in current.stories.size():
		current.listen(i);await frames();await photo("gathering_story_"+str(i));check(current.page.text.contains(String(current.stories[i].text)),"M10 full story text "+str(i))
	await open_page("modal");await photo("long_modal")
	for page in ["settings","growth","codex","gacha","exchange","quests","worlds","arena","archery","companion","shop","journal","oath","avatar","journey"]:
		await open_page(page)
		for node in current.find_children("*","ScrollContainer",true,false):node.scroll_vertical=100000
		await frames();await photo(page+"_bottom")
	for win in [true,false]:
		await clean()
		var report=preload("res://src/battle/BattleSettlementView.gd").new()
		report.report={"win":win,"title":"凯旋战报" if win else "整备再战","role_name":"破军","level":60,"hp_left":12345,"hp_max":23456,"pet_name":"青鸾与玄虎","seconds":123.4,"best_hit":1234567,"damage_out":23456789,"damage_in":123456,"rewards":{"gold":1234567,"expedition":23456,"soul":3456,"exp":45678}}
		await attach(report);await photo("settlement_"+str(win));report._scroll.scroll_vertical=100000;await frames();await photo("settlement_"+str(win)+"_bottom")
	check(GmConsole._bar_layer==null,"M05 overlay absent on all audited pages")
	await clean()

func make_map(id:String,role:String="zs",mount:String=""):
	G.selected_role=role;G.gm_world_open=true
	G.prog.main_world={"map_id":id}
	G.prog.flags["act3_supply_choice"]="merchant"
	if not mount.is_empty():G.mount_set_active(mount)
	G.mount_set_riding(not mount.is_empty(),false)
	var run=RunState.new();run.setup({"role_id":role,"theme":String(TableCache.main_world_map(id).get("theme","forest")),"level":60,"seed":71})
	MapScene.pending_cfg={"mode":"main_world","main_map_id":id,"run":run,"node":{"type":"normal","layer":1,"index":0}}
	return preload("res://src/explore/MapScene.tscn").instantiate()

func maps_suite():
	fixture()
	for id in TableCache.main_world_config().get("maps",{}):
		await clean()
		var fixture_map=make_map(String(id))
		# Freeze all actors for visual coverage, including monster contact callbacks.
		# Initial screenshots otherwise legitimately entered battles during sampling.
		fixture_map.process_mode=Node.PROCESS_MODE_DISABLED
		await attach(fixture_map)
		var map=current as MapScene
		map.set_physics_process(false)
		if map._city_content!=null:map._city_content.set_physics_process(false)
		check(map._player!=null and map._world!=null,"M06 map instantiated "+String(id))
		var blanks:Array=[]
		for node in map.find_children("*","Sprite2D",true,false):
			if node.is_visible_in_tree() and node.texture==null:blanks.append(str(map.get_path_to(node)))
		var extent=map._map_extent()
		var start=map._player.position
		var points=[start,extent*Vector2(.25,.25),extent*Vector2(.75,.25),extent*Vector2(.25,.75),extent*Vector2(.75,.75)]
		if id=="frost_post":points.append(Vector2(480,415))
		for i in points.size():
			map._player.position=points[i]
			for node in map._player.get_children():
				if node is Camera2D:node.reset_smoothing();node.force_update_scroll()
			await frames(10);await photo("map_"+String(id)+"_"+str(i))
		records.append({"map":id,"extent":str(extent),"spawn":str(start),"sample_positions":str(points),"blank_visible_sprites":blanks})
	await clean()

func mounts_suite(request:Dictionary={}):
	fixture()
	for mount in ["horse","bear"]:
		for role in ["zs","ck","fs","fz"]:
			await clean();await attach(make_map("lorin_wilds",role,mount))
			var map=current as MapScene
			var motion_origin=map._player.position
			map.set_physics_process(false)
			if map._city_content!=null:map._city_content.set_physics_process(false)
			for monster in map._monsters:
				if is_instance_valid(monster):monster.set_physics_process(false);monster.set_process(false)
			map._player.position=Vector2(480,700)
			for direction in ([] if bool(request.get("motion_only",false)) else [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]):
				var name="mount_%s_%s_%s"%[mount,role,str(direction).replace(" ","").replace(",","_").replace("(","").replace(")","")]
				map._update_player_anim(direction*180)
				map._mount_anim.pause();map._mount_hoof_timer=0;map._mount_contact_frame=-1
				for frame in 8:
					map._mount_anim.frame=frame;map._update_player_anim(direction*180);map._mount_anim.pause()
					await frames(1);await photo(name+"_"+str(frame))
				Audio._last_events.clear();Audio.event_log.clear()
				for voice in Audio._sfx_pool:voice.stop()
				map._mount_anim.frame=0;map._mount_contact_frame=-1;map._mount_hoof_timer=0
				map._tick_mount_hoof(.1,direction*180);map._tick_mount_hoof(.1,direction*180)
				check(Audio.event_log.size()==1,"M09 A05 one hoof event on held contact "+name)
				map._tick_mount_hoof(.1,Vector2.ZERO)
				check(map._mount_contact_frame==-1,"M09 stop clears contact "+name)
				check(map._mount_anim.sprite_frames.get_frame_count(map._mount_anim.animation)==8,"M08 eight sequential walking poses "+name)
				check(not map._player_anim.visible and map._mount_anim.visible,"M08 integrated rider and mount visible "+name)
			# Actual physics-driven normal/sprint/stop sequence; no forced anim frames.
			map.set_physics_process(true)
			for sprint in [false,true]:
				map._sprint=sprint;map._player.position=motion_origin
				var samples:Array=[]
				Audio.event_log.clear();Audio._last_events.clear()
				Input.action_press("move_down")
				var motion_started=Time.get_ticks_msec()
				while Time.get_ticks_msec()-motion_started<1800:
					await get_tree().physics_frame
					samples.append({"tick":Time.get_ticks_msec(),"frame":map._mount_anim.frame,"animation":str(map._mount_anim.animation),"playing":map._mount_anim.is_playing(),"riding":G.mount_riding(),"y":map._player.position.y,"velocity":map._player.velocity.length(),"modal":map._modal_open(),"city_modal":map._city_content!=null and bool(map._city_content.call("has_modal")),"ui_blocked":G.ui_blocked,"hoof_count":Audio.event_log.filter(func(row):return row.category=="Movement").size()})
				var seen={}
				for sample in samples:
					if sample.velocity>1:seen[sample.frame]=true
				check(seen.size()>=(10 if sprint else 6),"P10 actual moving gait advances "+mount+role+str(sprint),seen.keys())
				check(samples.all(func(sample):return sample.riding),"P10 remains mounted throughout isolated motion")
				check(samples.size()>1 and float(samples.back().y)-float(samples.front().y)>180.0,"P10 real world position advances during gait")
				check(samples.any(func(sample):return str(sample.animation).begins_with("run_" if sprint else "walk_") and sample.playing),"P10 requested gait is playing")
				check(Audio.event_log.any(func(row):return row.category=="Movement"),"P10 real hoof contacts audible")
				Input.action_release("move_down");await frames(6)
				var count=Audio.event_log.size();await pause(.4)
				check(Audio.event_log.size()==count,"M09 no hoof after stopping "+mount+role+str(sprint))
				records.append({"mount":mount,"role":role,"sprint":sprint,"samples":samples,"events":Audio.event_log.duplicate(true)})
	await clean()

func capture_start():
	capture_frames=PackedVector2Array()
	capture_effect=AudioEffectCapture.new();capture_effect.buffer_length=2.0
	AudioServer.add_bus_effect(0,capture_effect);capturing=true

func capture_finish(label:String):
	capturing=false
	var count=capture_effect.get_frames_available()
	if count>0:capture_frames.append_array(capture_effect.get_buffer(count))
	for i in range(AudioServer.get_bus_effect_count(0)-1,-1,-1):
		if AudioServer.get_bus_effect(0,i)==capture_effect:AudioServer.remove_bus_effect(0,i)
	var peak=0.0;var energy=0.0;var zeros=0
	var data=PackedByteArray();data.resize(capture_frames.size()*4)
	for i in capture_frames.size():
		var sample=capture_frames[i]
		peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)));energy+=sample.length_squared()
		if sample==Vector2.ZERO:zeros+=1
		data.encode_s16(i*4,roundi(clampf(sample.x,-1,1)*32767));data.encode_s16(i*4+2,roundi(clampf(sample.y,-1,1)*32767))
	var wav=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.stereo=true;wav.mix_rate=roundi(AudioServer.get_mix_rate());wav.data=data
	wav.save_to_wav(OUT+active_id+"/"+label+".wav")
	var row={"label":label,"frames":capture_frames.size(),"seconds":float(capture_frames.size())/AudioServer.get_mix_rate(),"peak":peak,"rms":sqrt(energy/maxi(1,capture_frames.size()*2)),"zero_frames":zeros,"discarded":capture_effect.get_discarded_frames()}
	records.append(row);capture_effect=null;capture_frames=PackedVector2Array()
	return row

func audio_suite():
	await clean();fixture()
	Audio.stop_bgm();Audio.play_bgm("bgm_home");await pause(.7)
	capture_start();await pause(1.0);var normal=capture_finish("normal_bgm")
	check(normal.peak>0 and normal.frames>0,"A07 native Android mix contains signal",normal)
	Audio.play_bgm("bgm_home");var initial=Audio._bgm.get_playback_position();Audio.play_bgm("bgm_home");await frames()
	check(Audio._bgm.get_playback_position()>=initial,"A01 repeat BGM does not restart")
	capture_start()
	for name in ["bgm_city","bgm_map","bgm_battle","bgm_home","bgm_title"]:Audio.play_bgm(name);await pause(.08)
	await pause(.7);capture_finish("rapid_bgm")
	check(Audio.current_bgm()=="bgm_title" and Audio._bgm.stream==Audio._stream("bgm_title"),"A01 rapid switch ends on requested track")
	Audio.play_bgm("bgm_battle");Audio.stop_bgm();await pause(.7)
	check(not Audio._bgm.playing and Audio.current_bgm().is_empty(),"A01 stop cancels pending fade callback")
	Audio.play_bgm("bgm_home");await pause(.4);Audio.sfx("reward");Audio.set_mute(true);await pause(.3)
	capture_start();Audio.sfx("hit_heavy");await pause(.8);var muted=capture_finish("global_mute")
	check(muted.frames>0 and muted.peak==0,"A02 global mute actual captured samples zero",muted)
	check(Audio.sfx_playing_count()==0,"A02 active effects cleared by mute")
	Audio.set_mute(false);Audio.set_bgm_vol(0);Audio.set_sfx_vol(0);await pause(.3)
	capture_start();Audio.sfx("reward");await pause(.8);var zero=capture_finish("zero_sliders")
	check(zero.frames>0 and zero.peak==0,"A02 both sliders zero actual captured samples zero",zero)
	Audio.set_bgm_vol(.7);Audio.set_sfx_vol(.8);await pause(.3)
	Audio.event_log.clear();Audio._last_events.clear()
	for voice in Audio._sfx_pool:voice.stop()
	Audio.sfx("victory",0)
	var protected:AudioStreamPlayer
	for voice in Audio._sfx_pool:
		if voice.get_meta("sound","")=="victory" and voice.playing:protected=voice
	var max_voices=0
	capture_start()
	for i in 40:
		for name in ["hit_light","hit_heavy","hit_crit","skill_cast","coin","reward"]:Audio.sfx(name)
		max_voices=maxi(max_voices,Audio.sfx_playing_count());await pause(.012)
		if i==5:check(protected!=null and protected.playing and protected.get_meta("sound","")=="victory","A03 pressure does not steal victory voice")
	var pressure=capture_finish("combat_pressure")
	check(max_voices<=Audio.SFX_POOL,"A03 bounded voice count",max_voices)
	check(pressure.peak<1.0,"A03 captured master has headroom",pressure)
	for voice in Audio._sfx_pool:voice.stop()
	Audio._last_events.clear();Audio.event_log.clear()
	Audio.sfx("boss_warn",0);Audio.sfx("low_hp",0);Audio.sfx("victory",0)
	await frames(2)
	check(Audio.event_log.any(func(row):return row.name=="victory"),"A03 victory can start when two lower-priority alerts occupy category",Audio.event_log.duplicate(true))
	await pause(.6);Audio.event_log.clear();Audio._last_events.clear()
	Audio.sfx("ui_click");Audio.sfx("ui_open");await frames(3)
	check(Audio.event_log.filter(func(row):return row.name=="ui_click").is_empty(),"A04 semantic feedback coalesces generic click",Audio.event_log.duplicate(true))
	var stream=Audio._stream("bgm_home")
	Audio.play_bgm("bgm_home");await pause(.6);Audio._bgm.seek(stream.get_length()-.3)
	capture_start();await pause(1.0);capture_finish("bgm_loop_join")
	check(Audio._bgm.playing and Audio._bgm.get_playback_position()<2.0,"A07 Android BGM crosses loop boundary")
	for role in ["zs","ck","fs","fz"]:
		Audio._last_events.clear();Audio.event_log.clear();Audio.cast(role);Audio.hit(role);await frames()
		records.append({"role":role,"events":Audio.event_log.duplicate(true)})
	Audio.play_bgm("bgm_home")

func audio_catalog():
	await clean();fixture()
	Audio.stop_bgm();Audio.stop_ambience();await pause(.3)
	Audio.event_log.clear()
	capture_start()
	var timeline:Array=[]
	for name in Audio.SFX_NAMES:
		for voice in Audio._sfx_pool:voice.stop()
		Audio._last_events.clear()
		var source=Audio._stream(name)
		timeline.append({"name":name,"sample_start":capture_frames.size(),"tick_ms":Time.get_ticks_msec(),"source_seconds":source.get_length()})
		Audio.sfx(name,0)
		await pause(source.get_length()+.12)
	var mixed=capture_finish("sfx_catalog")
	records.append({"timeline":timeline,"events":Audio.event_log.duplicate(true),"mix":mixed})
	check(timeline.size()==34,"A07 all 34 effects exercised on Android")
	Audio.play_bgm("bgm_home")

func motion_suite(request:Dictionary):
	fixture();await open_page("map",request)
	var map=current as MapScene
	if request.has("start"):map._player.position=Vector2(request.start[0],request.start[1])
	if map._city_content!=null:map._city_content.set_physics_process(false)
	for monster in map._monsters:
		if is_instance_valid(monster):monster.set_physics_process(false);monster.set_process(false)
	map._sprint=bool(request.get("sprint",false))
	Audio.event_log.clear();Audio._last_events.clear()
	var samples:Array=[]
	capture_start()
	var started=Time.get_ticks_msec()
	var directions=request.get("directions",["move_down","move_right","move_up","move_left"])
	var active=""
	var duration=float(request.get("seconds",15))
	while (Time.get_ticks_msec()-started)/1000.0<duration:
		var elapsed=(Time.get_ticks_msec()-started)/1000.0
		var direction=directions[mini(directions.size()-1,int(elapsed/(duration/directions.size())))]
		if active!=direction:
			if not active.is_empty():Input.action_release(active)
			if bool(request.get("isolated_directions",false)):
				map._player.position=clear_motion_origin(map,String(direction),duration/float(directions.size()))
				for camera in map._player.get_children():
					if camera is Camera2D:camera.reset_smoothing();camera.force_update_scroll()
			active=direction;Input.action_press(active)
		await get_tree().physics_frame
		samples.append({"tick":Time.get_ticks_msec(),"position":[map._player.position.x,map._player.position.y],"velocity":map._player.velocity.length(),"frame":map._mount_anim.frame,"animation":str(map._mount_anim.animation),"riding":G.mount_riding(),"modal":map._modal_open(),"city_modal":map._city_content!=null and bool(map._city_content.call("has_modal")),"ui_blocked":G.ui_blocked,"hoof_events":Audio.event_log.filter(func(row):return row.category=="Movement").size()})
	Input.action_release(active)
	await frames(6);var stop_events=Audio.event_log.size();await pause(.8)
	check(stop_events==Audio.event_log.size(),"M09 A05 no hoof events after stop in long motion")
	var mixed=capture_finish("motion_mix")
	records.append({"samples":samples,"audio_events":Audio.event_log.duplicate(true),"mix":mixed,"note":"Real Android map physics; monsters frozen to isolate motion; native joystick tested separately."})
	await photo("motion_end")

func clear_motion_origin(map:MapScene,direction:String,seconds:float)->Vector2:
	var vector:Vector2={"move_down":Vector2.DOWN,"move_right":Vector2.RIGHT,"move_up":Vector2.UP,"move_left":Vector2.LEFT}[direction]
	var speed=TableCache.map_player_speed()*float(G.first_mount_cfg().get("world_speed_mult",1.75))*(1.25 if map._sprint else 1.0)
	var motion=vector*speed*(seconds+.05)
	var extent=map._map_extent()
	var allowed=Rect2(70,1000,extent.x-140,950)
	var candidates:Array[Vector2]=[]
	for y in range(1050,1950,50):
		for x in range(100,int(extent.x)-100,50):candidates.append(Vector2(x,y))
	for origin in candidates:
		if not allowed.has_point(origin+motion):continue
		var transform=map._player.global_transform
		transform.origin=origin
		if not map._player.test_move(transform,motion,null,.08,true):
			check(true,"P10 native directional segment has clear original collisions "+direction,{"start":str(origin),"end":str(origin+motion)})
			return origin
	check(false,"P10 no sufficiently long clear native segment "+direction)
	return map._player.position

func battle_suite():
	fixture();await clean()
	BattleScene.pending_cfg={"ally":{"role_id":"zs","level":20,"traits":[],"potions":2},"enemy":{"theme":"forest","node_type":"normal","layer":1},"presentation":"classic_inline","seed":71}
	await attach(preload("res://src/battle/BattleScene.tscn").instantiate())
	await photo("battle_initial")
	await pause(8)
	await photo("battle_after8s")
	records.append({"battle_result":current.sim.result,"running_seconds":current.sim.tick_count/30.0})
