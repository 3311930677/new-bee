extends Node2D
## 在线世界独立于单机 MapScene；角色与战斗只接受服务端快照。

const Art := preload("res://src/world/ReferenceWorldArt.gd")
const Field := preload("res://src/ui/FieldUI.gd")
const BattlePage := preload("res://src/ui/OnlineBattle.tscn")
const Profile := preload("res://src/online/OnlineProfile.gd")
const JourneyPanel := preload("res://src/ui/OnlineJourneyPanel.gd")
const SocialPanel := preload("res://src/ui/OnlineSocialPanel.gd")
const CoopPanel := preload("res://src/ui/OnlineCoopPanel.gd")
const MarketPanel := preload("res://src/ui/OnlineMarketPanel.gd")
const GuildPanel := preload("res://src/ui/OnlineGuildPanel.gd")
const PvpPanel := preload("res://src/ui/OnlinePvpPanel.gd")
const PositionStream := preload("res://src/online/WorldPositionStream.gd")

var auto_connect := true
var automatic_poll := true
var lease: Dictionary = {}
var entities: Array = []
var battle: Dictionary = {}
var _floor: Sprite2D
var _rendered_map_id := ""
var _map_props: Array[Node] = []
var _portals: Array = []
var _npcs: Array = []
var _channels: Array = []
var _map_name := "昭元边城"
var _current_channel := 1
var _channels_panel: Control
var _social_panel: Control
var _coop_panel: Control
var _market_panel: Control
var _guild_panel: Control
var _pvp_panel: Control
var _coop_instance_id := ""
var _world := Node2D.new()
var _actors: Dictionary = {}
var _camera := Camera2D.new()
var _hud: Control
var _status: Label
var _town_label: Label
var _battle_page: Control
var _challenge_button: Control
var _encounters: Dictionary = {}
var _busy := false
var _poll_elapsed := 0.0
var _move_elapsed := 0.0
var _held := Vector2.ZERO
var _connected := false
var _profiles: Control
var _journey_panel: Control
var _journey: Dictionary = {}
var _journey_marker: Node2D
var _marker_key := ""
var _positions: PositionStream
var _position_tick := 0
var _positions_last := -10000
var _positions_retry_at := 0
var _player_draw_target := Vector2.ZERO
var _player_draw_ready := false


func _ready() -> void:
	_world.y_sort_enabled = true
	add_child(_world)
	_floor = Sprite2D.new()
	_floor.centered = false
	_floor.z_index = -10
	add_child(_floor)
	_render_map("lorin_wilds")
	_camera.position = Vector2(600, 1520)
	_camera.enabled = true
	add_child(_camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)
	var top := Field.surface(Vector2(12, 12), Vector2(456, 104))
	_hud.add_child(top)
	_town_label = Field.label("昭元边城 · 结伴远征", Vector2(28, 18), Vector2(420, 32), G.FS_MD, G.PARCHMENT, true)
	_hud.add_child(_town_label)
	_status = Field.label("正在进入城镇……", Vector2(28, 52), Vector2(420, 54), G.FS_SM, G.PARCHMENT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.add_child(_status)
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 16
	bottom.offset_right = -16
	bottom.offset_top = -236
	bottom.offset_bottom = -16
	bottom.add_theme_constant_override("separation", 6)
	_hud.add_child(bottom)
	_challenge_button = _button(bottom, "城南试炼 · 靠近野狼后挑战", _perform_journey_action)
	var arrows := HBoxContainer.new()
	arrows.add_theme_constant_override("separation", 8)
	bottom.add_child(arrows)
	for entry in [["←", Vector2.LEFT], ["↑", Vector2.UP], ["↓", Vector2.DOWN], ["→", Vector2.RIGHT]]:
		var arrow := _button(arrows, String(entry[0]), func() -> void: pass)
		var direction: Vector2 = entry[1]
		arrow.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				_held = direction if event.pressed else Vector2.ZERO
				arrow.accept_event())
		arrow.mouse_exited.connect(func() -> void: _held = Vector2.ZERO)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	bottom.add_child(actions)
	_button(actions, "同行名片", _open_profiles)
	if Online.manifest.get("features", []).has("world_channels"):
		_button(actions, "分线", _open_channels)
	if Online.manifest.get("features", []).has("social_chat"):
		_button(actions, "社交", open_social)
	if Online.manifest.get("features", []).has("coop_dungeons"):
		_button(actions, "副本", open_coop)
	var actions2 := HBoxContainer.new()
	actions2.add_theme_constant_override("separation", 6)
	bottom.add_child(actions2)
	if Online.manifest.get("features", []).has("market_sandbox"):
		_button(actions2, "集市", open_market)
	if Online.manifest.get("features", []).has("guilds"):
		_button(actions2, "帮派", open_guild)
	if Online.manifest.get("features", []).has("pvp_arena"):
		_button(actions2, "演武", open_pvp)
	if Online.manifest.get("features", []).has("town_journey"):
		_button(actions2, "行囊", open_journey)
	_button(actions2, "返回角色", _back)
	if auto_connect:
		call_deferred("enter_world")


func _button(parent: Control, words: String, action: Callable) -> Control:
	var button := G.ghost_button(words, 0, 50, G.FS_MD)
	button.custom_minimum_size.y = 50
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.gui_input.connect(func(event: InputEvent) -> void:
		if G.ui_blocked:
			return
		if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or event.is_action_pressed("ui_accept"):
			button.accept_event()
			action.call())
	parent.add_child(button)
	return button


func enter_world() -> Dictionary:
	if _busy:
		return {"ok": false, "code": "busy"}
	_busy = true
	var result: Dictionary = await Online.join_world()
	if bool(result.get("ok", false)):
		result = await Online.world_snapshot()
		if bool(result.get("ok", false)):
			_apply_world(result.data)
			_connected = true
			result = await Online.active_battle()
			if bool(result.get("ok", false)):
				_present_battle(result.data.get("battle"))
	_show_error(result)
	_busy = false
	return result


func refresh_world() -> Dictionary:
	if _busy:
		return {"ok": false, "code": "busy"}
	_busy = true
	var result: Dictionary = await Online.world_snapshot()
	if bool(result.get("ok", false)):
		_apply_world(result.data)
	_show_error(result)
	_busy = false
	return result


