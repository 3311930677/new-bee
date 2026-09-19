# CodexPanel.gd —— 宠物图鉴浮层（收集进度；未收集的只给暗色剪影 + 解锁途径）
# 版式：一屏一只灵宠的大卡轮播，大图居中、稀有度外框叠在图上；
#      插画命名 <宠物id>.png（如 pet_emberling.png），缺图就留白占位并标出素材名。
# 从 GameHome 的内部类抽出，营帐与主城两处入口共用
class_name CodexPanel
extends Control

signal closed

const PageDeckScript := preload("res://src/ui/PageDeck.gd")
const SlideCardScript := preload("res://src/ui/SlideCard.gd")

const RARITY_NAME := {"white": "普通", "blue": "稀有", "purple": "史诗", "gold": "传说"}
const ROLE_NAME := {
	"tank": "护卫", "ranged_dps": "远程", "fast_dps": "速攻", "control": "控制",
	"healer": "治疗", "aoe_dps": "群攻", "poison_control": "毒控",
}
# 稀有度 → 边框素材名（frame_* 为方框空心底图，叠在宠物头像外圈）
const RARITY_FRAME := {"white": "frame_white", "blue": "frame_blue",
	"purple": "frame_purple", "gold": "frame_gold"}
const RARITY_HUE := {
	"white": Color("a89e88"), "blue": Color("6f9fd0"),
	"purple": Color("a273c9"), "gold": Color("d8ab48"),
}
# 同 DeployPanel：440 羊皮纸 - 左右各 16 内边距 = 408，子控件按 408 排版才不右偏
const CONTENT_W := 408.0
const DECK_H := 400.0
const DECK_Y := 30.0

var _deck: Control = null   # 大卡轮播（工厂模式：卡用到才建）
var _pets: Array = []       # 宠物表快照（进化后重建卡组要重读）
var _content: Control = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	# 浮层底衬：统一走 G.veil（深棕 + 暗角 + 斜纹），不再各写一块纯灰
	G.veil(self, 0.72)

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
	_content = content

	var pets: Array = TableCache.pets()
	var owned_n := G.owned_pets().size()
	var tip := G.gold_label("已收集 %d / %d · 通关世界首领可结伴同行"
		% [owned_n, pets.size()],
		G.FS_XS, false, Color("7a5a2e"), false)
	tip.position = Vector2(0, 2)
	tip.custom_minimum_size = Vector2(CONTENT_W, 0)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(tip)

	# 一屏一只：拖拽、两侧箭头、←→/AD 翻页，圆点在卡下页脚
	# 卡「用到才建」（同 WorldPanel）：先把起始页算出来，卡由工厂按需建
	_pets = pets
	var start := -1
	for i in pets.size():
		var p: Dictionary = pets[i]
		if not G.owns_pet(String(p.get("id", ""))) and start < 0:
			start = i   # 打开先落在「还没收集到的那只」上（-1 哨兵：索引 0 也正确）
	_build_deck(maxi(0, start))

	# 进化入口：对「当前页」的灵宠生效（P1-3）；与「返回」左右成对
	var evolve := G.gold_button("进 化", 120, 38)
	evolve.position = Vector2(20, 480)
	evolve.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_evolve())
	content.add_child(evolve)

	var back := G.gold_button("返 回", 120, 38)
	back.position = Vector2(268, 480)
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			closed.emit())
	content.add_child(back)


## ESC / 返回手势关闭本浮层（轮次 14 统一口径）
func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:
		return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


func _card(p: Dictionary, idx: int, total: int) -> Control:
	var pid := String(p.get("id", ""))
	var owned: bool = G.owns_pet(pid)
	var rarity := String(p.get("rarity", "white"))
	var base: Dictionary = p.get("base", {})
	var hue: Color = RARITY_HUE.get(rarity, Color("a89e88"))

	var lines: Array = []
	var subtitle := ""
	if owned:
		subtitle = "%s · %s" % [RARITY_NAME.get(rarity, "普通"),
			ROLE_NAME.get(String(p.get("role", "")), "未知")]
		if bool(G.pet_stat(pid).get("evolved", false)):
			lines.append("已进化 · 全属性 +25％")
		lines.append("血 %d · 攻 %d · 防 %d" % [
			int(base.get("hp", 0)), int(base.get("atk", 0)), int(base.get("def", 0))])
		var sk := PackedStringArray()
		for s in p.get("skills", []):
			sk.append(String((s as Dictionary).get("name", "")))
		if sk.size() > 0:
			lines.append("技能 · " + " · ".join(sk))
	else:
		lines.append(G.pet_unlock_text(pid))

	return SlideCardScript.new({
		"kicker": "灵 宠 %02d / %02d" % [idx + 1, total],
		"title": String(p.get("name", pid)) if owned else "？？？",
		"subtitle": subtitle,
		"art_names": (["%s_evo" % pid, "%s_art" % pid, pid]
			if owned and bool(G.pet_stat(pid).get("evolved", false)) else ["%s_art" % pid, pid]),
		"art_hint": "%s.png" % pid,
		"art_tint": hue,
		"art_fit": "contain",
		"art_dim": not owned,
		"art_frame": RARITY_FRAME.get(rarity, "frame_white"),
		"art_ratio": 0.44,
		"badge": "已收集" if owned else "未收集",
		"badge_color": Color("4a7a44") if owned else Color("7a7263"),
		"lines": lines,
		"footer": "← → 翻阅 · 未收集的会标出解锁途径",
	})


## 建/重建卡组（进化后数据变了要整组重建；start = 落在哪一页）
func _build_deck(start: int) -> void:
	if _deck != null:
		_deck.queue_free()
		_deck = null
	_deck = PageDeckScript.new(CONTENT_W, DECK_H, 26.0)
	_deck.position = Vector2(0, DECK_Y)
	_deck.key_mode = "both"   # 方向键 / WASD 都能翻
	var total := _pets.size()
	_deck.set_factory(total, func(i: int) -> Control:
		return SlideCardScript.page(_card(_pets[i] as Dictionary, i, total), CONTENT_W, DECK_H),
		Vector2(CONTENT_W, DECK_H))
	if _content != null:
		_content.add_child(_deck)
	_deck.go(start, true)


## 进化当前页的灵宠（数据/素材变化 → 整组重建刷新）
func _on_evolve() -> void:
	if _deck == null or _pets.is_empty():
		return
	var idx: int = clampi(int(_deck.current), 0, _pets.size() - 1)
	var pid := String((_pets[idx] as Dictionary).get("id", ""))
	var res := G.pet_evolve(pid)
	if bool(res.get("ok", false)):
		_build_deck(idx)
		_toast("进化成功 · 全属性提升")
	else:
		_toast(String(res.get("err", "不可进化")))


## 一句话提示（图鉴没有行内提示位，用临时金字）
func _toast(msg: String) -> void:
	if _content == null:
		return
	var l := G.gold_label(msg, G.FS_SM, false, Color("8a4a3a"), false)
	l.position = Vector2(0, 452)
	l.custom_minimum_size = Vector2(CONTENT_W, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)
