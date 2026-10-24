extends Node
## Desktop reproductions of physical-pixel device metrics, not Android certification.
const OUT := "res://shots/mobile_rework_20261024/"
var failures := 0
var checks := 0
var capture := false
var measurements: Array[Dictionary] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("RESPONSIVE_FAIL "+message)

func frames(count := 5) -> void:
	for i in count: await get_tree().process_frame

func discard(node: Node) -> void:
	remove_child(node)
	node.queue_free()
	await frames(2)

func photo(id: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+id+".png")

func _ready() -> void:
	capture = "--capture-mobile" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUT)
	G.SAVE_PATH="user://mobile_rework_isolated.json"
	G.save_locked=true
	G._init_state_defaults()
	G.save_locked=true
	G.selected_role="zs"
	G.player_name="手机布局复核"
	G.set_meta("ui_review_mode",true)
	G.wallet={"gold":123456789,"expedition":2345678,"soul":345678,"honor":45678}
	for stat in ["atk","def","hp"]:
		for tier in range(1,6): G.items["gem_%s_%d" % [stat,tier]]=9
	get_window().unresizable=false
	get_window().min_size=Vector2i(320,480)
	var profiles := [
		{"id":"small_16_9","pixels":Vector2i(720,1280),"top":48,"bottom":72},
		{"id":"tall_gesture","pixels":Vector2i(1080,2400),"top":72,"bottom":72,"cutouts":[Rect2i(450,0,180,96)]},
		{"id":"tall_three_buttons","pixels":Vector2i(1080,2520),"top":84,"bottom":144},
		{"id":"large_phone","pixels":Vector2i(1440,3200),"top":120,"bottom":96},
		{"id":"tablet_portrait","pixels":Vector2i(1600,2560),"top":64,"bottom":96},
		{"id":"short_window","pixels":Vector2i(1080,1440),"top":72,"bottom":96},
	]
	for profile in profiles:
		var pixels:Vector2i=profile.pixels
		var logical:=Vector2i(480,roundi(float(pixels.y)*480.0/pixels.x))
		get_window().size=logical
		get_window().content_scale_size=logical
		G.set_meta("device_layout_sample",{
			"screen_safe":Rect2(0,profile.top,pixels.x,pixels.y-profile.top-profile.bottom),
			"transform":Transform2D(Vector2(pixels.x/480.0,0),Vector2(0,pixels.x/480.0),Vector2.ZERO),
			"cutouts":profile.get("cutouts",[])
		})
		await frames()
		var safe:=G.ui_safe_rect(self)
		check(absf(get_viewport().get_visible_rect().size.y-logical.y)<1,"actual viewport "+String(profile.id))
		check(absf(safe.end.y-(pixels.y-int(profile.bottom))*480.0/pixels.x)<1,"physical navigation inset "+String(profile.id))
		if profile.has("cutouts"): check(absf(safe.position.y-96.0*480.0/pixels.x)<.1,"physical cutout overrides smaller bar inset")
		var bag:=preload("res://src/ui/BagPanel.gd").new()
		add_child(bag)
		bag._select_tab("gem")
		await frames(8)
		var grid:=bag._scroll.get_child(0) as GridContainer
		check(grid.columns==4,"phone-width inventory uses readable four-column cells")
		check(safe.encloses(bag._close_btn.get_global_rect()),"inventory return safe "+String(profile.id))
		check(bag._close_btn.size.y>=56 and bag._tabs.size.y>=60,"inventory touch targets retained")
		check(bag._list.get_global_rect().end.y<bag._tray.get_global_rect().position.y,"inventory and detail do not overlap")
		for cell in bag._item_buttons:
			check(cell.item_image.texture!=null and cell.size.x>=96,"occupied gem has art and sufficient cell width")
		check(bag._detail_scroll.size.y>=48,"detail remains scrollable")
		await photo(String(profile.id)+"_bag")
		await discard(bag)
		var currency:=preload("res://src/ui/CurrencyPanel.gd").new()
		currency.currency_id="gold"
		add_child(currency)
		await frames(8)
		check(absf(currency._frame.size.y-(safe.size.y-24))<1,"currency uses available height")
		check("123456789" in currency._balance.text,"full balance visible in model")
		check(safe.encloses(currency._frame.get_global_rect()),"currency content fits safe area")
		check(currency._scroll.size.y>=100,"currency has useful reading area")
		await photo(String(profile.id)+"_currency")
		await discard(currency)
		var gathering:=preload("res://src/ui/CampGatheringPanel.gd").new()
		add_child(gathering)
		gathering.listen(1)
		await frames(8)
		check(safe.encloses(gathering._frame.get_global_rect()),"gathering frame does not grow beyond short screen")
		check(gathering._reading_scroll.size.y>=48,"gathering story can be read on short screen")
		for button in gathering._buttons: check(button.size.y>=60,"story touch targets are not scaled down")
		await photo(String(profile.id)+"_gathering")
		await discard(gathering)
		var result:=preload("res://src/battle/BattleSettlementView.gd").new()
		result.report={"title":"凯旋战报","win":true,"role_name":"手机布局复核","hp_left":1234,"hp_max":5678,"level":60,"rewards":{"gold":123456,"soul":42,"expedition":58,"exp":1200},"damage_out":1234567}
		add_child(result)
		await frames(8)
		check(result.scale==Vector2.ONE,"settlement never scales text or touch targets")
		check(safe.encloses(result.get_global_rect()),"settlement fits safe area")
		check(result._confirm.size.y>=64 and safe.encloses(result._confirm.get_global_rect()),"settlement action stays visible at full size")
		check(result._scroll.size.y>=160,"settlement report is scrollable")
		result._scroll.scroll_vertical=100000
		await frames()
		check(result._scroll.scroll_vertical>0,"actual settlement can scroll to rewards")
		await photo(String(profile.id)+"_settlement")
		measurements.append({"profile":profile.id,"pixels":str(pixels),"logical":str(logical),"safe":str(safe),"settlement_scroll":result._scroll.scroll_vertical})
		await discard(result)
	G.remove_meta("device_layout_sample")
	get_window().size=Vector2i(480,800)
	get_window().content_scale_size=Vector2i(480,800)
	await frames()
	await _verify_home_pointer()
	var output:=FileAccess.open("res://tools/_logs/mobile_rework_metrics.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(measurements,"\t"))
	output.close()
	print("MOBILE_REWORK_OK checks=%d failures=%d" % [checks,failures])
	await frames()
	get_tree().quit(0 if failures==0 else 1)

func _verify_home_pointer() -> void:
	var town:=preload("res://src/ui/home/TownHome.gd").new()
	add_child(town)
	await frames(8)
	var opened: Array[String]=[]
	town.entry_pressed.connect(func(id:String):opened.append(id))
	var button:=town._rail.bag as BaseButton
	var point:=button.get_global_rect().get_center()
	var move:=InputEventMouseMotion.new()
	move.position=point
	move.global_position=point
	Input.parse_input_event(move)
	await frames()
	for pressed in [true,false]:
		var click:=InputEventMouseButton.new()
		click.button_index=MOUSE_BUTTON_LEFT
		click.position=point
		click.global_position=point
		click.pressed=pressed
		Input.parse_input_event(click)
		await frames()
		if pressed: check(opened.is_empty(),"navigation does not fire on pointer down")
	check(opened==["bag"],"one pointer interaction opens exactly one inventory")
	await discard(town)
