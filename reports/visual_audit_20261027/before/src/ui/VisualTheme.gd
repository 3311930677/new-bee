extends RefCounted
## 每个功能有自己的材质；公共控件只提供布局和交互。

const FAMILIES := {
	"atlas": {"paper":"e4ebe6", "ink":"283e46", "accent":"75a8ad", "dark":"203842", "light":"deefdf", "icon":"world"},
	"forge": {"paper":"e3e6e9", "ink":"303a49", "accent":"b2bac7", "dark":"30394b", "light":"f4d6a2", "icon":"hammer"},
	"garden": {"paper":"e7ebd7", "ink":"344a39", "accent":"88a77b", "dark":"2f5145", "light":"e4eab8", "icon":"growth"},
	"arcane": {"paper":"e9e3ed", "ink":"4c3954", "accent":"b49cc4", "dark":"433451", "light":"f4d9b6", "icon":"summon"},
	"arena": {"paper":"eadfd5", "ink":"4b3334", "accent":"c39173", "dark":"573038", "light":"f4d1a0", "icon":"swords"},
	"market": {"paper":"f0e3c9", "ink":"4c3c2d", "accent":"c5a370", "dark":"5b4435", "light":"f7dfac", "icon":"coin"},
	"journal": {"paper":"f1ead7", "ink":"413c36", "accent":"b68770", "dark":"423d35", "light":"f3ddad", "icon":"book"},
	"quiet": {"paper":"eaece8", "ink":"35454c", "accent":"9ba9aa", "dark":"344952", "light":"e9e7d0", "icon":"settings"},
}

const PAGES := {
	"WorldPanel":"atlas", "RegionMapPanel":"atlas", "DeployPanel":"atlas", "WorldPuzzlePanel":"atlas", "RouteScene":"atlas",
	"BagPanel":"forge", "EquipPanel":"forge", "SkillBookPanel":"forge",
	"GrowthPanel":"garden", "TalentPanel":"garden", "PetRaisePanel":"garden", "CompanionPanel":"garden", "MountPanel":"garden", "FishingPanel":"garden",
	"CodexPanel":"arcane", "GachaPanel":"arcane", "FrostContractPanel":"arcane", "TraitPicker":"arcane",
	"ArenaPanel":"arena", "BattleScene":"arena", "TitlePanel":"arena",
	"ExchangePanel":"market", "ShopPanel":"market", "TradePanel":"market",
	"QuestPanel":"journal", "RoadMailPanel":"journal", "StoryBeat":"journal", "Prologue":"journal", "IntroductionPanel":"journal", "CityScene":"journal",
	"SettingsPanel":"quiet", "AvatarPanel":"quiet", "NameRecovery":"quiet", "Login":"journal", "CreateRole":"journal", "GmConsole":"quiet",
}

static func family(node: Node) -> String:
	var current := node
	while current != null:
		if current.has_meta("visual_family"): return String(current.get_meta("visual_family"))
		var script := current.get_script() as Script
		if script != null:
			var page := script.resource_path.get_file().get_basename()
			if PAGES.has(page): return String(PAGES[page])
		current = current.get_parent()
	return "journal"

static func palette(node: Node) -> Dictionary:
	return colors(family(node))

static func colors(key: String) -> Dictionary:
	var raw: Dictionary = FAMILIES.get(key, FAMILIES.journal)
	var result := {"family": key, "icon": raw.icon}
	for k in ["paper", "ink", "accent", "dark", "light"]: result[k] = Color(raw[k])
	return result

static func title_family(title: String, fallback := "journal") -> String:
	var words := {"forge":["锻","工坊","强化","镶嵌","装备","回炉"],"market":["交易","物资","商","货","港务","兑换","市集"],"garden":["伙伴","宠","坐骑","垂钓","兽栏","马厩"],"arcane":["祭坛","灵契","碑灵","召唤"],"arena":["演武","切磋","战报"],"atlas":["地图","行路","筹备","远征"],"quiet":["设置","存档","姓名","资源说明"]}
	for key in words:
		for word in words[key]:
			if title.contains(word): return key
	return fallback

static var _tex_cache: Dictionary = {}

