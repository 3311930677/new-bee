class_name FishingPanel
extends Control
signal closed
const View := preload("res://src/ui/ShowcaseUI.gd")
var spot_id := ""
var _cast: Dictionary = {}
var _casting := false
var _closing := false
var _started := 0
var _phase := 0.0
var _band: ColorRect
var _needle: ColorRect
var _info: Label
var _message: Label
var _stage_label: Label
var _action_button: Button
var _gauge: Control
var _action_grid: GridContainer
var _page: VBoxContainer
var _water: FishingWater
var _result_icon: TextureRect

func open_spot(id: String) -> void:
	spot_id = id
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("safe_layout_exempt",true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := TextureRect.new()
	background.texture = load("res://assets/ui/experience_20261026/fishing_scene.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0,.04,.08,.20)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_page = View.column(12)
	add_child(_page)
	var top := HBoxContainer.new()
	_page.add_child(top)
	var title := View.column(4)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	title.add_child(View.text("水边垂钓","title",View.GOLD))
	title.add_child(View.text(String(G.fishing_spot(id).get("name","钓点")),"object"))
	var back := View.button("返回")
	back.custom_minimum_size.x = 80
	back.pressed.connect(close)
	top.add_child(back)
	_water = FishingWater.new()
	_water.snow=String(G.fishing_spot(id).get("map",""))=="frost_post"
	if _water.snow:background.modulate=Color(.80,.91,1.0)
	_water.custom_minimum_size.y = 70
	_water.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(_water)
	var frame := View.frame(14)
	frame.add_theme_stylebox_override("panel",View.surface(Color("102b32",.94),View.GOLD,14))
	_page.add_child(frame)
	var body := View.column(10)
	frame.add_child(body)
	var row := HBoxContainer.new()
	body.add_child(row)
	_result_icon = View.picture(null,56)
	_result_icon.hide()
	row.add_child(_result_icon)
	_info = View.text("","caption",View.JADE)
	row.add_child(_info)
	var spot := G.fishing_spot(id)
	_stage_label=View.text("准备抛竿 · "+String(spot.get("fish_name","水中游鱼")),"object",View.GOLD)
	body.add_child(_stage_label)
	_gauge = Control.new()
	_gauge.custom_minimum_size.y = 32
	body.add_child(_gauge)
	var track := ColorRect.new()
	track.color = Color("332d25")
	track.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.add_child(track)
	_band = ColorRect.new()
	_band.color = Color("70ad7d")
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.add_child(_band)
	_needle = ColorRect.new()
	_needle.color = View.GOLD
	_needle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.add_child(_needle)
	_gauge.resized.connect(_update_gauge)
	_message = View.text(String(spot.get("king_hint","") if G.fishing_king_available(id) else spot.get("environment_hint","抛竿后，在绿色区间收竿。")),"body")
	_message.custom_minimum_size.y = 54
	body.add_child(_message)
	var actions := GridContainer.new()
	_action_grid=actions
	actions.columns=2
	actions.add_theme_constant_override("h_separation",10)
	actions.add_theme_constant_override("v_separation",8)
	body.add_child(actions)
	_action_button = View.button("抛竿",true)
	_action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_button.pressed.connect(_act)
	actions.add_child(_action_button)
	var cook := View.button("鲜鱼制粮 1换1")
	cook.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cook.pressed.connect(_cook)
	actions.add_child(cook)
	var rules := View.text("每日三竿 · 返回放弃本竿","tag",View.MUTED)
	rules.tooltip_text="每处每游戏日三竿，市集歇脚可推进一日；离开会放弃当前一竿。"
	body.add_child(rules)
	_refresh_info()
	get_viewport().size_changed.connect(layout)
	preload("res://src/ui/UiSafeArea.gd").watch(self,layout)
	layout()

func layout() -> void:
	var safe := G.ui_safe_rect(self)
	var width := minf(620,safe.size.x-28)
	_page.position = Vector2(safe.get_center().x-width*.5,safe.position.y+14)
	_page.size = Vector2(width,safe.size.y-28)
	_action_grid.columns=1 if width<350 else 2
	_page.add_theme_constant_override("separation",8 if width<350 else 12)
	_water.custom_minimum_size.y=56 if width<350 else 70

func _update_gauge() -> void:
	if _gauge==null or _band==null:return
	var w := _gauge.size.x if _gauge.size.x>1 else 360.0
	var radius := .08 if bool(_cast.get("king",false)) else .12
	_band.position = Vector2((float(_cast.get("center",.5))-radius)*w,0)
	_band.size = Vector2(radius*2*w,32)
	_needle.size = Vector2(4,32)
	_needle.position = Vector2(_phase*maxf(0,w-4),0)

func _refresh_info() -> void:
	var iid := String(G.fishing_spot(spot_id).get("item", ""))
	_info.text = "第 %d 日余 %d 竿 · %s %d 条 · 图鉴 %d/%d" % [int(G.economy_state()["day"]), G.fishing_remaining(spot_id),
		G.item_name(iid), G.item_count(iid), (G.fishing_state()["discoveries"] as Array).size(),(TableCache.fishing_config().get("spots",[]) as Array).size()]


func _process(_delta: float) -> void:
	if not _casting:
		return
	var elapsed := float(Time.get_ticks_msec()-_started)/1000.0
	_stage_label.text="抛竿入水" if elapsed<.45 else "静候咬钩" if elapsed<1.1 else "看准时机 · 收竿"
	_phase = 1.0 - absf(fmod(elapsed, 2.0) - 1.0)
	_update_gauge()
	_water.casting = _casting
	_water.queue_redraw()


func _act() -> void:
	if _closing:
		return
	if not _casting:
		var res := G.fishing_begin(spot_id)
		if not bool(res.get("ok", false)):
			_message.text = "本日已钓三竿，可去市集歇脚推进一日。" if String(res.get("reason", "")) == "limit" else "存档暂不可写，请稍后再试。"
			return
		_cast = res.get("cast", {})
		_started = Time.get_ticks_msec()
		_phase = 0.0
		_casting = true
		Audio.sfx("ui_confirm")
		var radius:=.08 if bool(_cast.get("king",false)) else .12
		_update_gauge()
		_water.casting = true
		_result_icon.hide()
		_action_button.text = "收 竿"
		_message.text = "浮标进入绿色区间时收竿。" if not bool(res.get("resumed",false)) else "接回未完成的一竿，不再消耗次数。看准绿色区间收竿。"
		_refresh_info()
		return
	var radius:=.08 if bool(_cast.get("king",false)) else .12
	var hit := absf(_phase - float(_cast.get("center", 0.5))) <= radius
	var result := G.fishing_finish(String(_cast.get("token", "")), hit)
	if not bool(result.get("ok", false)):
		_message.text = "结算未保存，请再收竿一次。"
		return
	_casting = false
	_water.casting = false
	_water.queue_redraw()
	_result_icon.texture = G.res_tex(G.item_icon(String(result.get("item","")))) if hit else null
	_result_icon.visible = hit
	if hit:Audio.sfx("reward")
	_cast = {}
	_action_button.text = "再抛一竿"
	_stage_label.text="本竿收获" if hit else "鱼儿脱钩"
	_message.text = "钓得 %s ×1，已入背包。" % G.item_name(String(result.get("item", ""))) if hit else "鱼挣脱了。下一竿再留意浮标位置。"
	if bool(result.get("king",false)):_message.text="认出鱼王 · %s ×1，图志留下水情记录。"%G.item_name(String(result.item))
	_refresh_info()


func _cook() -> void:
	if _casting:
		_message.text = "先收竿，再整理这次的收获。"
		return
	var iid := String(G.fishing_spot(spot_id).get("item", ""))
	var res := G.fishing_cook(iid)
	_message.text = "制得宠物粮 ×1，可在伙伴养成中喂食。" if bool(res.get("ok", false)) else "当前钓点的鲜鱼不足。"
	_refresh_info()


func close() -> void:
	if _closing:
		return
	_closing = true
	if _casting:
		var result := G.fishing_finish(String(_cast.get("token", "")), false)
		if not bool(result.get("ok",false)):
			_closing = false
			_message.text = "放弃本竿未能保存，请稍后重试。"
			return
		_casting = false
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

class FishingWater extends Control:
	var casting := false
	var snow := false
	var clock := 0.0
	func _process(delta: float) -> void:
		clock+=delta
		queue_redraw()
	func _draw() -> void:
		if snow:
			for i in 16:
				var x := fmod(i*67.0+sin(clock+i)*10,maxf(1,size.x))
				var y := fmod(i*31.0+clock*12,maxf(1,size.y))
				draw_circle(Vector2(x,y),1.2,Color(1,1,1,.45))
		var center := size*Vector2(.57,.58)+Vector2(0,sin(clock*2)*2)
		for i in 3:
			var radius := 12+fmod(clock*8+i*14,42)
			draw_set_transform(center,0,Vector2(1,.35))
			draw_arc(Vector2.ZERO,radius,0,TAU,40,Color(.68,.86,.82,.32*(1-radius/60)),1,true)
		draw_set_transform(Vector2.ZERO)
		if casting:
			draw_line(Vector2(size.x*.12,size.y*.95),center,Color("c2c4a1",.65),1,true)
			draw_circle(center,4,Color("d7a64e"))
			draw_line(center-Vector2(0,13),center+Vector2(0,4),Color("fff0c4"),2,true)
			draw_line(center-Vector2(0,11),center-Vector2(0,4),Color("ba4d3f"),3,true)
