# DeployPanel.gd —— 出征筹备浮层（秘境 / 人物 / 宠物 三页签，每页一屏一项的大卡轮播）
# 交互：← → （或 A/D、拖拽）翻当前页的选项；↑ ↓（或 W/S）切页签；点卡片选定。
# 插画命名：秘境 world_<theme>.png、人物 role_<role>.png、宠物 <宠物id>.png；
#          缺图时卡上留白占位并写出素材名，生成后丢进 image/generated_*/ready/ 即生效。
# 从 GameHome 的内部类抽出，营帐与主城两处入口共用同一份筹备面板
class_name DeployPanel
extends Control

signal confirmed(cfg: Dictionary)
signal canceled

# 新 class_name 尚未进编辑器全局类缓存，按项目惯例 preload 路径取脚本
const PageDeckScript := preload("res://src/ui/PageDeck.gd")
const SlideCardScript := preload("res://src/ui/SlideCard.gd")

const STEPS := ["秘境", "人物", "宠物"]
# 羊皮纸 440 宽 - 左右各 16 内边距 = 内容可用宽。子控件坐标一律以这个宽度为基准，
# 因为子控件挂的是 content（已被 PanelContainer 内缩过），再按 440 算就会整体右偏 16px
const CONTENT_W := 408.0
const TAB_W := 96.0
const TAB_H := 30.0
const GUTTER := 40.0     # 与卡片左右边距对齐（卡 = 408 - 2*40）
const DECK_Y := 36.0
const DECK_H := 346.0

# 秘境色标：maps.json 的 tint 是给地图叠色用的（8 个都接近白），当色卡完全分不出来，
# 所以另起一套辨识色 —— 林绿 / 雪蓝 / 火岩红 / 墓紫 / 沙黄 / 冰川青 / 深渊靛 / 城石灰
const THEME_HUE := {
	"forest": Color("5f8a46"), "snow": Color("7fa8cf"), "volcano": Color("b0523a"),
	"tomb": Color("6b5f88"), "desert": Color("c09a55"), "glacier": Color("6fb3ba"),
	"abyss": Color("6d5a9e"), "castle": Color("8d8474"),
}
# 稀有度色：宠物卡色标与徽标按它来，一眼分出白/蓝/紫/金档
const RARITY_HUE := {
	"white": Color("a89e88"), "blue": Color("6f9fd0"),
	"purple": Color("a273c9"), "gold": Color("d8ab48"),
}
const RARITY_NAME := {"white": "普通", "blue": "稀有", "purple": "史诗", "gold": "传说"}
const RARITY_FRAME := {"white": "frame_white", "blue": "frame_blue",
	"purple": "frame_purple", "gold": "frame_gold"}
const ROLE_NAME := {
	"tank": "护卫", "ranged_dps": "远程", "fast_dps": "速攻", "control": "控制",
	"healer": "治疗", "aoe_dps": "群攻", "poison_control": "毒控",
}
# 立绘文件名映射（内部类拿不到外层类的 _role_name()，这里自持一份）
const ROLE_ART := {"zs": "pojun", "ck": "chuanyang", "fs": "shuangyu", "fz": "chenxing"}

var _theme := "forest"
var _role := "zs"
var _active_pet := "pet_rockturtle"
var _bench_pet := ""

var _content: Control = null
var _deck = null          # PageDeck（类型不写死，避免全局类缓存未刷新时报错）
var _hint: Label = null
var _step := 0
var _tab_btns: Array = []
var _tab_sbs: Array = []
var _cards := {}          # "步骤:选项id" -> SlideCard（选中态只改样式，不重建卡）
var _sweep_btn: Control = null   # 扫荡按钮（持有引用用于刷新券余量）
var _help_btn: Control = null    # 右上角「?」操作说明

