class_name FishingPanel
extends Control

signal closed

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
var _action_label: Label


func open_spot(id: String) -> void:
	spot_id = id
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	G.veil(self, 0.72, true)
	var top := (maxf(800.0, get_viewport_rect().size.y) - 470.0) * 0.5
	var banner := G.banner_box("水边垂钓", 260, 48)
	banner.position = Vector2(110, top - 58)
	add_child(banner)
	var paper := G.parchment_box(432, 470, 16.0)
	paper.position = Vector2(24, top)
	add_child(paper)
	var body := Control.new()
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(body)
	var pic := TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.texture = G.res_tex("itm_fish_common")
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.position = Vector2(158, 10)
	pic.size = Vector2(84, 84)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(pic)
	pic.size = Vector2(84, 84)
	var spot := G.fishing_spot(spot_id)
	_label(body, String(spot.get("name", "钓点")), Vector2(12, 103), 376, G.FS_MD)
	_info = _label(body, "", Vector2(12, 140), 376, G.FS_SM)
	_label(body, "抛竿后，等浮标进入绿色区域再收竿。", Vector2(12, 178), 376, G.FS_SM)
	var gauge := ColorRect.new()
	gauge.color = Color("4b6968")
	gauge.position = Vector2(20, 220)
	gauge.size = Vector2(360, 30)
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(gauge)
	_band = ColorRect.new()
	_band.color = Color("94b872")
	_band.size = Vector2(86.4, 30)
	_band.position = Vector2(136.8, 0)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge.add_child(_band)
	_needle = ColorRect.new()
	_needle.color = Color("fff0ba")
	_needle.size = Vector2(5, 38)
	_needle.position = Vector2(0, -4)
	_needle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge.add_child(_needle)
	_message = _label(body, "每处每游戏日三竿。市集歇脚可推进一日，离开会放弃当前一竿。", Vector2(12, 263), 376, G.FS_SM)
	var action := _button(body, "抛 竿", Vector2(12, 330), 184, _act)
	_action_label = action.get_child(0) as Label
	_button(body, "鲜鱼制粮 · 1 换 1", Vector2(206, 330), 184, _cook)
	_button(body, "返 回", Vector2(140, 402), 120, close)
	_refresh_info()


func _label(parent: Control, value: String, at: Vector2, width: float, fs: int) -> Label:
	var lab := G.text_label(value, fs, Color("493724"))
	lab.position = at
	lab.custom_minimum_size = Vector2(width, 0)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(lab)
	return lab


func _button(parent: Control, value: String, at: Vector2, width: int, action: Callable) -> Control:
	var btn := G.gold_button(value, width, 44, G.FS_SM)
	btn.position = at
	btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			action.call())
	parent.add_child(btn)
	return btn


func _refresh_info() -> void:
	var iid := String(G.fishing_spot(spot_id).get("item", ""))
	_info.text = "第 %d 日余 %d 竿 · %s %d 条 · 图鉴 %d/3" % [int(G.economy_state()["day"]), G.fishing_remaining(spot_id),
		G.item_name(iid), G.item_count(iid), (G.fishing_state()["discoveries"] as Array).size()]


func _process(_delta: float) -> void:
	if not _casting:
		return
	_phase = 1.0 - absf(fmod(float(Time.get_ticks_msec() - _started) / 1000.0, 2.0) - 1.0)
	_needle.position.x = _phase * 355.0


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
		_band.position.x = (float(_cast.get("center", 0.5)) - 0.12) * 360.0
		_action_label.text = "收 竿"
		_message.text = "看准绿色区域。重启后在同一钓点可接回未完成的一竿。"
		_refresh_info()
		return
	var hit := absf(_phase - float(_cast.get("center", 0.5))) <= 0.12
	var result := G.fishing_finish(String(_cast.get("token", "")), hit)
	if not bool(result.get("ok", false)):
		_message.text = "结算未保存，请再收竿一次。"
		return
	_casting = false
	_cast = {}
	_action_label.text = "再抛一竿"
	_message.text = "钓得 %s ×1，已入背包。" % G.item_name(String(result.get("item", ""))) if hit else "鱼挣脱了。下一竿再留意浮标位置。"
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
		G.fishing_finish(String(_cast.get("token", "")), false)
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
