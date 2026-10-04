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

static func paper(item: CanvasItem, sz: Vector2) -> void:
	if sz.x < 16 or sz.y < 16: return
	var c := palette(item)
	var large := sz.x >= 300 and sz.y >= 120
	var bounds := Rect2(Vector2.ZERO, sz)
	item.draw_rect(Rect2(Vector2(0, 4), sz), Color("090d13", 0.34))
	item.draw_rect(bounds, c.dark)
	item.draw_rect(bounds.grow(-3 if large else -1), c.paper)
	if not large:
		item.draw_line(Vector2(1, 1), Vector2(sz.x-1, 1), c.paper.lightened(0.12))
		return
	match c.family:
		"forge":
			item.draw_rect(bounds.grow(-1), c.accent, false)
			item.draw_rect(bounds.grow(-6), c.dark.lightened(0.18), false)
			for x in [4.0, sz.x-5]:
				for y in [4.0, sz.y-5]:
					item.draw_rect(Rect2(x-1,y-1,3,3), Color("d5d9dd"))
			item.draw_line(Vector2(8, 8),Vector2(8,sz.y-8),Color("bac4cc"))
		"garden":
			item.draw_rect(bounds.grow(-1), c.accent, false)
			for p in [Vector2(8,8), Vector2(sz.x-8,sz.y-8)]:
				var flip := 1.0 if p.x < sz.x*0.5 else -1.0
				item.draw_line(p,p+Vector2(25,0)*flip,c.dark,1)
				item.draw_line(p,p+Vector2(0,25)*flip,c.dark,1)
				for i in 3:
					var leaf: Vector2 = p+Vector2(5+i*5,3)*flip
					item.draw_colored_polygon(PackedVector2Array([leaf,leaf+Vector2(4,2)*flip,leaf+Vector2(1,5)*flip]),c.accent)
		"arcane":
			item.draw_rect(bounds.grow(-1),c.accent,false)
			item.draw_rect(bounds.grow(-7),Color(c.accent,0.42),false)
			for p in [Vector2(8,8),Vector2(sz.x-8,8),Vector2(8,sz.y-8),Vector2(sz.x-8,sz.y-8)]:
				diamond(item,p,5,c.dark)
				diamond(item,p,2,c.light)
		"atlas":
			item.draw_rect(bounds.grow(-1),c.accent,false)
			for y in range(16,int(sz.y-12),24):
				item.draw_line(Vector2(6,y),Vector2(9,y),Color(c.dark,0.45))
			for x in range(16,int(sz.x-12),24):
				item.draw_line(Vector2(x,6),Vector2(x,9),Color(c.dark,0.45))
		"arena":
			item.draw_rect(bounds.grow(-1),c.accent,false)
			item.draw_rect(Rect2(6,10,2,sz.y-20),c.dark)
			item.draw_rect(Rect2(sz.x-8,10,2,sz.y-20),c.dark)
			for y in [7.0,sz.y-7]:
				item.draw_line(Vector2(16,y),Vector2(sz.x-16,y),c.accent)
		"market":
			item.draw_rect(bounds.grow(-1),c.accent,false)
			for y in range(12,int(sz.y-10),9):
				item.draw_line(Vector2(5,y),Vector2(5,y+3),c.light)
				item.draw_line(Vector2(sz.x-5,y),Vector2(sz.x-5,y+3),c.light)
		"quiet":
			item.draw_rect(bounds.grow(-1),c.accent,false)
			item.draw_rect(Rect2(3,3,sz.x-6,2),c.dark)
		_:
			item.draw_rect(bounds.grow(-1),c.accent,false)
			item.draw_line(Vector2(10,10),Vector2(10,sz.y-10),Color(c.accent,0.4))
			for y in range(18,int(sz.y-10),30):
				item.draw_line(Vector2(4,y),Vector2(9,y+2),c.dark)
			item.draw_line(Vector2(15,sz.y-7),Vector2(sz.x-9,sz.y-7),Color(c.accent,0.5))

static func diamond(item: CanvasItem,p: Vector2,r: float,color: Color) -> void:
	item.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-r),p+Vector2(r,0),p+Vector2(0,r),p+Vector2(-r,0)]),color)

static func heading(item: Control) -> void:
	var c := palette(item)
	var sz := item.size
	if sz.x < 20: return
	# 开放式题签，留出书法笔画空间，不再把标题装进同一块木牌。
	var center := Vector2(sz.x*0.5,sz.y-2)
	var wings := maxf(10,sz.x*0.5-38)
	item.draw_line(center+Vector2(-wings,0),center+Vector2(-9,0),Color(c.accent,0.72),1)
	item.draw_line(center+Vector2(9,0),center+Vector2(wings,0),Color(c.accent,0.72),1)
	match c.family:
		"arcane":
			item.draw_circle(center,5,Color(c.accent,0.9),false,1)
			diamond(item,center,2,c.light)
		"garden":
			item.draw_line(center+Vector2(-5,1),center+Vector2(5,-3),c.light,1)
			diamond(item,center+Vector2(-2,-2),3,c.accent)
		"forge", "arena":
			diamond(item,center,5,c.accent)
			diamond(item,center,2,c.dark)
		_:
			item.draw_rect(Rect2(center-Vector2(3,2),Vector2(6,4)),c.accent)

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
