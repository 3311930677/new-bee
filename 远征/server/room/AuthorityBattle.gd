extends RefCounted
## 无 autoload、无玩家存档、无数据库；共用客户端的 BattleSim 源码。

var sim: BattleSim
var initial: Dictionary = {}
var inputs: Array[Dictionary] = []
var receipts: Dictionary = {}
var opened_msec := 0
var initial_tick := 0
var external_clock := false


static func battle_config(config: Dictionary) -> Dictionary:
	if String(config.get("mode", "")) == "pvp":
		return _pvp_battle_config(config)
	if config.get("members") is Array and not (config.get("members") as Array).is_empty():
		return _coop_battle_config(config)
	var result := {"role_id": config.get("role_id"), "monster_id": config.get("monster_id"),
		"level": config.get("level"), "seed": config.get("seed")}
	var raw: Variant = config.get("loadout", {})
	if not raw is Dictionary:
		return {}
	var gear: Dictionary = raw
	var limits := {"attack": 200, "defense": 200, "health": 1000, "potions": 20}
	var loadout := {}
	for field in limits:
		var amount: Variant = gear.get(field, 0)
		if not (amount is int or amount is float) or not is_finite(float(amount)):
			return {}
		if float(amount) < 0.0 or float(amount) > float(limits[field]) or float(amount) != floor(float(amount)):
			return {}
		if int(amount) != 0:
			loadout[field] = int(amount)
	var companion := String(gear.get("active_pet", ""))
	if not companion.is_empty():
		if companion != "pet_rockturtle" or TableCache.get_pet(companion).is_empty():
			return {}
		loadout["active_pet"] = companion
	if not loadout.is_empty():
		result["loadout"] = loadout
	return result


