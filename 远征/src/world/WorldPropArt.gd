extends RefCounted
## Shared deterministic prop rendering; collision, triggers and quest state stay with MapScene.
const SIGN_PATH := "res://image/main_world/art_v2/signpost.png"
const ATLAS_PATH := "res://image/main_world/art_v2/props_atlas.png"
const STORY_ATLAS_PATH := "res://image/main_world/art_v2/story_props_atlas.png"
const RETURN_ATLAS_PATH := "res://image/main_world/art_v2/return_props_atlas.png"
const DESATURATE := preload("res://src/world/prop_desaturate.gdshader")
const Grounding := preload("res://src/world/BuildingGrounding.gd")
static var _ground_sources: Dictionary = {}
const REGIONS := {
	"vein":Rect2(62,113,343,292),"altar":Rect2(512,26,317,394),
	"herb":Rect2(64,513,341,314),"post":Rect2(533,454,284,406),
	"chime":Rect2(111,887,233,396),"vent":Rect2(456,933,399,350),
	"flags":Rect2(64,1330,317,392),"chest":Rect2(480,1419,357,275)}
const STORY_REGIONS := {
	"mine_cart":Rect2(81,178,334,258),"frost_brazier":Rect2(546,82,239,355),
	"frost_lichen":Rect2(71,579,341,245),"frost_echo":Rect2(558,504,220,334),
	"rope":Rect2(84,946,287,294),"feather":Rect2(533,984,270,273),
	"salt_cart":Rect2(63,1362,384,293),"tide_cargo":Rect2(517,1383,302,263)}
const RETURN_REGIONS := {
	"lantern":Rect2(66,22,193,349),"letter":Rect2(406,160,273,197),"tidebud":Rect2(746,61,313,311),
	"snowflower":Rect2(33,434,316,284),"rune":Rect2(424,408,243,314),"mailbox":Rect2(799,395,219,337),
	"road_ledger":Rect2(27,736,324,310),"tide_board":Rect2(404,745,278,314),"watch_table":Rect2(741,799,327,253),
	"dummy":Rect2(51,1057,253,362),"fishing":Rect2(386,1060,294,353),"barrier":Rect2(715,1190,358,197)}
static var _sign: Texture2D
static var _atlas: Texture2D
static var _story_atlas: Texture2D
static var _return_atlas: Texture2D

static func supplementary(c: CanvasItem,key: String,height: float,tint := Color.WHITE) -> void:
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _return_atlas==null: _return_atlas = load(RETURN_ATLAS_PATH)
	if _return_atlas==null: return
	var region: Rect2 = RETURN_REGIONS[key]
	var width := region.size.x/region.size.y*height
	_ground_bitmap(c,_return_atlas,Rect2(-width*.5,-height,width,height),region)
	c.draw_texture_rect_region(_return_atlas,Rect2(-width*.5,-height,width,height),region,tint)

static func barrier(c: CanvasItem,start: float,width: float,height := 48.0,tint := Color.WHITE) -> void:
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _return_atlas==null: _return_atlas = load(RETURN_ATLAS_PATH)
	if _return_atlas==null: return
	var region: Rect2 = RETURN_REGIONS.barrier
	var module_width := region.size.x/region.size.y*height
	var x := start
	while x<start+width:
		var part_width := minf(module_width,start+width-x)
		c.draw_texture_rect_region(_return_atlas,Rect2(x,-height*.5,part_width,height),Rect2(region.position,Vector2(region.size.x*part_width/module_width,region.size.y)),tint)
		x+=module_width

static func story(c: CanvasItem,key: String,height: float) -> void:
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _story_atlas==null: _story_atlas = load(STORY_ATLAS_PATH)
	if _story_atlas==null: return
	var region: Rect2 = STORY_REGIONS[key]
	var width := region.size.x/region.size.y*height
	_ground_bitmap(c,_story_atlas,Rect2(-width*.5,-height,width,height),region)
	c.draw_texture_rect_region(_story_atlas,Rect2(-width*.5,-height,width,height),region)

static func muted_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = DESATURATE
	return material

static func _bitmap(c: CanvasItem,key: String,height: float,tint := Color.WHITE) -> bool:
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _atlas==null: _atlas = load(ATLAS_PATH)
	if _atlas==null: return false
	var region: Rect2 = REGIONS[key]
	var width := region.size.x/region.size.y*height
	_ground_bitmap(c,_atlas,Rect2(-width*.5,-height,width,height),region)
	c.draw_texture_rect_region(_atlas,Rect2(-width*.5,-height,width,height),region,tint)
	return true