func _apply_world(data: Dictionary) -> void:
	var current := data.get("lease", {}) as Dictionary
	var new_lease: bool = current.get("room_id") != lease.get("room_id") or current.get("generation") != lease.get("generation")
	if new_lease:
		_close_positions()
	lease = current.duplicate(true)
	var map_info: Dictionary = data.get("map", {}) as Dictionary
	var map_id := String(lease.get("map_id", "lorin_wilds"))
	if not String(map_info.get("name", "")).is_empty():
		_map_name = String(map_info.get("name"))
	else:
		var cfg_map := TableCache.main_world_map(map_id)
		_map_name = String(cfg_map.get("name", "昭元边城"))
	_channels = (data.get("channels", []) as Array).duplicate(true)
	for ch in _channels:
		if ch is Dictionary and bool(ch.get("current", false)):
			_current_channel = int(ch.get("channel", 1))
			break
	_portals = (data.get("portals", []) as Array).duplicate(true)
	_npcs = (data.get("npcs", []) as Array).duplicate(true)
	_encounters = (data.get("encounters", {}) as Dictionary).duplicate(true)
	_render_map(map_id)
	_sync_world_markers()
	if not _positions_recent():
		_apply_people(data.get("entities", []), false)
	_show_player(Vector2(float(lease.get("x", 600)), float(lease.get("y", 1520))), new_lease or not automatic_poll)
	if map_id == "lorin_wilds" and data.has("journey"):
		_update_journey(data.get("journey", {}))
	else:
		_update_field_prompt()


func _render_map(map_id: String) -> void:
	if _rendered_map_id == map_id:
		return
	_rendered_map_id = map_id
	for node in _map_props:
		if is_instance_valid(node):
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.queue_free()
	_map_props.clear()
	if is_instance_valid(_journey_marker):
		if _journey_marker.get_parent() != null:
			_journey_marker.get_parent().remove_child(_journey_marker)
		_journey_marker.queue_free()
		_journey_marker = null
	_marker_key = ""
	var cfg := TableCache.main_world_map(map_id)
	if _floor != null and not cfg.is_empty():
		_floor.texture = load(String(cfg.get("background", ""))) as Texture2D
		if _floor.texture != null:
			_floor.scale = Vector2(float(cfg.get("map_cols", 25)) * 48, float(cfg.get("map_rows", 44)) * 48) / _floor.texture.get_size()
	var before_count := _world.get_child_count()
	for id in cfg.get("city_building_positions", {}):
		var at: Array = cfg.city_building_positions[id]
		Art.add_prop(_world, "ledger" if id == "gate" else String(id), Vector2(at[0], at[1]), "props" if id == "gate" else "buildings")
	for idx in range(before_count, _world.get_child_count()):
		_map_props.append(_world.get_child(idx))


func _sync_world_markers() -> void:
	var has_wolf := _encounters.has("training_wolf") or _encounters.has("maple_wolf")
	if not _world.has_node("TrainingWolf") and has_wolf:
		var enc_id := "training_wolf" if _encounters.has("training_wolf") else "maple_wolf"
		var enc: Dictionary = _encounters[enc_id]
		var target := Node2D.new()
		target.name = "TrainingWolf"
		var at: Array = enc.position
		target.position = Vector2(at[0], at[1])
		_world.add_child(target)
		_map_props.append(target)
		var picture := Sprite2D.new()
		picture.texture = load("res://image/generated_101_200/ready/map/mon_wolf.png")
		picture.position.y = -36
		picture.scale = Vector2.ONE * 0.75
		target.add_child(picture)
		var caption := G.gold_label("城南试炼 · 野狼" if enc_id == "training_wolf" else "古道野狼", G.FS_SM)
		caption.position = Vector2(-90, -112)
		caption.size = Vector2(180, 30)
		target.add_child(caption)
	for npc_value in _npcs:
		if not npc_value is Dictionary:
			continue
		var npc := npc_value as Dictionary
		var nid := String(npc.get("id", ""))
		var node_name := "NPCMarker_" + nid
		if nid.is_empty() or _world.has_node(node_name):
			continue
		var at: Array = npc.get("position", [])
		if at.size() != 2:
			continue
		var marker := Node2D.new()
		marker.name = node_name
		marker.position = Vector2(float(at[0]), float(at[1]))
		_world.add_child(marker)
		_map_props.append(marker)
		var tag := Field.surface(Vector2(-72, -62), Vector2(144, 30))
		tag.add_child(Field.label("◇ " + String(npc.get("name", "旅人")), Vector2.ZERO, Vector2(144, 30), G.FS_SM, G.PARCHMENT, true))
		marker.add_child(tag)
	for portal_value in _portals:
		if not portal_value is Dictionary:
			continue
		var portal := portal_value as Dictionary
		var pid := String(portal.get("id", ""))
		var node_name := "PortalMarker_" + pid
		if pid.is_empty() or _world.has_node(node_name):
			continue
		var at: Array = portal.get("position", [])
		if at.size() != 2:
			continue
		var pnode := Node2D.new()
		pnode.name = node_name
		pnode.position = Vector2(float(at[0]), float(at[1]))
		_world.add_child(pnode)
		_map_props.append(pnode)
		var tag := Field.surface(Vector2(-92, -46), Vector2(184, 32))
		tag.add_child(Field.label("◈ " + String(portal.get("label", "传送门")), Vector2.ZERO, Vector2(184, 32), G.FS_SM, G.GOLD_BRIGHT, true))
		pnode.add_child(tag)


func _update_field_prompt() -> void:
	var action := "古道斥候 · 查看周围"
	var here := Vector2(float(lease.get("x", 0)), float(lease.get("y", 0)))
	for p in _portals:
		if p is Dictionary:
			var at: Array = p.get("position", [])
			if at.size() == 2 and here.distance_to(Vector2(float(at[0]), float(at[1]))) <= float(p.get("radius", 120)):
				action = String(p.get("label", "前往下一地图"))
				break
	if _encounters.has("maple_wolf"):
		var enc: Dictionary = _encounters.maple_wolf
		var at: Array = enc.get("position", [])
		if at.size() == 2 and here.distance_to(Vector2(float(at[0]), float(at[1]))) <= float(enc.get("radius", 112)):
			action = "迎战古道野狼"
	(_challenge_button.get_child(0) as Label).text = action
	_status.text = "%s（%d线）\n沿着古道探索，靠近斥候或出口可交互。" % [_map_name, _current_channel]


func _apply_people(people: Array, interpolate: bool) -> void:
	entities = people.duplicate(true)
	_town_label.text = "%s · %d线 · 附近 %d 人" % [_map_name, _current_channel, entities.size()]
	var live_ids: Array[String] = []
	var own_id := String(lease.get("character_id", ""))
	for entity_value in entities:
		if not entity_value is Dictionary:
			continue
		var entity := entity_value as Dictionary
		var id := String(entity.get("id", ""))
		var at := Vector2(float(entity.get("x", 0)), float(entity.get("y", 0)))
		live_ids.append(id)
		if not _actors.has(id):
			var actor := Traveller.new()
			actor.identity = entity
			actor.position = _camera.position if id == own_id and _player_draw_ready else at
			_actors[id] = actor
			_world.add_child(actor)
		if id != own_id:
			(_actors[id] as Traveller).update_position(at, interpolate)
	for id in _actors.keys():
		if not live_ids.has(String(id)):
			(_actors[id] as Node2D).queue_free()
			_actors.erase(id)


