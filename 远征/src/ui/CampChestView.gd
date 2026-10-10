extends Control
const UI := preload("res://src/ui/TravelChestUI.gd")
const CAMP := "res://image/background/art_v2/camp_bluehour.png"
var host: Control
var content: Control
var _background: TextureRect
var _sky: TextureRect
var _veil: TextureRect
var _name: Label
var _level: Label
var _percent: Label
var _exp_bg: ColorRect
var _exp_fill: ColorRect
var _quest: Button
var _rail: Array[Button] = []
var _nav: Array[Button] = []
var _settings: Button
var _hero: Button
var _role_name: Label
var _job: Label
var _pool: TextureRect
var _shadow: Node2D
var _avatar: Button
var _safe := Rect2()
var _compact := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UI.theme()
	_background = TextureRect.new()
	_background.texture = load(CAMP)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_background)
	_sky = TextureRect.new()
	_sky.texture = load(UI.ROOT+"camp_sky.png")
	_sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform sampler2D original : filter_nearest;
uniform float extra_height=267.0;
uniform float layer_height=307.0;
uniform float fraction=0.30;
void fragment(){
 float y=UV.y*layer_height;
 vec4 sky=texture(TEXTURE,vec2(UV.x,UV.y*fraction));
 vec4 base=texture(original,vec2(UV.x,clamp((y-extra_height)/800.0,0.0,1.0)));
 COLOR=mix(sky,base,smoothstep(extra_height-40.0,extra_height+40.0,y));
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("original",_background.texture)
	material.set_shader_parameter("fraction",_sky.texture.get_width()*300.0/480.0/_sky.texture.get_height())
	_sky.material = material
	add_child(_sky)
	_veil = preload("res://src/ui/LacquerUI.gd").scrim(Vector2(480,160))
	add_child(_veil)
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	_build_identity()
	_build_wallet()
	_quest = UI.QuestSlip.new()
	_quest.name = "QuestSummary"
	_quest.pressed.connect(func(): host._open_quests())
	content.add_child(_quest)
	var entries := [["活动","event"],["竞技","arena"],["召唤","summon"],["兑换","exchange"],["小聚","reunion"]]
	for i in entries.size():
		var index := i
		var button := UI.action(entries[i][0],"rail",entries[i][1])
		button.name = ["ActivitiesEntry","ArenaEntry","SummonEntry","ExchangeEntry","ReunionEntry"][i]
		button.pressed.connect(func(): _activate_rail(index))
		content.add_child(button)
		_rail.append(button)
	_build_stage()
	_hero = UI.action("继续旅程","hero","journey")
	_hero.name = "ReturnToWorld"
	_hero.pressed.connect(_continue_journey)
	content.add_child(_hero)
	var tray := UI.Tray.new()
	tray.name = "NavigationTray"
	content.add_child(tray)
	var nav := [["世界","world"],["背包","bag"],["养成","growth"],["图鉴","codex"]]
	for entry in nav:
		var words: String = entry[0]
		var b := UI.action(words,"nav",entry[1])
		b.name = "Navigation_"+words
		b.pressed.connect(func(): host._dispatch_entry(words))
		content.add_child(b)
		_nav.append(b)
	get_viewport().size_changed.connect(layout)
	layout()
	refresh()
	_hero.grab_focus()

func _build_identity() -> void:
	_avatar = _AvatarButton.new()
	_avatar.name = "AvatarEntry"
	_avatar.size = Vector2(56,56)
	_avatar.pressed.connect(func(): host._open_avatar_panel())
	content.add_child(_avatar)
	host._avatar_frame = _avatar
	host._avatar_pic = _avatar.picture
	_name = UI.label(G.display_name(),"section")
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.clip_text = true
	content.add_child(_name)
	_level = UI.label("","caption",UI.AGED)
	content.add_child(_level)
	_percent = UI.label("","tag",UI.AGED)
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content.add_child(_percent)
	_exp_bg = ColorRect.new()
	_exp_bg.color = UI.FACE
	_exp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_exp_bg)
	_exp_fill = ColorRect.new()
	_exp_fill.color = UI.BLUE
	_exp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_exp_bg.add_child(_exp_fill)
	_settings = UI.action("","icon","settings")
	_settings.name = "SettingsEntry"
	_settings.tooltip_text = "设置"
	_settings.pressed.connect(func(): host._open_settings(host._click_ev()))
	content.add_child(_settings)

