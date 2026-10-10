# 技能研习：具名导航、招式图示和同一行的升级收益。
class_name SkillBookPanel
extends Control

signal closed
var _chest:Control
const CONTENT_W := 432.0
const DECK_H := 468.0
const PageDeckScript := preload("res://src/ui/PageDeck.gd")
const Field := preload("res://src/ui/FieldUI.gd")
const Craft := preload("res://src/ui/CraftUI.gd")
const Showcase := preload("res://src/ui/SkillShowcase.gd")
var _deck: Control = null
var _expedition_l: Label = null
var _toast: Control = null
var _content: Control = null
var _tabs: Array = []
var _sids: Array = []

func _ready() -> void:
	G.skill_study_refund()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_sids = G.get_role(G.selected_role).get("skills",[])
	_build()

func _build() -> void:
	_chest=preload("res://src/ui/CollectionChestView.gd").new()
	_chest.system="skill"
	_chest.host=self
	add_child(_chest)
	_refresh()

func _refresh(preserve:=false) -> void:
	var wanted:=row_want(preserve)
	_deck.go(wanted,true)

func _select_tab(index: int) -> void:
	for i in _tabs.size():
		_tabs[i].selected = i == index
		_tabs[i].queue_redraw()
	if _deck != null:
		for page_index in _deck._made:
			var preview: Node = _deck._made[page_index].get_node_or_null("SkillPreview")
			if preview != null: preview.process_mode = Node.PROCESS_MODE_INHERIT if int(page_index)==index else Node.PROCESS_MODE_DISABLED

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
	var hue: Color = Craft.ROLE_COLORS.get(G.selected_role,Craft.GOLD)
	var page := Control.new()
	page.size = Vector2(CONTENT_W,DECK_H)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(Craft.label(String(sd.get("name",sid)),Vector2(0,0),Vector2(210,38),28,Craft.WHITE,true,true))
	var cooldown := float(sd.get("cd",0))
	var cooldown_words := str(int(cooldown)) if is_equal_approx(cooldown,roundf(cooldown)) else str(cooldown)
	var meta := Craft.label("冷却 %s秒 · 耗能 %d" % [cooldown_words,int(sd.get("cost",0))],Vector2(212,8),Vector2(220,26),14,Craft.MUTED)
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	page.add_child(meta)
	var description := String(sd.get("desc","")).replace("MaxHP","最大生命").replace("ATK","攻击").replace("DEF","防御").replace("HP","生命")
	var desc := Craft.label(description,Vector2(0,40),Vector2(432,40),16,Craft.WHITE)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(desc)
	var preview := Showcase.new()
	preview.name = "SkillPreview"
	preview.skill_id = sid
	preview.role_id = G.selected_role
	preview.position = Vector2(0,84)
	preview.size = Vector2(432,218)
	page.add_child(preview)
	page.add_child(Craft.panel(Vector2(0,310),Vector2(432,98),.86))
	page.add_child(Craft.label("研习等级",Vector2(14,313),Vector2(210,26),14,Craft.MUTED))
	var level := Craft.label("LV %02d / %02d" % [lv,mx],Vector2(278,310),Vector2(140,30),18,Craft.WHITE,true)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	page.add_child(level)
	for i in mx:
		var segment := ColorRect.new()
		segment.position = Vector2(14+i*(404.0/mx),346)
		segment.size = Vector2(404.0/mx-4,3)
		segment.color = hue if i<lv else Color("48616c")
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(segment)
	var k0 := float(sd.get("k",0))
	var k_per := float(TableCache.skillbook_config().get("k_per_level",.05))
	var studyable := SkillSystem.can_study(sd)
	if not studyable:
		page.add_child(Craft.label("效果固定",Vector2(14,356),Vector2(404,30),20,Craft.WHITE,true))
		page.add_child(Craft.label("纯功能招式无需研习 · 原有功能保留",Vector2(14,384),Vector2(404,20),12,Craft.MUTED))
	elif k0<=0:
		var effect: Dictionary = sd.get("effect", {})
		var kind := String(effect.get("type", ""))
		var strength_name := "治疗量" if kind in ["heal", "invincible_heal"] else ("护盾量" if kind == "shield" else "攻击增益")
		var words := "%s ×%.2f" % [strength_name, 1.0 + k_per * (lv - 1)]
		if lv < mx: words += " → ×%.2f" % (1.0 + k_per * lv)
		page.add_child(Craft.label(words,Vector2(14,356),Vector2(404,30),20,Craft.WHITE,true))
		page.add_child(Craft.label("持续时间、冷却与耗能保持原值",Vector2(14,384),Vector2(404,20),12,Craft.MUTED))
	elif lv>=mx:
		page.add_child(Craft.label("×%.2f" % (k0*(1+k_per*(lv-1))),Vector2(14,354),Vector2(220,30),24,Craft.WHITE,true))
		page.add_child(Craft.label("研习已满 · 基础系数提升 %d%%" % roundi(k_per*(lv-1)*100),Vector2(14,384),Vector2(404,20),12,Craft.MUTED))
	else:
		page.add_child(Craft.label("×%.2f" % (k0*(1+k_per*(lv-1))),Vector2(14,354),Vector2(160,30),24,Craft.WHITE,true))
		page.add_child(Craft.label("→",Vector2(193,354),Vector2(40,30),22,Craft.GOLD))
		var next_value := Craft.label("×%.2f" % (k0*(1+k_per*lv)),Vector2(242,354),Vector2(176,30),24,hue,true)
		next_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		page.add_child(next_value)
		page.add_child(Craft.label("当前 LV%d" % lv,Vector2(14,384),Vector2(180,20),12,Craft.MUTED))
		var next_note := Craft.label("LV%d · 基础系数 +%d%%" % [lv+1,roundi(k_per*100)],Vector2(206,384),Vector2(212,20),12,Craft.MUTED)
		next_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		page.add_child(next_note)
	var can_pay := int(G.wallet.get("expedition",0))>=cost
	var words := "无需研习" if not studyable else ("研习已满" if lv>=mx else ("研习升级 · %d 远征币" % cost if can_pay else "远征币不足 · 需要 %d" % cost))
	var upgrade := Craft.action(words,Vector2(0,418),Vector2(CONTENT_W,50),"primary")
	upgrade.disabled = not studyable or lv>=mx or not can_pay
	if upgrade.disabled: upgrade.caption.add_theme_color_override("font_color",Craft.WHITE)
	upgrade.activated.connect(func(): _on_upgrade(sid))
	page.add_child(upgrade)
	return page

func _on_upgrade(sid: String) -> void:
	if G.skill_upgrade(sid):
		_toast_msg("「%s」升至 LV%d" % [String(TableCache.get_skill(sid).get("name", sid)), G.skill_level(sid)])
	else:
		_toast_msg("研习未成功，请检查远征币或存档状态")
	_refresh(true)   # 升级后留在同一页（问题 #3：以前会跳回第 1 页）


func _toast_msg(msg:String) -> void:
	if is_instance_valid(_toast):_toast.queue_free()
	_toast=preload("res://src/ui/TravelChestUI.gd").toast(self,msg)
	_toast.position.y=G.ui_safe_rect(self).end.y-116

func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:   # GM 控制台等全屏层优先（轮次 14）
		return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
