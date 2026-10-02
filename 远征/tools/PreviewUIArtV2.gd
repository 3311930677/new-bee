# Isolated design study. Does not instantiate or replace production menus.
extends SubViewport

const OUT := "res://shots/ui_art_direction_v2_20261003"

func _ready() -> void:
	size = Vector2i(1120, 1190)
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var sheet := ArtSheet.new()
	sheet.size = Vector2(size)
	add_child(sheet)
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var result := img.save_png(OUT + "/art_direction_board.png")
	var camp_result := img.get_region(Rect2i(48, 140, 480, 800)).save_png(OUT + "/camp_480x800.png")
	var bag_result := img.get_region(Rect2i(592, 140, 480, 800)).save_png(OUT + "/bag_480x800.png")
	if result != OK or camp_result != OK or bag_result != OK:
		push_error("UI_ART_V2_CAPTURE_FAILED")
		get_tree().quit(1)
		return
	print("UI_ART_V2_SAVED: isolated design board + two 480x800 studies")
	sheet.queue_free()
	for i in 3:
		await get_tree().process_frame
	get_tree().quit()

class ArtSheet extends Control:
	var regular: FontFile
	var bold: FontFile
	var title: FontFile
	var backdrop: Texture2D
	var hero: Texture2D
	var sword_icon: Texture2D
	var armor_icon: Texture2D
	var potion_icon: Texture2D
	const INK := Color("34392e")
	const MUTED := Color("646956")
	const PAPER := Color("eee4ca")
	const WHITE := Color("f6f0de")

	func _ready() -> void:
		regular = load("res://assets/fonts/NotoSansSC-Regular.otf").duplicate() as FontFile
		bold = load("res://assets/fonts/NotoSansSC-Bold.otf").duplicate() as FontFile
		title = load("res://assets/fonts/ZCOOLXiaoWei-Regular.ttf").duplicate() as FontFile
		for f in [regular, bold, title]:
			f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
			f.hinting = TextServer.HINTING_LIGHT
			f.oversampling = 2.0
		backdrop = load("res://image/background/home.png") as Texture2D
		hero = load("res://image/role/zs/pojun_idle.png") as Texture2D
		sword_icon = load("res://image/generated_201_333/ready/icons/slot_sword.png") as Texture2D
		armor_icon = load("res://image/generated_201_333/ready/icons/slot_armor.png") as Texture2D
		potion_icon = load("res://image/generated_201_333/ready/icons/itm_potion_hp_s.png") as Texture2D
		queue_redraw()

	func _text(s: String, x: float, baseline: float, fs: int = 18, color: Color = INK, f: Font = null) -> void:
		draw_string(regular if f == null else f, Vector2(x, baseline), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

	func _center(s: String, x: float, baseline: float, fs: int = 18, color: Color = INK, f: Font = null) -> void:
		var used := regular if f == null else f
		_text(s, x - used.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / 2, baseline, fs, color, used)

	func _poly(coords: Array, c: Color, outline: Color = Color.TRANSPARENT, width: float = 1.0) -> void:
		var pts := PackedVector2Array()
		for p in coords:
			pts.append(Vector2(p[0], p[1]))
		draw_colored_polygon(pts, c)
		if outline.a > 0:
			pts.append(pts[0])
			draw_polyline(pts, outline, width, false)

	func _line(x1: float, y1: float, x2: float, y2: float, c: Color, w: float = 1.0) -> void:
		draw_line(Vector2(x1, y1), Vector2(x2, y2), c, w, false)

	func _stitches(points: Array, c: Color) -> void:
		for p in points:
			_line(p[0], p[1], p[0] + 4, p[1], c)

	func _shadow_label(s: String, x: float, baseline: float) -> void:
		_center(s, x + 1, baseline + 2, 19, Color("302d32"), bold)
		_center(s, x, baseline, 19, WHITE, bold)

	func _coin(x: float, y: float, radius: float = 7) -> void:
		draw_circle(Vector2(x, y + 1), radius + 1, Color("463324"))
		draw_circle(Vector2(x, y), radius, Color("d6b469"))
		draw_arc(Vector2(x, y), radius - 2, 0, TAU, 24, Color("f0d397"), 1, false)
		draw_rect(Rect2(x - 2, y - 2, 4, 4), Color("674829"))

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("e7e3db"))
		_text("远征 · 界面美术方向 02", 48, 52, 28, INK, title)
		_text("让入口成为物件，让页面拥有自己的构图。", 48, 87, 18, MUTED)
		_text("营帐 / 场景导航", 48, 122, 18, INK, bold)
		_text("行囊 / 装订册与器物", 592, 122, 18, INK, bold)
		draw_set_transform(Vector2(48, 140))
		_camp()
		draw_set_transform(Vector2(592, 140))
		_bag()
		draw_set_transform(Vector2.ZERO)
		_text("控件按用途长成不同形状", 48, 990, 22, INK, title)
		draw_set_transform(Vector2(56, 1005))
		_seal(38, 39, 30)
		_text("召唤", 86, 45, 19, INK, bold)
		_text("仪式：封蜡与印记", 0, 101, 17, MUTED)
		draw_set_transform(Vector2(342, 1012))
		_leather_action(0, 0, 188, 54, "装备", Color("395d86"))
		_text("主操作：染色皮带", 0, 94, 17, MUTED)
		draw_set_transform(Vector2(632, 1018))
		_bookmark(0, 0, 44, 50, Color("a54d48"))
		_text("装备", 63, 31, 19, INK, bold)
		_text("页签：布书签", 0, 88, 17, MUTED)
		draw_set_transform(Vector2(886, 1025))
		_line(0, 15, 25, 15, MUTED, 2)
		_line(0, 15, 8, 7, MUTED, 2)
		_line(0, 15, 8, 23, MUTED, 2)
		_text("返回", 38, 22, 19, INK)
		_text("导航：文字与箭头", 0, 81, 17, MUTED)
		draw_set_transform(Vector2.ZERO)
		_line(48, 1141, 1072, 1141, Color("c5c2b7"))
		_text("独立设计样板 · 非实装界面 · 数值为排版示例 · 保留现有角色与场景素材", 48, 1170, 17, MUTED)

	func _camp() -> void:
		draw_texture_rect(backdrop, Rect2(0, 0, 480, 800), false)
		# Local atmosphere layers; the middle stays open around the character.
		for i in 14:
			draw_rect(Rect2(0, i * 10, 480, 10), Color(0.12, 0.13, 0.21, 0.70 - i * 0.036))
		for i in 28:
			draw_rect(Rect2(0, 520 + i * 10, 480, 10), Color(0.13, 0.12, 0.18, 0.05 + i * 0.025))
		_text("昭元营帐", 26, 48, 29, WHITE, title)
		_text("破军  Lv.12", 27, 79, 17, Color("e0ccab"))
		_coin(215, 70)
		_text("1,280", 229, 77, 17, WHITE)
		_poly([[317, 64], [324, 58], [331, 64], [328, 77], [320, 77]], Color("8cc1c3"), Color("324b69"))
		_text("36", 340, 77, 17, WHITE)
		# Settings uses a corner symbol, not another giant plaque.
		draw_arc(Vector2(432, 38), 11, 0, TAU, 8, Color("d9d8d2"), 3, false)
		draw_circle(Vector2(432, 38), 4, Color("474853"))
		_center("设置", 432, 74, 16, WHITE)
		# A pinned quest note is a physical paper object with a folded corner.
		_poly([[34, 114], [336, 108], [359, 120], [350, 187], [37, 192]], Color(0.12, 0.10, 0.11, 0.25))
		_poly([[30, 110], [332, 104], [354, 116], [345, 181], [33, 186]], Color("dfd5b7"), Color("9f8a68"))
		_poly([[332, 104], [332, 123], [354, 116]], Color("bfb090"))
		_line(39, 133, 317, 127, Color("c5b793"))
		draw_circle(Vector2(43, 115), 4, Color("b39250"))
		_text("下一站", 48, 144, 16, Color("746d53"))
		_text("洛林野地 · 寻找巡林人", 48, 170, 18, INK)
		# Existing hero, one frame. Foot shadow is on the ground.
		draw_set_transform(Vector2(48 + 237, 140 + 426), 0.0, Vector2(1.0, 0.26))
		draw_circle(Vector2.ZERO, 48, Color(0.08, 0.07, 0.09, 0.36))
		draw_set_transform(Vector2(48, 140))
		draw_texture_rect_region(hero, Rect2(164, 289, 146, 146), Rect2(0, 0, 128, 128))
		# The scene's props carry navigation. Text stays visible for touch users.
		draw_set_transform(Vector2(48 + 83, 140 + 300))
		_map_prop()
		draw_set_transform(Vector2(48, 140))
		_shadow_label("世界", 83, 370)
		draw_set_transform(Vector2(48 + 393, 140 + 300))
		_bag_prop()
		draw_set_transform(Vector2(48, 140))
		_shadow_label("背包", 393, 370)
		draw_set_transform(Vector2(48 + 83, 140 + 454))
		_growth_prop()
		draw_set_transform(Vector2(48, 140))
		_shadow_label("养成", 83, 532)
		draw_set_transform(Vector2(48 + 393, 140 + 464))
		_book_prop()
		draw_set_transform(Vector2(48, 140))
		_shadow_label("图鉴", 393, 532)
		_text("营地事务", 29, 584, 16, Color("c5c0b8"))
		_line(113, 578, 445, 578, Color(0.8, 0.78, 0.72, 0.20))
		# Three quiet secondary entries, each with a characteristic symbol.
		_line(62, 604, 82, 624, Color("d3dde0"), 3)
		_line(82, 604, 62, 624, Color("d3dde0"), 3)
		_line(59, 619, 66, 612, Color("b98b5c"), 3)
		_line(78, 618, 85, 625, Color("b98b5c"), 3)
		_text("竞技", 94, 622, 18, WHITE)
		_star(222, 614, Color("b6a9dd"))
		_text("召唤", 243, 622, 18, WHITE)
		_coin(360, 614, 9)
		_text("兑换", 382, 622, 18, WHITE)
		_travel_action()
		_center("返回主世界 · 洛林野地", 240, 760, 16, Color("ded1bf"))

	func _bag() -> void:
		draw_rect(Rect2(0, 0, 480, 800), Color("263647"))
		# Woven blue cloth, not a flat global UI background.
		for y in range(0, 800, 4):
			_line(0, y, 480, y, Color(0.40, 0.52, 0.63, 0.045))
		for x in range(0, 480, 5):
			_line(x, 0, x, 800, Color(0.10, 0.16, 0.25, 0.18))
		_line(29, 38, 52, 38, WHITE, 2)
		_line(29, 38, 37, 30, WHITE, 2)
		_line(29, 38, 37, 46, WHITE, 2)
		_text("返回营帐", 66, 45, 17, WHITE)
		_coin(346, 38)
		_text("1,280", 360, 45, 17, WHITE)
		# Leather cover, layered page edges, irregular trimmed sheet.
		_poly([[24, 93], [428, 86], [450, 105], [453, 733], [426, 756], [29, 747], [16, 723]], Color(0.04, 0.07, 0.10, 0.4))
		_poly([[20, 87], [420, 80], [443, 99], [447, 726], [421, 749], [24, 740], [12, 716]], Color("72483b"), Color("a07855"), 2)
		_poly([[37, 91], [415, 88], [430, 99], [433, 718], [416, 731], [37, 724]], Color("b6a57e"))
		_poly([[40, 92], [417, 90], [430, 103], [432, 712], [413, 724], [39, 718]], Color("d1c4a0"))
		_poly([[41, 92], [419, 93], [432, 105], [429, 700], [414, 714], [39, 709]], PAPER, Color("bbad8a"))
		_poly([[414, 695], [429, 700], [414, 714]], Color("cdbf9c"))
		# Grain follows the page, and remains faint in the reading area.
		var rng := RandomNumberGenerator.new()
		rng.seed = 283
		for i in 1150:
			var at := Vector2(rng.randi_range(46, 423), rng.randi_range(99, 696))
			draw_rect(Rect2(at, Vector2(rng.randi_range(1, 3), 1)), Color(0.43, 0.34, 0.20, rng.randf_range(0.015, 0.045)))
		# Spine and thread are placed where binding makes sense.
		_poly([[21, 91], [38, 91], [36, 711], [22, 737]], Color("583d34"))
		for y in range(111, 703, 22):
			_line(24, y, 34, y - 2, Color("c2aa80"), 1)
			_line(25, y + 1, 25, y + 5, Color("372d29"), 1)
		_text("行囊", 59, 144, 32, INK, title)
		_text("随身物件", 60, 171, 16, MUTED)
		_text("12 / 40", 339, 171, 16, MUTED)
		# One fabric bookmark, three unboxed labels.
		_bookmark(58, 187, 80, 43, Color("a64e4b"))
		_center("装备", 98, 215, 18, WHITE)
		_text("材料", 164, 215, 18, MUTED)
		_text("药剂", 260, 215, 18, MUTED)
		_text("宝石", 352, 215, 18, MUTED)
		_line(55, 236, 415, 236, Color("b6aa8c"))
		# Large item illustration with a discreet ink annotation.
		draw_set_transform(Vector2(592 + 147, 140 + 353), -0.48)
		_sword_study()
		draw_set_transform(Vector2(592, 140))
		_text("狼牙大剑", 242, 283, 23, INK, title)
		draw_circle(Vector2(248, 306), 3, Color("87604c"))
		_text("精良 · 双手武器", 258, 312, 16, MUTED)
		_line(242, 328, 410, 328, Color("c4b998"))
		_text("攻击", 242, 360, 18, INK)
		_text("14", 361, 360, 24, INK, bold)
		_text("穿戴后", 242, 392, 16, MUTED)
		_text("+4", 362, 392, 19, Color("42664c"), bold)
		_leather_action(241, 414, 171, 50, "装备", Color("416688"))
		_text("狼骨制成的护手，", 61, 442, 16, MUTED)
		_text("留着荒野的旧痕。", 61, 465, 16, MUTED)
		_line(55, 489, 415, 489, Color("b6aa8c"))
		_text("我的装备", 60, 516, 18, INK, bold)
		_text("按获得时间  ↓", 298, 516, 16, MUTED)
		# List rows have no individual panel; selection has a small cloth marker.
		_bookmark(45, 534, 12, 48, Color("a64e4b"))
		draw_texture_rect(sword_icon, Rect2(68, 534, 38, 38), false)
		_text("狼牙大剑", 121, 552, 18, INK)
		_text("精良 · 攻击 14", 121, 576, 16, MUTED)
		_text("查看", 366, 559, 16, Color("466988"))
		_line(64, 586, 411, 586, Color("d1c4a5"))
		draw_texture_rect(armor_icon, Rect2(68, 596, 38, 38), false)
		_text("鳞甲", 121, 614, 18, INK)
		_text("当前穿戴", 121, 638, 16, MUTED)
		_text("已装备", 350, 621, 16, Color("476551"))
		_line(64, 648, 411, 648, Color("d1c4a5"))
		draw_texture_rect(potion_icon, Rect2(68, 656, 38, 38), false)
		_text("恢复药剂", 121, 677, 18, INK)
		_text("× 8", 370, 677, 18, MUTED)
		# Secondary and dangerous actions remain smaller and separated.
		_line(62, 755, 62, 741, Color("d5ccbc"), 2)
		draw_arc(Vector2(68, 740), 6, PI, TAU, 12, Color("d5ccbc"), 2, false)
		_line(74, 755, 74, 741, Color("d5ccbc"), 2)
		_line(62, 755, 74, 755, Color("d5ccbc"), 2)
		_text("锁定物品", 85, 758, 17, WHITE)
		_text("出售", 353, 758, 17, Color("e4b4a4"))
		_line(351, 764, 389, 764, Color("c28773"))

	func _bookmark(x: float, y: float, w: float, h: float, col: Color) -> void:
		_poly([[x + 2, y + 3], [x + w + 2, y + 3], [x + w + 2, y + h + 3], [x + w / 2 + 2, y + h - 4], [x + 2, y + h + 3]], Color(0.2, 0.15, 0.10, 0.18))
		_poly([[x, y], [x + w, y], [x + w, y + h], [x + w / 2, y + h - 7], [x, y + h]], col, col.darkened(0.24))
		_line(x + 4, y + 4, x + w - 4, y + 4, col.lightened(0.32))
		_line(x + 4, y + 6, x + 4, y + h - 6, col.lightened(0.12))

	func _leather_action(x: float, y: float, w: float, h: float, s: String, col: Color) -> void:
		# Strapped silhouette with a folded loop and buckle; only primary actions use it.
		_poly([[x + 17, y + 5], [x + w - 14, y + 5], [x + w, y + h / 2 + 5], [x + w - 14, y + h + 5], [x + 14, y + h + 5], [x, y + h / 2 + 5]], col.darkened(0.60))
		_poly([[x + 17, y], [x + w - 17, y], [x + w, y + h / 2], [x + w - 17, y + h], [x + 14, y + h], [x, y + h / 2]], col, col.darkened(0.45), 2)
		_line(x + 21, y + 4, x + w - 22, y + 4, col.lightened(0.28))
		for n in range(26, int(w) - 23, 11):
			_line(x + n, y + 8, x + n + 4, y + 8, Color(0.96, 0.9, 0.71, 0.52))
			_line(x + n, y + h - 8, x + n + 4, y + h - 8, Color(0.96, 0.9, 0.71, 0.42))
		_line(x + 17, y + 14, x + 17, y + h - 14, Color("b9a17b"), 3)
		_center(s, x + w / 2 + 3, y + h / 2 + 7, 20, WHITE, bold)

	func _map_prop() -> void:
		_poly([[-47, 26], [-22, -30], [41, -25], [53, 27], [17, 41]], Color(0.09, 0.07, 0.08, 0.30))
		_poly([[-47, 20], [-28, -27], [27, -31], [44, 13], [29, 29], [-17, 36]], Color("d5c9a1"), Color("756c55"), 2)
		_poly([[-28, -27], [-10, -11], [-17, 36], [-47, 20]], Color("b6b89a"))
		_poly([[-10, -11], [12, -18], [29, 29], [-17, 36]], Color("eadab3"))
		_line(-3, -6, -8, 22, Color("88a3a0"), 3)
		_line(-8, 22, 15, 17, Color("88a3a0"), 3)
		_poly([[18, -9], [26, 5], [10, 7]], Color("8d9581"))
		_line(-29, 6, -14, 0, Color("a65f4c"), 1)
		_line(-14, 0, 0, 10, Color("a65f4c"), 1)
		draw_circle(Vector2(0, 10), 3, Color("a65f4c"))
		_poly([[-50, 6], [-45, 2], [-33, 31], [-38, 34]], Color("a08e63"))
		_line(-29, -22, -11, -9, Color("f2e4bf"), 2)
		_line(13, -17, 26, 25, Color("beac84"))
		for at in [[-30, 15], [-18, 10], [12, 17], [25, 9]]:
			_line(at[0], at[1], at[0] + 4, at[1] - 2, Color("969e85"))

	func _bag_prop() -> void:
		_poly([[-43, 30], [-25, -28], [24, -28], [41, 24], [25, 43], [-29, 42]], Color(0.1, 0.07, 0.09, 0.40))
		_poly([[-34, -13], [-21, -29], [18, -27], [34, -11], [38, 29], [24, 37], [-30, 37], [-41, 22]], Color("537472"), Color("283a40"), 3)
		_poly([[-30, -16], [-23, -34], [20, -31], [33, -14], [22, 3], [-28, 4]], Color("936a4a"), Color("4d3b36"), 2)
		_poly([[-9, -32], [6, -33], [7, 25], [-9, 25]], Color("6b493a"))
		draw_rect(Rect2(-10, -2, 19, 15), Color("c6aa73"), false, 3)
		_line(-10, 4, 9, 4, Color("e3c590"), 2)
		for x in range(-24, 23, 8):
			_line(x, 27, x + 3, 27, Color("94ada0"))
		_line(-35, 6, -28, 24, Color("749c91"), 2)
		_line(29, 8, 26, 26, Color("345550"), 3)
		_poly([[-39, 10], [-33, -6], [-28, 4], [-26, 32], [-31, 32]], Color("789a8b"))
		_poly([[28, 3], [35, -5], [37, 28], [24, 33]], Color("3c5b5d"))
		_line(-27, -21, -19, -29, Color("c09a69"), 2)
		_line(12, -27, 25, -18, Color("b59261"), 2)
		for y in range(12, 27, 7):
			_line(-20, y, -12, y + 1, Color("628680"))
			_line(12, y, 21, y - 1, Color("486963"))

	func _travel_action() -> void:
		# A cloth standard attached to a compass; not the same control as equipment.
		_poly([[112, 673], [434, 668], [420, 699], [437, 730], [111, 737]], Color(0.09, 0.06, 0.08, 0.38))
		_poly([[109, 667], [431, 662], [417, 693], [434, 724], [109, 731]], Color("884b42"), Color("57383a"), 2)
		_poly([[112, 671], [425, 667], [412, 692], [427, 717], [112, 724]], Color("a0604d"))
		_line(124, 675, 416, 672, Color("c3916c"))
		_line(125, 720, 420, 714, Color("643e3b"))
		for x in range(139, 408, 12):
			_line(x, 680, x + 3, 680, Color("c98f6c"))
		for x in range(139, 408, 16):
			_line(x, 712, x + 3, 712, Color("ba7d60"))
		draw_circle(Vector2(94, 699), 39, Color("392d2b"))
		draw_circle(Vector2(94, 694), 38, Color("ac8b53"))
		draw_circle(Vector2(94, 694), 33, Color("45574f"))
		draw_arc(Vector2(94, 694), 34, 0, TAU, 48, Color("d7bb7c"), 2, false)
		draw_arc(Vector2(94, 694), 27, 0, TAU, 48, Color("879278"), 1, false)
		for i in 16:
			var a := i * TAU / 16
			_line(94 + cos(a) * 28, 694 + sin(a) * 28, 94 + cos(a) * 31, 694 + sin(a) * 31, Color("bdaf7b"))
		_poly([[94, 671], [99, 694], [94, 718], [89, 694]], Color("e9dfb3"), Color("485c53"))
		_poly([[94, 671], [99, 694], [94, 694]], Color("b7735a"))
		_poly([[74, 694], [94, 689], [113, 694], [94, 699]], Color("b9c0a0"))
		draw_circle(Vector2(94, 694), 3, Color("ccb274"))
		_center("继续旅程", 263, 704, 22, WHITE, bold)
		_line(369, 697, 390, 697, WHITE, 2)
		_line(383, 690, 390, 697, WHITE, 2)
		_line(383, 704, 390, 697, WHITE, 2)

	func _book_prop() -> void:
		_poly([[-49, -25], [-6, -30], [41, -11], [45, 33], [-6, 16], [-48, 23]], Color("41344b"), Color("282634"), 3)
		_poly([[-44, -25], [-7, -26], [-7, 12], [-45, 17]], Color("d9d5b7"), Color("8e8974"))
		_poly([[-7, -26], [36, -11], [38, 27], [-7, 12]], Color("efe4c9"), Color("aaa084"))
		for i in 4:
			_line(-39, -15 + 7 * i, -16, -17 + 7 * i, Color("97997c"))
			_line(2, -12 + 7 * i, 28, -3 + 7 * i, Color("b6a47c"))
		_poly([[21, -10], [27, -8], [29, 31], [22, 25]], Color("a95759"))
		_line(-7, -26, -7, 13, Color("827f70"), 2)

	func _growth_prop() -> void:
		# Training tools: an anvil and planted sword, not a framed glyph.
		_poly([[-37, 31], [36, 31], [30, 43], [-32, 43]], Color("4a3c37"))
		_poly([[-41, 1], [34, 1], [42, 13], [9, 19], [8, 30], [-18, 30], [-17, 17], [-40, 11]], Color("737d81"), Color("303841"), 2)
		_line(-37, 3, 30, 3, Color("b6c2c2"), 2)
		_poly([[-7, -38], [0, -52], [7, -38], [5, 7], [-5, 7]], Color("b6c2c4"), Color("3b4c5c"), 2)
		_poly([[0, -52], [7, -38], [5, 7], [0, 7]], Color("71889b"))
		_line(-15, -35, 15, -35, Color("b49268"), 5)
		_line(0, -69, 0, -38, Color("784938"), 7)
		_line(0, -68, 0, -40, Color("b5764b"), 2)
		draw_circle(Vector2(0, -72), 5, Color("b99f70"))

	func _sword_study() -> void:
		# Drawn specifically for the study, not a production replacement item sprite.
		_poly([[-14, -96], [0, -121], [16, -96], [15, 48], [0, 62], [-14, 48]], Color(0.3, 0.26, 0.17, 0.12))
		_poly([[-13, -100], [0, -128], [13, -100], [11, 39], [0, 51], [-11, 39]], Color("4b5961"), Color("4c4a42"), 2)
		_poly([[-9, -99], [0, -119], [0, 45], [-8, 36]], Color("d4dacf"))
		_poly([[0, -119], [10, -98], [8, 36], [0, 45]], Color("99a9ab"))
		_line(-6, -99, -6, 30, Color("f3edcf"), 2)
		_line(1, -100, 1, 34, Color("6d7d7e"), 2)
		for y in [-63, -42, -21]:
			_line(2, y, 7, y + 6, Color("657777"))
		_poly([[-32, 33], [-22, 20], [-13, 29], [13, 29], [22, 20], [32, 33], [24, 43], [11, 38], [-11, 38], [-25, 43]], Color("ad9970"), Color("675a44"), 2)
		_poly([[-23, 28], [-16, 34], [-29, 38]], Color("e2d1a4"))
		_poly([[23, 28], [16, 34], [29, 38]], Color("d4c296"))
		_poly([[-7, 38], [7, 38], [8, 89], [-8, 89]], Color("79514a"), Color("4a4238"), 2)
		for y in range(44, 85, 8):
			_line(-6, y + 3, 6, y, Color("b5836e"), 2)
		_poly([[-9, 87], [-5, 100], [5, 100], [9, 87], [0, 82]], Color("b6a078"), Color("665b47"), 2)

	func _star(x: float, y: float, c: Color) -> void:
		_poly([[x, y - 12], [x + 4, y - 4], [x + 12, y], [x + 4, y + 4], [x, y + 12], [x - 4, y + 4], [x - 12, y], [x - 4, y - 4]], c, c.darkened(0.25))
		draw_circle(Vector2(x, y), 3, Color("efdbc6"))

	func _seal(x: float, y: float, r: float) -> void:
		var pts := []
		for i in 24:
			var rad := r + (2 if i % 3 == 0 else -1)
			pts.append([x + cos(i * TAU / 24) * rad, y + 3 + sin(i * TAU / 24) * rad])
		_poly(pts, Color("5d343b"))
		for i in 24:
			pts[i][1] -= 3
		_poly(pts, Color("a95355"), Color("74383e"), 2)
		draw_arc(Vector2(x, y), r - 6, 0, TAU, 32, Color("cb7b70"), 2, false)
		_star(x, y, Color("dfb392"))