func _show_player(target: Vector2, instant: bool) -> void:
	_player_draw_target = target
	if instant or not _player_draw_ready:
		_player_draw_ready = true
		_draw_player(target)


func _draw_player(point: Vector2) -> void:
	_camera.position = point
	var own_id := String(lease.get("character_id", ""))
	if _actors.has(own_id):
		(_actors[own_id] as Node2D).position = point


func _positions_recent() -> bool:
	return Time.get_ticks_msec() - _positions_last < 1200


func _close_positions() -> void:
	if _positions != null:
		_positions.close()
	_positions = null
	_position_tick = 0
	_positions_last = -10000
	_positions_retry_at = 0


func _poll_positions() -> void:
	var now := Time.get_ticks_msec()
	if _positions == null and now >= _positions_retry_at:
		_positions = Online.open_world_positions()
		_position_tick = 0
		_positions_retry_at = now + 800
	if _positions == null:
		return
	var frame := _positions.poll_latest()
	if not _positions.is_open():
		_positions = null
		_positions_retry_at = now + 250
	if frame.is_empty():
		return
	if frame.get("room_id") != lease.get("room_id") or frame.get("map_id") != lease.get("map_id") or frame.get("generation") != lease.get("generation"):
		_close_positions()
		_positions_retry_at = now + 800
		return
	var tick := int(frame.get("tick", 0))
	if tick <= _position_tick or not frame.get("entities") is Array:
		return
	_position_tick = tick
	_positions_last = now
	_apply_people(frame.entities, true)


func _update_journey(value: Dictionary) -> void:
	if int(value.get("version", 0)) >= int(_journey.get("version", 0)):
		_journey = value.duplicate(true)
	var event := String(_journey.get("event", ""))
	var target := String(_journey.get("target_id", ""))
	var goal := String(_journey.get("goal", "城南试炼：首胜金币 10、阅历 5"))
	var action := "城南试炼 · 挑战野狼"
	var point: Dictionary = _journey.get("point", {})
	match event:
		"interact":
			action = "查看城南路标" if target == "south_signpost" else "与%s交谈" % String(point.get("name", "旅人"))
		"gear", "companion":
			action = "打开行囊 · %s" % String(_journey.get("title", "整备"))
		"victory":
			action = "碑影巡查 · 挑战树妖" if target == "southern_patrol" else "城南试炼 · 挑战野狼"
		"complete":
			action = "查看碑窟通行资格"
	(_challenge_button.get_child(0) as Label).text = action
	_status.text = "%s\n%s" % [String(_journey.get("title", Online.selected_character.get("nickname", "旅人"))), goal]
	_update_journey_marker(target, point)


func _update_journey_marker(target: String, point: Dictionary) -> void:
	var at: Array = point.get("position", [])
	var caption := String(point.get("name", ""))
	var icon := ""
	match target:
		"npc_steward", "npc_scribe":
			icon = "res://assets/world/reference_complete_20261011/ready/%s.png" % target
		"southern_patrol":
			var encounter: Dictionary = _encounters.get(target, {})
			at = encounter.get("position", [])
			caption = "碑影巡查 · 树妖"
			icon = "res://image/generated_101_200/ready/map/mon_treant.png"
	var key := target if at.size() == 2 else ""
	if key == _marker_key:
		return
	if is_instance_valid(_journey_marker):
		_journey_marker.queue_free()
		_journey_marker = null
	_marker_key = key
	if key.is_empty():
		return
	_journey_marker = Node2D.new()
	_journey_marker.position = Vector2(float(at[0]), float(at[1]))
	_world.add_child(_journey_marker)
	if not icon.is_empty():
		var picture := Sprite2D.new()
		picture.texture = load(icon) as Texture2D
		if picture.texture != null:
			picture.scale = Vector2.ONE * (96.0 / maxf(1.0, picture.texture.get_height()))
		picture.position.y = -46
		_journey_marker.add_child(picture)
	var tag := Field.surface(Vector2(-72, -138 if not icon.is_empty() else -48), Vector2(144, 30))
	var words := Field.label("◆ " + caption, Vector2.ZERO, Vector2(144, 30), G.FS_SM, G.GOLD_BRIGHT, true)
	_journey_marker.add_child(tag)
	tag.add_child(words)


func _perform_journey_action() -> void:
	if String(lease.get("map_id", "lorin_wilds")) != "lorin_wilds":
		var here := Vector2(float(lease.get("x", 0)), float(lease.get("y", 0)))
		for p in _portals:
			if p is Dictionary:
				var at: Array = p.get("position", [])
				if at.size() == 2 and here.distance_to(Vector2(float(at[0]), float(at[1]))) <= float(p.get("radius", 120)):
					travel_portal(String(p.get("id", "")))
					return
		if _encounters.has("maple_wolf"):
			var enc: Dictionary = _encounters.maple_wolf
			var at: Array = enc.get("position", [])
			if at.size() == 2 and here.distance_to(Vector2(float(at[0]), float(at[1]))) <= float(enc.get("radius", 112)):
				challenge("maple_wolf")
				return
		for npc in _npcs:
			if npc is Dictionary:
				interact_npc(String(npc.get("id", "")))
				return
		return
	var target := String(_journey.get("target_id", ""))
	match String(_journey.get("event", "")):
		"interact":
			interact_with_journey()
		"gear", "companion", "complete":
			open_journey()
		"victory":
			challenge(target)
		_:
			challenge("training_wolf")


func switch_channel(channel: int, request_id := "") -> Dictionary:
	if _busy or not battle.is_empty():
		return {"ok": false, "code": "busy"}
	_busy = true
	var result: Dictionary = await Online.switch_channel(channel, request_id)
	_busy = false
	if bool(result.get("ok", false)):
		_close_channels()
		_apply_world(result.data)
	else:
		_show_error(result)
	return result


func travel_portal(portal_id: String, request_id := "") -> Dictionary:
	if _busy or not battle.is_empty():
		return {"ok": false, "code": "busy"}
	_busy = true
	var result: Dictionary = await Online.travel_portal(portal_id, request_id)
	_busy = false
	if bool(result.get("ok", false)):
		_close_channels()
		_close_profiles()
		_close_journey()
		_apply_world(result.data)
	else:
		_show_error(result)
	return result


func interact_npc(npc_id: String, request_id := "") -> Dictionary:
	if _busy or not battle.is_empty():
		return {"ok": false, "code": "busy"}
	_busy = true
	var result: Dictionary = await Online.interact_npc(npc_id, request_id)
	_busy = false
	if bool(result.get("ok", false)):
		if result.data.get("npcs") is Array:
			_npcs = (result.data.npcs as Array).duplicate(true)
		var npc: Dictionary = result.data.get("npc", {}) as Dictionary
		_status.text = "%s：%s" % [String(npc.get("name", "旅人")), String(npc.get("dialogue", ""))]
	else:
		_show_error(result)
	return result


