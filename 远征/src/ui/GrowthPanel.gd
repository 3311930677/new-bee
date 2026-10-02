# GrowthPanel.gd —— 养成 6 线主面板（玩法文档 §6）
# 六条养成线入口枢纽：天赋 / 装备 / 宠物 / 技能书 / 坐骑 / 称号。
# 子面板以全屏浮层叠在本面板之上，关闭后回到本页并刷新状态行。
class_name GrowthPanel
extends Control

signal closed

const CONTENT_W := 408.0
const TILE_W := 196.0
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


func _ready() -> void:
	G.center_fixed_page.call_deferred(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	# 浮层底衬：统一走 G.veil（深棕 + 暗角 + 斜纹），不再各写一块纯灰
	G.veil(self, 0.72)

	var banner := G.banner_box("养 成", 240, 50)
	banner.position = Vector2(120, 30)
	add_child(banner)

	var panel := G.parchment_box(440, 604, 16.0)
	panel.position = Vector2(20, 100)
	add_child(panel)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	# 六张入口卡：图标、名称与当前状态；规则留在各自页面。
	var entries := [
		{"id": "talent", "name": "天赋", "icon": "growth", "hue": Color("44654e")},
		{"id": "equip", "name": "装备", "icon": "swords", "hue": Color("765546")},
		{"id": "pet", "name": "宠物", "icon": "paw", "hue": Color("65734d")},
		{"id": "skill", "name": "技能书", "icon": "book", "hue": Color("4b6774")},
		{"id": "mount", "name": "坐骑", "icon": "mount", "hue": Color("866a3c")},
		{"id": "title", "name": "称号", "icon": "crown", "hue": Color("75627e")},
	]
	for i in entries.size():
		var e: Dictionary = entries[i]
		var row := _entry_row(String(e["name"]), String(e["icon"]), e["hue"] as Color, String(e["id"]))
		row.position = Vector2((i % 2) * 212, 16 + (i / 2) * 166)
		content.add_child(row)
		G.reveal_control(row, i * 0.035)

	var close_btn := G.gold_button("返 回", G.BTN_S.x, G.BTN_S.y, G.FS_MD)
	close_btn.size = Vector2(G.BTN_S.x, G.BTN_S.y)
	close_btn.position = Vector2(CONTENT_W / 2.0 - G.BTN_S.x / 2.0, 534)
	close_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close())
	content.add_child(close_btn)

	_refresh()


func _entry_row(name: String, icon: String, hue: Color, id: String) -> Control:
	# 纸卡入口：PixelButton 皮（切角+厚度+硬影）+ 内凹图标槽——
	# 原先是"纯色圆角5+1px 边"的平面卡，六块排一起就是模板脸
	var root := G.PixelButton.new()
	root.custom_minimum_size = Vector2(TILE_W, 146)
	root.set_surface(Color("e9dfc8"), Color("b9ae94"))
	root.set_content_margin(0.0)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	G._bind_press_feedback(root)

	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(inner)

	# 内凹图标槽（与营帐木牌入口同一语言，配色换成纸面浅槽）
	var slot := G.inset_slot(46, 46)
	slot.position = Vector2(14, 16)
	inner.add_child(slot)
	var tr := G.ui_icon(icon, Vector2(34, 34), hue)
	tr.position = Vector2(20, 22)
	inner.add_child(tr)

	# 名称（FS_LG 宋体深字）
	var name_l := G.gold_label(name, G.FS_MD, false, G.TEXT_DARK, false)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.position = Vector2(72, 26)
	inner.add_child(name_l)

	# 状态行（FS_XS，最深棕辅助字 4a2f14；羊皮纸上对比度最高，小字也不虚）
	var status := G.text_label("", G.FS_XS, Color("4a2f14"))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status.position = Vector2(16, 82)
	status.size = Vector2(TILE_W - 32, 46)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(status)
	_rows.append({"id": id, "label": status})

	# 右侧箭头：宋体金标，垂直居中偏上
	var arrow := G.ui_icon("forward", Vector2(14, 14), G.TEXT_MUTED)
	arrow.position = Vector2(TILE_W - 28, 34)
	inner.add_child(arrow)

	root.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_open(id))
	return root


# ---------- 状态行刷新 ----------
func _refresh() -> void:
	for r in _rows:
		var l := (r as Dictionary)["label"] as Label
		match String((r as Dictionary)["id"]):
			"talent":
				l.text = "点数 %d / %d" % [G.talent_points_left(), G.talent_points_total()]
			"equip":
				var ws := G.equip_weapon_slot()
				l.text = "武器 +%d\n护甲 +%d · 饰品 +%d" % [
					int(G.equip_state(ws).get("lv", 0)), int(G.equip_state("armor").get("lv", 0)),
					int(G.equip_state("accessory").get("lv", 0))]
			"pet":
				l.text = "已收 %d / %d" % [G.owned_pets().size(), TableCache.pets().size()]
			"skill":
				var n := 0
				for k in (G.prog.get("skills", {}) as Dictionary):
					if int((G.prog["skills"] as Dictionary)[k]) > 1:
						n += 1
				l.text = "精研 %d 门 · 上限 %d" % [n, G.skill_max_level()]
			"mount":
				var mid := G.mount_active()
				l.text = ("骑乘：%s" % String(G.mount_cfg(mid).get("name", ""))) if not mid.is_empty() else "尚未拥有"
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
