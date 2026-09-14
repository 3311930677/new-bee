# G.gd —— 全局单例：主题、字体、共享状态
extends Node

# ---------- 配色（模仿参考游戏：暖棕 + 羊皮纸 + 金） ----------
const BG_DEEP := Color("2a1f14")        # 深棕黑（选人底）
const BANNER := Color("5a3a1e")          # 棕色横幅
const PARCHMENT := Color("e8d5a3")       # 羊皮纸底
const GOLD := Color("f0c060")            # 金字/金边
const GOLD_BRIGHT := Color("ffd97a")     # 选中亮金
const NAME_GREEN := Color("8ce88c")      # 角色名绿
const LV_ORANGE := Color("f0a030")      # 等级橙
const TEXT_DARK := Color("3a2a14")      # 羊皮纸上的深字
const TEXT_LIGHT := Color("f5ead0")      # 深底上的浅字

# ---------- 参考风（创建角色页）配色 ----------
const WOOD := Color("6b4a28")            # 木框/顶栏棕
const WOOD_DARK := Color("4a3018")       # 木框暗部
const GOLD_BTN := Color("e8b84a")        # 金色实心按钮
const GOLD_BTN_EDGE := Color("8a6220")   # 金按钮描边
const INPUT_BG := Color("cdc4ab")        # 输入框灰米底
const INPUT_BG_FOCUS := Color("ece5cf")
const BOX_BG := Color("c2b79b")          # 选择框底
const BOX_EDGE := Color("7c5f2c")        # 选择框描边

# ---------- 字体 ----------
const FONT_REG := "res://assets/fonts/NotoSansSC-Regular.otf"
const FONT_BOLD := "res://assets/fonts/NotoSansSC-Bold.otf"
var font_reg: FontFile
var font_bold: FontFile

# ---------- 共享状态 ----------
var account := ""           # 登录账号（游客登录时为"游客"）
var gender := "男"          # 玩家选择性别
var selected_role := ""     # "zs" / "ck" / "fs" / "fz"
var player_name := ""       # 玩家起的名字
var roles: Array = []       # data/roles.json 内容


func _ready() -> void:
	font_reg = load(FONT_REG) as FontFile
	font_bold = load(FONT_BOLD) as FontFile
	if font_reg == null:
		push_warning("Noto Sans SC Regular 加载失败")
	if font_bold == null:
		font_bold = font_reg
	_load_roles()


func _load_roles() -> void:
	var f := FileAccess.open("res://data/roles.json", FileAccess.READ)
	if f == null:
		push_error("data/roles.json 缺失")
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		roles = parsed


func get_role(id: String) -> Dictionary:
	for r in roles:
		if r.get("id", "") == id:
			return r
	return {}


func role_dir(id: String) -> String:
	# 素材目录映射：zs→zs / ck→ck / fs→fs / fz→fz（image/role/<id>/）
	return "res://image/role/%s/" % id


# ---------- 通用 UI 工厂 ----------

## 金字 Label（可带描边/阴影）
func gold_label(text: String, size: int, bold := true,
		color := GOLD, outline := true) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font_bold if bold else font_reg)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", Color("1a0f06"))
		l.add_theme_constant_override("outline_size", maxi(2, size / 12))
	return l


## 带字间距的字体（标题用）
func spaced_font(glyph_spacing: int, bold := true) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = font_bold if bold else font_reg
	fv.spacing_glyph = glyph_spacing
	return fv


## 深色横幅按钮（模仿参考游戏右侧按钮列）
func menu_button(text: String) -> Control:
	var root := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.10, 0.05, 0.72)
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(1)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.35)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	root.add_theme_stylebox_override("panel", sb)
	var l := gold_label(text, 20)
	root.add_child(l)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	return root


## 高亮/取消高亮按钮（选中项深色横幅更亮金字）
func set_button_active(btn: Control, active: bool) -> void:
	var sb: StyleBoxFlat = btn.get_theme_stylebox("panel")
	if sb == null:
		return
	if active:
		sb.bg_color = Color(0.24, 0.13, 0.04, 0.92)
		sb.border_color = GOLD_BRIGHT
	else:
		sb.bg_color = Color(0.16, 0.10, 0.05, 0.72)
		sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.35)
	var l := btn.get_child(0) as Label
	if l:
		l.add_theme_color_override("font_color", GOLD_BRIGHT if active else GOLD)


