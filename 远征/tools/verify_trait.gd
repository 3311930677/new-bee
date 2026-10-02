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

	# 7. 三处词条接线（P1-12）：荆棘·小反伤取表值、弱点洞悉对满血加成、处决者普攻生效
	var e_th := _eff("tr_thorns_s")
	var ts_th := TraitSystem.new(["tr_thorns_s"])
	if not _num_ok(ts_th.reflect_pct(), float(e_th.get("pct", 0.0))):
		fails += 1
		push_error("FAIL: 荆棘·小反伤应取表值 %.2f，实为 %.2f"
			% [float(e_th.get("pct", 0.0)), ts_th.reflect_pct()])
	var sim7 := BattleSim.new()
	sim7.record_events = false
	sim7.setup(51, {"role_id": "zs", "level": 10, "traits": ["tr_crit_2", "tr_execute"]},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	var u7 := sim7.role_unit()
	var foe7 := sim7.alive_units("enemy")[0]
	var e_cr := _eff("tr_crit_2")
	if not _num_ok(u7.traits.crit_vs_full_hp_bonus(foe7), float(e_cr.get("crit_vs_full_hp", 0.15))):
		fails += 1
		push_error("FAIL: 弱点洞悉对满血目标应 +%.2f" % float(e_cr.get("crit_vs_full_hp", 0.15)))
	foe7.hp = 1
	if not _num_ok(u7.traits.crit_vs_full_hp_bonus(foe7), 0.0):
		fails += 1
		push_error("FAIL: 弱点洞悉对残血目标不应加成")
	var e_ex := _eff("tr_execute")
	var want7 := int(100.0 * (1.0 + float(e_ex.get("dmg_pct", 0.25))))
	var boosted := u7.traits.modify_outgoing(u7, foe7, 100, false, false)
	if boosted != want7:
		fails += 1
		push_error("FAIL: 处决者应在普攻路径生效（100 → %d，期望 %d）" % [boosted, want7])

	# 8. 流派偏置（B2）：已持有同系词条后，三选一应优先出本系
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 20260921
	var st5 := RunState.new()
	st5.setup({"seed": 5})
	st5.traits = ["tr_bleed_1"]
	var st6 := RunState.new()
	st6.setup({"seed": 6})
	var trials := 200
	var hit_bias := 0
	var hit_plain := 0
	for i in trials:
		var cb: Array = st5.roll_trait_choices(rng2)
		for r in cb:
			if String((r as Dictionary).get("school", "none")) == "bleed":
				hit_bias += 1
				break
		var cp: Array = st6.roll_trait_choices(rng2)
		for r in cp:
			if String((r as Dictionary).get("school", "none")) == "bleed":
				hit_plain += 1
				break
	var rb := float(hit_bias) / float(trials)
	var rp := float(hit_plain) / float(trials)
	if rb <= 0.60:
		fails += 1
		push_error("FAIL: 偏置后「三选一里至少一张本系」的命中率 %.2f 应显著高于随机" % rb)
	if rb <= rp + 0.20:
		fails += 1
		push_error("FAIL: 偏置命中率 %.2f 应显著高于无偏置 %.2f" % [rb, rp])

	# 9. 硬编码归表（N-05）：代码取值必须等于 traits.json / growth.json 表值（防「改表不生效」）
	#    先发制人 ×2、越战越勇 0.06/5 层、碎冰 0.20、凝神 0.12、普攻能量 20 都已改为读表。
	var e_fs := _eff("tr_first_strike")
	var ts_fs := TraitSystem.new(["tr_first_strike"])
	if not ts_fs.has_first_strike() \
			or not _num_ok(ts_fs.first_strike_k(), float(e_fs.get("first_hit_k", 2.0))):
		fails += 1
		push_error("FAIL: 先发制人倍率应取表值 %.2f，实为 %.2f"
			% [float(e_fs.get("first_hit_k", 2.0)), ts_fs.first_strike_k()])
	var e_rp := _eff("tr_rampage")
	var sim_rp := BattleSim.new()
	sim_rp.record_events = false
	sim_rp.setup(70, {"role_id": "zs", "level": 10, "traits": ["tr_rampage"]},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	var u_rp := sim_rp.role_unit()
	u_rp.rampage_stacks = 3
	var want_rp := float(e_rp.get("atk_pct_per_kill", 0.06)) * 3.0
	if absf(u_rp.traits.dynamic_atk_pct(u_rp) - want_rp) > 0.0001:
		fails += 1
		push_error("FAIL: 越战越勇 3 层 ATK 加成应为 %.2f，实为 %.2f"
			% [want_rp, u_rp.traits.dynamic_atk_pct(u_rp)])
	var cap_rp := maxi(1, int(e_rp.get("stack", 5)))
	for i in cap_rp + 3:
		u_rp.traits.on_kill(sim_rp, u_rp, u_rp)
	if u_rp.rampage_stacks != cap_rp:
		fails += 1
		push_error("FAIL: 越战越勇叠层上限应取表值 %d，实为 %d" % [cap_rp, u_rp.rampage_stacks])
	var e_ct := _eff("tr_ctrl_2")
	var sim_ct := BattleSim.new()
	sim_ct.record_events = false
	sim_ct.setup(71, {"role_id": "zs", "level": 10, "traits": ["tr_ctrl_2"]},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	var u_ct := sim_ct.role_unit()
	var foe_ct := sim_ct.alive_units("enemy")[0]
	foe_ct.add_buff("stun", 30, {})
	var want_ct := int(100.0 * (1.0 + float(e_ct.get("vs_controlled_pct", 0.20))))
	if u_ct.traits.modify_outgoing(u_ct, foe_ct, 100, false, false) != want_ct:
		fails += 1
		push_error("FAIL: 碎冰对受控目标 100 → 期望 %d（表值 %.2f）"
			% [want_ct, float(e_ct.get("vs_controlled_pct", 0.20))])
	var e_fc := _eff("tr_focus")
	var ts_fc := TraitSystem.new(["tr_focus"])
	var want_fc := int(100.0 * (1.0 + float(e_fc.get("skill_dmg_pct", 0.12))))
	if ts_fc.modify_outgoing(u_ct, foe_ct, 100, true, false) != want_fc:
		fails += 1
		push_error("FAIL: 凝神技能伤害 100 → 期望 %d（表值 %.2f）"
			% [want_fc, float(e_fc.get("skill_dmg_pct", 0.12))])
	var e_pe := int((TableCache.growth().get("energy", {}) as Dictionary).get("per_basic_attack", 20))
	var sim_pe := BattleSim.new()
	sim_pe.record_events = false
	sim_pe.setup(72, {"role_id": "zs", "level": 10, "traits": []},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	var u_pe := sim_pe.role_unit()
	u_pe.energy = 0
	u_pe.do_basic_attack(sim_pe)
	if u_pe.energy != e_pe:
		fails += 1
		push_error("FAIL: 普攻应回 %d 能量（growth.json 表值），实为 %d" % [e_pe, u_pe.energy])

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