func interact_with_journey(request_id := "") -> Dictionary:
	if _busy or not battle.is_empty() or String(_journey.get("event", "")) != "interact":
		return {"ok": false, "code": "busy"}
	_busy = true
	var result: Dictionary = await Online.interact_journey(String(_journey.id), String(_journey.target_id), request_id)
	_busy = false
	if bool(result.get("ok", false)):
		_update_journey(result.data.journey)
		_open_journey_panel(result.data)
	else:
		_show_error(result)
	return result


func open_journey() -> void:
	if _busy or not battle.is_empty() or is_instance_valid(_journey_panel):
		return
	_close_profiles()
	_open_journey_panel()
	_busy = true
	var result: Dictionary = await Online.journey_state()
	_busy = false
	if not is_instance_valid(_journey_panel):
		return
	if bool(result.get("ok", false)):
		_update_journey(result.data.journey)
		_journey_panel.present(result.data)
	else:
		_journey_panel.show_message(String(result.get("error", "暂时无法查看行囊")))


func _open_journey_panel(data: Dictionary = {}) -> void:
	if not is_instance_valid(_journey_panel):
		_held = Vector2.ZERO
		_journey_panel = JourneyPanel.new()
		_hud.add_child(_journey_panel)
		_journey_panel.closed.connect(_close_journey)
		_journey_panel.equipment_requested.connect(_equip_from_journey)
	if not data.is_empty():
		_journey_panel.present(data)


func _equip_from_journey(id: String, equipped: bool) -> void:
	if _busy or not is_instance_valid(_journey_panel):
		return
	_busy = true
	_journey_panel.set_busy(true)
	var result: Dictionary = await Online.equip_journey_item(id, equipped)
	_busy = false
	if bool(result.get("ok", false)):
		_update_journey(result.data.journey)
	if not is_instance_valid(_journey_panel):
		return
	_journey_panel.set_busy(false)
	if bool(result.get("ok", false)):
		_journey_panel.present(result.data, true)
	else:
		_journey_panel.show_message(String(result.get("error", "暂时无法操作这件物品")))


func _close_journey() -> void:
	if is_instance_valid(_journey_panel):
		_journey_panel.queue_free()
	_journey_panel = null


func move_by(direction: Vector2) -> Dictionary:
	if _busy or not battle.is_empty() or lease.is_empty():
		return {"ok": false, "code": "busy"}
	_busy = true
	var confirmed := Vector2(float(lease.x), float(lease.y))
	var target := confirmed + direction.limit_length(24)
	if automatic_poll:
		_show_player(target, false)
	var result: Dictionary = await Online.move_world(lease, target)
	if bool(result.get("ok", false)):
		lease = (result.data.lease as Dictionary).duplicate(true)
		confirmed = Vector2(float(lease.x), float(lease.y))
		if String(lease.get("map_id", "lorin_wilds")) != "lorin_wilds":
			_update_field_prompt()
	_show_player(confirmed, not automatic_poll)
	_show_error(result)
	_busy = false
	return result


func challenge(encounter_id: String) -> Dictionary:
	if _busy:
		return {"ok": false, "code": "busy"}
	_busy = true
	var result: Dictionary = await Online.start_battle(encounter_id)
	if bool(result.get("ok", false)):
		_present_battle(result.data.get("battle"))
	_show_error(result)
	_busy = false
	return result


func refresh_battle() -> Dictionary:
	if _busy or battle.is_empty():
		return {"ok": false, "code": "busy"}
	_busy = true
	var result: Dictionary = await Online.battle_snapshot(String(battle.id))
	if bool(result.get("ok", false)):
		_present_battle(result.data.get("battle"))
	_show_error(result)
	_busy = false
	return result


func send_action(action: Dictionary, request_id := "") -> Dictionary:
	if _busy or battle.is_empty():
		return {"ok": false, "code": "busy"}
	_busy = true
	_battle_page.set_busy(true)
	var result: Dictionary = await Online.battle_command(String(battle.id), action, request_id)
	if bool(result.get("ok", false)):
		_present_battle(result.data.get("battle"))
	_show_error(result)
	_busy = false
	_battle_page.set_busy(false)
	return result


func confirm_result() -> Dictionary:
	if _busy or battle.is_empty():
		return {"ok": false, "code": "busy"}
	_busy = true
	var result: Dictionary = await Online.acknowledge_battle(String(battle.id))
	if bool(result.get("ok", false)):
		_present_battle(null)
	_show_error(result)
	_busy = false
	if bool(result.get("ok", false)):
		await refresh_world()
	return result


func _present_battle(value: Variant) -> void:
	battle = value.duplicate(true) if value is Dictionary else {}
	if not battle.is_empty():
		_close_positions()
		_close_profiles()
		_close_journey()
		_close_channels()
		_close_social()
		_close_coop()
		_close_market()
		_close_guild()
		_close_pvp()
	_hud.visible = battle.is_empty()
	if battle.is_empty():
		if is_instance_valid(_battle_page):
			_battle_page.queue_free()
		_battle_page = null
		return
	if not is_instance_valid(_battle_page):
		_battle_page = BattlePage.instantiate() as Control
		_hud.get_parent().add_child(_battle_page)
		_battle_page.command_requested.connect(send_action)
		_battle_page.acknowledge_requested.connect(confirm_result)
		_battle_page.leave_requested.connect(_back)
	_battle_page.present(battle)


