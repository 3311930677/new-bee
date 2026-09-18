# TraitPicker.gd —— 战斗胜利词条三选一（玩法文档 §2.4）
# 三卡横排：槽1 数值/机制 · 槽2 流派85%/双刃15% · 槽3 全池；含双刃时可「放弃」。
# 注意：卡片内层 parchment（PanelContainer）必须 MOUSE_FILTER_IGNORE——
# 它是 STOP 会把点击整片吞掉，卡面根节点的 gui_input 永远收不到（「点不动」的根因）。
class_name TraitPicker
extends Control

signal picked(tid: String)  # 选中的词条 id；"" = 放弃

const VIEW_W := 480.0
const CARD_W := 140.0
const CARD_H := 264.0
const CARD_Y := 246.0

const TYPE_META := {  # type → [类别名, 色带]
	"num": ["数值", Color("c9c9c9")],
	"mech": ["机制", Color("6a9ad0")],
	"link": ["流派", Color("9a6ad0")],
	"double": ["双刃", Color("d05a4a")],
}
const SCHOOL_NAME := {
	"bleed": "流血", "crit": "暴击", "thorn": "反伤",
	"control": "控制", "energy": "能量", "summon": "召唤",
}
# 流派 → school_* 图标素材名（thorn 对应素材是 school_thorns；summon 无图标）
const SCHOOL_ART := {
	"bleed": "school_bleed", "crit": "school_crit", "thorn": "school_thorns",
	"control": "school_control", "energy": "school_energy",
}

var choices: Array = []


func setup(rows: Array) -> void:
	choices = rows
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 浮层底衬：统一走 G.veil（深棕 + 暗角 + 斜纹），不再各写一块纯灰
	G.veil(self, 0.66, true)

	var title := G.serif_label("选择一份祝福", G.FS_BIG, Color("ffd9a0"))
	title.position = Vector2(0, 158)
	title.custom_minimum_size = Vector2(VIEW_W, 0)
	add_child(title)

	var gap := 12.0
	var x0 := (VIEW_W - (3.0 * CARD_W + 2.0 * gap)) * 0.5
	for i in mini(3, choices.size()):
		var card := _make_card(choices[i])
		card.position = Vector2(x0 + float(i) * (CARD_W + gap), CARD_Y)
		add_child(card)

	# 双刃可选不选：卡组含双刃时提供放弃
	var has_double := false
	for r in choices:
		if String((r as Dictionary).get("type", "")) == "double":
			has_double = true
	if has_double:
		var skip := G.gold_button("放 弃", 160, 42)
		skip.position = Vector2((VIEW_W - 160.0) * 0.5, CARD_Y + CARD_H + 42.0)
		skip.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_emit_pick(""))
		add_child(skip)