static func _ground_bitmap(c: CanvasItem,texture: Texture2D,rect: Rect2,region := Rect2()) -> void:
	var source := texture
	if region.has_area():
		var key := "%s:%s" % [texture.resource_path,region]
		if not _ground_sources.has(key):
			var part := AtlasTexture.new()
			part.atlas = texture
			part.region = region
			_ground_sources[key] = part
		source = _ground_sources[key]
	var row := Grounding.silhouette(source,roundi(rect.size.x),roundi(rect.size.y))
	Grounding.draw_prop(c,row,rect.position,rect.size.x)

static func signpost(canvas: CanvasItem,style := "normal") -> void:
	if _sign==null: _sign = load(SIGN_PATH)
	_ground_bitmap(canvas,_sign,Rect2(-46,-94,92,96))
	var tint := Color("bfc6c5") if style=="sealed" else (Color("ffefbb") if style=="restored" else Color.WHITE)
	canvas.draw_texture_rect(_sign,Rect2(-46,-94,92,96),false,tint)
	if style=="restored":
		canvas.draw_rect(Rect2(6,-36,4,18),Color("b94d3c"))
		canvas.draw_rect(Rect2(7,-36,1,16),Color("f2be72"))

static func shadow(c: CanvasItem,r := 25.0) -> void:
	c.draw_set_transform(Vector2(3,5),0,Vector2(1,.25))
	c.draw_circle(Vector2.ZERO,r,Color("14241f",.23))
	c.draw_set_transform(Vector2.ZERO)

static func marker(c: CanvasItem,at: Vector2,hue: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-8),at+Vector2(5,0),at+Vector2(0,8),at+Vector2(-5,0)]),hue.darkened(.30))
	c.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-7),at+Vector2(0,1),at+Vector2(-4,0)]),hue.lightened(.30))
	c.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-7),at+Vector2(4,0),at+Vector2(0,6)]),hue)
	c.draw_rect(Rect2(at+Vector2(-1,11),Vector2(2,2)),hue.lightened(.2))

static func vein(c: CanvasItem,used := false) -> void:
	if _bitmap(c,"vein",44,Color("788b8f") if used else Color.WHITE): return
	shadow(c,27)
	var stone := PackedVector2Array([Vector2(-25,5),Vector2(-22,-9),Vector2(-12,-18),Vector2(7,-22),Vector2(24,-7),Vector2(27,5),Vector2(17,12),Vector2(-17,12)])
	c.draw_colored_polygon(stone,Color("343f47"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(-22,-7),Vector2(-12,-16),Vector2(7,-19),Vector2(10,-5),Vector2(-10,3)]),Color("879397"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(10,-5),Vector2(7,-19),Vector2(23,-6),Vector2(23,5),Vector2(5,9)]),Color("536a75"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(-22,-7),Vector2(-10,3),Vector2(5,9),Vector2(-17,9),Vector2(-22,4)]),Color("627378"))
	for point in [Vector2(-14,-10),Vector2(0,-13),Vector2(13,-4)]:
		var tint := Color("536b74") if used else Color("72c8df")
		var crystal := PackedVector2Array([point+Vector2(-3,5),point+Vector2(-4,-3),point+Vector2(1,-9),point+Vector2(5,-4),point+Vector2(4,5)])
		c.draw_colored_polygon(crystal,tint.darkened(.40))
		c.draw_colored_polygon(PackedVector2Array([point+Vector2(-3,3),point+Vector2(-2,-3),point+Vector2(1,-7),point+Vector2(1,3)]),tint.lightened(.18))
		c.draw_line(point+Vector2(1,-7),point+Vector2(3,-3),Color("d6f4ec") if not used else tint,1)
	for p in [Vector2(-19,5),Vector2(12,7),Vector2(-3,3)]: c.draw_rect(Rect2(p,Vector2(3,2)),Color("a5afa1"))

static func altar(c: CanvasItem,used := false) -> void:
	if _bitmap(c,"altar",72,Color("7b858a") if used else Color.WHITE): return
	shadow(c,28)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-23,7),Vector2(-17,2),Vector2(18,2),Vector2(24,8),Vector2(18,15),Vector2(-20,15)]),Color("41474e"))
	c.draw_rect(Rect2(-19,5,38,5),Color("919391"))
	c.draw_rect(Rect2(-16,-38,32,43),Color("454957"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(-15,4),Vector2(-15,-35),Vector2(-11,-42),Vector2(11,-42),Vector2(15,-35),Vector2(15,4)]),Color("7c8492"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(-15,-35),Vector2(-11,-42),Vector2(11,-42),Vector2(14,-36)]),Color("b8b9ad"))
	c.draw_rect(Rect2(-11,-33,22,32),Color("535f6d"))
	var hue := Color("72878c") if used else Color("a2ded9")
	c.draw_polyline(PackedVector2Array([Vector2(-5,-26),Vector2(0,-31),Vector2(5,-26),Vector2(0,-21),Vector2(-5,-26)]),hue,2)
	c.draw_line(Vector2(0,-21),Vector2(0,-8),hue,2)
	for y in [-17,-11]: c.draw_line(Vector2(-5,y),Vector2(5,y),hue.darkened(.2),1)
	c.draw_polyline(PackedVector2Array([Vector2(9,-37),Vector2(6,-31),Vector2(9,-25)]),Color("313f4a"),1)
	c.draw_rect(Rect2(-20,7,7,3),Color("75946c"))
	if not used: marker(c,Vector2(0,-53),Color("85e5e7"))

