extends RefCounted
## 无 autoload、无玩家存档、无数据库；共用客户端的 BattleSim 源码。

var sim: BattleSim
var initial: Dictionary = {}
var inputs: Array[Dictionary] = []
var receipts: Dictionary = {}
var opened_msec := 0
var initial_tick := 0
var external_clock := false


func setup(config: Dictionary) -> bool:
	var role_id := String(config.get("role_id", ""))
	var monster_id := String(config.get("monster_id", ""))
	if not ["zs", "ck", "fs", "fz"].has(role_id) or TableCache.get_monster(monster_id).is_empty():
		return false
	var level := int(config.get("level", 0))
	var seed := int(config.get("seed", -1))
	if level < 1 or level > 60 or seed < 0 or seed > 9007199254740991:
		return false
	initial = {"role_id": role_id, "monster_id": monster_id, "level": level, "seed": seed}
	sim = BattleSim.new()
	sim.setup(seed, {"role_id": role_id, "level": level, "traits": [], "active_pet": "", "potions": 0},
		{"theme": "forest", "custom_mon": TableCache.get_monster(monster_id).duplicate(true)})
	sim.manual_basic_attack = true
	sim.auto_mode = false
	opened_msec = Time.get_ticks_msec()
	return sim.setup_error.is_empty()


func advance(now_msec: int) -> void:
	if external_clock:
		return
	var target := mini(BattleSim.MAX_TICKS, int(float(now_msec - opened_msec) * BattleSim.TICK_RATE / 1000.0))
	var budget := 120
	while not sim.finished and sim.tick_count < target and budget > 0:
		sim.step()
		budget -= 1
	# Presentation events are not the authoritative input log. Snapshots expose state;
	# an event stream with per-client cursors is added by the public room transport.
	sim.events.clear()


func synchronize(config: Dictionary, intentions: Array, target_tick: int) -> Dictionary:
	if target_tick < 0 or target_tick > BattleSim.MAX_TICKS or intentions.size() > 6000:
		return {"ok": false, "error": "invalid_journal"}
	var expected_config := {"role_id": config.get("role_id"), "monster_id": config.get("monster_id"), "level": config.get("level"), "seed": config.get("seed")}
	var confirmed_sequence := int(config.get("confirmed_sequence", 0))
	var confirmed_tick := int(config.get("confirmed_tick", 0))
	var expected_hash := String(config.get("expected_state_hash", ""))
	if confirmed_sequence < 0 or confirmed_sequence > intentions.size() or confirmed_tick < 0 or confirmed_tick > target_tick:
		return {"ok": false, "error": "invalid_checkpoint"}
	var reset := sim == null or JSON.stringify(initial, "", true) != JSON.stringify(expected_config, "", true)
	if not reset:
		reset = sim.tick_count > target_tick or inputs.size() > intentions.size()
		# Any provisional execution may belong to a rolled-back database transaction.
		# Rebuild it from the committed prefix before accepting another input.
		if not expected_hash.is_empty():
			reset = reset or inputs.size() != confirmed_sequence or sim.tick_count != confirmed_tick
			if not reset:
				reset = String(snapshot().state_hash) != expected_hash
	var last_tick := 0
	for i in intentions.size():
		if not intentions[i] is Dictionary:
			return {"ok": false, "error": "invalid_journal"}
		var entry := intentions[i] as Dictionary
		var tick := int(entry.get("tick", -1))
		if int(entry.get("sequence", 0)) != i + 1 or tick < last_tick or tick > target_tick or not entry.get("action") is Dictionary:
			return {"ok": false, "error": "invalid_journal"}
		last_tick = tick
		if (i < confirmed_sequence and tick > confirmed_tick) or (i >= confirmed_sequence and tick < confirmed_tick):
			return {"ok": false, "error": "invalid_checkpoint"}
		if i < inputs.size():
			if tick != int(inputs[i].tick) or JSON.stringify(entry.action, "", true) != JSON.stringify(inputs[i].action, "", true):
				reset = true
			elif entry.has("accepted") and (bool(entry.accepted) != bool(inputs[i].accepted) or String(entry.get("reason", "")) != String(inputs[i].reason) or int(entry.get("applied_tick", -1)) != int(inputs[i].applied_tick)):
				return {"ok": false, "error": "journal_diverged"}
		elif sim != null and tick < sim.tick_count:
			reset = true
	if reset:
		inputs.clear()
		receipts.clear()
		if not setup(expected_config):
			return {"ok": false, "error": "setup_failed"}
	external_clock = true
	var verified_checkpoint := expected_hash.is_empty()
	for i in range(inputs.size(), intentions.size()):
		if not verified_checkpoint and i == confirmed_sequence:
			while not sim.finished and sim.tick_count < confirmed_tick:
				sim.step()
			if String(snapshot().state_hash) != expected_hash:
				return {"ok": false, "error": "checkpoint_diverged"}
			verified_checkpoint = true
		var entry := intentions[i] as Dictionary
		while not sim.finished and sim.tick_count < int(entry.tick):
			sim.step()
		var applied := apply_action(entry.action)
		if entry.has("accepted") and (bool(entry.accepted) != bool(applied.accepted) or String(entry.get("reason", "")) != String(applied.reason) or int(entry.get("applied_tick", -1)) != sim.tick_count):
			return {"ok": false, "error": "journal_diverged"}
		inputs.append({"sequence": i + 1, "tick": int(entry.tick), "action": entry.action.duplicate(true),
			"applied_tick": sim.tick_count, "accepted": applied.accepted, "reason": applied.reason})
	if not verified_checkpoint:
		while not sim.finished and sim.tick_count < confirmed_tick:
			sim.step()
		if String(snapshot().state_hash) != expected_hash:
			return {"ok": false, "error": "checkpoint_diverged"}
	while not sim.finished and sim.tick_count < target_tick:
		sim.step()
	sim.events.clear()
	return {"ok": true, "state": snapshot(), "inputs": inputs.duplicate(true)}