static func _kit_tex(path: String) -> Texture2D:
	var full_path := path
	if not full_path.begins_with("res://"):
		var candidate := "res://assets/ui/kit_20261013/" + full_path
		if not ResourceLoader.exists(candidate) and not FileAccess.file_exists(candidate) and ResourceLoader.exists("res://assets/ui/battle_settle/" + full_path):
			full_path = "res://assets/ui/battle_settle/" + full_path
		else:
			full_path = candidate
	if _tex_cache.has(full_path) and _tex_cache[full_path] != null:
		return _tex_cache[full_path]
	var t: Texture2D = null
	if ResourceLoader.exists(full_path):
		t = load(full_path) as Texture2D
	if t == null and FileAccess.file_exists(full_path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(full_path))
		if img != null and not img.is_empty():
			t = ImageTexture.create_from_image(img)
	_tex_cache[full_path] = t
	return t

static func nine_slice(item: CanvasItem, tex: Texture2D, rect: Rect2, mx := 12.0, my := 12.0, tint := Color.WHITE) -> void:
	draw_nine(item, tex, rect, maxf(mx, my), tint)

static func draw_nine(item: CanvasItem, tex: Texture2D, rect: Rect2, m: float, tint := Color.WHITE) -> void:
	if tex == null or rect.size.x < 8 or rect.size.y < 8:
		return
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var ms := minf(m, minf(tw * 0.33, th * 0.33))
	var md := minf(m, minf(rect.size.x * 0.33, rect.size.y * 0.33))
	var xs := [0.0, ms, tw - ms, tw]
	var ys := [0.0, ms, th - ms, th]
	var xd := [rect.position.x, rect.position.x + md, rect.end.x - md, rect.end.x]
	var yd := [rect.position.y, rect.position.y + md, rect.end.y - md, rect.end.y]
	for iy in 3:
		for ix in 3:
			var dw: float = xd[ix + 1] - xd[ix]
			var dh: float = yd[iy + 1] - yd[iy]
			var sw: float = xs[ix + 1] - xs[ix]
			var sh: float = ys[iy + 1] - ys[iy]
			if dw > 0 and dh > 0 and sw > 0 and sh > 0:
				item.draw_texture_rect_region(tex, Rect2(xd[ix], yd[iy], dw, dh), Rect2(xs[ix], ys[iy], sw, sh), tint)

class _PlaqueHeader extends Control:
	var plaque_h := 40.0
	func _draw() -> void:
		var w := size.x
		var h := plaque_h
		var r := Rect2(0, 0, w, h)
		draw_rect(Rect2(2, 4, w - 2, h - 1), Color("090d0e", 0.42))
		draw_colored_polygon(G.octagon_path(Vector2(w, h), 0.0, 5.0), Color("1d3635"))
		var p_tex := G.Visuals._kit_tex("plaque_header_jade.png")
		if p_tex != null:
			G.Visuals.draw_nine(self, p_tex, r, 16.0, Color(1, 1, 1, 0.96))
		var p1 := G.octagon_path(Vector2(w, h), 1.0, 5.0)
		p1.append(p1[0])
		draw_polyline(p1, Color("d8b268", 0.92), 1.0)
		var p2 := G.octagon_path(Vector2(w, h), 3.0, 4.0)
		p2.append(p2[0])
		draw_polyline(p2, Color("9e3828", 0.55), 1.0)
		for sx in [14.0, w - 14.0]:
			G.Visuals.diamond(self, Vector2(sx, h * 0.5), 4.0, Color("d8b268"))
			G.Visuals.diamond(self, Vector2(sx, h * 0.5), 2.0, Color("a63429"))
		var div_tex := G.Visuals._kit_tex("divider_scroll_ornament.png")
		var dw := minf(w - 20.0, 320.0)
		if div_tex != null:
			draw_texture_rect(div_tex, Rect2((w - dw) * 0.5, h + 1.0, dw, 12.0), false)
		else:
			draw_line(Vector2(16, h + 6.0), Vector2(w - 16, h + 6.0), Color("b89456", 0.65), 1.0)

