extends Node2D

const Art := preload("res://src/world/AssetCompletion.gd")
const WorldPropArt := preload("res://src/world/WorldPropArt.gd")

var _signature := ""
var _wait := 0.0
var flat_floor := false

func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = 0.25
	var flags: Dictionary = G.prog.get("flags", {})
	var parts := PackedStringArray()
	for k in [
		"act1_stele_rooms_v1", "act1_stele_clue",
		"act1_echo_crack_left", "act1_echo_crack_middle", "act1_echo_crack_right",
		"act1_stele_seat_1", "act1_stele_shadow_decided", "act1_stele_shadow_defeated",
		"act1_stele_shadow_avoided", "act1_stele_seat_2"
	]:
		parts.append(str(flags.get(k, false)))
	var signature := "|".join(parts) + "|" + String(G.story_current().get("id", ""))
	if signature != _signature:
		_signature = signature
		queue_redraw()

func _draw() -> void:
	texture_filter = preload("res://src/world/WorldPresentation.gd").sampling()
	if not flat_floor:
		_draw_floor()
	_draw_state()

func _draw_floor() -> void:
	# 三处石缝围着听声堂，侧壁碑座围着回响庭，北端收束到碑心。
	# 墙面为地形底图，通行与机关碰撞仍由原场景统一控制。
	draw_rect(Rect2(0, 0, 960, 1248), Color("232b32"))
	var rooms := [Rect2(160, 795, 640, 350), Rect2(210, 555, 540, 175), Rect2(260, 125, 440, 345)]
	for room in rooms:
		draw_rect(room.grow(18), Color("4c5254"))
		draw_rect(room.grow(8), Color("777269"))
		draw_rect(room, Color("3b4549"))
		var row_index := 0
		for y in range(int(room.position.y), int(room.end.y), 40):
			for x in range(int(room.position.x), int(room.end.x), 72):
				var offset := 0 if row_index % 2 == 0 else 28
				var tile := Rect2(x + offset, y, 68, 36).intersection(room)
				draw_rect(tile, Color("465054") if (x / 72 + row_index) % 3 != 0 else Color("4f5654"))
				draw_line(tile.position, tile.position + Vector2(tile.size.x, 0), Color("626a67"), 1)
			row_index += 1
	for connector in [Rect2(405, 700, 150, 125), Rect2(405, 440, 150, 145), Rect2(405, 1120, 150, 128)]:
		draw_rect(connector, Color("555c58"))
		for y in range(int(connector.position.y), int(connector.end.y), 26):
			draw_line(Vector2(connector.position.x, y), Vector2(connector.end.x, y), Color("788075"), 2)

func _draw_state() -> void:
	var flags: Dictionary = G.prog.get("flags", {})
	var heard := bool(flags.get("act1_stele_clue", false))
	var seat1 := bool(flags.get("act1_stele_seat_1", false))
	var seat2 := bool(flags.get("act1_stele_seat_2", false))
	var rooms_v1 := bool(flags.get("act1_stele_rooms_v1", false)) or String(G.story_current().get("id", "")) == "s09"
	var room1_ready := heard and (not rooms_v1 or (
		bool(flags.get("act1_echo_crack_left", false))
		and bool(flags.get("act1_echo_crack_middle", false))
		and bool(flags.get("act1_echo_crack_right", false))
	))
	var shadow_resolved := not rooms_v1 or bool(flags.get("act1_stele_shadow_avoided", false)) or bool(flags.get("act1_stele_shadow_defeated", false))

	# 1. 听声堂三处石缝：像素石隙与导音刻槽
	var crack_rows := [
		[Vector2(210, 940), bool(flags.get("act1_echo_crack_left", false))],
		[Vector2(480, 955), bool(flags.get("act1_echo_crack_middle", false))],
		[Vector2(750, 940), bool(flags.get("act1_echo_crack_right", false))],
	]
	for row in crack_rows:
		var at: Vector2 = row[0]
		var done: bool = row[1] or heard
		_draw_stone_fissure(at, done)

	# 2. 回响庭导音石渠：连接西侧「辨声碑座」→ 中廊 → 东侧「定向碑座」→ 北门碑心
	var west_at := Vector2(315, 680)
	var mid_at := Vector2(480, 635)
	var east_at := Vector2(650, 610)
	var gate_at := Vector2(480, 540)
	_draw_rune_channel([west_at + Vector2(28, -4), Vector2(410, 680), mid_at], seat1)
	_draw_rune_channel([mid_at, Vector2(565, 610), east_at + Vector2(-28, -4)], seat1 and shadow_resolved)
	_draw_rune_channel([east_at + Vector2(0, -24), Vector2(650, 565), gate_at], seat2)

	# 3. 回响庭左右两处碑座（替换原本突兀的几何圆圈为像素石雕碑座 + 碑体 + 状态铭文）
	var west_entity_spawned := room1_ready and not seat1
	var east_entity_spawned := seat1 and shadow_resolved and not seat2
	var west_status := "辨声碑座 · 已归位" if seat1 else ("辨声碑座" if west_entity_spawned else "辨声碑座 · 待拓片引声")
	var east_status := "定向碑座 · 已归位" if seat2 else ("定向碑座" if east_entity_spawned else "定向碑座 · 待前座共鸣")
	_draw_stele_seat(west_at, seat1, west_entity_spawned, west_status)
	_draw_stele_seat(east_at, seat2, east_entity_spawned, east_status)

	# 4. 北端碑心台：八方古石铭文阵盘
	var heart := Vector2(480, 315)
	_draw_heart_dais(heart, seat2)

	# 5. 四壁共鸣石灯柱（像素石柱，替代原先突兀的纯色方块）
	for at in [Vector2(187, 1080), Vector2(773, 1080), Vector2(235, 705), Vector2(725, 705), Vector2(282, 450), Vector2(678, 450)]:
		_draw_wall_brazier(at, heard or seat1)

func _draw_stone_fissure(at: Vector2, active: bool) -> void:
	Art.centered(self, "ground_fissure", at, 56, Color("b7d7d1") if active else Color.WHITE)

func _draw_rune_channel(pts: Array, lit: bool) -> void:
	Art.channel(self, pts, lit)

func _draw_stele_seat(at: Vector2, calibrated: bool, entity_active: bool, status_text: String) -> void:
	Art.centered(self, "rune_dais", at + Vector2(0,5), 76,
		Color("c9e8de") if calibrated else Color("898e91"))
	# Interactive entities still own their body and trigger while they are present.
	if not entity_active:
		draw_set_transform(at, 0.0, Vector2(.92,.92))
		WorldPropArt.altar(self, not calibrated)
		draw_set_transform(Vector2.ZERO)
		if G.font_bold != null and not status_text.is_empty():
			var fs := 12
			var tw := G.font_bold.get_string_size(status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var tag_rect := Rect2(at.x-tw*.5-6, at.y+22, tw+12, 18)
			draw_rect(tag_rect, Color("141b1d",.82))
			draw_rect(tag_rect, Color("86e3de",.55) if calibrated else Color("8b8570",.45), false, 1)
			draw_string(G.font_bold, Vector2(at.x-tw*.5,at.y+35),status_text,
				HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color("b8f2ee") if calibrated else Color("cbbd9d"))

func _draw_heart_dais(heart: Vector2, aligned: bool) -> void:
	Art.centered(self, "rune_dais", heart, 136, Color("c9e8de") if aligned else Color("788386"))

func _draw_wall_brazier(at: Vector2, lit: bool) -> void:
	Art.prop(self, "lantern", at+Vector2(0,10), 40, Color.WHITE if lit else Color("626b6b"))
