# GrowthPanel.gd —— 养成 6 线主面板（玩法文档 §6）
# 六条养成线入口枢纽：天赋 / 装备 / 宠物 / 技能书 / 坐骑 / 称号。
# 子面板以全屏浮层叠在本面板之上，关闭后回到本页并刷新状态行。
class_name GrowthPanel
extends Control

signal closed

const CONTENT_W := 408.0
const Field := preload("res://src/ui/FieldUI.gd")
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
	G.veil(self,.90)
	Field.heading(self,"养成","行前整备 / 人物与同行伙伴")
	var paper := Field.surface(Vector2(24,128),Vector2(432,572),true)
	add_child(paper)
	paper.add_child(Field.portrait(G.selected_role,Vector2(22,8),Vector2(80,110)))
	var role := G.get_role(G.selected_role)
	paper.add_child(Field.label(String(role.get("name","旅人")),Vector2(114,19),Vector2(220,34),24,G.FIELD_INK,true,true))
	paper.add_child(Field.label("LV %02d · %s" % [int(G.prog.get("level",1)),role.get("job","")],Vector2(116,55),Vector2(248,24),14,G.FIELD_MUTED))
	_summary = Field.label("",Vector2(116,85),Vector2(260,24),14,G.FIELD_MUTED)
	paper.add_child(_summary)
	Field.line(paper,Vector2(28,128),376)
	paper.add_child(Field.label("战斗修习",Vector2(28,138),Vector2(260,24),14,G.FIELD_MUTED))
	var entries := [["talent","天赋","growth"],["equip","装备","swords"],["skill","技能书","book"],
		["pet","宠物","paw"],["mount","坐骑","mount"],["title","称号","crown"]]
	for i in entries.size():
		var e: Array = entries[i]
		var y := 172 + i*56 + (40 if i >= 3 else 0)
		var row := _entry_row(e[1],e[2],e[0])
		row.position = Vector2(28,y)
		paper.add_child(row)
	paper.add_child(Field.label("同行与荣誉",Vector2(28,346),Vector2(300,24),14,G.FIELD_MUTED))
	var close_btn := Field.action("返回",Vector2(24,720),Vector2(432,48))
	close_btn.tooltip_text = "返回营帐"
	close_btn.activated.connect(_close)
	add_child(close_btn)
	_refresh()


func _entry_row(words: String, icon: String, id: String) -> Control:
	var row := Field.action("",Vector2.ZERO,Vector2(376,56),false,true)
	row.quiet = true
	row.tooltip_text = "打开" + words
	var tr := G.ui_icon(icon,Vector2(28,28))
	tr.position = Vector2(2,12)
	row.add_child(tr)
	row.add_child(Field.label(words,Vector2(44,8),Vector2(88,36),18,G.FIELD_INK,true))
	var status := Field.label("",Vector2(136,7),Vector2(208,40),14,G.FIELD_MUTED)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(status)
	_rows.append({"id":id,"label":status})
	Field.line(row,Vector2(0,55),376,Color(G.FIELD_LINE,.5))
	var arrow := G.ui_icon("forward",Vector2(10,10),G.FIELD_MUTED)
	arrow.position = Vector2(364,22)
	row.add_child(arrow)
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
				l.text = "可分配 %d / 共 %d 点" % [G.talent_points_left(), G.talent_points_total()]
			"equip":
				var ws := G.equip_weapon_slot()
				l.text = "武器 +%d · 护甲 +%d · 饰品 +%d" % [
					int(G.equip_state(ws).get("lv", 0)), int(G.equip_state("armor").get("lv", 0)),
					int(G.equip_state("accessory").get("lv", 0))]
			"pet":
				l.text = "已收 %d / %d" % [G.owned_pets().size(), TableCache.pets().size()]
			"skill":
				var n := 0
				for k in (G.prog.get("skills", {}) as Dictionary):
					if int((G.prog["skills"] as Dictionary)[k]) > 1:
						n += 1
				l.text = "精研 %d 门 / 上限 %d 级" % [n, G.skill_max_level()]
			"mount":
				var mid := G.mount_active()
				l.text = ("骑乘：%s" % String(G.mount_cfg(mid).get("name", ""))) if not mid.is_empty() else "尚未骑乘"
			"title":
				var tid := G.title_active()
				l.text = ("佩戴：%s" % String(G.title_cfg(tid).get("name", ""))) if not tid.is_empty() else "未佩戴"


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
