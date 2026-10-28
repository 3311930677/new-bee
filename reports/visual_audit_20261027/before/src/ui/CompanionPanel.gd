class_name CompanionPanel
extends Control

signal closed
signal changed

var _sel := ""
var _slot := 0
var _message := ""
var _tab := 0
var _deck: Control
const PageDeckScript := preload("res://src/ui/PageDeck.gd")

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_sel = G.companion_active()
	_build()

func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked: return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()

func _button(parent: Control, title: String, at: Vector2, width: float, action: Callable, icon := "") -> void:
	var button := G.ghost_button(title,width,44,G.FS_SM)
	if not icon.is_empty(): G.button_icon(button, icon)
	button.position = at
	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: action.call())
	parent.add_child(button)

func _text(parent: Control, words: String, at: Vector2, width: float, height: float, small := false) -> Label:
	var label := G.text_label("",G.FS_XS if small else G.FS_SM,G.TEXT_DARK)
	label.position = at
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size = Vector2(width,height)
	label.text = words
	parent.add_child(label)
	return label

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	G.veil(self, 0.78)
	var top := (maxf(800, get_viewport_rect().size.y) - 618) * 0.5
	var banner := G.banner_box("伙伴", 240, 48)
	banner.position = Vector2(120, top - 55)
	add_child(banner)
	var panel := G.parchment_box(432, 618, 16)
	panel.position = Vector2(24, top)
	add_child(panel)
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	var owned := G.owned_pets()
	if not owned.has(_sel) and not owned.is_empty(): _sel = String(owned[0])
	if _sel.is_empty():
		var paw := G.ui_icon("paw", Vector2(64, 64))
		paw.position = Vector2(168, 140)
		content.add_child(paw)
		_text(content, "尚未与伙伴结缘", Vector2(104, 236), 260, 32)
		_text(content, "昭元兽栏可领取岩龟", Vector2(104, 278), 260, 32, true)
	else:
		var row := CompanionService.state(G.prog, _sel)
		var pet := TableCache.get_pet(_sel)
		var art := TextureRect.new()
		art.texture = G.res_tex(_sel)
		art.position = Vector2(12, 8)
		art.size = Vector2(80, 80)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(art)
		_text(content, String(pet.get("name", _sel)), Vector2(112, 24), 260, 30)
		_text(content, "协战 %d / 20" % int(row.get("wins", 0)), Vector2(112, 57), 260, 26, true)
		_button(content, "上一只", Vector2(0, 104), 116, func(): _cycle(-1), "back")
		_button(content, "下一只", Vector2(126, 104), 116, func(): _cycle(1), "forward")
		_button(content, "随行中" if G.companion_active() == _sel else "设为随行", Vector2(252, 104), 148, _select, "paw")
		_deck = PageDeckScript.new(400, 302)
		_deck.position = Vector2(0, 232)
		_deck.key_mode = "lr"
		_deck.page_gap = 16
		_deck.add_page(_overview_page(row))
		_deck.add_page(_training_page())
		content.add_child(_deck)
		var tabs := G.page_tabs(_deck, ["协战", "训练"], ["shield", "growth"], 400)
		tabs.position = Vector2(0, 170)
		content.add_child(tabs)
		_deck.page_changed.connect(func(index: int): _tab = index)
		_deck.go(_tab, true)
		var note := _text(content, _message, Vector2(0, 512), 400, 34, true)
		note.add_theme_color_override("font_color", G.C_GAIN_INK)
	_button(content, "返回", Vector2(130, 552), 140, func(): closed.emit())

func _page_root() -> Control:
	var page := Control.new()
	page.size = Vector2(400, 302)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return page