static func header_plaque(title_text: String, w := 360.0, h := 40.0) -> Control:
	var root := _PlaqueHeader.new()
	root.plaque_h = h
	root.custom_minimum_size = Vector2(w, h + 14.0)
	root.size = Vector2(w, h + 14.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var lbl := G.art_label(title_text, G.FS_LG, G.GOLD_BRIGHT, true)
	lbl.name = "PlaqueLabel"
	lbl.size = Vector2(w, h)
	lbl.custom_minimum_size = Vector2(w, h)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(lbl)
	return root

class _SubcardBox extends Control:
	func _draw() -> void:
		var tex := G.Visuals._kit_tex("card_frame_parchment.png")
		if tex != null:
			G.Visuals.draw_nine(self, tex, Rect2(Vector2.ZERO, size), 14.0, Color(1, 1, 1, 0.94))
		else:
			draw_rect(Rect2(Vector2.ZERO, size), Color("e6dac0", 0.92))
			draw_rect(Rect2(Vector2.ZERO, size), Color("a88958", 0.75), false, 1.0)

static func parchment_subcard(at: Vector2, sz: Vector2) -> Control:
	var c := _SubcardBox.new()
	c.position = at
	c.size = sz
	c.custom_minimum_size = sz
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return c

static func paper(item: CanvasItem, sz: Vector2) -> void:
	if sz.x < 16 or sz.y < 16: return
	var c := palette(item)
	var large := sz.x >= 260 and sz.y >= 110
	var bounds := Rect2(Vector2.ZERO, sz)
	item.draw_rect(Rect2(Vector2(2, 6), sz - Vector2(2, 2)), Color("08060a", 0.52))
	var iron_tex := _kit_tex("res://assets/ui/kit_20261013/panel_iron.png")
	var slip_tex := _kit_tex("res://assets/ui/kit_20261013/quest_slip.png")
	var subcard_tex := _kit_tex("res://assets/ui/kit_20261013/card_frame_parchment.png")
	if large:
		if iron_tex != null:
			draw_nine(item, iron_tex, bounds.grow(2.0), 16.0)
		else:
			item.draw_colored_polygon(G.octagon_path(sz, 0, 5), c.dark)
		var inner_rect := bounds.grow(-4.0)
		item.draw_rect(inner_rect, c.paper)
		if slip_tex != null:
			draw_nine(item, slip_tex, bounds.grow(-1.0), 14.0, Color(1, 1, 1, 0.85))
		# 保持内芯宣纸温润纯净，避免外框暗边侵入 x=16 文本区
		item.draw_rect(bounds.grow(-6.0), Color(c.paper, 0.92))
		# 双层古铜与朱砂内框线（紧贴边缘不压内文）
		item.draw_rect(bounds.grow(-5.0), Color("b89456", 0.78), false, 1.0)
		item.draw_rect(bounds.grow(-7.0), Color("8c3b2b", 0.24), false, 1.0)
		G.draw_brass_corners(item, sz, 15.0, 5.0)
		var seal_tex := _kit_tex("res://assets/ui/battle_settle/seal_stamps.png")
		if seal_tex != null and sz.x >= 320 and sz.y >= 160:
			item.draw_texture_rect_region(seal_tex, Rect2(sz.x - 48, 10, 34, 34), Rect2(0, 0, 56, 56), Color(1, 1, 1, 0.20))
	else:
		item.draw_colored_polygon(G.octagon_path(sz, 0, 3), c.dark)
		item.draw_rect(bounds.grow(-2), c.paper)
		var small_tex := subcard_tex if subcard_tex != null else slip_tex
		if small_tex != null:
			draw_nine(item, small_tex, bounds.grow(-1), 12.0, Color(1, 1, 1, 0.92))
		item.draw_rect(bounds.grow(-2), Color(c.accent, 0.65), false, 1.0)
		return
	match c.family:
		"forge":
			item.draw_line(Vector2(9, 14), Vector2(9, sz.y - 14), Color("bac4cc", 0.45))
		"garden":
			for p in [Vector2(10, 10), Vector2(sz.x - 10, sz.y - 10)]:
				var flip := 1.0 if p.x < sz.x * 0.5 else -1.0
				for i in 3:
					var leaf: Vector2 = p + Vector2(4 + i * 4, 3) * flip
					item.draw_colored_polygon(PackedVector2Array([leaf, leaf + Vector2(3, 2) * flip, leaf + Vector2(1, 4) * flip]), Color(c.accent, 0.55))
		"arcane":
			for p in [Vector2(10, 10), Vector2(sz.x - 10, 10), Vector2(10, sz.y - 10), Vector2(sz.x - 10, sz.y - 10)]:
				diamond(item, p, 3, c.dark)
				diamond(item, p, 1.5, c.light)
		"atlas":
			for y in range(22, int(sz.y - 18), 24):
				item.draw_line(Vector2(8, y), Vector2(11, y), Color(c.dark, 0.35))
		"arena":
			for y in [10.0, sz.y - 10]:
				item.draw_line(Vector2(18, y), Vector2(sz.x - 18, y), Color(c.accent, 0.55))
		"market":
			for y in range(18, int(sz.y - 16), 18):
				item.draw_line(Vector2(8, y), Vector2(11, y), Color("8c6d3f", 0.35))
		_:
			for y in range(22, int(sz.y - 18), 28):
				item.draw_line(Vector2(8, y), Vector2(11, y + 1), Color(c.dark, 0.32))

static func diamond(item: CanvasItem,p: Vector2,r: float,color: Color) -> void:
	item.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-r),p+Vector2(r,0),p+Vector2(0,r),p+Vector2(-r,0)]),color)