func _make_card(row: Dictionary) -> Control:
	var t := String(row.get("type", "num"))
	var meta: Array = TYPE_META.get(t, ["？", Color.GRAY])
	var col: Color = meta[1]

	var root := Control.new()
	root.custom_minimum_size = Vector2(CARD_W, CARD_H)
	root.size = Vector2(CARD_W, CARD_H)
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	# 底：羊皮纸（IGNORE——不能挡根节点的点击）
	var panel := G.parchment_box(CARD_W, CARD_H, 12.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	# 类别色带：右端斜切，避免齐刷刷的矩形模板感
	var band := Polygon2D.new()
	band.color = col
	band.polygon = PackedVector2Array([
		Vector2(10, 10), Vector2(CARD_W - 10, 10), Vector2(CARD_W - 18, 16), Vector2(10, 16),
	])
	root.add_child(band)

	var school := String(row.get("school", "none"))
	var tag: String = "%s · %s" % [String(meta[0]), SCHOOL_NAME.get(school, "通用")] \
		if school != "none" else String(meta[0])
	# 流派图标（school_* 素材；通用无图标不占位，文字左移）
	var tag_x := 10.0
	var school_tex: Texture2D = G.res_tex(String(SCHOOL_ART.get(school, "")))
	if school_tex != null:
		var si := TextureRect.new()
		si.texture = school_tex
		si.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # 必须在 size 前：否则被钳到原图尺寸
		si.position = Vector2(10, 18)
		si.size = Vector2(17, 17)
		si.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		si.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(si)
		tag_x = 31.0
	var tag_l := G.gold_label(tag, G.FS_XS, false, col.darkened(0.25), false)
	tag_l.position = Vector2(tag_x, 20)
	tag_l.size = Vector2(CARD_W - 20 - (tag_x - 10.0), 16)
	root.add_child(tag_l)

	var name_l := G.serif_label(String(row.get("name", "")), G.FS_MD, Color("5a3a1e"))
	name_l.position = Vector2(10, 40)
	name_l.size = Vector2(CARD_W - 20, 24)
	name_l.clip_text = true
	root.add_child(name_l)

	var line := ColorRect.new()
	line.color = Color(0.55, 0.42, 0.24, 0.5)
	line.position = Vector2(10, 70)
	line.size = Vector2(CARD_W - 20, 1)
	root.add_child(line)

	# 描述最长约 19 字符（「免死 1 次并回 20%HP（每场 1 次）」）：
	# FS_XS(13px) 每行约 9 汉字，给 3 行高度；中文无空格必须按字符断行
	var desc_l := G.text_label(String(row.get("desc", "")), G.FS_XS, Color("7a5a2e"))
	desc_l.position = Vector2(10, 78)
	desc_l.size = Vector2(CARD_W - 20, 54)
	desc_l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	desc_l.clip_text = true
	root.add_child(desc_l)

	# 中部大号图标：按词条效果取 宝石/流派/双刃 素材，填充描述下方的空档
	var icon_name := _trait_icon(row)
	if icon_name != "":
		var icon_tex: Texture2D = G.res_tex(icon_name)
		if icon_tex != null:
			var ic := TextureRect.new()
			ic.texture = icon_tex
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # 必须在 size 前
			ic.position = Vector2((CARD_W - 64.0) * 0.5, 136)
			ic.size = Vector2(64, 64)
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(ic)

	# 底部点选条：整卡唯一「按钮感」落点
	var strip := ColorRect.new()
	strip.color = Color(col.r, col.g, col.b, 0.16)
	strip.position = Vector2(8, CARD_H - 34)
	strip.size = Vector2(CARD_W - 16, 26)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(strip)
	var hint_l := G.gold_label("— 点 选 —", G.FS_XS, false, Color("a8895a", 0.9), false)
	hint_l.position = Vector2(8, CARD_H - 31)
	hint_l.size = Vector2(CARD_W - 16, 20)
	root.add_child(hint_l)

	# 悬停：浮起 + 点选条染实
	# 注意：GDScript lambda 捕获局部变量是值拷贝，ready 里改 base_y 外层看不到，
	# hover 会 tween 到 0-6=-6 把卡推出屏。基准 y 必须挂 meta，lambda 里现取现用
	var tid := String(row.get("id", ""))
	root.ready.connect(func(): root.set_meta("base_y", root.position.y))
	root.mouse_entered.connect(func():
		var tw := root.create_tween()
		tw.tween_property(root, "position:y",
			float(root.get_meta("base_y", root.position.y)) - 6.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		strip.color = Color(col.r, col.g, col.b, 0.42))
	root.mouse_exited.connect(func():
		var tw := root.create_tween()
		tw.tween_property(root, "position:y",
			float(root.get_meta("base_y", root.position.y)), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		strip.color = Color(col.r, col.g, col.b, 0.16))
	root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_emit_pick(tid))
	return root


func _emit_pick(tid: String) -> void:
	if tid == "":
		Audio.sfx("ui_cancel")   # 放弃（双刃代价划不来时）
	else:
		Audio.sfx("ui_confirm")
	picked.emit(tid)
	queue_free()


## 词条 → 中部大图标素材名：双刃用剑交叉图标；攻防血数值词条用对应宝石；
## 其余优先流派图标（school_*），都没有则返回空（卡面维持纯文字）
func _trait_icon(row: Dictionary) -> String:
	if String(row.get("type", "")) == "double":
		return "icon_double_edge"
	var eff: Dictionary = row.get("effect", {})
	match String(eff.get("stat", "")):
		"atk":
			return "gem_atk_3"
		"maxhp":
			return "gem_hp_3"
		"def":
			return "gem_def_3"
	return String(SCHOOL_ART.get(String(row.get("school", "none")), ""))


## ESC = 放弃本次祝福（轮次 14：三选一浮层也是浮层，PC 上按 ESC 不该无动于衷；
## 走的是界面上本来就有的「放弃」分支，不新增规则）
func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:   # GM 控制台等全屏层优先
		return
	if event.is_action_pressed("ui_cancel"):
		_emit_pick("")
		get_viewport().set_input_as_handled()
