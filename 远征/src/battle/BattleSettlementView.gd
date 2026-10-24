extends PanelContainer
## Reading layout: fixed title/action, scrollable report, no scaled text or buttons.
signal confirmed
const Reading := preload("res://src/ui/ReadingSkin.gd")
var report: Dictionary = {}
var _scroll: ScrollContainer
var _column: VBoxContainer
var _confirm: Button
var _loot: GridContainer

func _ready() -> void:
	name = "SettlementModal"
	var box := StyleBoxTexture.new()
	box.texture = preload("res://assets/ui/kit_20261013/panel_iron.png")
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		box.set_texture_margin(side,24)
		box.set_content_margin(side,20)
	add_theme_stylebox_override("panel",box)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation",16)
	add_child(_column)
	var title := Reading.label(String(report.get("title","战报")),30,Color("ffe8a8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(title)
	_scroll = ScrollContainer.new()
	_scroll.name = "ReportScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	_column.add_child(_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",18)
	_scroll.add_child(body)
	var banner := TextureRect.new()
	banner.texture = load("res://assets/ui/battle_settle/victory_header_banner.png" if bool(report.get("win",false)) else "res://assets/ui/battle_settle/defeat_header_banner.png")
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	banner.custom_minimum_size.y = 104
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(banner)
	body.add_child(Reading.label("%s  ·  Lv.%d" % [report.get("role_name","旅人"),int(report.get("level",1))],26,Reading.TEXT))
	body.add_child(Reading.label("剩余生命 %d / %d\n协战伙伴：%s" % [int(report.get("hp_left",0)),int(report.get("hp_max",1)),report.get("pet_name","无")],22,Reading.TEXT))
	_section(body,"四维战功录")
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation",12)
	stats.add_theme_constant_override("v_separation",12)
	body.add_child(stats)
	for pair in [["战斗用时","%.1f 秒" % float(report.get("seconds",0))],["最高单击",str(report.get("best_hit",0))],["我方输出",str(report.get("damage_out",0))],["承受伤害",str(report.get("damage_in",0))]]:
		var card := Reading.frame(false)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(card)
		var rows := VBoxContainer.new()
		card.add_child(rows)
		rows.add_child(Reading.label(pair[0],20,Color("c7b69a")))
		rows.add_child(Reading.label(pair[1],26,Color("ffe298")))
	_section(body,String(report.get("loot_heading","凯旋战利品")))
	if bool(report.get("win",false)):
		_loot = GridContainer.new()
		_loot.columns = 2
		_loot.add_theme_constant_override("h_separation",12)
		_loot.add_theme_constant_override("v_separation",12)
		body.add_child(_loot)
		var reward: Dictionary = report.get("rewards",{})
		for row in [["金币","gold","cur_gold"],["远征币","expedition","cur_expedition"],["魂晶","soul","cur_soul"],["历练经验","exp","exp"]]:
			var card := Reading.frame(false)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_loot.add_child(card)
			var rows := VBoxContainer.new()
			rows.add_theme_constant_override("separation",8)
			card.add_child(rows)
			rows.add_child(Reading.label(row[0],22,Reading.TEXT))
			rows.add_child(Reading.label("+%d" % int(reward.get(row[1],0)),28,Color("ffe298")))
	else:
		for words in ["铁匠锻造：强化武器防具，精炼装备词条。","灵兽协战：喂养与升星伙伴，分担承伤。","招式药剂：调整技能衔接，备齐药剂再战。"]:
			body.add_child(Reading.label(words,22,Reading.TEXT))
	_confirm = Reading.button(String(report.get("action","继续征途")),true)
	_confirm.name = "ConfirmSettlement"
	_confirm.custom_minimum_size.y = 64
	_confirm.pressed.connect(func():
		_confirm.disabled = true
		confirmed.emit())
	_column.add_child(_confirm)
	get_viewport().size_changed.connect(layout)
	preload("res://src/ui/UiSafeArea.gd").watch(self,layout)
	layout()
	_confirm.grab_focus.call_deferred()

func _section(parent: VBoxContainer, words: String) -> void:
	parent.add_child(Reading.label(words,24,Color("e9c784")))

func layout() -> void:
	var safe := G.ui_safe_rect(self)
	var extent := Vector2(minf(600,safe.size.x-24),safe.size.y-24)
	position = (safe.get_center()-extent*.5).round()
	size = extent
	scale = Vector2.ONE
