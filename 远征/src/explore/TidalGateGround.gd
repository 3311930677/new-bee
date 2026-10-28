class_name TidalGateGround
extends Node2D
const Art := preload("res://src/world/AssetCompletion.gd")
const Surface := preload("res://src/explore/TerrainSurface.gd")

# 水闸战场的双侧水道、闸墙和退潮石道；中央保持首领战可走空间。
var dynamic_water := false
var upper_released := false
var bridge_drained := false
var passages := "sealed"
var flat_floor := false

func _draw() -> void:
	if bool(get_meta("illustrated_floor", false)):
		_draw_illustrated_state()
		return
	for side in [0, 1]:
		var x := 0.0 if side == 0 else 610.0
		if not flat_floor:
			preload("res://src/explore/TerrainSurface.gd").tiled(self,
				"res://image/main_world/shenyuan_port_ground_reference_v2.png",
				Rect2(x, 0, 350, 1248), Vector2(175, 220), Color("89b2bb"), Rect2(12, 120, 270, 320))
		for y in range(65, 1200, 78):
			draw_line(Vector2(x + 35, y), Vector2(x + 245, y - 13),
				Color("95bfc0", 0.6), 2)
		if dynamic_water:
			var water_top := 750.0 if not upper_released else 900.0
			draw_rect(Rect2(x + 25, water_top, 265, 1248.0 - water_top),
				Color("347b8b", 0.35 if not upper_released else 0.52))
			draw_line(Vector2(x + 25, water_top), Vector2(x + 290, water_top),
				Color("bbebe0", 0.8), 4)
		draw_rect(Rect2(332 if side == 0 else 610, 0, 18, 1248), Color("74777a"))
	# 中段积水随两道闸线退去，露出可穿行的石板；无现实计时依赖。
	if dynamic_water and not bridge_drained:
		draw_rect(Rect2(350, 485, 260, 63), Color("438d9a", 0.5))
		for y in [504.0, 530.0]:
			draw_line(Vector2(355, y), Vector2(605, y), Color("c5e7de", 0.75), 2)
	elif dynamic_water:
		if passages in ["bridge", "both"]:
			draw_rect(Rect2(365, 485, 100, 63), Color("838f8c", 0.8))
			for x in [382.0, 414.0, 446.0]:
				draw_line(Vector2(x, 488), Vector2(x, 545), Color("596b67"), 3)
		if passages in ["cargo", "both"]:
			draw_rect(Rect2(495, 485, 100, 63), Color("9a927e", 0.8))
			for x in [515.0, 548.0, 580.0]:
				draw_line(Vector2(x, 489), Vector2(x, 545), Color("687065"), 3)
	# 两侧货物与水线一起变化；箱脚落在石道上，补给实体浮在其前方。
	if dynamic_water:
		_draw_supply_cache(Vector2(408, 625), false, passages in ["bridge", "both"])
		_draw_supply_cache(Vector2(555, 625), true, passages in ["cargo", "both"])
	for y in range(0, 1248, 64):
		draw_line(Vector2(350, y), Vector2(610, y), Color("68757a", 0.38), 2)
	for x in [365.0, 595.0]:
		draw_rect(Rect2(x - 17, 245, 34, 130), Color("565d61"))
		draw_rect(Rect2(x - 25, 237, 50, 16), Color("929799"))
		draw_circle(Vector2(x, 312), 12, Color("b3a57e"))
	# 上方横闸与悬挂的铁链，不遮住中央首领脚点。
	draw_rect(Rect2(350, 175, 260, 34), Color("4b5358"))
	for x in [380.0, 480.0, 580.0]:
		draw_line(Vector2(x, 210), Vector2(x, 268), Color("9a9277"), 4)


func _draw_illustrated_state() -> void:
	if not dynamic_water: return
	if not bridge_drained:
		draw_texture_rect(Art.texture("shallow_flood"),Rect2(350,485,260,63),false,Color(1,1,1,.8))
	else:
		if passages in ["bridge","both"]:
			_draw_dry_passage(Rect2(365,485,100,63),Color("bdc5c0"))
		if passages in ["cargo","both"]:
			_draw_dry_passage(Rect2(495,485,100,63),Color("c7b995"))
	var level := 900.0 if upper_released else 750.0
	for x in [25.0,670.0]:
		draw_texture_rect(Art.texture("shallow_flood"),Rect2(x,level-8,265,28),false,Color(.9,1,1,.5))
	_draw_supply_cache(Vector2(408,625),false,passages in ["bridge","both"])
	_draw_supply_cache(Vector2(555,625),true,passages in ["cargo","both"])

func _draw_dry_passage(rect: Rect2, tone: Color) -> void:
	# A worn deck section makes the open lane visible without a flat painted block.
	draw_texture_rect(Art.texture("bridge_planks"),rect.grow(-3),false,tone)

func _draw_supply_cache(at: Vector2, cargo: bool, dry: bool) -> void:
	Art.prop(self,"tide_cargo" if cargo else "supply_sack",at+Vector2(0,22),
		52 if cargo else 48,Color.WHITE if dry else Color("7b9695"))
