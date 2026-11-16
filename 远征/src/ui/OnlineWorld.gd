extends Node2D
## 在线世界独立于单机 MapScene；角色与战斗只接受服务端快照。

const Art := preload("res://src/world/ReferenceWorldArt.gd")
const Field := preload("res://src/ui/FieldUI.gd")
const BattlePage := preload("res://src/ui/OnlineBattle.tscn")

var auto_connect := true
var automatic_poll := true
var lease: Dictionary = {}
var entities: Array = []
var battle: Dictionary = {}
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


func _ready() -> void:
	_world.y_sort_enabled = true
	add_child(_world)
	var cfg := TableCache.main_world_map("lorin_wilds")
	var floor := Sprite2D.new()
	floor.texture = load(String(cfg.get("background", ""))) as Texture2D
	floor.centered = false
	floor.z_index = -10
	if floor.texture != null:
		floor.scale = Vector2(float(cfg.get("map_cols", 25)) * 48, float(cfg.get("map_rows", 44)) * 48) / floor.texture.get_size()
	add_child(floor)
	for id in cfg.get("city_building_positions", {}):
		var at: Array = cfg.city_building_positions[id]
		Art.add_prop(_world, "ledger" if id == "gate" else String(id), Vector2(at[0], at[1]), "props" if id == "gate" else "buildings")
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
	bottom.offset_top = -194
	bottom.offset_bottom = -16
	bottom.add_theme_constant_override("separation", 8)
	_hud.add_child(bottom)
	_challenge_button = _button(bottom, "城南试炼 · 靠近野狼后挑战", func() -> void: challenge("training_wolf"))
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
	_button(bottom, "返回在线角色", _back)
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
	lease = (data.get("lease", {}) as Dictionary).duplicate(true)
	entities = (data.get("entities", []) as Array).duplicate(true)
	_encounters = (data.get("encounters", {}) as Dictionary).duplicate(true)
	_town_label.text = "昭元边城 · 同行 %d 人" % entities.size()
	_status.text = "%s · 方向键或下方按钮移动\n城南试炼：首胜金币 10、阅历 5" % Online.selected_character.get("nickname", "旅人")
	var live_ids: Array[String] = []
	for entity_value in entities:
		if not entity_value is Dictionary:
			continue
		var entity := entity_value as Dictionary
		var id := String(entity.get("id", ""))
		live_ids.append(id)
		if not _actors.has(id):
			var actor := Traveller.new()
			actor.identity = entity
			_actors[id] = actor
			_world.add_child(actor)
		(_actors[id] as Node2D).position = Vector2(float(entity.get("x", 0)), float(entity.get("y", 0)))
	for id in _actors.keys():
		if not live_ids.has(String(id)):
			(_actors[id] as Node2D).queue_free()
			_actors.erase(id)
	_camera.position = Vector2(float(lease.get("x", 600)), float(lease.get("y", 1520)))
	if not _world.has_node("TrainingWolf") and _encounters.has("training_wolf"):
		var target := Node2D.new()
		target.name = "TrainingWolf"
		var at: Array = _encounters.training_wolf.position
		target.position = Vector2(at[0], at[1])
		_world.add_child(target)
		var picture := Sprite2D.new()
		picture.texture = load("res://image/generated_101_200/ready/map/mon_wolf.png")
		picture.position.y = -36
		picture.scale = Vector2.ONE * 0.75
		target.add_child(picture)
		var caption := G.gold_label("城南试炼 · 野狼", G.FS_SM)
		caption.position = Vector2(-90, -112)
		caption.size = Vector2(180, 30)
		target.add_child(caption)


func move_by(direction: Vector2) -> Dictionary:
	if _busy or not battle.is_empty() or lease.is_empty():
		return {"ok": false, "code": "busy"}
	_busy = true
	var target := Vector2(float(lease.x), float(lease.y)) + direction.limit_length(24)
	var result: Dictionary = await Online.move_world(lease, target)
	if bool(result.get("ok", false)):
		lease = (result.data.lease as Dictionary).duplicate(true)
		_camera.position = Vector2(float(lease.x), float(lease.y))
		var own_id := String(lease.get("character_id", ""))
		if _actors.has(own_id):
			(_actors[own_id] as Node2D).position = _camera.position
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
			lease.clear()
		var message := String(result.get("error", "连接中断，请稍后重试。"))
		_status.text = message
		if is_instance_valid(_battle_page):
			_battle_page.show_error(message)


func _process(delta: float) -> void:
	if not _connected or not automatic_poll or G.ui_blocked:
		return
	_poll_elapsed += delta
	_move_elapsed += delta
	if _busy:
		return
	if not Online.is_authenticated():
		_status.text = "登录已过期，请返回在线角色重新登录。"
		return
	if _poll_elapsed >= 0.7:
		_poll_elapsed = 0.0
		if not battle.is_empty():
			refresh_battle()
		elif lease.is_empty():
			enter_world()
		else:
			refresh_world()
		return
	if battle.is_empty() and _move_elapsed >= 0.15:
		var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if direction.is_zero_approx():
			direction = _held
		if not direction.is_zero_approx():
			_move_elapsed = 0.0
			move_by(direction.normalized() * 24)


func _back() -> void:
	_connected = false
	G.go("res://src/ui/OnlineGateway.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if not G.ui_blocked and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()


class Traveller extends Node2D:
	var identity: Dictionary = {}
	var _texture: Texture2D
	func _ready() -> void:
		var role_id := String(identity.get("role_id", "zs"))
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
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.3))
		draw_circle(Vector2.ZERO, 23, Color(G.BG_DEEP, 0.3))
		draw_set_transform(Vector2.ZERO)
		if _texture != null:
			draw_texture_rect(_texture, Rect2(-48, -96, 96, 96), false)
