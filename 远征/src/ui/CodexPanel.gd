# CodexPanel.gd —— 宠物图鉴浮层（收集进度；未收集卡显示解锁途径）
# 从 GameHome 的内部类抽出，营帐与主城两处入口共用
class_name CodexPanel
extends Control

signal closed

const RARITY_NAME := {"white": "普通", "blue": "稀有", "purple": "史诗", "gold": "传说"}
const ROLE_NAME := {
	"tank": "护卫", "ranged_dps": "远程", "fast_dps": "速攻", "control": "控制",
	"healer": "治疗", "aoe_dps": "群攻", "poison_control": "毒控",
}
# 稀有度 → 边框素材名（frame_* 为方框空心底图，叠在宠物头像外圈）
const RARITY_FRAME := {"white": "frame_white", "blue": "frame_blue",
	"purple": "frame_purple", "gold": "frame_gold"}
# 同 DeployPanel：440 羊皮纸 - 左右各 16 内边距 = 408，子控件按 408 排版才不右偏
const CONTENT_W := 408.0
# 两列卡片：408 里放两张 196，间距 16 → 第二列起点 212（不是 16+208=224，那会顶出右边）
const COL_STEP := 212.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var banner := G.banner_box("宠 物 图 鉴", 300, 50)
	banner.position = Vector2(90, 36)
	add_child(banner)

	var panel := G.parchment_box(440, 600, 16.0)
	panel.position = Vector2(20, 108)
	add_child(panel)

	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	var pets: Array = TableCache.pets()
	var owned_n := G.owned_pets().size()
	var tip := G.gold_label("已收集 %d / %d · 通关世界首领可结伴同行" % [owned_n, pets.size()],
		G.FS_XS, false, Color("7a5a2e"), false)
	tip.position = Vector2(0, 2)
	tip.custom_minimum_size = Vector2(CONTENT_W, 0)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(tip)

	for i in pets.size():
		var card := _card(pets[i] as Dictionary)
		card.position = Vector2((i % 2) * COL_STEP, 28 + (i / 2) * 112)
		content.add_child(card)

	var back := G.gold_button("返 回", 120, 38)
	back.position = Vector2((CONTENT_W - 120.0) * 0.5, 528)
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			closed.emit())
	content.add_child(back)

func _card(p: Dictionary) -> Control:
	var pid := String(p.get("id", ""))
	var owned: bool = G.owns_pet(pid)
	var rarity := String(p.get("rarity", "white"))

	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(196, 104)
	var sb := StyleBoxFlat.new()
	sb.bg_color = G.BOX_BG if owned else Color("b0a68e")
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 7
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 4
	sb.set_border_width_all(2)
	sb.border_color = G.BOX_EDGE if owned else Color("8a7f68")
	G._apply_shadow(sb, 4.0, 2.0, 0.30)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	root.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 宠物头像 + 稀有度边框（未收集显示暗色剪影——立绘先染暗再半透明，保留轮廓神秘感）
	var portrait := _portrait(pid, rarity, owned)
	head.add_child(portrait)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 1)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(info)

	var name_l := G.gold_label(String(p.get("name", pid)), G.FS_MD, false,
		G.TEXT_DARK if owned else Color("6a6152"), false)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info.add_child(name_l)
	col.add_child(head)

	var base: Dictionary = p.get("base", {})
	var meta := "%s · %s" % [RARITY_NAME.get(rarity, "普通"), ROLE_NAME.get(String(p.get("role", "")), "未知")]
	var meta_l := G.gold_label(meta, G.FS_XS, false, Color("8a6a34"), false)
	meta_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(meta_l)

	var stat := "气血 %d · 攻击 %d · 防御 %d" % [
		int(base.get("hp", 0)), int(base.get("atk", 0)), int(base.get("def", 0))]
	var stat_l := G.gold_label(stat, G.FS_XS, false, Color("8a6a34"), false)
	stat_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(stat_l)

	var state_l := G.gold_label("已收集" if owned else G.pet_unlock_text(pid),
		G.FS_XS, owned, Color("4a7a44") if owned else Color("9a6a5a"), false)
	state_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(state_l)

	root.add_child(col)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return root


## 宠物头像：立绘缩进 62×62 框位 + 稀有度边框叠加；未收集压暗
func _portrait(pid: String, rarity: String, owned: bool) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(70, 70)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = G.res_tex(pid)
	if tex != null:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # 必须在 size 前：否则被钳到原图尺寸
		pic.position = Vector2(5, 5)
		pic.size = Vector2(60, 60)
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not owned:  # 暗色剪影：降亮度 + 微透明，只留轮廓
			pic.modulate = Color(0.25, 0.22, 0.2, 0.85)
		holder.add_child(pic)
	var frame: Texture2D = G.res_tex(String(RARITY_FRAME.get(rarity, "frame_white")))
	if frame != null:
		var fr := TextureRect.new()
		fr.texture = frame
		fr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # 必须在 size 前：否则被钳到原图尺寸
		fr.position = Vector2.ZERO
		fr.size = Vector2(70, 70)
		fr.stretch_mode = TextureRect.STRETCH_SCALE
		if not owned:
			fr.modulate = Color(0.55, 0.55, 0.55, 0.8)
		holder.add_child(fr)
	return holder
