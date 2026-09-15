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

	if fails == 0:
		print("TRAIT_OK all tests passed")
	else:
		print("TRAIT_FAIL fails=%d" % fails)
	quit(0 if fails == 0 else 1)