func _build_wallet() -> void:
	var row := HBoxContainer.new()
	row.name = "CurrencyRow"
	row.add_theme_constant_override("separation",4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(row)
	host._wallet_row = row
	for data in [["金币","gold","cur_gold"],["远征币","expedition","cur_expedition"],["魂晶","soul","cur_soul"],["荣誉","honor","cur_honor"]]:
		var chip := UI.CurrencyChip.new()
		chip.name = "Currency_"+data[1]
		chip.currency_image.texture = G.res_tex(data[2])
		chip.pressed.connect(func(): host._show_chest_dialog("行囊与货币",G.wallet_info_lines()))
		row.add_child(chip)
		host._wallet_labels.append({"label":chip.amount,"key":data[1],"name":data[0],"button":chip})

func _build_stage() -> void:
	_pool = TextureRect.new()
	_pool.texture = UI.texture("stage_pool")
	_pool.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pool.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pool.modulate.a = 0.18 / maxf(0.18,float(UI._regions.get("stage_pool",{}).get("alpha_max",255))/255.0)
	content.add_child(_pool)
	_shadow = _Contact.new()
	content.add_child(_shadow)
	host._anim = AnimatedSprite2D.new()
	host._anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host._anim.scale = Vector2.ONE*2
	host._anim.sprite_frames = host._frames(G.selected_role if not G.selected_role.is_empty() else "zs")
	host._anim.animation = &"idle"
	host._anim.play()
	content.add_child(host._anim)
	var role := G.get_role(G.selected_role)
	_role_name = UI.label(String(role.get("name","旅人")),"title")
	_role_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_role_name)
	_job = UI.label("","caption",UI.AGED)
	_job.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_job)

func layout(safe_override: Rect2 = Rect2()) -> void:
	var view := get_viewport_rect()
	_safe = safe_override if safe_override.has_area() else G.ui_safe_rect(self)
	_background.position = Vector2((view.size.x-480)*0.5,view.size.y-800)
	_background.size = Vector2(480,800)
	_sky.visible = view.size.y>800
	_sky.size = Vector2(view.size.x,maxf(1,view.size.y-800+40))
	(_sky.material as ShaderMaterial).set_shader_parameter("extra_height",maxf(0,view.size.y-800))
	(_sky.material as ShaderMaterial).set_shader_parameter("layer_height",_sky.size.y)
	_veil.size = Vector2(view.size.x,_safe.position.y+160)
	var origin := _safe.position
	var right := _safe.end.x
	_avatar.position = origin+Vector2(12,8)
	_name.position = origin+Vector2(72,8)
	_name.size = Vector2(172,26)
	_level.position = origin+Vector2(72,34)
	_level.size = Vector2(52,22)
	_exp_bg.position = origin+Vector2(128,46)
	_exp_bg.size = Vector2(64,4)
	_percent.position = origin+Vector2(196,34)
	_percent.size = Vector2(48,22)
	_settings.position = Vector2(right-56,origin.y+10)
	_settings.size = Vector2(44,44)
	host._wallet_row.position = origin+Vector2(12,66)
	host._wallet_row.size = Vector2(_safe.size.x-24,44)
	_quest.position = origin+Vector2(12,120)
	_quest.size = Vector2(248,68)
	_compact = _safe.size.y<760
	for i in _rail.size():
		_rail[i].position = Vector2(right-68,origin.y+120+i*64)
		_rail[i].size = Vector2(56,60)
	_hero.position = Vector2(origin.x+40,_safe.end.y-204)
	_hero.size = Vector2(_safe.size.x-80,72)
	var feet := _hero.position.y-56
	host._anim.position = Vector2(_safe.get_center().x,feet-118)
	_shadow.position = Vector2(_safe.get_center().x,feet)
	_pool.position = Vector2(_safe.get_center().x-100,feet-32)
	_pool.size = Vector2(200,48)
	_role_name.position = Vector2(_safe.get_center().x-100,feet)
	_role_name.size = Vector2(200,32)
	_job.position = Vector2(_safe.get_center().x-100,feet+34)
	_job.size = Vector2(200,18)
	var tray := content.get_node("NavigationTray") as Control
	tray.position = Vector2(0,_safe.end.y-88)
	tray.size = Vector2(view.size.x,view.size.y-tray.position.y)
	for i in _nav.size():
		var width := (_safe.size.x-36)/4
		_nav[i].position = Vector2(origin.x+12+i*(width+4),_safe.end.y-88)
		_nav[i].size = Vector2(width,76)
	refresh()