# ---------- 参考风控件（创建角色 / 登录页） ----------

## 顶部棕色木匾横幅（金边 + 金字）
func banner_box(text: String, w := 260, h := 52, font_size := 28) -> PanelContainer:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(w, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.36, 0.22, 0.10, 0.95)
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	sb.border_color = GOLD
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	root.add_theme_stylebox_override("panel", sb)
	var l := gold_label(text, font_size, true, GOLD_BRIGHT)
	l.add_theme_font_override("font", spaced_font(maxi(4, font_size / 4)))
	root.add_child(l)
	return root


## 羊皮纸面板（金边，内部留白）
func parchment_box(w := 400, h := 200, pad := 18.0) -> PanelContainer:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(w, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PARCHMENT
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(3)
	sb.border_color = GOLD
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.7
	sb.content_margin_bottom = pad * 0.6
	root.add_theme_stylebox_override("panel", sb)
	return root


## 金色实心按钮（棕字，参考"随机取名"）
func gold_button(text: String, w := 0.0, h := 42.0, font_size := 20) -> Control:
	var root := PanelContainer.new()
	if w > 0.0:
		root.custom_minimum_size = Vector2(w, h)
	else:
		root.custom_minimum_size = Vector2(0, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = GOLD_BTN
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	sb.border_color = GOLD_BTN_EDGE
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	root.add_theme_stylebox_override("panel", sb)
	var l := gold_label(text, font_size, true, TEXT_DARK, false)
	root.add_child(l)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	return root


## 米色选择框（参考"◀ 猎 ▶"中间的方框）
func select_box(text: String, w := 132.0, h := 42.0, font_size := 21) -> PanelContainer:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(w, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BOX_BG
	sb.set_corner_radius_all(3)
	sb.set_border_width_all(2)
	sb.border_color = BOX_EDGE
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	root.add_theme_stylebox_override("panel", sb)
	var l := gold_label(text, font_size, true, TEXT_DARK, false)
	root.add_child(l)
	return root


## 输入框样式（灰米底 + 深棕字）
func style_line_edit(le: LineEdit, font_size := 20) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = INPUT_BG
	sb.set_corner_radius_all(3)
	sb.set_border_width_all(2)
	sb.border_color = BOX_EDGE
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	var focus := sb.duplicate() as StyleBoxFlat
	focus.bg_color = INPUT_BG_FOCUS
	focus.border_color = GOLD_BTN_EDGE
	le.add_theme_stylebox_override("normal", sb)
	le.add_theme_stylebox_override("focus", focus)
	le.add_theme_font_override("font", font_reg)
	le.add_theme_font_size_override("font_size", font_size)
	le.add_theme_color_override("font_color", TEXT_DARK)
	le.add_theme_color_override("font_placeholder_color", Color(0.42, 0.36, 0.26))
	le.add_theme_color_override("caret_color", BANNER)


## 取一个武侠风随机名（姓 + 1~2 字名）
const SURNAMES := ["独孤", "南宫", "慕容", "上官", "东方", "西门", "夏侯", "轩辕",
	"沈", "苏", "林", "洛", "秦", "萧", "叶", "顾", "云", "燕", "陆", "裴"]
const GIVEN1 := ["渊", "霜", "岚", "川", "辰", "夜", "辞", "澜", "舟", "昭",
	"砚", "澈", "梧", "寒", "炎", "隐", "白", "青", "墨", "珩"]
const GIVEN2 := ["闻", "风", "雪", "月", "尘", "生", "离", "歌", "影", "觞",
	"羽", "归", "然", "行", "书", "痕", "野", "梦", "遥", "舟"]

func random_name() -> String:
	var s: String = SURNAMES[randi() % SURNAMES.size()]
	var g: String = GIVEN1[randi() % GIVEN1.size()]
	if randf() < 0.45:
		g += GIVEN2[randi() % GIVEN2.size()]
	return s + g