func command(sequence: int, action: Dictionary) -> Dictionary:
	if sequence < 1 or sequence > 6000:
		return {"ok": false, "error": "invalid_sequence"}
	var serialized := JSON.stringify(action, "", true)
	if receipts.has(sequence):
		var old: Dictionary = receipts[sequence]
		if String(old.action) != serialized:
			return {"ok": false, "error": "sequence_conflict"}
		return old.reply.duplicate(true)
	if sequence != inputs.size() + 1:
		return {"ok": false, "error": "sequence_out_of_order"}
	var applied := apply_action(action)
	inputs.append({"sequence": sequence, "tick": sim.tick_count, "action": action.duplicate(true),
		"accepted": applied.accepted, "reason": applied.reason})
	# Keep receipts bounded: clients fetch state separately instead of retaining a
	# complete unit/skill snapshot for each of up to 6,000 input commands.
	var state := snapshot()
	var reply := {"ok": true, "sequence": sequence, "accepted": applied.accepted,
		"reason": applied.reason, "tick": sim.tick_count, "state_hash": state.state_hash}
	receipts[sequence] = {"action": serialized, "reply": reply.duplicate(true)}
	return reply


func apply_action(action: Dictionary) -> Dictionary:
	if sim.finished:
		return {"accepted": false, "reason": "finished"}
	match String(action.get("action", "")):
		"attack":
			var reason := sim.trigger_manual_attack()
			return {"accepted": reason == "attacked", "reason": reason}
		"skill":
			var ok := sim.cast_skill(sim.role_uid, String(action.get("skill_id", "")), int(action.get("target_uid", -1)))
			return {"accepted": ok, "reason": "cast" if ok else "unavailable"}
		"potion":
			var ok := sim.use_potion()
			return {"accepted": ok, "reason": "used" if ok else "unavailable"}
		"flee":
			sim.finished = true
			sim.result = "flee"
			return {"accepted": true, "reason": "fled"}
	return {"accepted": false, "reason": "invalid_action"}


func snapshot() -> Dictionary:
	var units: Array = []
	for unit in sim.units:
		units.append({"uid": unit.uid, "kind": unit.kind, "side": unit.side,
			"template_id": String(unit.data.get("id", "")), "name": unit.name,
			"hp": unit.hp, "max_hp": unit.get_max_hp(), "alive": unit.alive,
			"energy": unit.energy, "attack_timer": unit.attack_timer,
			"row": unit.row, "col": unit.col, "atk": unit.get_atk(), "def": unit.get_def(),
			"speed": unit.get_spd(), "buffs": unit.buffs.duplicate(true),
			"skills": unit.skills.duplicate(true), "once_flags": unit.once_flags.duplicate(true)})
	var state := {"tick": sim.tick_count, "finished": sim.finished, "result": sim.result,
		"role_uid": sim.role_uid, "units": units, "potions": sim.potions_left,
		"potion_cd": sim.potion_cd_ticks, "cast_queue": sim.cast_queue.duplicate(true),
		"last_cast": sim.last_cast.duplicate(true), "rng_state": str(sim.rng.state)}
	state["state_hash"] = JSON.stringify(state, "", true, true).sha256_text()
	return state


func replay(log: Array, target_tick: int) -> Dictionary:
	if log.size() > 6000 or target_tick < 0 or target_tick > BattleSim.MAX_TICKS:
		return {"ok": false, "error": "invalid_replay"}
	var copy := get_script().new() as RefCounted
	if not copy.setup(initial):
		return {"ok": false, "error": "setup_failed"}
	var expected_sequence := 1
	for entry_value in log:
		if not entry_value is Dictionary:
			return {"ok": false, "error": "invalid_replay"}
		var entry := entry_value as Dictionary
		var tick := int(entry.get("tick", -1))
		if int(entry.get("sequence", -1)) != expected_sequence or tick < copy.sim.tick_count or tick > target_tick or not entry.get("action") is Dictionary:
			return {"ok": false, "error": "invalid_replay"}
		while copy.sim.tick_count < tick and not copy.sim.finished:
			copy.sim.step()
		if copy.sim.tick_count != tick:
			return {"ok": false, "error": "invalid_replay"}
		var result: Dictionary = copy.apply_action(entry.action)
		if bool(result.accepted) != bool(entry.get("accepted", false)) or String(result.reason) != String(entry.get("reason", "")):
			return {"ok": false, "error": "replay_diverged"}
		expected_sequence += 1
	while copy.sim.tick_count < target_tick and not copy.sim.finished:
		copy.sim.step()
	if copy.sim.tick_count != target_tick:
		return {"ok": false, "error": "invalid_replay"}
	return {"ok": true, "state": copy.snapshot()}