# 操作说明：? 弹层与首次进入的引导共用同一份文案
const TIPS := [
	"← → 或 A/D：切当前页的选项，也可直接左右拖动卡片",
	"↑ ↓ 或 W/S：切换「秘境 / 人物 / 宠物」三个页签",
	"点卡片选定；宠物再点一次可换替补或取消出战",
	"秘境未解锁时，需先通关前一片大陆的首领",
]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if G.selected_role != "":
		_role = G.selected_role
	_build()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# 这里别用 set_anchors_preset 定位：浮层自己的 rect 要等一帧才结算完，
	# 锚点基准取到的是 0，横幅会被推到屏幕左边外面去，直接写死坐标最稳
	var banner := G.banner_box("出征筹备", 300, 50)
	banner.position = Vector2(90, 36)
	add_child(banner)

	var panel := G.parchment_box(440, 560, 16.0)
	panel.position = Vector2(20, 108)
	add_child(panel)

	# PanelContainer 是 Container，直接放子控件会被布局系统覆盖位置；
	# 包一层 Control 再手动布局
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_content)

	# 三页签：点哪个进哪个，↑↓/WS 也能切（比再套一层横向分页更好认）
	var gap := (CONTENT_W - GUTTER * 2.0 - TAB_W * float(STEPS.size())) / 2.0
	for i in STEPS.size():
		var tab := PanelContainer.new()
		tab.custom_minimum_size = Vector2(TAB_W, TAB_H)
		tab.position = Vector2(GUTTER + float(i) * (TAB_W + gap), 0.0)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(15)
		sb.set_border_width_all(1)
		sb.content_margin_top = 4.0
		sb.content_margin_bottom = 4.0
		tab.add_theme_stylebox_override("panel", sb)
		tab.add_child(G.gold_label(STEPS[i], G.FS_MD, true, G.TEXT_DARK, false))
		tab.mouse_filter = Control.MOUSE_FILTER_STOP
		tab.gui_input.connect(func(e: InputEvent): _on_tab_click(e, i))
		_content.add_child(tab)
		_tab_btns.append(tab)
		_tab_sbs.append(sb)

	_hint = G.gold_label("", G.FS_XS, false, Color("8a6a34"), false)
	_hint.position = Vector2(0, 410)
	_hint.custom_minimum_size = Vector2(CONTENT_W, 0)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_hint)

	# 操作说明收进「?」圆钮：常驻文案会把卡片视野压掉一块，点开才看
	var help := G.info_button("出征筹备 · 怎么操作", TIPS)
	help.position = Vector2(CONTENT_W - 26.0, 3.0)
	_help_btn = help
	_content.add_child(help)
	# 头一回打开自动弹一次（新手教程），之后只靠右上角 ? 复看
	G.tip_once.call_deferred("deploy", "出征筹备 · 怎么操作", TIPS, self)

	# 扫荡：已通关秘境 + 1 张扫荡券 = 标准路线收益一键入账（免跑图）
	_sweep_btn = G.gold_button("扫荡×%d" % G.item_count("ticket_sweep"), 140, 44, G.FS_SM)
	_sweep_btn.position = Vector2(GUTTER, 448)
	_sweep_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_sweep())
	_content.add_child(_sweep_btn)

	var go := G.gold_button("出 征", 172, 48)
	go.position = Vector2(196, 446)
	go.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_confirm())
	_content.add_child(go)

	var back := G.gold_button("返 回", 120, 36)
	back.position = Vector2((CONTENT_W - 120.0) * 0.5, 502)
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			canceled.emit())
	_content.add_child(back)

	_rebuild_step()

# ---------- 页签 ----------
func _on_tab_click(e: InputEvent, i: int) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_goto_step(i)

func _goto_step(i: int) -> void:
	i = wrapi(i, 0, STEPS.size())
	if i == _step:
		return
	_step = i
	_rebuild_step()

func _refresh_tabs() -> void:
	for i in _tab_btns.size():
		var sb: StyleBoxFlat = _tab_sbs[i]
		var on := i == _step
		sb.bg_color = G.GOLD_BTN if on else Color("ddd0ae")
		sb.border_color = G.GOLD_BTN_EDGE if on else Color("c0a068")
		(_tab_btns[i] as Control).modulate = Color.WHITE if on else Color(0.86, 0.84, 0.80)

# ---------- 选项页（一屏一项） ----------
func _rebuild_step() -> void:
	if _deck != null:
		_content.remove_child(_deck)
		_deck.queue_free()
	_deck = null
	_cards.clear()
	_deck = PageDeckScript.new(CONTENT_W, DECK_H, 26.0)
	_deck.position = Vector2(0, DECK_Y)
	_deck.key_mode = "lr"   # ↑↓/WS 留给页签，别和二级导航抢键
	match _step:
		0:
			_fill_themes()
		1:
			_fill_roles()
		2:
			_fill_pets()
	_content.add_child(_deck)
	_refresh_tabs()
	_set_hint_default()
	_refresh_sel()

