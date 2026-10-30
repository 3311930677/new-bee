extends Node2D

# The three rooms share a carved basalt floor; symbols show the saved mechanism state.
const Surface := preload("res://src/explore/TerrainSurface.gd")
const Art := preload("res://src/world/AssetCompletion.gd")
var map_id := ""
var _flags := ""
var flat_floor := false

func _process(_delta: float) -> void:
	var value := JSON.stringify(G.prog.get("flags", {}))
	if value != _flags or map_id == "stele_resonance":
		_flags = value
		queue_redraw()

func _draw() -> void:
	if not flat_floor:
		Surface.tiled(self, "res://image/map_proc/011_tile_tomb_2.png", Rect2(180, 64, 600, 1120), Vector2(96, 96), Color("7e8791"))
		Surface.tiled(self, "res://image/map_proc/011_tile_tomb_2.png", Rect2(404, 80, 152, 1080), Vector2(76, 76), Color("b5b7af"))
	if not bool(get_meta("illustrated_floor", false)):
		_draw_legacy_trim()
	match map_id:
		"stele_entry":
			_seal(Vector2(480, 625), 80, "act4_return_anchor", Color("9adad0"))
			for y in [360.0, 895.0]:
				Art.centered(self, "rune_dais", Vector2(480,y), 88, Color("777b82"))
		"stele_resonance":
			var flags_d: Dictionary = G.prog.get("flags", {})
			var aligned := bool(flags_d.get("act4_voices_aligned", false))
			var v1 := bool(flags_d.get("act4_forest_voice", false)) or aligned
			var v2 := bool(flags_d.get("act4_tide_voice", false)) or aligned
			var v3 := bool(flags_d.get("act4_snow_voice", false)) or aligned
			Art.channel(self, [Vector2(480, 880), Vector2(480, 625)], v1, Color("93bf95"))
			Art.channel(self, [Vector2(480, 625), Vector2(480, 375)], v1 and v2, Color("82bacb"))
			Art.channel(self, [Vector2(480, 375), Vector2(480, 266)], aligned or (v1 and v2 and v3), Color("bca6da"))
			for row in [[Vector2(335,880),"act4_forest_voice",Color("93bf95")],
				[Vector2(625,625),"act4_tide_voice",Color("82bacb")],
				[Vector2(335,375),"act4_snow_voice",Color("d1dceb")]]:
				var lit := bool(flags_d.get(row[1],false)) or aligned
				var edge_x := float(row[0].x) + (32.0 if float(row[0].x) < 480.0 else -32.0)
				Art.channel(self, [Vector2(edge_x, row[0].y), Vector2(480, row[0].y)], lit, row[2])
				Art.channel_junction(self, Vector2(480, row[0].y), lit, row[2], "t")
				_seal(row[0], 40, row[1], row[2])
			_seal(Vector2(480,230), 72, "act4_voices_aligned", Color("bca6da"))
		"stele_core":
			_seal(Vector2(480,570), 160, "act4_avatar_down", Color("a4d9d1"))
			for i in 3:
				var angle := TAU * i / 3.0 - PI / 2
				var p := Vector2(480,570) + Vector2(cos(angle),sin(angle)) * 133
				Art.prop(self, "rune_stone", p + Vector2(0,8), 32, [Color("93bf95"),Color("82bacb"),Color("d1dceb")][i])

func _draw_legacy_trim() -> void:
	for x in [196.0, 762.0]:
		for y in range(64, 1190, 96):
			draw_rect(Rect2(x, y, 12, 86), Color("28313e"))
			draw_line(Vector2(x + 3, y + 4), Vector2(x + 3, y + 82), Color("616876"), 2)
	for y in [275.0, 525.0, 775.0, 1025.0]:
		if not flat_floor:
			for x in [245.0, 715.0]: _pillar(Vector2(x, y))
	for y in range(140, 1150, 112):
		draw_line(Vector2(429, y), Vector2(453, y), Color("c6ae71"), 3)
		draw_line(Vector2(507, y), Vector2(531, y), Color("c6ae71"), 3)

func _pillar(p: Vector2) -> void:
	draw_set_transform(p + Vector2(8,8),0,Vector2(1,.36))
	draw_circle(Vector2.ZERO,31,Color(0,0,0,.3))
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	draw_rect(Rect2(p-Vector2(24,72),Vector2(48,78)),Color("303a48"))
	draw_rect(Rect2(p-Vector2(18,70),Vector2(13,68)),Color("68727b"))
	draw_rect(Rect2(p-Vector2(30,79),Vector2(60,12)),Color("8a918e"))
	draw_rect(Rect2(p-Vector2(30,4),Vector2(60,12)),Color("5b6672"))
	draw_line(p+Vector2(5,-58),p+Vector2(9,-35),Color("b5a87d"),3)

func _seal(p: Vector2, radius: float, flag: String, color: Color) -> void:
	var lit := bool(G.prog.get("flags",{}).get(flag,false))
	Art.centered(self, "rune_dais", p, radius*2.0, color.lightened(.22) if lit else Color("727b87"))
