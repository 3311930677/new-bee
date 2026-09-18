# GrowthPanel.gd —— 养成 6 线主面板（玩法文档 §6）
# 六条养成线入口枢纽：天赋 / 装备 / 宠物 / 技能书 / 坐骑 / 称号。
# 子面板以全屏浮层叠在本面板之上，关闭后回到本页并刷新状态行。
class_name GrowthPanel
extends Control

signal closed

const CONTENT_W := 408.0
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
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	# 浮层底衬：统一走 G.veil（深棕 + 暗角 + 斜纹），不再各写一块纯灰
	G.veil(self, 0.72)

	var banner := G.banner_box("养 成", 240, 50)
	banner.position = Vector2(120, 34)
	add_child(banner)

	var panel := G.parchment_box(440, 600, 16.0)
	panel.position = Vector2(20, 108)
	add_child(panel)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	var intro := G.text_label("六条修行路，条条通强者。", G.FS_SM, Color("7a5a2e"))
	intro.position = Vector2(0, 2)
	content.add_child(intro)

	# 六线入口行：图标色块 + 名称 + 当前状态
	var entries := [
		{"id": "talent", "name": "天赋树", "icon": "ui_panel_talent", "hue": Color("c06040")},
		{"id": "equip", "name": "装备", "icon": "ui_panel_equip", "hue": Color("8a6a34")},
		{"id": "pet", "name": "宠物", "icon": "pet_rockturtle", "hue": Color("6a8a4a")},
		{"id": "skill", "name": "技能书", "icon": "ui_panel_skillbook", "hue": Color("4a7a9a")},
		{"id": "mount", "name": "坐骑", "icon": "ui_panel_mount", "hue": Color("a07a3a")},
		{"id": "title", "name": "称号", "icon": "ui_panel_title", "hue": Color("b08ad0")},
	]
	for i in entries.size():
		var e: Dictionary = entries[i]
		var row := _entry_row(String(e["name"]), String(e["icon"]), e["hue"] as Color, String(e["id"]))
		row.position = Vector2(0, 34 + i * 82)
		content.add_child(row)

	var close_btn := G.gold_button("返 回", 130, 38, G.FS_MD)
	close_btn.position = Vector2(CONTENT_W / 2.0 - 65, 528)
	close_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close())
	content.add_child(close_btn)

	_refresh()


func _entry_row(name: String, icon: String, hue: Color, id: String) -> Control:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(CONTENT_W, 72)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f0e2bc")
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 7
	sb.set_border_width_all(2)
	sb.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.55)
	G._apply_shadow(sb, 3.0, 2.0, 0.25)
	root.add_theme_stylebox_override("panel", sb)
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(inner)

	var tex: Texture2D = G.res_tex(icon)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = Vector2(44, 44)
		tr.size = Vector2(44, 44)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2(10, 13)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(tr)
	else:
		var box := Panel.new()
		box.position = Vector2(10, 13)
		box.size = Vector2(44, 44)
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = hue
		bsb.set_corner_radius_all(6)
		box.add_theme_stylebox_override("panel", bsb)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(box)

	var name_l := G.serif_label(name, G.FS_LG, G.TEXT_DARK)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.position = Vector2(66, 10)
	inner.add_child(name_l)

	var status := G.gold_label("", G.FS_XS, false, Color("8a6a34"), false)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status.position = Vector2(66, 40)
	inner.add_child(status)
	_rows.append({"id": id, "label": status})

	var arrow := G.gold_label("›", G.FS_BIG, true, Color("a8842e"), false)
	arrow.position = Vector2(CONTENT_W - 34, 14)
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
				l.text = "可用点数 %d / %d" % [G.talent_points_left(), G.talent_points_total()]
			"equip":
				var ws := G.equip_weapon_slot()
				l.text = "武器 +%d · 甲 +%d · 饰 +%d" % [
					int(G.equip_state(ws).get("lv", 0)), int(G.equip_state("armor").get("lv", 0)),
					int(G.equip_state("accessory").get("lv", 0))]
			"pet":
				l.text = "已收集 %d / %d 只" % [G.owned_pets().size(), TableCache.pets().size()]
			"skill":
				var n := 0
				for k in (G.prog.get("skills", {}) as Dictionary):
					if int((G.prog["skills"] as Dictionary)[k]) > 1:
						n += 1
				l.text = "已精研 %d 门 · 上限 LV%d" % [n, G.skill_max_level()]
			"mount":
				var mid := G.mount_active()
				l.text = "骑乘中：%s" % String(G.mount_cfg(mid).get("name", "")) if not mid.is_empty() else "尚未拥有坐骑"
			"title":
				var tid := G.title_active()
				l.text = "佩戴中：%s" % String(G.title_cfg(tid).get("name", "")) if not tid.is_empty() else "尚未佩戴称号"


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
		_refresh())
	add_child(_sub)


func _close() -> void:
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:   # GM 控制台等全屏层优先（轮次 14）
		return
	if event.is_action_pressed("ui_cancel") and _sub == null:
		_close()
		get_viewport().set_input_as_handled()