func _fill_themes() -> void:
	var order: Array = G.theme_order()
	var start := maxi(0, order.find(_theme))
	for i in order.size():
		var tid := String(order[i])
		var open: bool = G.is_world_unlocked(tid)
		var card := SlideCardScript.new({
			"kicker": "秘 境 %02d / %02d" % [i + 1, order.size()],
			"title": G.world_name(tid),
			"art_names": ["world_%s_art" % tid, "world_%s" % tid],
			"art_hint": "world_%s.png" % tid,
			"art_tint": THEME_HUE.get(tid, Color("8d8474")),
			"art_fit": "cover",
			"art_dim": not open,
			"art_ratio": 0.44,
			"lines": ["首领未讨伐 · 通关开启下一片" if open else "尚未解锁 · 先通关前一片"],
			"footer": "点击选定出征目标",
			"on_click": func(): _select_theme(tid),
		})
		card.set_meta("locked", not open)   # 未解锁标记：校验脚本与后续扩展按它取态
		_cards["0:%s" % tid] = card
		_deck.add_page(SlideCardScript.page(card, CONTENT_W, DECK_H), Vector2(CONTENT_W, DECK_H))
	_deck.go(start, true)

func _fill_roles() -> void:
	var start := 0
	for i in G.roles.size():
		var r: Dictionary = G.roles[i]
		var rid := String(r.get("id", ""))
		if rid == _role:
			start = i
		var card := SlideCardScript.new({
			"kicker": "人 物 %02d / %02d" % [i + 1, G.roles.size()],
			"title": String(r.get("name", rid)),
			"subtitle": "%s · %s" % [String(r.get("job", "")), String(r.get("weapon", ""))],
			"art_names": ["role_%s_art" % rid, "role_%s" % rid],
			"art_hint": "role_%s.png" % rid,
			"art_fallback": G.role_dir(rid) + String(ROLE_ART.get(rid, rid)) + "_icon.png",
			"art_tint": Color("b8923c"),
			"art_fit": "contain",
			"art_ratio": 0.44,
			# 只放一行 tag：desc 是两三行散文，塞进选择卡会把卡片顶破（长文案在创角页看）
			"lines": [String(r.get("tags", ""))],
			"footer": "点击选定出战人物",
			"on_click": func(): _select_role(rid),
		})
		_cards["1:%s" % rid] = card
		_deck.add_page(SlideCardScript.page(card, CONTENT_W, DECK_H), Vector2(CONTENT_W, DECK_H))
	_deck.go(start, true)

func _fill_pets() -> void:
	var pets: Array = TableCache.pets()
	var start := 0
	for i in pets.size():
		var p: Dictionary = pets[i]
		var pid := String(p.get("id", ""))
		if pid == _active_pet or pid == _bench_pet:
			start = i
		var owned: bool = G.owns_pet(pid)
		var rarity := String(p.get("rarity", "white"))
		var card := SlideCardScript.new({
			"kicker": "灵 宠 %02d / %02d" % [i + 1, pets.size()],
			"title": String(p.get("name", pid)),
			"subtitle": "%s · %s" % [RARITY_NAME.get(rarity, "普通"),
				ROLE_NAME.get(String(p.get("role", "")), "未知")],
			"art_names": ["%s_art" % pid, pid],
			"art_hint": "%s.png" % pid,
			"art_tint": RARITY_HUE.get(rarity, Color("a89e88")),
			"art_fit": "contain",
			"art_dim": not owned,
			"art_frame": RARITY_FRAME.get(rarity, "frame_white"),
			"art_ratio": 0.44,
			# 文案只留一行：两行会把卡撑高、被页脚裁掉（操作说明在右上角 ? 里）
			"lines": [G.pet_unlock_text(pid)] if not owned else [],
			"footer": "",
			"on_click": func(): _select_pet(pid),
		})
		card.set_meta("locked", not owned)
		_cards["2:%s" % pid] = card
		_deck.add_page(SlideCardScript.page(card, CONTENT_W, DECK_H), Vector2(CONTENT_W, DECK_H))
	_deck.go(start, true)

# ---------- 选择 ----------
func _select_theme(id: String) -> void:
	if not G.is_world_unlocked(id):
		_warn("「%s」尚未解锁：先通关前一世界的首领" % G.world_name(id))
		return
	_theme = id
	_set_hint_default()
	_refresh_sel()

func _select_role(id: String) -> void:
	_role = id
	_set_hint_default()
	_refresh_sel()

func _select_pet(id: String) -> void:
	if not G.owns_pet(id):
		_warn("「%s」未收集：%s" % [
			String(TableCache.get_pet(id).get("name", id)), G.pet_unlock_text(id)])
		return
	if id == _active_pet:
		if _bench_pet != "":
			_active_pet = _bench_pet
			_bench_pet = ""
		else:
			_active_pet = ""
	elif id == _bench_pet:
		_bench_pet = ""
	else:
		if _active_pet == "":
			_active_pet = id
		else:
			_bench_pet = id
	_set_hint_default()
	_refresh_sel()