func _overview_page(row: Dictionary) -> Control:
	var page := _page_root()
	_text(page, "当前特性", Vector2(0, 4), 350, 30)
	var traits: Array = row.get("traits", [])
	for i in 2:
		var card := G.parchment_box(192, 136, 12)
		card.position = Vector2(i * 208, 46)
		page.add_child(card)
		var inner := Control.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(inner)
		var tid := String(traits[i]) if i < traits.size() else ""
		var cfg: Dictionary = CompanionService.config().traits.get(tid, {})
		var icon := G.ui_icon(_trait_icon(tid), Vector2(32, 32), Color("56746b"))
		icon.position = Vector2(2, 2)
		inner.add_child(icon)
		_text(inner, String(cfg.get("name", "待训练")), Vector2(44, 8), 120, 26)
		_text(inner, _trait_brief(tid), Vector2(2, 58), 164, 46, true)
	_text(page, "每次主世界参战胜利累积协战；\n3次开放第二项特性。", Vector2(0, 214), 376, 64, true)
	var help := G.info_button("协战规则", [
		"训练消耗宠粮，同一特性限装一次；霜关驿舍可训练。",
		"每次主世界参战胜利累积协战，3次开放第二项。",
	] + _response_tips(_sel))
	help.position = Vector2(370, 214)
	page.add_child(help)
	return page

func _training_page() -> Control:
	var page := _page_root()
	for i in 2:
		var index := i
		_button(page, "第%d项%s" % [i + 1, " · 已选" if _slot == i else ""], Vector2(i * 208, 0), 192,
			func(): _slot = index; _build())
	var slots: Array = CompanionService.config().slots
	var cost := int(slots[_slot].pet_food)
	var food := G.ui_icon("food", Vector2(20, 20))
	food.position = Vector2(0, 62)
	page.add_child(food)
	_text(page, "%d / 持有%d · 需协战%d次" % [cost, G.item_count("pet_food"), int(slots[_slot].wins)], Vector2(30, 61), 368, 26, true)
	var index := 0
	for tid in CompanionService.config().traits:
		var id := String(tid)
		var trait_row: Dictionary = CompanionService.config().traits[id]
		var y := 102.0 + index * 62.0
		_button(page, String(trait_row.name), Vector2(0, y), 140, func(): _train(id), _trait_icon(id))
		_text(page, _trait_brief(id), Vector2(156, y + 3), 204, 46, true)
		var help := G.info_button(String(trait_row.name), [String(trait_row.desc)] + (_response_tips(_sel) if id == "comp_resonance" else []))
		help.position = Vector2(374, y + 8)
		page.add_child(help)
		index += 1
	return page

func _trait_icon(tid: String) -> String:
	return {"comp_guard": "shield", "comp_pursuit": "swords", "comp_resonance": "spark"}.get(tid, "growth")

func _trait_brief(tid: String) -> String:
	return {"comp_guard": "分担一次重击", "comp_pursuit": "技能后追击", "comp_resonance": "对应技能净化负面"}.get(tid, "在训练页选择特性")

func _cycle(direction: int) -> void:
	var owned := G.owned_pets()
	if owned.is_empty(): return
	_sel = String(owned[posmod(owned.find(_sel)+direction,owned.size())])
	_message = ""
	_build()

func _select() -> void:
	var result := G.companion_select(_sel)
	_message = "已设为随行" if bool(result.get("ok",false)) else String(result.get("err","未完成"))
	if bool(result.get("ok",false)): changed.emit()
	_build()

func _train(tid: String) -> void:
	var result := G.companion_train(_sel,_slot,tid)
	_message = ("这项已训练，未扣宠粮" if bool(result.get("unchanged",false)) else "训练完成，特性已保存") if bool(result.get("ok",false)) else String(result.get("err","未完成"))
	if bool(result.get("ok",false)): changed.emit()
	_build()

func _response_tips(pid: String) -> Array:
	var elements: Array = CompanionService.config().pet_elements.get(pid,[])
	var role_skills: Array = []
	for sid in TableCache.get_role(G.selected_role if not G.selected_role.is_empty() else "zs").get("skills",[]):
		if elements.has(CompanionService.config().skill_elements.get(sid,"")):
			role_skills.append(String(TableCache.get_skill(String(sid)).get("name",sid)))
	var pet_skills: Array = []
	for skill in TableCache.get_pet(pid).get("skills",[]): pet_skills.append(String(skill.get("name","")))
	return ["当前职业对应技能：" + (" / ".join(role_skills) if not role_skills.is_empty() else "无；可由伙伴自身技能响应"),
		"伙伴对应技能：" + " / ".join(pet_skills),
		"技能必须真实生效；每次净化角色与伙伴各一项最早负面，冷却12秒。没有负面时不消耗触发。"]
