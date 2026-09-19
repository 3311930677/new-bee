# verify_trait.gd —— 词条三选一抽取逻辑单测（-s 模式：godot --headless --path . -s res://tools/verify_trait.gd）
# 规则（玩法文档 §2.4）：槽1=num/mech，槽2=link(85%)/double(15%)，槽3=全池；过滤已获；槽池尽回退。
extends SceneTree

func _init() -> void:
	var fails := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260916
	var st := RunState.new()
	st.setup({"theme": "forest", "role_id": "zs", "level": 5, "seed": 1})

	# 1. 结构与去重（150 次抽取，不消费）
	for i in 150:
		var ch: Array = st.roll_trait_choices(rng)
		if ch.size() != 3:
			fails += 1
			push_error("FAIL: 应返回 3 张候选，实为 %d" % ch.size())
			break
		var t1 := String(ch[0].get("type", ""))
		var t2 := String(ch[1].get("type", ""))
		if not ["num", "mech"].has(t1):
			fails += 1
			push_error("FAIL: 槽1 应为 num/mech，实为 %s" % t1)
			break
		if not ["link", "double"].has(t2):
			fails += 1
			push_error("FAIL: 槽2 应为 link/double，实为 %s" % t2)
			break
		var ids := [String(ch[0].get("id", "")), String(ch[1].get("id", "")), String(ch[2].get("id", ""))]
		if ids[0] == ids[1] or ids[1] == ids[2] or ids[0] == ids[2]:
			fails += 1
			push_error("FAIL: 三张候选应互不重复")
			break

	# 2. 槽2 双刃频率 ≈15%（n=200，带宽 [0.08, 0.24]）
	var dbl := 0
	for i in 200:
		var ch2: Array = st.roll_trait_choices(rng)
		if String(ch2[1].get("type", "")) == "double":
			dbl += 1
	var fr := float(dbl) / 200.0
	if fr < 0.08 or fr > 0.24:
		fails += 1
		push_error("FAIL: 槽2 双刃频率 %.3f 超出带宽 [0.08, 0.24]" % fr)

	# 3. 槽池回退：link/double 全部已获时仍出满 3 张且不含已获
	var st2 := RunState.new()
	st2.setup({"seed": 2})
	for t in TableCache.traits():
		var ty := String((t as Dictionary).get("type", ""))
		if ty == "link" or ty == "double":
			st2.traits.append(String((t as Dictionary).get("id", "")))
	for i in 50:
		var ch3: Array = st2.roll_trait_choices(rng)
		if ch3.size() != 3:
			fails += 1
			push_error("FAIL: 槽池回退后应仍出 3 张，实为 %d" % ch3.size())
			break
		for r in ch3:
			if st2.traits.has(String((r as Dictionary).get("id", ""))):
				fails += 1
				push_error("FAIL: 候选不应含已获词条")
				break

	# 4. 全池尽返回空
	var st3 := RunState.new()
	st3.setup({"seed": 3})
	for t in TableCache.traits():
		st3.traits.append(String((t as Dictionary).get("id", "")))
	if not st3.roll_trait_choices(rng).is_empty():
		fails += 1
		push_error("FAIL: 全池拿光应返回空数组")

	# 5. 余量不足 3 张按余量返回
	var st4 := RunState.new()
	st4.setup({"seed": 4})
	var all_ids: Array = []
	for t in TableCache.traits():
		all_ids.append(String((t as Dictionary).get("id", "")))
	for i in all_ids.size() - 2:
		st4.traits.append(all_ids[i])
	var ch4: Array = st4.roll_trait_choices(rng)
	if ch4.size() != 2:
		fails += 1
		push_error("FAIL: 余 2 条应返回 2 张，实为 %d" % ch4.size())

	# 6. 双刃词条：代码取值必须等于 traits.json 表值（防硬编码漂移；燃血/薄甲曾错配）
	var e_rx := _eff("de_ranxue")
	var e_bj := _eff("de_baojia")
	var e_kc := _eff("de_kuangchao")
	var e_sx := _eff("de_sixian")
	var ts_rx := TraitSystem.new(["de_ranxue"])
	if not _num_ok(ts_rx.passive_atk_pct(), float(e_rx.get("atk_pct", 0.0))):
		fails += 1
		push_error("FAIL: 燃血 ATK 应 +%.2f，实为 %.2f"
			% [float(e_rx.get("atk_pct", 0.0)), ts_rx.passive_atk_pct()])
	var ts_bj := TraitSystem.new(["de_baojia"])
	if not _num_ok(ts_bj.passive_atk_pct(), float(e_bj.get("atk_pct", 0.0))) \
			or not _num_ok(ts_bj.passive_def_pct(), float(e_bj.get("def_pct", 0.0))):
		fails += 1
		push_error("FAIL: 薄甲数值与表不符（ATK %.2f / DEF %.2f）"
			% [ts_bj.passive_atk_pct(), ts_bj.passive_def_pct()])
	var ts_kc := TraitSystem.new(["de_kuangchao"])
	if not _num_ok(ts_kc.passive_spd_pct(), float(e_kc.get("spd_pct", 0.0))) \
			or not _num_ok(ts_kc.passive_dmg_taken_pct(), float(e_kc.get("dmg_taken_pct", 0.0))):
		fails += 1
		push_error("FAIL: 狂潮数值与表不符（SPD %.2f / 受伤 %.2f）"
			% [ts_kc.passive_spd_pct(), ts_kc.passive_dmg_taken_pct()])
	if not _num_ok(ts_rx.heal_taken_pct(), 0.0) or not _num_ok(ts_kc.heal_taken_pct(), 0.0):
		fails += 1
		push_error("FAIL: 非死线词条不应有治疗折减")
	# 死线：低血 ATK 倍率 = 1 + 表值 dmg_pct
	var sim_d := BattleSim.new()
	sim_d.record_events = false
	sim_d.setup(6, {"role_id": "zs", "level": 10, "traits": ["de_sixian"]},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	var u6 := sim_d.role_unit()
	var atk_full := u6.get_atk()
	u6.hp = maxi(1, int(float(u6.get_max_hp()) * 0.30))
	var ratio := float(u6.get_atk()) / float(atk_full)
	var want6 := 1.0 + float(e_sx.get("dmg_pct", 0.5))
	if absf(ratio - want6) > 0.02:
		fails += 1
		push_error("FAIL: 死线低血 ATK 应 ×%.2f，实为 ×%.2f" % [want6, ratio])

	if fails == 0:
		print("TRAIT_OK all tests passed")
	else:
		print("TRAIT_FAIL fails=%d" % fails)
	quit(0 if fails == 0 else 1)


## traits.json 里某词条的 effect（不经过 TraitSystem，做「表值 vs 代码值」对拍）
func _eff(id: String) -> Dictionary:
	for t in TableCache.traits():
		if String((t as Dictionary).get("id", "")) == id:
			return (t as Dictionary).get("effect", {})
	return {}


func _num_ok(got: float, want: float) -> bool:
	return absf(got - want) < 0.0001