func _set_hint_default() -> void:
	# 平常留空：操作说明交给右上角「?」，这行只用来报错与提示结果
	_hint.text = ""
	_hint.add_theme_color_override("font_color", Color("8a6a34"))

func _warn(msg: String) -> void:
	if _hint == null:
		return
	_hint.text = msg
	_hint.add_theme_color_override("font_color", Color("a04a3a"))

## 选中态刷新：只改卡片的描边、徽标与提示行，不重建（点一下不闪屏）
func _refresh_sel() -> void:
	for key in _cards:
		var card = _cards[key]
		var s := String(key)
		match int(s.get_slice(":", 0)):
			0:
				_paint_theme(card, s.get_slice(":", 1))
			1:
				_paint_role(card, s.get_slice(":", 1))
			2:
				_paint_pet(card, s.get_slice(":", 1))

func _paint_theme(card, tid: String) -> void:
	var on := tid == _theme
	card.set_selected(on)
	if on:
		card.set_badge("出征目标", Color("8a4a2a"))
		card.set_footer("已选定 · 出征即前往此秘境")
	elif G.is_world_cleared(tid):
		card.set_badge("已通关", Color("4a7a44"))
		card.set_footer("点击选定出征目标 · 已通关可扫荡")
	elif G.is_world_unlocked(tid):
		card.set_badge("可挑战", Color("a06020"))
		card.set_footer("点击选定出征目标")
	else:
		card.set_badge("未解锁", Color("7a7263"))

func _paint_role(card, rid: String) -> void:
	var on := rid == _role
	card.set_selected(on)
	card.set_badge("出战人物" if on else "", Color("8a4a2a"))
	card.set_footer("已选定 · 出征带队人物" if on else "点击选定出战人物")

func _paint_pet(card, pid: String) -> void:
	if not G.owns_pet(pid):
		card.set_selected(false)
		card.set_badge("未收集", Color("7a7263"))
		card.set_footer("未收集 · 不可出战")
		return
	card.set_footer("点卡片派出 · 再点换位或取消")
	card.set_selected(pid == _active_pet or pid == _bench_pet)
	if pid == _active_pet:
		card.set_badge("▶ 出战", Color("8a4a2a"))
	elif pid == _bench_pet:
		card.set_badge("◇ 替补", Color("3a5a6a"))
	else:
		card.set_badge("可出战", Color("4a7a44"))

# ---------- 键盘：↑↓/WS 切页签（←→ 交给卡片轮播） ----------
func _unhandled_input(e: InputEvent) -> void:
	if G.ui_blocked:
		return
	if e.is_action_pressed("move_up") or e.is_action_pressed("ui_up"):
		_goto_step(_step - 1)
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("move_down") or e.is_action_pressed("ui_down"):
		_goto_step(_step + 1)
		get_viewport().set_input_as_handled()

# ---------- 扫荡 / 出征 ----------
## 扫荡：已通关秘境 + 1 张扫荡券 → 标准路线收益（×0.7）直接入账
func _on_sweep() -> void:
	if not G.is_world_cleared(_theme):
		_warn("「%s」尚未通关首领，不能扫荡" % G.world_name(_theme))
		return
	if G.item_count("ticket_sweep") < 1:
		_warn("扫荡券不足（可在荣誉兑换补给）")
		return
	var gains := G.sweep_world(_theme)
	if gains.is_empty():
		_warn("扫荡失败：条件不满足")
		return
	var ups := int(gains.get("level_ups", 0))
	var msg := "扫荡入账：金+%d 币+%d 魂+%d 荣誉+%d" % [
		int(gains["gold"]), int(gains["expedition"]), int(gains["soul"]), int(gains["honor"])]
	if ups > 0:
		msg += " · 升 %d 级" % ups
	_hint.text = msg
	_hint.add_theme_color_override("font_color", Color("4a7a44"))
	# 刷新按钮上的券余量
	if _sweep_btn != null and _sweep_btn.get_child_count() > 0:
		(_sweep_btn.get_child(0) as Label).text = "扫荡×%d" % G.item_count("ticket_sweep")

func _on_confirm() -> void:
	if _active_pet == "":
		_warn("请先点选一只出战宠物")
		return
	if not G.owns_pet(_active_pet):
		_warn("出战宠物尚未收集：%s" % G.pet_unlock_text(_active_pet))
		return
	if not G.is_world_unlocked(_theme):
		_warn("「%s」尚未解锁" % G.world_name(_theme))
		return
	confirmed.emit({
		"theme": _theme,
		"role_id": _role,
		"level": int(G.prog.get("level", 1)),
		"active_pet": _active_pet,
		"bench_pet": _bench_pet,
		"potions": 2,
		"seed": 0,
	})
