class_name CompanionPanel
extends Control

signal closed
signal changed

var _sel := ""
var _slot := 0
var _message := ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_sel = G.companion_active()
	_build()

func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked: return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()

func _button(parent: Control, title: String, at: Vector2, width: float, action: Callable) -> void:
	var button := G.gold_button(title,width,44,G.FS_SM)
	button.position = at
	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: action.call())
	parent.add_child(button)

func _text(parent: Control, words: String, at: Vector2, width: float, height: float, small := false) -> Label:
	var label := G.text_label("",G.FS_XS if small else G.FS_SM,G.TEXT_DARK)
	label.position = at
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	label.size = Vector2(width,height)
	label.text = words
	parent.add_child(label)
	return label

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	G.veil(self,0.78)
	var top := (maxf(800,get_viewport_rect().size.y) - 618) * 0.5
	var banner := G.banner_box("伙伴协战",240,48)
	banner.position = Vector2(120,top - 55)
	add_child(banner)
	var panel := G.parchment_box(432,618,16)
	panel.position = Vector2(24,top)
	add_child(panel)
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	var owned := G.owned_pets()
	if not owned.has(_sel) and not owned.is_empty(): _sel = String(owned[0])
	if _sel.is_empty():
		_text(content,"尚未与伙伴结缘。第一幕可在昭元兽栏领取岩龟。",Vector2(24,40),382,100)
	else:
		var row := CompanionService.state(G.prog,_sel)
		var names: Array = []
		for tid in row.get("traits",[]):
			names.append(String((CompanionService.config().traits as Dictionary).get(tid,{}).get("name","未训练")))
		var pet := TableCache.get_pet(_sel)
		var help := G.info_button("元素响应 · 对应技能",_response_tips(_sel))
		help.position = Vector2(374,8)
		content.add_child(help)
		var tex := G.res_tex(_sel)
		if tex != null:
			var art := TextureRect.new()
			art.texture = tex
			art.position = Vector2(26,12)
			art.size = Vector2(70,70)
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			content.add_child(art)
		_text(content,"%s · 协战 %d / 20\n%s" % [String(pet.get("name",_sel)),int(row.get("wins",0))," / ".join(names) if not names.is_empty() else "尚未训练特性"],Vector2(110,14),258,65)
		_button(content,"上一只",Vector2(24,88),106,func(): _cycle(-1))
		_button(content,"下一只",Vector2(142,88),106,func(): _cycle(1))
		_button(content,"随行中" if G.companion_active() == _sel else "设为随行",Vector2(260,88),146,_select)
		_text(content,"每次主世界胜利仅记录实际参战伙伴。第二项需协战3次。重训同项也耗粮，同一特性不能装两次。",Vector2(24,144),382,60,true)
		for i in 2:
			var ix: int = i
			_button(content,"第%d项%s" % [i+1," · 已选" if _slot == i else ""],Vector2(24+i*196,211),186,func(): _slot=ix; _build())
		var slots: Array = CompanionService.config().slots
		var cost: int = int(slots[_slot].pet_food)
		_text(content,"当前训练：宠粮 ×%d（持有%d） · 协战要求%d次" % [cost,G.item_count("pet_food"),int(slots[_slot].wins)],Vector2(24,266),382,30,true)
		var elements: Array = (CompanionService.config().pet_elements as Dictionary).get(_sel,[])
		var element_names: Array = []
		for element in elements: element_names.append(String(CompanionService.config().element_names.get(element,element)))
		var index := 0
		for tid in CompanionService.config().traits:
			var id := String(tid)
			var trait_row: Dictionary = CompanionService.config().traits[id]
			var y := 304.0 + index * 67
			_button(content,String(trait_row.name),Vector2(24,y),114,func(): _train(id))
			var detail := String(trait_row.desc)
			if id == "comp_resonance": detail += "\n对应：" + " / ".join(element_names)
			_text(content,detail,Vector2(150,y+2),252,58,true)
			index += 1
		_text(content,_message if not _message.is_empty() else "找回矿道记录后，在霜关驿舍训练。对应元素技能生效可响应。",Vector2(24,511),382,47,true)
	_button(content,"返回",Vector2(146,566),140,func(): closed.emit())

func _cycle(direction: int) -> void:
	var owned := G.owned_pets()
	if owned.is_empty(): return
	_sel = String(owned[posmod(owned.find(_sel)+direction,owned.size())])
	_message = ""
	_build()

func _select() -> void:
	var result := G.companion_select(_sel)
	_message = "已选择随行，走图和下次接战立即使用这只伙伴" if bool(result.get("ok",false)) else String(result.get("err","未完成"))
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