static func heading(item: Control) -> void:
	var c := palette(item)
	var sz := item.size
	if sz.x < 20: return
	var plaque_tex := _kit_tex("res://assets/ui/kit_20261013/plaque_title.png")
	if plaque_tex != null and sz.y >= 34:
		var pw := clampf(sz.x + 28.0, 180.0, 340.0)
		var ph := clampf(sz.y + 8.0, 44.0, 62.0)
		var pr := Rect2((sz.x - pw) * 0.5, (sz.y - ph) * 0.5, pw, ph)
		item.draw_texture_rect(plaque_tex, pr, false)
	var center := Vector2(sz.x*0.5,sz.y-2)
	var wings := maxf(10,sz.x*0.5-38)
	item.draw_line(center+Vector2(-wings,0),center+Vector2(-9,0),Color("e2c48c",0.78),1)
	item.draw_line(center+Vector2(9,0),center+Vector2(wings,0),Color("e2c48c",0.78),1)
	diamond(item, center, 4, Color("e2c48c"))
	diamond(item, center, 2, c.dark)

class Atmosphere extends Control:
	var theme_key := "journal"
	var phase := 0.0
	var art: Texture2D
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		theme_key = G.Visuals.family(get_parent())
		var art_path: String = {
			"forge":"res://image/main_world/city_forge_reference_v2.png",
			"atlas":"res://image/background/refined/enter.png",
			"garden":"res://image/main_world/city_kennel_reference_v2.png",
			"market":"res://image/main_world/city_market_reference_v2.png",
		}.get(theme_key,"")
		if not String(art_path).is_empty() and ResourceLoader.exists(art_path): art = load(art_path)
		set_process(DisplayServer.get_name() != "headless")
	func _process(delta: float) -> void:
		phase += delta
		queue_redraw()
	func _draw() -> void:
		var c: Dictionary = G.Visuals.colors(theme_key)
		draw_rect(Rect2(Vector2.ZERO,size),Color(c.dark,0.92))
		if art != null:
			var ratio := float(art.get_height())/art.get_width()
			var width := size.x*0.9
			draw_texture_rect(art,Rect2(size.x-width,size.y-width*ratio,width,width*ratio),false,Color(1,1,1,0.12))
		# 边缘的大形状与少量缓慢星尘，避免纹理噪声。
		for i in 3:
			var center := Vector2(size.x*(0.04+i*0.46),size.y*(0.12+i*0.39))
			draw_arc(center,80+i*45,0,TAU,48,Color(c.accent,0.055),1)
		for i in 9:
			var x := fposmod(23+i*67+sin(phase*0.17+i)*6,size.x)
			var y := fposmod(47+i*109-phase*(1.5+i%3),size.y)
			var alpha := 0.12+0.10*sin(phase*0.6+i)
			draw_rect(Rect2(Vector2(x,y).floor(),Vector2(2,2)),Color(c.light,alpha))

class SceneryMotion extends Control:
	var phase := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(DisplayServer.get_name() != "headless")
	func _process(delta: float) -> void:
		phase += delta
		queue_redraw()
	func _draw() -> void:
		for i in 12:
			var origin := Vector2(20+i*31,size.y*0.75)
			var life := fposmod(phase*0.12+i*0.17,1.0)
			var p := origin+Vector2(sin(i+life*4)*12,-life*140)
			draw_rect(Rect2(p.floor(),Vector2.ONE*(2 if i%4 == 0 else 1)),Color("eac284",sin(life*PI)*0.33))