func refresh() -> void:
	if _name == null: return
	var name_text := G.display_name()
	_name.text = name_text.left(8)+"…" if name_text.length()>8 else name_text
	_name.tooltip_text = G.display_name()
	var level := int(G.prog.get("level",1))
	_level.text = "LV %02d" % level
	var need := G.exp_to_next(level)
	var ratio := 1.0 if need<=0 else clampf(float(G.prog.get("exp",0))/need,0,1)
	_percent.text = "%d%%" % roundi(ratio*100)
	_exp_fill.size = Vector2(_exp_bg.size.x*ratio,4)
	var goal := String(G.story_current().get("goal","查看主线与今日委托"))
	_quest.goal.text = goal
	_quest.claimable = host._quest_claimable()
	_quest.queue_redraw()
	for i in _rail.size():
		_rail[i].hint_dot = host._entry_has_badge(["活动","竞技","召唤","兑换",""][i])
		_rail[i].queue_redraw()
	var unlocked := G.side_status_of("a4_rel_nighttable")==QuestService.SIDE_DONE
	_rail[4].locked = not unlocked and not _compact
	_rail[4].caption.text = "更多" if _compact else "小聚"
	_rail[4].tooltip_text = "更多行旅活动" if _compact else ("归路小聚" if unlocked else "完成归路小聚支线后开放")
	var state: Dictionary = G.prog.get("main_world",{})
	var place := String(TableCache.main_world_map(String(state.get("map_id","lorin_wilds"))).get("name","昭元边城"))
	_hero.subtitle.text = "整备中…" if _hero.disabled else place
	_hero.subtitle.clip_text = true
	_hero.subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hero.tooltip_text = "返回主世界 · "+place
	var role := G.get_role(G.selected_role)
	_job.text = "%s · LV %02d" % [role.get("job",""),level]
	for entry in host._wallet_labels:
		var value := int(G.wallet.get(entry.key,0))
		entry.label.text = UI.format_number(value)
		entry.button.tooltip_text = "%s：%d" % [entry.name,value]

func _activate_rail(index: int) -> void:
	if index<4:
		host._dispatch_entry(["活动","竞技","召唤","兑换"][index])
	elif _compact:
		host._show_chest_dialog("行旅小聚",["归路旧识，相约营灯之下。"], ["归路小聚"],func(_choice:int): _open_reunion())
	else: _open_reunion()

func _open_reunion() -> void:
	if G.side_status_of("a4_rel_nighttable")==QuestService.SIDE_DONE: host._open_gathering()
	else: UI.toast(host,"完成归路小聚支线后开放")

func _continue_journey() -> void:
	if G.ui_blocked or not G.can_go("res://src/explore/MapScene.tscn"): return
	_hero.disabled = true
	refresh()
	var tw := create_tween()
	tw.tween_property(self,"modulate:a",0.0,0.24)
	tw.tween_callback(func(): host._open_city(host._click_ev()))

class _AvatarButton extends Button:
	const Chest = preload("res://src/ui/TravelChestUI.gd")
	var picture: TextureRect
	func _ready() -> void:
		tooltip_text = "更换头像"
		focus_mode = Control.FOCUS_ALL
		for state in ["normal","hover","pressed","focus","disabled"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
		picture = TextureRect.new()
		picture.texture = G.avatar_texture()
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		picture.position = Vector2(6,6)
		picture.size = Vector2(44,44)
		var mask := Shader.new()
		mask.code = "shader_type canvas_item; varying vec4 tint; void vertex(){tint=COLOR;} void fragment(){vec4 c=texture(TEXTURE,UV)*tint; c.a*=1.0-smoothstep(0.49,0.5,length(UV-vec2(0.5))); COLOR=c;}"
		var masked := ShaderMaterial.new()
		masked.shader = mask
		picture.material = masked
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(picture)
		for event in [mouse_entered,mouse_exited,focus_entered,focus_exited]: event.connect(queue_redraw)
	func _draw() -> void:
		draw_circle(Vector2(28,28),27,Chest.NIGHT)
		draw_arc(Vector2(28,28),26,0,TAU,64,Chest.COPPER,2,true)
		if has_focus(): draw_arc(Vector2(28,28),30,0,TAU,64,Chest.GOLD,2,true)

class _Contact extends Node2D:
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO,0,Vector2(1,0.19))
		draw_circle(Vector2.ZERO,34,Color("0e0d10",0.18))
		draw_circle(Vector2(0,-2),22,Color("0e0d10",0.16))
