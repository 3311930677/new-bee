# GrowthPanel.gd —— 养成 6 线主面板（玩法文档 §6）
# 六条养成线入口枢纽：天赋 / 装备 / 宠物 / 技能书 / 坐骑 / 称号。
# 子面板以全屏浮层叠在本面板之上，关闭后回到本页并刷新状态行。
class_name GrowthPanel
extends Control

signal closed

const CONTENT_W := 408.0
const Field := preload("res://src/ui/FieldUI.gd")
const Craft := preload("res://src/ui/CraftUI.gd")
# 新 class_name 尚未进编辑器全局类缓存，按项目惯例 preload 路径取脚本
const TalentPanelScript := preload("res://src/ui/TalentPanel.gd")
const EquipPanelScript := preload("res://src/ui/EquipPanel.gd")
const PetRaisePanelScript := preload("res://src/ui/PetRaisePanel.gd")
const SkillBookPanelScript := preload("res://src/ui/SkillBookPanel.gd")
const MountPanelScript := preload("res://src/ui/MountPanel.gd")
const TitlePanelScript := preload("res://src/ui/TitlePanel.gd")

var _rows: Array = []        # 各行状态 Label 引用（刷新用）
var _sub: Control = null     # 当前打开的子面板
var _toast: Label = null
var _summary: Label = null


func _ready() -> void:
	G.center_fixed_page.call_deferred(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	Craft.scene(self,.46)
	Craft.heading(self,"人物养成","装备与修习 / 同行与荣誉")
	var role := G.get_role(G.selected_role)
	var crest := Craft.Crest.new()
	crest.position = Vector2(116,148)
	crest.size = Vector2(248,336)
	crest.hue = Craft.ROLE_COLORS.get(G.selected_role,Craft.GOLD)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crest)
	add_child(Field.portrait(G.selected_role,Vector2(112,192),Vector2(256,256)))
	var role_name := Craft.label(String(role.get("name","旅人")),Vector2(132,450),Vector2(216,36),28,Craft.WHITE,true,true)
	role_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(role_name)
	var level := Craft.label("%s · LV %02d" % [role.get("job",""),int(G.prog.get("level",1))],Vector2(142,490),Vector2(196,24),15,Craft.GOLD)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(level)
	var entries := [["equip","装备","swords",24,176],["talent","天赋","growth",24,286],
		["skill","技能书","book",24,396],["pet","宠物","paw",344,176],
		["mount","坐骑","mount",344,286],["title","称号","crown",344,396]]
	for e in entries:
		var row := _entry_row(e[1],e[2],e[0])
		row.position = Vector2(e[3],e[4])
		add_child(row)
	var summary_panel := Craft.panel(Vector2(24,546),Vector2(432,128),.90)
	add_child(summary_panel)
	summary_panel.add_child(Craft.label("行前整备",Vector2(18,10),Vector2(200,30),18,Craft.GOLD,true))
	_summary = Craft.label("",Vector2(18,42),Vector2(396,26),16,Craft.WHITE)
	summary_panel.add_child(_summary)
	var tip := Craft.label("点击角色两侧的徽章，查看装备、招式与同行伙伴。",Vector2(18,76),Vector2(396,40),14,Craft.MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_panel.add_child(tip)
	var close_btn := Craft.action("返回",Vector2(24,720),Vector2(432,48))
	close_btn.tooltip_text = "返回营帐"
	close_btn.activated.connect(_close)
	add_child(close_btn)
	_refresh()


func _entry_row(words: String, icon: String, id: String) -> Control:
	var row := Craft.action(words,Vector2.ZERO,Vector2(112,100),"badge")
	row.tooltip_text = "打开" + words
	row.caption.position = Vector2(0,55)
	row.caption.size = Vector2(112,25)
	row.caption.set_meta("fixed_y",55)
	row.caption.add_theme_font_size_override("font_size",17)
	Craft.icon(row,icon,Vector2(36,8),Vector2(40,40))
	var status := Craft.label("",Vector2(0,81),Vector2(112,20),12,Craft.MUTED)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(status)
	_rows.append({"id":id,"label":status,"action":row,"words":words})
	row.activated.connect(func(): _open(id))
	return row


# ---------- 状态行刷新 ----------
func _refresh() -> void:
	var left := G.talent_points_left()
	_summary.text = "尚有 %d 点天赋待分配" % left if left > 0 else "天赋点已分配完毕"
	for r in _rows:
		var l := (r as Dictionary)["label"] as Label
		match String((r as Dictionary)["id"]):
			"talent":
				l.text = "可分配 %d 点" % G.talent_points_left()
			"equip":
				var ws := G.equip_weapon_slot()
				l.text = "武%d / 甲%d / 饰%d" % [
					int(G.equip_state(ws).get("lv", 0)), int(G.equip_state("armor").get("lv", 0)),
					int(G.equip_state("accessory").get("lv", 0))]
			"pet":
				l.text = "已收 %d / %d" % [G.owned_pets().size(), TableCache.pets().size()]
			"skill":
				var n := 0
				for k in (G.prog.get("skills", {}) as Dictionary):
					if int((G.prog["skills"] as Dictionary)[k]) > 1:
						n += 1
				l.text = "精研 %d 门" % n
			"mount":
				var mid := G.mount_active()
				l.text = ("骑乘：%s" % String(G.mount_cfg(mid).get("name", ""))) if not mid.is_empty() else "尚未骑乘"
			"title":
				var tid := G.title_active()
				l.text = ("佩戴：%s" % String(G.title_cfg(tid).get("name", ""))) if not tid.is_empty() else "未佩戴"

		(r as Dictionary)["action"].tooltip_text = "打开" + String((r as Dictionary)["words"]) + " · " + l.text


# ---------- 子面板 ----------
func _open(id: String) -> void:
	if _sub != null:
		return
	match id:
		"talent":
			_sub = TalentPanelScript.new()
		"equip":
			_sub = EquipPanelScript.new()
		"pet":
			_sub = PetRaisePanelScript.new()
		"skill":
			_sub = SkillBookPanelScript.new()
		"mount":
			_sub = MountPanelScript.new()
		"title":
			_sub = TitlePanelScript.new()
	if _sub == null:
		return
	Audio.sfx("ui_open")
	_sub.set("z_index", 10)
	_sub.connect("closed", func():
		Audio.sfx("ui_close")
		_sub.queue_free()
		_sub = null
		_set_page_visible(true)
		_refresh())
	_set_page_visible(false)
	add_child(_sub)


func _set_page_visible(shown: bool) -> void:
	for child in get_children():
		if child is CanvasItem and child != _sub:
			child.visible = shown

func _close() -> void:
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:   # GM 控制台等全屏层优先（轮次 14）
		return
	if event.is_action_pressed("ui_cancel") and _sub == null:
		_close()
		get_viewport().set_input_as_handled()