func _show_error(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		if String(result.get("code", "")) in ["room_required", "stale_lease"]:
			_close_positions()
			lease.clear()
		var message := String(result.get("error", "连接中断，请稍后重试。"))
		_status.text = message
		if is_instance_valid(_battle_page):
			_battle_page.show_error(message)


func _process(delta: float) -> void:
	if not _connected or not automatic_poll or G.ui_blocked:
		return
	if _player_draw_ready and not _camera.position.is_equal_approx(_player_draw_target):
		_draw_player(_camera.position.move_toward(_player_draw_target, 300.0 * delta))
	if Online.is_authenticated() and not lease.is_empty() and battle.is_empty():
		_poll_positions()
	_poll_elapsed += delta
	_move_elapsed += delta
	if _busy:
		return
	if not Online.is_authenticated():
		_close_positions()
		_status.text = "登录已过期，请返回在线角色重新登录。"
		return
	var refresh_interval := 4.0 if _positions_recent() else 0.7
	if _poll_elapsed >= refresh_interval:
		_poll_elapsed = 0.0
		if not battle.is_empty():
			refresh_battle()
		elif lease.is_empty():
			enter_world()
		else:
			refresh_world()
		return
	if battle.is_empty() and not is_instance_valid(_profiles) and not is_instance_valid(_journey_panel) and not is_instance_valid(_channels_panel) and not is_instance_valid(_social_panel) and not is_instance_valid(_coop_panel) and _move_elapsed >= 0.15:
		var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if direction.is_zero_approx():
			direction = _held
		if not direction.is_zero_approx():
			_move_elapsed = 0.0
			move_by(direction.normalized() * 24)


func _back() -> void:
	_connected = false
	_close_positions()
	G.go("res://src/ui/OnlineGateway.tscn")


func _exit_tree() -> void:
	_close_positions()


func _unhandled_input(event: InputEvent) -> void:
	if not G.ui_blocked and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if is_instance_valid(_profiles):
			_close_profiles()
		elif is_instance_valid(_journey_panel):
			_close_journey()
		elif is_instance_valid(_channels_panel):
			_close_channels()
		elif is_instance_valid(_social_panel):
			_close_social()
		elif is_instance_valid(_coop_panel):
			_close_coop()
		elif is_instance_valid(_market_panel):
			_close_market()
		elif is_instance_valid(_guild_panel):
			_close_guild()
		elif is_instance_valid(_pvp_panel):
			_close_pvp()
		else:
			_back()


func open_social() -> void:
	if _busy or not battle.is_empty() or is_instance_valid(_social_panel):
		return
	_close_profiles()
	_close_journey()
	_close_channels()
	_close_coop()
	_close_market()
	_close_guild()
	_close_pvp()
	_held = Vector2.ZERO
	_social_panel = SocialPanel.new()
	_hud.add_child(_social_panel)
	_social_panel.closed.connect(_close_social)
	_social_panel.action_requested.connect(_on_social_action)
	await _refresh_social()


func _refresh_social() -> void:
	if not is_instance_valid(_social_panel):
		return
	_busy = true
	_social_panel.set_busy(true)
	var st: Dictionary = await Online.social_state()
	var ch: Dictionary = await Online.chat_messages(0)
	_busy = false
	if not is_instance_valid(_social_panel):
		return
	_social_panel.set_busy(false)
	if bool(st.get("ok", false)) and bool(ch.get("ok", false)):
		_social_panel.present(st.data, ch.data.get("messages", []), entities)
	else:
		var err_res: Dictionary = st if not bool(st.get("ok", false)) else ch
		_social_panel.show_message(String(err_res.get("error", "社交状态暂时不可用")))


func _on_social_action(kind: String, payload: Dictionary) -> void:
	if _busy or not is_instance_valid(_social_panel):
		return
	_busy = true
	_social_panel.set_busy(true)
	var result := {"ok": false}
	match kind:
		"refresh":
			result = {"ok": true}
		"party_create":
			result = await Online.create_party()
		"party_invite":
			result = await Online.invite_party(String(payload.get("target_id", "")))
		"party_respond":
			result = await Online.respond_party_invite(String(payload.get("id", "")), bool(payload.get("accept", false)))
		"party_ready":
			result = await Online.set_party_ready(bool(payload.get("ready", false)))
		"party_kick":
			result = await Online.kick_party_member(String(payload.get("target_id", "")))
		"party_leader":
			result = await Online.promote_party_leader(String(payload.get("target_id", "")))
		"party_leave":
			result = await Online.leave_party()
		"friend_request":
			result = await Online.request_friend(String(payload.get("target_id", "")))
		"friend_respond":
			result = await Online.respond_friend(String(payload.get("id", "")), bool(payload.get("accept", false)))
		"friend_remove":
			result = await Online.remove_friend(String(payload.get("target_id", "")))
		"block_add":
			result = await Online.block_player(String(payload.get("target_id", "")))
		"block_remove":
			result = await Online.unblock_player(String(payload.get("account_id", "")))
		"report_send":
			result = await Online.report_player(String(payload.get("target_id", "")), "harassment", "玩家在面板举报不当行为")
		"chat_send":
			result = await Online.send_chat(String(payload.get("channel_kind", "room")), String(payload.get("content", "")))
	_busy = false
	if not is_instance_valid(_social_panel):
		return
	_social_panel.set_busy(false)
	if not bool(result.get("ok", false)):
		_social_panel.show_message(String(result.get("error", "操作未完成")))
		return
	await _refresh_social()


func _close_social() -> void:
	if is_instance_valid(_social_panel):
		_social_panel.queue_free()
	_social_panel = null


func open_coop(tab_id := "dungeons") -> void:
	if _busy or not battle.is_empty() or is_instance_valid(_coop_panel):
		return
	_close_profiles()
	_close_journey()
	_close_channels()
	_close_coop()
	_close_social()
	_close_market()
	_close_guild()
	_close_pvp()
	_held = Vector2.ZERO
	_coop_panel = CoopPanel.new()
	_hud.add_child(_coop_panel)
	_coop_panel.closed.connect(_close_coop)
	_coop_panel.action_requested.connect(_on_coop_action)
	if not tab_id.is_empty():
		_coop_panel.set_tab(tab_id)
	await _refresh_coop()


func _refresh_coop() -> void:
	if not is_instance_valid(_coop_panel):
		return
	_busy = true
	_coop_panel.set_busy(true)
	var ov: Dictionary = await Online.coop_dungeons()
	var inst := {}
	if bool(ov.get("ok", false)):
		var aid := String(ov.data.get("active_instance_id", ""))
		if aid.is_empty() and not _coop_instance_id.is_empty():
			aid = _coop_instance_id
		if not aid.is_empty():
			var ir: Dictionary = await Online.get_coop_instance(aid)
			if bool(ir.get("ok", false)):
				inst = ir.data
				_coop_instance_id = aid
	var wb: Dictionary = await Online.world_boss_current()
	var wb_data: Dictionary = wb.data if bool(wb.get("ok", false)) else {}
	_busy = false
	if not is_instance_valid(_coop_panel):
		return
	_coop_panel.set_busy(false)
	if bool(ov.get("ok", false)):
		_coop_panel.apply_state(ov.data, inst, wb_data, String(Online.selected_character.get("id", "")))
		_coop_panel.set_status("在线合作副本与公共首领同步成功")
	else:
		_coop_panel.set_status(String(ov.get("error", "合作副本状态同步失败")))


func _on_coop_action(kind: String, payload: Dictionary) -> void:
	if _busy or not is_instance_valid(_coop_panel):
		return
	_busy = true
	_coop_panel.set_busy(true)
	var res := {"ok": false}
	match kind:
		"refresh":
			res = {"ok": true}
		"open_instance":
			_coop_instance_id = String(payload.get("instance_id", ""))
			res = await Online.get_coop_instance(_coop_instance_id)
		"create_instance":
			res = await Online.create_coop_instance(String(payload.get("dungeon_id", "stele_cavern")), String(payload.get("difficulty", "standard")), String(payload.get("goal", "first_clear")), bool(payload.get("allow_solo", false)))
			if bool(res.get("ok", false)):
				_coop_instance_id = String(res.data.get("id", ""))
				_coop_panel.set_tab("instance")
		"queue_join":
			res = await Online.join_coop_queue(String(payload.get("dungeon_id", "stele_cavern")), String(payload.get("difficulty", "standard")), String(payload.get("goal", "first_clear")), bool(payload.get("friends_only", false)))
			if bool(res.get("ok", false)) and res.data.has("instance"):
				var inst_d: Dictionary = res.data.get("instance", {})
				_coop_instance_id = String(inst_d.get("id", ""))
				_coop_panel.set_tab("instance")
		"queue_leave":
			res = await Online.leave_coop_queue()
		"instance_ready":
			res = await Online.set_coop_ready(String(payload.get("instance_id", "")), bool(payload.get("ready", true)))
		"interact":
			res = await Online.interact_coop_stage(String(payload.get("instance_id", "")), String(payload.get("mechanic_id", "")), String(payload.get("choice", "")))
		"battle_start":
			res = await Online.start_coop_battle(String(payload.get("instance_id", "")))
		"battle_cmd":
			res = await Online.coop_battle_command(String(payload.get("instance_id", "")), int(payload.get("sequence", 1)), String(payload.get("action", "attack")), String(payload.get("skill_id", "")), int(payload.get("target_uid", 0)))
		"battle_tick":
			res = await Online.tick_coop_battle(String(payload.get("instance_id", "")), int(payload.get("advance_ticks", 60)))
		"leave_instance":
			res = await Online.leave_coop_instance(String(payload.get("instance_id", "")))
			if bool(res.get("ok", false)):
				_coop_instance_id = ""
		"retreat":
			res = await Online.retreat_coop_instance(String(payload.get("instance_id", "")), bool(payload.get("vote", true)))
		"claim_drop":
			res = await Online.claim_coop_drop(String(payload.get("drop_id", "")))
		"wb_objective":
			res = await Online.world_boss_objective(String(payload.get("event_id", "")), String(payload.get("objective_id", "")))
		"wb_engage":
			res = await Online.world_boss_engage(String(payload.get("event_id", "")), "attack")
		"wb_claim":
			res = await Online.world_boss_claim(String(payload.get("event_id", "")))
		"wb_select_map":
			res = await Online.world_boss_current(String(payload.get("map_id", "shenyuan_port")))
			if bool(res.get("ok", false)) and is_instance_valid(_coop_panel):
				var ov2: Dictionary = await Online.coop_dungeons()
				var ov_d: Dictionary = ov2.data if bool(ov2.get("ok", false)) else {}
				_coop_panel.apply_state(ov_d, {}, res.data, String(Online.selected_character.get("id", "")))
				_coop_panel.set_status("已切至 %s 激活公共首领" % String(payload.get("map_id", "")))
				_busy = false
				_coop_panel.set_busy(false)
				return
	_busy = false
	if not is_instance_valid(_coop_panel):
		return
	_coop_panel.set_busy(false)
	if not bool(res.get("ok", false)):
		_coop_panel.set_status(String(res.get("error", "合作副本操作失败")))
		return
	await _refresh_coop()


func _close_coop() -> void:
	if is_instance_valid(_coop_panel):
		_coop_panel.queue_free()
	_coop_panel = null


func open_market(tab_id := "market") -> void:
	if _busy or not battle.is_empty() or is_instance_valid(_market_panel):
		return
	_close_profiles()
	_close_journey()
	_close_channels()
	_close_coop()
	_close_social()
	_close_guild()
	_close_pvp()
	_held = Vector2.ZERO
	_market_panel = MarketPanel.new()
	_hud.add_child(_market_panel)
	_market_panel.closed.connect(_close_market)
	_market_panel.action_requested.connect(_on_market_action)
	if not tab_id.is_empty():
		_market_panel.set_tab(tab_id)
	await _refresh_market()


func _refresh_market() -> void:
	if not is_instance_valid(_market_panel):
		return
	_busy = true
	_market_panel.set_busy(true)
	var sum_res: Dictionary = await Online.market_summary()
	var ord_res: Dictionary = await Online.market_orders()
	var pay_res: Dictionary = await Online.market_payouts()
	var trd_res: Dictionary = await Online.trade_sessions()
	var soc_res: Dictionary = await Online.social_state()
	var jrn_res: Dictionary = await Online.journey_state()
	_busy = false
	if not is_instance_valid(_market_panel):
		return
	_market_panel.set_busy(false)
	if bool(sum_res.get("ok", false)):
		var orders: Array = ord_res.data.get("orders", []) if bool(ord_res.get("ok", false)) else []
		var payouts: Array = pay_res.data.get("payouts", []) if bool(pay_res.get("ok", false)) else []
		var sessions: Array = trd_res.data.get("sessions", []) if bool(trd_res.get("ok", false)) else []
		var friends: Array = soc_res.data.get("friends", []) if bool(soc_res.get("ok", false)) else []
		var pack_items: Array = jrn_res.data.get("pack", {}).get("items", []) if bool(jrn_res.get("ok", false)) else []
		_market_panel.apply_state(sum_res.data, orders, payouts, sessions, friends, pack_items, String(Online.selected_character.get("id", "")))
		_market_panel.set_status("在线集市与面对面交易同步成功")
	else:
		_market_panel.set_status(String(sum_res.get("error", "集市状态同步失败")))


func _on_market_action(kind: String, payload: Dictionary) -> void:
	if _busy or not is_instance_valid(_market_panel):
		return
	_busy = true
	_market_panel.set_busy(true)
	var res := {"ok": false}
	match kind:
		"refresh":
			res = {"ok": true}
		"npc_buy":
			res = await Online.npc_market_trade("buy", String(payload.get("template_id", "")), int(payload.get("quantity", 1)))
		"create_order":
			res = await Online.create_market_order(String(payload.get("item_uid", "")), int(payload.get("quantity", 1)), int(payload.get("unit_price", 15)))
		"buy_order":
			res = await Online.buy_market_order(String(payload.get("order_id", "")), int(payload.get("quantity", 1)))
		"cancel_order":
			res = await Online.cancel_market_order(String(payload.get("order_id", "")))
		"claim_payout":
			res = await Online.claim_market_payout(String(payload.get("payout_id", "")))
		"trade_start":
			res = await Online.start_trade_session(String(payload.get("target_character_id", "")))
		"trade_offer":
			var offer_payload := {}
			if payload.has("gold"):
				offer_payload["gold"] = int(payload.get("gold", 0))
			if payload.has("add_item_uid"):
				offer_payload["add_item_uid"] = String(payload.get("add_item_uid", ""))
				offer_payload["add_quantity"] = int(payload.get("add_quantity", 1))
			res = await Online.update_trade_offer(String(payload.get("trade_id", "")), offer_payload)
		"trade_confirm":
			res = await Online.confirm_trade_session(String(payload.get("trade_id", "")), int(payload.get("revision", 1)))
		"trade_cancel":
			res = await Online.cancel_trade_session(String(payload.get("trade_id", "")))
	_busy = false
	if not is_instance_valid(_market_panel):
		return
	_market_panel.set_busy(false)
	if not bool(res.get("ok", false)):
		_market_panel.set_status(String(res.get("error", "集市操作未完成")))
		return
	await _refresh_market()


func _close_market() -> void:
	if is_instance_valid(_market_panel):
		_market_panel.queue_free()
	_market_panel = null


func open_guild(tab_id := "overview") -> void:
	if _busy or not battle.is_empty() or is_instance_valid(_guild_panel):
		return
	_close_profiles()
	_close_journey()
	_close_channels()
	_close_coop()
	_close_social()
	_close_market()
	_close_pvp()
	_held = Vector2.ZERO
	_guild_panel = GuildPanel.new()
	_hud.add_child(_guild_panel)
	_guild_panel.closed.connect(_close_guild)
	_guild_panel.action_requested.connect(_on_guild_action)
	if not tab_id.is_empty():
		_guild_panel.set_tab(tab_id)
	await _refresh_guild()


func _refresh_guild() -> void:
	if not is_instance_valid(_guild_panel):
		return
	_busy = true
	_guild_panel.set_busy(true)
	var st: Dictionary = await Online.guild_state()
	var jrn: Dictionary = await Online.journey_state()
	var soc: Dictionary = await Online.social_state()
	_busy = false
	if not is_instance_valid(_guild_panel):
		return
	_guild_panel.set_busy(false)
	if bool(st.get("ok", false)):
		var pack_items: Array = jrn.data.get("pack", {}).get("items", []) if bool(jrn.get("ok", false)) else []
		var friends: Array = soc.data.get("friends", []) if bool(soc.get("ok", false)) else []
		_guild_panel.apply_state(st.data, pack_items, friends, String(Online.selected_character.get("id", "")))
		_guild_panel.set_status("帮派与共同据点同步成功")
	else:
		_guild_panel.set_status(String(st.get("error", "帮派状态同步失败")))


func _on_guild_action(kind: String, payload: Dictionary) -> void:
	if _busy or not is_instance_valid(_guild_panel):
		return
	_busy = true
	_guild_panel.set_busy(true)
	var res := {"ok": false}
	match kind:
		"refresh":
			res = {"ok": true}
		"create":
			res = await Online.create_guild(String(payload.get("name", "")), String(payload.get("motto", "")))
		"invite":
			res = await Online.invite_guild(String(payload.get("target_character_id", "")))
		"respond_invite":
			res = await Online.respond_guild_invite(String(payload.get("id", "")), bool(payload.get("accept", false)))
		"permission":
			res = await Online.update_guild_permissions(String(payload.get("target_character_id", "")), String(payload.get("rank", "member")), bool(payload.get("can_invite", false)), bool(payload.get("can_manage_warehouse", false)), bool(payload.get("can_edit_announcement", false)))
		"announcement":
			res = await Online.update_guild_banner(String(payload.get("announcement", "")), String(payload.get("decor_banner", "")), String(payload.get("decor_monument", "")))
		"deposit":
			res = await Online.deposit_guild_warehouse(String(payload.get("item_uid", "")), int(payload.get("quantity", 1)))
		"withdraw":
			res = await Online.withdraw_guild_warehouse(String(payload.get("template_id", "")), int(payload.get("quantity", 1)))
		"task_contribute":
			res = await Online.contribute_guild_task(String(payload.get("template_id", "")), int(payload.get("quantity", 1)))
		"leave":
			res = await Online.leave_guild()
		"leader":
			res = await Online.transfer_guild_leader(String(payload.get("target_character_id", "")))
		"claim_inactive":
			res = await Online.claim_inactive_guild_leader()
	_busy = false
	if not is_instance_valid(_guild_panel):
		return
	_guild_panel.set_busy(false)
	if not bool(res.get("ok", false)):
		_guild_panel.set_status(String(res.get("error", "帮派操作未完成")))
		return
	await _refresh_guild()


func _close_guild() -> void:
	if is_instance_valid(_guild_panel):
		_guild_panel.queue_free()
	_guild_panel = null


func open_pvp(tab_id := "arena") -> void:
	if _busy or not battle.is_empty() or is_instance_valid(_pvp_panel):
		return
	_close_profiles()
	_close_journey()
	_close_channels()
	_close_coop()
	_close_social()
	_close_market()
	_close_guild()
	_held = Vector2.ZERO
	_pvp_panel = PvpPanel.new()
	_hud.add_child(_pvp_panel)
	_pvp_panel.closed.connect(_close_pvp)
	_pvp_panel.action_requested.connect(_on_pvp_action)
	if not tab_id.is_empty():
		_pvp_panel.set_tab(tab_id)
	await _refresh_pvp()


func _refresh_pvp(replay_data: Dictionary = {}) -> void:
	if not is_instance_valid(_pvp_panel):
		return
	_busy = true
	_pvp_panel.set_busy(true)
	var ov: Dictionary = await Online.pvp_overview(_pvp_panel.selected_mode())
	_busy = false
	if not is_instance_valid(_pvp_panel):
		return
	_pvp_panel.set_busy(false)
	if bool(ov.get("ok", false)):
		_pvp_panel.apply_state(ov.data, replay_data)
		_pvp_panel.set_status("昭元演武场已同步（1v1 / 2v2 / 3v3 独立段位）")
	else:
		_pvp_panel.set_status(String(ov.get("error", "演武场状态同步失败")))


func _on_pvp_action(kind: String, payload: Dictionary) -> void:
	if _busy or not is_instance_valid(_pvp_panel):
		return
	_busy = true
	_pvp_panel.set_busy(true)
	var res := {"ok": false}
	var replay_data := {}
	match kind:
		"refresh":
			res = {"ok": true}
		"challenge_send":
			res = await Online.send_pvp_challenge(String(payload.get("mode", "1v1")), String(payload.get("target_character_id", "")))
		"challenge_respond":
			res = await Online.respond_pvp_challenge(String(payload.get("id", "")), bool(payload.get("accept", false)))
			if bool(res.get("ok", false)) and res.data.has("match"):
				_pvp_panel.set_tab("match")
		"queue_join":
			res = await Online.join_pvp_queue(String(payload.get("mode", "1v1")), bool(payload.get("allow_random_fill", false)))
			if bool(res.get("ok", false)) and res.data.has("match"):
				_pvp_panel.set_tab("match")
		"queue_leave":
			res = await Online.leave_pvp_queue()
		"match_ready":
			res = await Online.ready_pvp_match(String(payload.get("match_id", "")), bool(payload.get("ready", true)))
		"match_cmd":
			res = await Online.pvp_battle_command(String(payload.get("match_id", "")), int(payload.get("sequence", 1)), String(payload.get("action", "attack")), String(payload.get("skill_id", "")), int(payload.get("target_uid", 0)))
		"match_tick":
			res = await Online.tick_pvp_match(String(payload.get("match_id", "")), int(payload.get("advance_ticks", 60)))
		"match_reconnect_cycle":
			var mid := String(payload.get("match_id", ""))
			res = await Online.pvp_connection(mid, "disconnected")
			if bool(res.get("ok", false)):
				res = await Online.pvp_connection(mid, "reconnected")
		"match_forfeit":
			res = await Online.forfeit_pvp_match(String(payload.get("match_id", "")))
		"replay":
			res = await Online.replay_pvp_match(String(payload.get("match_id", "")))
			if bool(res.get("ok", false)):
				replay_data = res.data
				_pvp_panel.set_tab("replay")
		"season_claim":
			res = await Online.claim_pvp_season_reward()
		"honor_buy":
			res = await Online.buy_pvp_honor_item(String(payload.get("item_id", "")))
	_busy = false
	if not is_instance_valid(_pvp_panel):
		return
	_pvp_panel.set_busy(false)
	if not bool(res.get("ok", false)):
		_pvp_panel.set_status(String(res.get("error", "演武操作未完成")))
		return
	await _refresh_pvp(replay_data)


func _close_pvp() -> void:
	if is_instance_valid(_pvp_panel):
		_pvp_panel.queue_free()
	_pvp_panel = null


func _open_channels() -> void:
	if is_instance_valid(_channels_panel) or not battle.is_empty():
		return
	_close_profiles()
	_close_journey()
	_close_social()
	_close_coop()
	_close_market()
	_close_guild()
	_close_pvp()
	_held = Vector2.ZERO
	_channels_panel = Control.new()
	_channels_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(_channels_panel)
	G.veil(_channels_panel, 0.9, true)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_channels_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	column.add_child(G.gold_label("地图分线", G.FS_BIG))
	column.add_child(G.gold_label("%s · 当前 %d线" % [_map_name, _current_channel], G.FS_SM, false))
	var list := VBoxContainer.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	column.add_child(list)
	for ch_value in _channels:
		if not ch_value is Dictionary:
			continue
		var ch := ch_value as Dictionary
		var ch_no := int(ch.get("channel", 1))
		var caption := "%d线 · %d/%d 人%s" % [ch_no, int(ch.get("player_count", 0)), int(ch.get("capacity", 24)), "（当前）" if bool(ch.get("current", false)) else ""]
		_button(list, caption, func() -> void: switch_channel(ch_no))
	_button(column, "关闭分线", _close_channels)


func _close_channels() -> void:
	if is_instance_valid(_channels_panel):
		_channels_panel.queue_free()
	_channels_panel = null


func _open_profiles() -> void:
	if is_instance_valid(_profiles) or not battle.is_empty():
		return
	_held = Vector2.ZERO
	_profiles = Control.new()
	_profiles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(_profiles)
	G.veil(_profiles, 0.9, true)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_profiles.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	column.add_child(G.gold_label("同行旅人", G.FS_BIG))
	column.add_child(G.gold_label("附近 %d 人 · 身份信息由旅人选择" % entities.size(), G.FS_SM, false))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var roster := VBoxContainer.new()
	roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster.add_theme_constant_override("separation", 12)
	scroll.add_child(roster)
	for value in entities:
		if not value is Dictionary:
			continue
		var identity := value as Dictionary
		var row := HBoxContainer.new()
		row.name = "ProfileEntry_" + String(identity.get("id", ""))
		row.set_meta("character_id", String(identity.get("id", "")))
		row.add_theme_constant_override("separation", 12)
		roster.add_child(row)
		var portrait := Field.portrait(Profile.avatar_role(identity), Vector2.ZERO, Vector2(76, 84))
		portrait.custom_minimum_size = Vector2(76, 84)
		portrait.set_meta("avatar_role", Profile.avatar_role(identity))
		row.add_child(portrait)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(words)
		var own := " · 我" if String(identity.get("id", "")) == String(Online.selected_character.get("id", "")) else ""
		words.add_child(G.gold_label(String(identity.get("nickname", "旅人")) + own, G.FS_MD))
		var role_index := maxi(0, Profile.ROLE_IDS.find(String(identity.get("role_id", "zs"))))
		words.add_child(G.gold_label("%s · %s · Lv.%d" % [["破军", "穿杨", "霜语", "晨星"][role_index], Profile.gender_name(String(identity.get("gender_id", "unspecified"))), int(identity.get("level", 1))], G.FS_SM, false))
	_button(column, "关闭名片", _close_profiles)


func _close_profiles() -> void:
	if is_instance_valid(_profiles):
		_profiles.queue_free()
	_profiles = null


class Traveller extends Node2D:
	var identity: Dictionary = {}
	var _texture: Texture2D
	var _from := Vector2.ZERO
	var _aim := Vector2.ZERO
	var _progress := 0.0
	func _ready() -> void:
		set_process(false)
		var role_id := Profile.safe_role(String(identity.get("role_id", "zs")))
		var slug := String({"zs": "pojun", "ck": "chuanyang", "fs": "shuangyu", "fz": "chenxing"}.get(role_id, "pojun"))
		var source := load("res://image/role/%s/%s_idle.png" % [role_id, slug]) as Texture2D
		var region := AtlasTexture.new()
		region.atlas = source
		region.region = Rect2(0, 0, source.get_width() / 4.0, source.get_height())
		_texture = region
		var caption := G.gold_label(String(identity.get("nickname", "旅人")), G.FS_SM, true, G.GOLD_BRIGHT if String(identity.get("id", "")) == String(Online.selected_character.get("id", "")) else G.PARCHMENT)
		caption.add_theme_color_override("font_outline_color", G.BG_DEEP)
		caption.add_theme_constant_override("outline_size", 5)
		caption.position = Vector2(-110, -122)
		caption.size = Vector2(220, 28)
		add_child(caption)
	func update_position(at: Vector2, interpolate: bool) -> void:
		if not interpolate:
			position = at
			_aim = at
			set_process(false)
		elif not _aim.is_equal_approx(at):
			_from = position
			_aim = at
			_progress = 0.0
			set_process(not position.is_equal_approx(at))
	func _process(delta: float) -> void:
		_progress = minf(_progress + delta * 10.0, 1.0)
		position = _from.lerp(_aim, _progress)
		if _progress == 1.0:
			set_process(false)
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.3))
		draw_circle(Vector2.ZERO, 23, Color(G.BG_DEEP, 0.3))
		draw_set_transform(Vector2.ZERO)
		if _texture != null:
			draw_texture_rect(_texture, Rect2(-48, -96, 96, 96), false)
