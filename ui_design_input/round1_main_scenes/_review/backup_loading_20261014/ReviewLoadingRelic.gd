extends Node
## Captures and checks the real loading page without touching player saves.
var _fails := 0
var _out := "res://shots/loading_relic_20261007"
var _reports: Array = []

func _ready() -> void:
	G.SAVE_PATH = "user://save_review_loading_relic.json"
	G.save_locked = true
	G.set_meta("ui_review_mode",true)
	var baseline_source := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): _out = arg.trim_prefix("--out=")
		if arg.begins_with("--baseline-source="): baseline_source = arg.trim_prefix("--baseline-source=")
	DirAccess.make_dir_recursive_absolute(_out)
	if not baseline_source.is_empty():
		await _baseline(baseline_source)
		return
	var view := SubViewport.new()
	view.size = Vector2i(480,800)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(view)
	var page: Control = load("res://src/ui/LoadScreen.tscn").instantiate()
	page.set("auto_advance",false)
	view.add_child(page)
	page.set_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	print("LOGO_SOURCE imported_size=",preload("res://image/ui/expedition_wordmark_v1.png").get_size(),
		" alpha_bounds=",preload("res://image/ui/expedition_wordmark_v1.png").get_image().get_used_rect())
	for height in [800,1067]:
		view.size = Vector2i(480,height)
		await get_tree().process_frame
		await get_tree().process_frame
		for progress in [0.0,.49,1.0]:
			page.call("_set_bar_ratio",progress)
			var gauge: Control = page.get_node("LoadingGauge")
			var percent: Label = gauge.get_node("LoadingPercent")
			var status: Label = gauge.get_node("LoadingStatus")
			var width: float = page.call("bar_fill_width")
			_check(is_equal_approx(width,300.0*progress),"filled width tracks "+str(progress))
			_check(percent.text == "%d%%"%roundi(progress*100),"percent matches rail")
			_check((status.text == "整备完成") == (progress == 1.0),"completion text only at 100%")
			_check(gauge.get_global_rect().end.y <= height-44,"panel clears lore and bottom")
			await RenderingServer.frame_post_draw
			var name := "loading-game-%d-%02d.png"%[height,roundi(progress*100)]
			var err := view.get_texture().get_image().save_png(_out+"/"+name)
			_check(err == OK,"PNG saved")
			_reports.append({"size":[480,height],"ratio":progress,"fill_width":width,
				"status":status.text,"percent":percent.text,
				"gauge_rect":str(gauge.get_global_rect()),"image":name})
	page.call("_set_bar_ratio",.999)
	_check(page.get_node("LoadingGauge/LoadingPercent").text=="99%",
		"percentage cannot reach 100 before completion")
	_check(page.get_node("LoadingGauge/LoadingStatus").text!="整备完成",
		"nearly complete still shows the current stage")
	# Check out-of-range progress, resize and a simulated device safe area.
	for progress in [-.5,1.5]:
		page.call("_set_bar_ratio",progress)
		_check(is_equal_approx(float(page.call("bar_fill_width")),300.0*clampf(progress,0,1)),
			"progress clamped")
	var tips: Label = page.get_node("LoadingTip")
	_check(tips.size.x >= tips.get_minimum_size().x,"lore hint fits its rect")
	var inset_safe := Rect2(8,36,464,1007)
	page.call("_layout",inset_safe)
	var inset_gauge: Control = page.get_node("LoadingGauge")
	_check(inset_safe.encloses(inset_gauge.get_global_rect()),"safe area contains loading frame")
	_check(inset_safe.encloses(tips.get_global_rect()),"safe area contains hint")
	page.call("_layout")
	# Complete the existing warm-up queue to make sure visual changes preserve it.
	var guard := 0
	while not bool(page.get("_done")) and guard < 600:
		page.call("_process",1.0/60.0)
		guard += 1
		await get_tree().process_frame
	_check(bool(page.get("_done")),"prewarm completes")
	_check((page.get("_queue") as Array).is_empty() and (page.get("_code") as Array).is_empty()
		and (page.get("_ground") as Array).is_empty(),"all warm-up queues drained")
	_reports.append({"warmup_frames":guard,"completed":page.get("_done")})
	var physical_fill: Control = page.get("_bar_fill")
	_check(physical_fill.get_parent()!=null and not physical_fill.get_parent() is Container,
		"lit blade remains a native control free of container stretching")
	# Exercise the original ink reveal shader and the crystal's live breathing.
	G.set_meta("ui_review_mode",false)
	var animated: Control = load("res://src/ui/LoadScreen.tscn").instantiate()
	animated.set("auto_advance",false)
	view.add_child(animated)
	animated.set_process(false)
	animated.call("_set_bar_ratio",.49)
	await get_tree().create_timer(1.05).timeout
	var mark: TextureRect = animated.get_node("LoadingBrand/ExpeditionWordmark")
	_check(is_equal_approx(float(mark.material.get_shader_parameter("reveal")),1.0),
		"ink animation completes")
	var live_gauge: Control = animated.get_node("LoadingGauge")
	_check(float(live_gauge.get("_clock"))>0.0,"crystal breathing advances")
	_reports.append({"ink_reveal":mark.material.get_shader_parameter("reveal"),
		"crystal_clock":live_gauge.get("_clock")})
	animated.queue_free()
	G.set_meta("ui_review_mode",true)
	await get_tree().process_frame
	var report := FileAccess.open(_out+"/loading-game-verification.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"failures":_fails,"checks":_reports},"\t"))
	page.queue_free()
	view.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("LOADING_REVIEW_OK failures=",_fails)
	get_tree().quit(0 if _fails == 0 else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		_fails += 1
		push_error("LOADING_REVIEW_FAIL "+message)

func _baseline(source_path: String) -> void:
	var historical := GDScript.new()
	historical.source_code = FileAccess.get_file_as_string(source_path)
	_check(historical.reload()==OK,"baseline source compiles")
	var view := SubViewport.new()
	view.size = Vector2i(480,800)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var page: Control = historical.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.set("auto_advance",false)
	view.add_child(page)
	page.set_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	page.call("_set_bar_ratio",.49)
	page.get("_bar_l").set("text","擦拭兵器……")
	await RenderingServer.frame_post_draw
	_check(view.get_texture().get_image().save_png(_out+"/loading-game-before.png")==OK,"baseline screenshot")
	view.queue_free()
	page = null
	historical = null
	await get_tree().process_frame
	await get_tree().process_frame
	print("LOADING_BASELINE_OK failures=",_fails)
	get_tree().quit(0 if _fails==0 else 1)
