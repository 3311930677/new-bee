# 技能研习：具名导航、招式图示和同一行的升级收益。
class_name SkillBookPanel
extends Control

signal closed
const CONTENT_W := 376.0
const DECK_H := 456.0
const PageDeckScript := preload("res://src/ui/PageDeck.gd")
const Field := preload("res://src/ui/FieldUI.gd")
var _deck: Control = null
var _expedition_l: Label = null
var _toast: Label = null
var _content: Control = null
var _tabs: Array = []
var _sids: Array = []

func _ready() -> void:
	G.center_fixed_page.call_deferred(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_sids = G.get_role(G.selected_role).get("skills",[])
	_build()

func _build() -> void:
	G.veil(self,.90)
	Field.heading(self,"技能书","招式研习 / " + String(G.get_role(G.selected_role).get("name","")))
	var paper := Field.surface(Vector2(24,128),Vector2(432,572),true)
	add_child(paper)
	_content = Control.new()
	_content.position = Vector2(28,0)
	_content.size = Vector2(CONTENT_W,572)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(_content)
	_expedition_l = Field.label("",Vector2(0,14),Vector2(318,28),16,G.FIELD_INK,true)
	_content.add_child(_expedition_l)
	var info := Field.action("?",Vector2(332,4),Vector2(44,44),false,true)
	info.quiet = true
	info.tooltip_text = "技能书规则"
	info.activated.connect(func(): G.show_info_popup(info,"技能书规则",[
		"每门招式最高 %d 级；每级增幅作用于基础伤害系数。" % G.skill_max_level(),
		"研习消耗远征币，后续等级所需远征币更多。",
		"效果型技能的持续时间、效果与冷却不随研习等级改变。" ]))
	_content.add_child(info)
	for i in _sids.size():
		var width := CONTENT_W / maxf(1,_sids.size())
		var words := String(TableCache.get_skill(String(_sids[i])).get("name",_sids[i]))
		var tab := Field.action(words,Vector2(i*width,52),Vector2(width,44),false,true)
		tab.quiet = true
		tab.accent = G.FIELD_ROLE.get(G.selected_role,G.FIELD_COPPER)
		tab.caption.position.x = 0
		tab.caption.size.x = width
		tab.caption.add_theme_font_size_override("font_size",16)
		var index := i
		tab.activated.connect(func(): _deck.go(index,true))
		_content.add_child(tab)
		_tabs.append(tab)
	var back := Field.action("返回",Vector2(24,720),Vector2(432,48))
	back.tooltip_text = "返回养成"
	back.activated.connect(func(): closed.emit())
	add_child(back)
	_refresh()

func _refresh(preserve := false) -> void:
	_expedition_l.text = "远征币  %d" % int(G.wallet.get("expedition",0))
	var prev := row_want(preserve)
	if _deck != null:
		_content.remove_child(_deck)
		_deck.queue_free()
	_deck = PageDeckScript.new(CONTENT_W,DECK_H,0.0)
	_deck.position = Vector2(0,108)
	_deck.key_mode = "both"
	_deck.navigation_visible = false
	_deck.set_factory(_sids.size(),func(i: int) -> Control:
		return _skill_page(String(_sids[i])),Vector2(CONTENT_W,DECK_H))
	_content.add_child(_deck)
	_deck.page_changed.connect(_select_tab)
	_deck.go(clampi(prev,0,maxi(0,_sids.size()-1)),true)
	_select_tab(int(_deck.current))

func _select_tab(index: int) -> void:
	for i in _tabs.size():
		_tabs[i].selected = i == index
		_tabs[i].queue_redraw()

func row_want(preserve: bool) -> int:
	if preserve and _deck != null: return int(_deck.current)
	for i in _sids.size():
		if G.skill_level(String(_sids[i])) < G.skill_max_level(): return i
	return 0

func _skill_page(sid: String) -> Control:
	var sd := TableCache.get_skill(sid)
	var lv := G.skill_level(sid)
	var mx := G.skill_max_level()
	var cost := G.skill_upgrade_cost(sid)
	var hue: Color = G.FIELD_ROLE.get(G.selected_role,G.FIELD_COPPER)
	var page := Control.new()
	page.size = Vector2(CONTENT_W,DECK_H)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hero := Field.surface(Vector2.ZERO,Vector2(CONTENT_W,192))
	page.add_child(hero)
	var marker := ColorRect.new()
	marker.color = hue
	marker.size = Vector2(3,192)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(marker)
	var number := _sids.find(sid)+1
	hero.add_child(Field.label("招式 %02d / %s" % [number,G.get_role(G.selected_role).get("job","")],Vector2(18,14),Vector2(224,24),14,G.FIELD_COPPER))
	hero.add_child(Field.label(String(sd.get("name",sid)),Vector2(18,42),Vector2(236,52),32,G.FIELD_PAPER_LIGHT,false,true))
	var description := String(sd.get("desc","")).replace("MaxHP","最大生命").replace("ATK","攻击").replace("DEF","防御").replace("HP","生命")
	description = description.replace("回复 ","回复\n").replace("+"," + ")
	var desc := Field.label(description,Vector2(20,99),Vector2(218,54),16,G.FIELD_PAPER_LIGHT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero.add_child(desc)
	var cooldown := float(sd.get("cd",0))
	var cooldown_words := str(int(cooldown)) if is_equal_approx(cooldown,roundf(cooldown)) else str(cooldown)
	hero.add_child(Field.label("冷却 %s秒    耗能 %d" % [cooldown_words,int(sd.get("cost",0))],Vector2(20,159),Vector2(330,24),14,G.FIELD_PAPER_LIGHT))
	var diagram := SkillDiagram.new()
	diagram.role_id = G.selected_role
	diagram.index = number-1
	diagram.position = Vector2(242,18)
	diagram.size = Vector2(120,128)
	diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(diagram)
	page.add_child(Field.label("研习等级",Vector2(0,211),Vector2(196,28),16,G.FIELD_MUTED))
	var level := Field.label("LV %02d / %02d" % [lv,mx],Vector2(208,209),Vector2(168,30),18,G.FIELD_INK,true)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	page.add_child(level)
	for i in mx:
		Field.line(page,Vector2(i*(CONTENT_W/mx),252), CONTENT_W/mx-4, hue if i<lv else G.FIELD_LINE)
	var k0 := float(sd.get("k",0.0))
	var k_per := float(TableCache.skillbook_config().get("k_per_level",.05))
	page.add_child(Field.label("伤害系数" if k0>0 else "技能效果",Vector2(0,276),Vector2(376,24),14,G.FIELD_MUTED))
	if k0 <= 0:
		page.add_child(Field.label("效果固定",Vector2(0,304),Vector2(376,36),24,G.FIELD_INK,true))
		page.add_child(Field.label("研习等级不改变效果数值",Vector2(0,347),Vector2(376,24),14,G.FIELD_MUTED))
	elif lv >= mx:
		page.add_child(Field.label("×%.2f" % (k0*(1+k_per*(lv-1))),Vector2(0,304),Vector2(376,36),30,G.FIELD_INK,true))
		page.add_child(Field.label("研习已满 · 基础系数提升 %d%%" % roundi(k_per*(lv-1)*100),Vector2(0,347),Vector2(376,24),14,G.FIELD_MUTED))
	else:
		page.add_child(Field.label("×%.2f" % (k0*(1+k_per*(lv-1))),Vector2(0,304),Vector2(150,36),30,G.FIELD_INK,true))
		page.add_child(Field.label("→",Vector2(157,304),Vector2(40,36),24,G.FIELD_MUTED))
		var next_value := Field.label("×%.2f" % (k0*(1+k_per*lv)),Vector2(215,304),Vector2(161,36),30,G.FIELD_INK,true)
		next_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		page.add_child(next_value)
		page.add_child(Field.label("当前 LV%d" % lv,Vector2(0,347),Vector2(180,24),14,G.FIELD_MUTED))
		var next_note := Field.label("LV%d · 基础系数 +%d%%" % [lv+1,roundi(k_per*100)],Vector2(180,347),Vector2(196,24),14,G.FIELD_MUTED)
		next_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		page.add_child(next_note)
	var can_pay := int(G.wallet.get("expedition",0)) >= cost
	var words := "研习已满" if lv>=mx else ("研习升级 · %d 远征币" % cost if can_pay else "远征币不足 · 需要 %d" % cost)
	var upgrade := Field.action(words,Vector2(0,397),Vector2(CONTENT_W,52),true)
	upgrade.disabled = lv>=mx or not can_pay
	upgrade.activated.connect(func(): _on_upgrade(sid))
	page.add_child(upgrade)
	return page

# 原生像素招式图，四职业采用同一笔宽；图形跟招式种类变化。
class SkillDiagram extends Control:
	var role_id := "fs"
	var index := 0
	func _draw() -> void:
		var hue: Color = G.FIELD_ROLE.get(role_id,G.FIELD_COPPER)
		draw_set_transform(Vector2(10,8),0,Vector2(2,2))
		var p := Vector2(25,25)
		if role_id == "fs":
			if index in [0,2,4]:
				var shard := PackedVector2Array([Vector2(36,3),Vector2(34,20),Vector2(25,28),Vector2(16,46),Vector2(17,26),Vector2(24,18)])
				draw_colored_polygon(shard,hue)
				draw_colored_polygon(PackedVector2Array([Vector2(36,3),Vector2(26,25),Vector2(16,46),Vector2(17,26),Vector2(24,18)]),G.FIELD_PAPER_LIGHT)
				draw_line(Vector2(31,15),Vector2(25,22),G.FIELD_COPPER,1)
				draw_line(Vector2(21,30),Vector2(26,25),hue,1)
				draw_rect(Rect2(11,17,2,3),G.FIELD_PAPER_LIGHT)
				draw_rect(Rect2(39,34,3,2),hue)
				if index == 2:
					draw_line(Vector2(16,7),Vector2(7,26),hue,2)
					draw_line(Vector2(45,16),Vector2(36,35),hue,2)
					draw_line(Vector2(20,8),Vector2(13,21),G.FIELD_PAPER_LIGHT,1)
				elif index == 4:
					for i in 5:
						var v := Vector2.from_angle(i*TAU/5+.4)
						draw_line((p+v*18).round(),(p+v*27).round(),hue,2)
						draw_line((p+v*27).round(),(p+v*29).round(),G.FIELD_PAPER_LIGHT,1)
			else:
				for i in 6:
					var v := Vector2.from_angle(i*TAU/6)
					draw_line((p+v*5).round(),(p+v*20).round(),G.FIELD_PAPER_LIGHT,2)
					var q := (p+v*14).round()
					draw_line(q,(q+v.rotated(.7)*7).round(),hue,1)
					draw_line(q,(q+v.rotated(-.7)*7).round(),hue,1)
				if index == 3:
					var shield := PackedVector2Array([Vector2(7,8),Vector2(25,4),Vector2(43,8),Vector2(40,31),Vector2(25,47),Vector2(10,31),Vector2(7,8)])
					draw_polyline(shield,hue,1)
		elif role_id == "zs":
			var blade := PackedVector2Array([Vector2(38,3),Vector2(42,14),Vector2(17,39),Vector2(10,32)])
			draw_colored_polygon(blade,G.FIELD_PAPER_LIGHT)
			draw_line(Vector2(39,8),Vector2(17,33),hue,2)
			draw_line(Vector2(8,28),Vector2(23,43),G.FIELD_COPPER,3)
			draw_line(Vector2(15,36),Vector2(6,45),hue,4)
			for i in index+1: draw_line(Vector2(7+i*7,10),Vector2(3+i*7,15),hue,1)
		elif role_id == "ck":
			for i in (3 if index==4 else (2 if index==0 else 1)):
				var off := Vector2(i*7,-i*5)
				draw_line(Vector2(7,43)+off,Vector2(33,9)+off,G.FIELD_COPPER,2)
				draw_colored_polygon(PackedVector2Array([Vector2(33,4)+off,Vector2(37,16)+off,Vector2(27,13)+off]),G.FIELD_PAPER_LIGHT)
				draw_line(Vector2(10,36)+off,Vector2(3,36)+off,hue,2)
		else:
			if index in [0,1]:
				draw_rect(Rect2(22,9,6,32),G.FIELD_PAPER_LIGHT)
				draw_rect(Rect2(11,20,28,6),G.FIELD_PAPER_LIGHT)
				draw_rect(Rect2(24,11,2,28),G.FIELD_COPPER)
				if index == 1:
					for q in [Vector2(6,5),Vector2(40,5),Vector2(39,38)]:
						draw_rect(Rect2(q,Vector2(2,9)),hue)
						draw_rect(Rect2(q+Vector2(-3,3),Vector2(8,2)),hue)
			elif index == 2:
				draw_colored_polygon(PackedVector2Array([Vector2(25,4),Vector2(33,20),Vector2(29,34),Vector2(19,34),Vector2(15,20)]),G.FIELD_PAPER_LIGHT)
				draw_line(Vector2(24,13),Vector2(20,27),hue,2)
				draw_line(Vector2(7,41),Vector2(42,41),G.FIELD_COPPER,1)
			elif index == 3:
				draw_colored_polygon(PackedVector2Array([Vector2(25,3),Vector2(29,21),Vector2(47,25),Vector2(29,29),Vector2(25,47),Vector2(21,29),Vector2(3,25),Vector2(21,21)]),G.FIELD_PAPER_LIGHT)
				draw_rect(Rect2(23,23,4,4),G.FIELD_COPPER)
			else:
				for i in 7:
					var v := Vector2.from_angle(PI+i*PI/6)
					draw_line((Vector2(25,34)+v*13).round(),(Vector2(25,34)+v*23).round(),hue,2)
				draw_rect(Rect2(17,23,16,12),G.FIELD_PAPER_LIGHT)
				draw_line(Vector2(5,36),Vector2(45,36),G.FIELD_COPPER,2)
		draw_set_transform(Vector2.ZERO)

func _on_upgrade(sid: String) -> void:
	if G.skill_upgrade(sid):
		_toast_msg("「%s」升至 LV%d" % [String(TableCache.get_skill(sid).get("name", sid)), G.skill_level(sid)])
	else:
		_toast_msg("远征币不足或已满级")
	_refresh(true)   # 升级后留在同一页（问题 #3：以前会跳回第 1 页）


func _toast_msg(msg: String) -> void:
	if _toast != null:
		_toast.queue_free()
	_toast = G.toast_label(msg)
	_toast.position = Vector2(-28,4)
	_content.add_child(_toast)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_toast.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:   # GM 控制台等全屏层优先（轮次 14）
		return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