static func chest(c: CanvasItem) -> void:
	if _bitmap(c,"chest",42): return
	shadow(c,28)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-24,-22),Vector2(-19,-29),Vector2(19,-29),Vector2(24,-22),Vector2(24,5),Vector2(-24,5)]),Color("362b25"))
	c.draw_rect(Rect2(-21,-20,42,23),Color("865737"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(-21,-22),Vector2(-17,-27),Vector2(17,-27),Vector2(21,-22),Vector2(21,-17),Vector2(-21,-17)]),Color("c0945d"))
	c.draw_rect(Rect2(-21,-17,42,2),Color("4b3428"))
	for x in [-16,12]:
		c.draw_rect(Rect2(x,-27,4,30),Color("534e46"))
		c.draw_rect(Rect2(x,-25,2,26),Color("c2b18a"))
		for y in [-22,-7,0]: c.draw_rect(Rect2(x+1,y,1,1),Color("eee0b3"))
	for y in [-11,-4]: c.draw_line(Vector2(-10,y),Vector2(10,y+1),Color("a47649"),1)
	c.draw_rect(Rect2(-5,-20,10,12),Color("e0b66b"))
	c.draw_rect(Rect2(-3,-17,6,6),Color("8e6039"))
	c.draw_rect(Rect2(-1,-16,2,3),Color("302d29"))
	c.draw_line(Vector2(-19,2),Vector2(19,2),Color("b99156"),1)

static func herb(c: CanvasItem) -> void:
	if _bitmap(c,"herb",44): return
	shadow(c,20)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-19,4),Vector2(-11,-2),Vector2(12,-2),Vector2(20,5),Vector2(10,12),Vector2(-14,10)]),Color("6d5a3c"))
	c.draw_line(Vector2(-12,2),Vector2(9,9),Color("b29463"),2)
	for row in [[Vector2(-2,3),Vector2(-22,-15)],[Vector2(1,0),Vector2(-8,-30)],[Vector2(3,2),Vector2(20,-21)],[Vector2(3,3),Vector2(27,-7)]]:
		var a: Vector2 = row[0]
		var b: Vector2 = row[1]
		var side := (b-a).orthogonal().normalized()*4
		c.draw_colored_polygon(PackedVector2Array([a,(a+b)*.5+side,b,(a+b)*.5-side]),Color("426c46"))
		c.draw_line(a,b,Color("a9c776"),1)
		c.draw_line((a+b)*.5,b,Color("709b52"),2)
	for p in [Vector2(-12,7),Vector2(4,8),Vector2(15,5)]: c.draw_rect(Rect2(p,Vector2(3,2)),Color("a89362"))
	c.draw_line(Vector2(-4,5),Vector2(-11,15),Color("c1a474"),1)
	c.draw_line(Vector2(2,6),Vector2(10,15),Color("947c50"),1)

static func post(c: CanvasItem) -> void:
	if _bitmap(c,"post",80): return
	shadow(c,27)
	c.draw_rect(Rect2(-5,-57,10,62),Color("47382b"))
	c.draw_rect(Rect2(-4,-56,4,60),Color("9c7851"))
	for y in [-39,-7]:
		c.draw_rect(Rect2(-6,y,12,5),Color("565958"))
		c.draw_line(Vector2(-5,y),Vector2(5,y),Color("aaa58a"),1)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-33,-51),Vector2(-20,-64),Vector2(21,-64),Vector2(34,-51),Vector2(28,-47),Vector2(-29,-47)]),Color("3c464d"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(-29,-53),Vector2(-19,-62),Vector2(20,-62),Vector2(29,-53)]),Color("81918b"))
	for x in [-20,-10,0,10,20]: c.draw_line(Vector2(x,-59),Vector2(x+5,-53),Color("c0bda5"),1)
	c.draw_line(Vector2(-29,-50),Vector2(29,-50),Color("bba16b"),2)
	c.draw_colored_polygon(PackedVector2Array([Vector2(5,-47),Vector2(22,-47),Vector2(22,-18),Vector2(17,-21),Vector2(12,-17),Vector2(5,-20)]),Color("324854"))
	c.draw_rect(Rect2(6,-45,3,25),Color("a28a57"))
	c.draw_line(Vector2(12,-37),Vector2(19,-37),Color("e1c993"),2)
	c.draw_line(Vector2(13,-34),Vector2(17,-28),Color("cfb481"),2)