static func _clean_loadout(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var gear: Dictionary = raw
	var limits := {"attack": 200, "defense": 200, "health": 1000, "potions": 20}
	var loadout := {}
	for field in limits:
		var amount: Variant = gear.get(field, 0)
		if not (amount is int or amount is float) or not is_finite(float(amount)):
			return {"_invalid": true}
		if float(amount) < 0.0 or float(amount) > float(limits[field]) or float(amount) != floor(float(amount)):
			return {"_invalid": true}
		if int(amount) != 0:
			loadout[field] = int(amount)
	var companion := String(gear.get("active_pet", ""))
	if not companion.is_empty():
		if companion != "pet_rockturtle" or TableCache.get_pet(companion).is_empty():
			return {"_invalid": true}
		loadout["active_pet"] = companion
	return loadout


static func _coop_battle_config(config: Dictionary) -> Dictionary:
	var raw_members := config.get("members") as Array
	if raw_members.size() < 1 or raw_members.size() > 4:
		return {}
	var seed := int(config.get("seed", -1))
	var monster_id := String(config.get("monster_id", ""))
	if seed < 0 or seed > 9007199254740991 or TableCache.get_monster(monster_id).is_empty():
		return {}
	var members: Array = []
	for mv in raw_members:
		if not mv is Dictionary:
			return {}
		var m := mv as Dictionary
		var cid := String(m.get("character_id", ""))
		var role_id := String(m.get("role_id", ""))
		var level := int(m.get("level", 0))
		if cid.is_empty() or not ["zs", "ck", "fs", "fz"].has(role_id) or level < 1 or level > 60:
			return {}
		var lo := _clean_loadout(m.get("loadout", {}))
		if lo.has("_invalid"):
			return {}
		var entry := {"character_id": cid, "role_id": role_id, "level": level}
		if not String(m.get("name", "")).is_empty():
			entry["name"] = String(m.get("name", ""))
		if not lo.is_empty():
			entry["loadout"] = lo
		members.append(entry)
	var result := {"mode": "coop", "monster_id": monster_id, "seed": seed, "members": members,
		"downed_window_ticks": clampi(int(config.get("downed_window_ticks", 450)), 0, 1800)}
	if config.get("coop_scaling") is Dictionary:
		var cs := config.get("coop_scaling") as Dictionary
		var clean_cs := {"hp_mult": float(cs.get("hp_mult", 1.0)), "atk_mult": float(cs.get("atk_mult", 1.0)),
			"def_mult": float(cs.get("def_mult", 1.0)), "extra_adds": clampi(int(cs.get("extra_adds", 0)), 0, 4)}
		if not String(cs.get("add_monster_id", "")).is_empty():
			clean_cs["add_monster_id"] = String(cs.get("add_monster_id", ""))
		result["coop_scaling"] = clean_cs
	return result


static func _clean_pvp_team(raw_team: Variant, want_size: int) -> Array:
	if not (raw_team is Array):
		return []
	var arr := raw_team as Array
	if arr.size() != want_size:
		return []
	var team: Array = []
	for mv in arr:
		if not (mv is Dictionary):
			return []
		var m := mv as Dictionary
		var cid := String(m.get("character_id", ""))
		var role_id := String(m.get("role_id", ""))
		var level := int(m.get("level", 0))
		if cid.is_empty() or not ["zs", "ck", "fs", "fz"].has(role_id) or level < 1 or level > 60:
			return []
		var lo := _clean_loadout(m.get("loadout", {}))
		if lo.has("_invalid"):
			return []
		var entry := {"character_id": cid, "role_id": role_id, "level": level}
		if not String(m.get("name", "")).is_empty():
			entry["name"] = String(m.get("name", ""))
		if not lo.is_empty():
			entry["loadout"] = lo
		team.append(entry)
	return team


static func _pvp_battle_config(config: Dictionary) -> Dictionary:
	var fmt := String(config.get("pvp_format", ""))
	var want_size := 1 if fmt == "1v1" else (2 if fmt == "2v2" else (3 if fmt == "3v3" else 0))
	if want_size == 0:
		return {}
	var seed := int(config.get("seed", -1))
	if seed < 0 or seed > 9007199254740991:
		return {}
	var team_a := _clean_pvp_team(config.get("team_a"), want_size)
	var team_b := _clean_pvp_team(config.get("team_b"), want_size)
	if team_a.is_empty() or team_b.is_empty():
		return {}
	var default_max := 7200 if want_size == 3 else 5400
	return {
		"mode": "pvp",
		"pvp_format": fmt,
		"seed": seed,
		"team_a": team_a,
		"team_b": team_b,
		"pvp_max_ticks": clampi(int(config.get("pvp_max_ticks", default_max)), 300, BattleSim.MAX_TICKS),
		"aoe_target_cap": clampi(int(config.get("aoe_target_cap", 3)), 1, 4),
		"pvp_heal_mult": clampf(float(config.get("pvp_heal_mult", 0.85)), 0.4, 1.2),
	}


func _to_member_cfgs(arr: Array) -> Array:
	var out: Array = []
	for mv in arr:
		var m := mv as Dictionary
		var lo: Dictionary = m.get("loadout", {})
		var g := {"atk_add": int(lo.get("attack", 0)), "def_add": int(lo.get("defense", 0)),
			"hp_add": int(lo.get("health", 0))}
		out.append({"character_id": String(m.get("character_id", "")),
			"role_id": String(m.get("role_id", "zs")), "level": int(m.get("level", 1)),
			"name": String(m.get("name", "")), "traits": [], "growth": g,
			"active_pet": String(lo.get("active_pet", "")), "potions": int(lo.get("potions", 0))})
	return out


func setup(config: Dictionary) -> bool:
	var normalized := battle_config(config)
	if normalized.is_empty():
		return false
	if String(normalized.get("mode", "")) == "pvp":
		initial = normalized
		var a_cfgs := _to_member_cfgs(normalized.get("team_a", []) as Array)
		var b_cfgs := _to_member_cfgs(normalized.get("team_b", []) as Array)
		sim = BattleSim.new()
		sim.setup(int(normalized.get("seed", 0)), {
			"pvp_mode": true,
			"members": a_cfgs,
			"opponents": b_cfgs,
			"pvp_max_ticks": int(normalized.get("pvp_max_ticks", 5400)),
			"aoe_target_cap": int(normalized.get("aoe_target_cap", 3)),
			"pvp_heal_mult": float(normalized.get("pvp_heal_mult", 0.85)),
		}, {"theme": "forest"})
		sim.manual_basic_attack = true
		sim.auto_mode = false
		opened_msec = Time.get_ticks_msec()
		return sim.setup_error.is_empty()
	if String(normalized.get("mode", "")) == "coop":
		initial = normalized
		var member_cfgs: Array = []
		for mv in normalized.get("members", []):
			var m := mv as Dictionary
			var lo: Dictionary = m.get("loadout", {})
			var g := {"atk_add": int(lo.get("attack", 0)), "def_add": int(lo.get("defense", 0)),
				"hp_add": int(lo.get("health", 0))}
			member_cfgs.append({"character_id": String(m.get("character_id", "")),
				"role_id": String(m.get("role_id", "zs")), "level": int(m.get("level", 1)),
				"name": String(m.get("name", "")), "traits": [], "growth": g,
				"active_pet": String(lo.get("active_pet", "")), "potions": int(lo.get("potions", 0))})
		var enemy_cfg := {"theme": "tomb", "custom_mon": TableCache.get_monster(String(normalized.get("monster_id", ""))).duplicate(true)}
		if normalized.has("coop_scaling"):
			enemy_cfg["coop_scaling"] = (normalized.get("coop_scaling") as Dictionary).duplicate(true)
		sim = BattleSim.new()
		sim.setup(int(normalized.get("seed", 0)), {"members": member_cfgs,
			"downed_window_ticks": int(normalized.get("downed_window_ticks", 450))}, enemy_cfg)
		sim.manual_basic_attack = true
		sim.auto_mode = false
		opened_msec = Time.get_ticks_msec()
		return sim.setup_error.is_empty()
	var role_id := String(config.get("role_id", ""))
	var monster_id := String(config.get("monster_id", ""))
	if not ["zs", "ck", "fs", "fz"].has(role_id) or TableCache.get_monster(monster_id).is_empty():
		return false
	var level := int(config.get("level", 0))
	var seed := int(config.get("seed", -1))
	if level < 1 or level > 60 or seed < 0 or seed > 9007199254740991:
		return false
	initial = normalized
	var loadout: Dictionary = initial.get("loadout", {})
	var growth := {"atk_add": int(loadout.get("attack", 0)), "def_add": int(loadout.get("defense", 0)),
		"hp_add": int(loadout.get("health", 0))}
	sim = BattleSim.new()
	sim.setup(seed, {"role_id": role_id, "level": level, "traits": [], "growth": growth,
		"active_pet": String(loadout.get("active_pet", "")), "potions": int(loadout.get("potions", 0))},
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
	var expected_config := battle_config(config)
	if expected_config.is_empty():
		return {"ok": false, "error": "invalid_loadout"}
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
	var actor_uid := sim.role_uid
	var cid := String(action.get("character_id", ""))
	if sim.coop_mode:
		if cid.is_empty() or not sim.member_uids.has(cid):
			if String(action.get("action", "")) != "flee":
				return {"accepted": false, "reason": "unknown_actor"}
		else:
			actor_uid = int(sim.member_uids[cid])
	match String(action.get("action", "")):
		"attack":
			var reason := sim.trigger_manual_attack_for(actor_uid) if sim.coop_mode else sim.trigger_manual_attack()
			return {"accepted": reason == "attacked", "reason": reason}
		"skill":
			var ok := sim.cast_skill(actor_uid, String(action.get("skill_id", "")), int(action.get("target_uid", -1)))
			return {"accepted": ok, "reason": "cast" if ok else "unavailable"}
		"potion":
			var ok := sim.use_potion_for(actor_uid) if sim.coop_mode else sim.use_potion()
			return {"accepted": ok, "reason": "used" if ok else "unavailable"}
		"rescue":
			return sim.rescue_ally(actor_uid, int(action.get("target_uid", -1)))
		"focus":
			var ok := sim.set_role_focus_target_for(actor_uid, int(action.get("target_uid", -1)))
			return {"accepted": ok, "reason": "focused" if ok else "invalid_target"}
		"safe_defend":
			var ok := sim.set_safe_defend(actor_uid, bool(action.get("enabled", true)))
			return {"accepted": ok, "reason": "updated" if ok else "invalid_actor"}
		"timeout_default":
			var reason := sim.trigger_manual_attack_for(actor_uid)
			if reason == "attacked":
				return {"accepted": true, "reason": "timeout_attack"}
			var ok := sim.set_safe_defend(actor_uid, true)
			return {"accepted": ok, "reason": "timeout_defend" if ok else "invalid_actor"}
		"forfeit":
			if sim.pvp_mode:
				var actor := sim.unit_by_uid(actor_uid)
				if actor == null:
					return {"accepted": false, "reason": "unknown_actor"}
				sim.winner_side = "enemy" if actor.side == "ally" else "ally"
				sim.result = "defeat" if sim.winner_side == "enemy" else "victory"
				sim.finished = true
				return {"accepted": true, "reason": "forfeited"}
			sim.finished = true
			sim.result = "flee"
			return {"accepted": true, "reason": "fled"}
		"flee":
			if sim.pvp_mode:
				return {"accepted": false, "reason": "pvp_use_forfeit"}
			sim.finished = true
			sim.result = "flee"
			return {"accepted": true, "reason": "fled"}
	return {"accepted": false, "reason": "invalid_action"}


func snapshot() -> Dictionary:
	var units: Array = []
	for unit in sim.units:
		var u_row := {"uid": unit.uid, "kind": unit.kind, "side": unit.side,
			"template_id": String(unit.data.get("id", "")), "name": unit.name,
			"hp": unit.hp, "max_hp": unit.get_max_hp(), "alive": unit.alive,
			"energy": unit.energy, "attack_timer": unit.attack_timer,
			"row": unit.row, "col": unit.col, "atk": unit.get_atk(), "def": unit.get_def(),
			"speed": unit.get_spd(), "buffs": unit.buffs.duplicate(true),
			"skills": unit.skills.duplicate(true), "once_flags": unit.once_flags.duplicate(true)}
		if sim.coop_mode:
			u_row["coop_slot"] = unit.coop_slot
			u_row["owner_uid"] = unit.owner_uid
			u_row["downed"] = unit.downed
			u_row["downed_ticks"] = unit.downed_ticks
		units.append(u_row)
	var state := {"tick": sim.tick_count, "finished": sim.finished, "result": sim.result,
		"role_uid": sim.role_uid, "units": units, "potions": sim.potions_left,
		"potion_cd": sim.potion_cd_ticks, "cast_queue": sim.cast_queue.duplicate(true),
		"last_cast": sim.last_cast.duplicate(true), "rng_state": str(sim.rng.state)}
	if sim.coop_mode:
		var member_stats: Dictionary = {}
		for cid_key in sim.member_uids.keys():
			var uid := int(sim.member_uids[cid_key])
			var u := sim.unit_by_uid(uid)
			if u == null:
				continue
			member_stats[String(cid_key)] = {
				"uid": uid,
				"side": u.side,
				"hp": u.hp,
				"max_hp": u.get_max_hp(),
				"alive": u.alive,
				"downed": u.downed,
				"downed_ticks": u.downed_ticks,
				"energy": u.energy,
				"potions": int(sim.role_potions.get(uid, 0)),
				"potion_cd": int(sim.role_potion_cd.get(uid, 0)),
				"damage_dealt": u.damage_dealt,
				"healing_done": u.healing_done,
				"rescues": int(sim.rescue_counts.get(uid, 0)),
				"actions": int(sim.action_counts.get(uid, 0)),
				"safe_defend": bool(sim.safe_defend_uids.get(uid, false)),
			}
		state["coop_members"] = member_stats
		if sim.pvp_mode:
			state["pvp"] = true
			state["winner_side"] = sim.winner_side
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