static func chime(c: CanvasItem,sway := 0.0) -> void:
	if _bitmap(c,"chime",62): return
	c.draw_polyline(PackedVector2Array([Vector2(-20,-49),Vector2(-11,-46),Vector2(8,-47),Vector2(19,-42)]),Color("523e2e"),4)
	c.draw_line(Vector2(-17,-48),Vector2(5,-47),Color("ae8b5f"),1)
	c.draw_line(Vector2(0,-47),Vector2(sway,-34),Color("bda77e"),1)
	c.draw_set_transform(Vector2(roundf(sway),0))
	c.draw_colored_polygon(PackedVector2Array([Vector2(-5,-34),Vector2(5,-34),Vector2(7,-29),Vector2(10,-17),Vector2(13,-14),Vector2(-13,-14),Vector2(-10,-17),Vector2(-7,-29)]),Color("514c3a"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(-4,-33),Vector2(4,-33),Vector2(6,-27),Vector2(9,-17),Vector2(-9,-17),Vector2(-6,-27)]),Color("b99b5d"))
	c.draw_line(Vector2(-4,-31),Vector2(-7,-19),Color("f0d59b"),2)
	c.draw_rect(Rect2(-11,-17,22,3),Color("e5c381"))
	c.draw_rect(Rect2(-12,-14,24,2),Color("7b6b43"))
	c.draw_line(Vector2(0,-12),Vector2(0,-7),Color("bda373"),2)
	c.draw_rect(Rect2(-2,-7,4,3),Color("665845"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(-2,-3),Vector2(7,-3),Vector2(5,10),Vector2(-1,7)]),Color("5f9f9a"))
	c.draw_line(Vector2(0,-1),Vector2(3,6),Color("b7d9bd"),1)
	c.draw_set_transform(Vector2.ZERO)

static func vent(c: CanvasItem) -> void:
	if _bitmap(c,"vent",70): return
	shadow(c,30)
	c.draw_rect(Rect2(-26,-20,52,24),Color("344450"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(-26,-20),Vector2(-20,-26),Vector2(21,-26),Vector2(26,-20)]),Color("7b9092"))
	for x in range(-20,21,8): c.draw_rect(Rect2(x,-14,4,11),Color("172e39"))
	c.draw_circle(Vector2(0,-42),23,Color("343f46"))
	c.draw_arc(Vector2(0,-42),21,0,TAU,24,Color("c6aa71"),4)
	c.draw_arc(Vector2(0,-42),16,0,TAU,24,Color("7b7160"),2)
	for i in 4:
		var a := i*TAU/4+.25
		var tip := Vector2(0,-42)+Vector2.from_angle(a)*15
		c.draw_colored_polygon(PackedVector2Array([Vector2(0,-42),tip,tip+Vector2.from_angle(a+1.3)*7]),Color("708b8e"))
	c.draw_circle(Vector2(0,-42),4,Color("e1c98e"))
	for x in [-22,20]: c.draw_rect(Rect2(x,-18,2,2),Color("d9c995"))

static func flag(c: CanvasItem,at: Vector2,hue: Color) -> void:
	c.draw_set_transform(at)
	c.draw_rect(Rect2(-4,-78,8,83),Color("413a32"))
	c.draw_rect(Rect2(-3,-76,3,79),Color("a99265"))
	c.draw_rect(Rect2(-5,-80,10,5),Color("dfc88e"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(3,-72),Vector2(27,-72),Vector2(29,-45),Vector2(25,-36),Vector2(19,-40),Vector2(11,-34),Vector2(3,-37)]),hue.darkened(.25))
	c.draw_colored_polygon(PackedVector2Array([Vector2(5,-70),Vector2(24,-70),Vector2(25,-47),Vector2(19,-43),Vector2(11,-40),Vector2(5,-43)]),hue)
	c.draw_rect(Rect2(5,-70,3,28),Color("e0c792"))
	c.draw_polyline(PackedVector2Array([Vector2(12,-59),Vector2(17,-64),Vector2(22,-59),Vector2(17,-53),Vector2(12,-59)]),Color("f2e5bc"),2)
	c.draw_line(Vector2(17,-53),Vector2(17,-46),Color("edd9a2"),2)
	for y in [-67,-39]: c.draw_line(Vector2(-5,y),Vector2(5,y),Color("6e8e92"),2)
	c.draw_set_transform(Vector2.ZERO)

static func signal_flags(c: CanvasItem) -> void:
	if _bitmap(c,"flags",84): return
	flag(c,Vector2(-26,0),Color("c9b477"))
	flag(c,Vector2(26,0),Color("83bfc6"))
