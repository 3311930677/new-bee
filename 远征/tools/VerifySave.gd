# VerifySave.gd —— 存档完整性回归（场景模式：godot --headless --path . res://tools/VerifySave.tscn）
# 守问题清单 #39（版本闸门/逐版迁移/未来版本拒绝写回/坏档 fixture）与 #24（未来时间水位）。
# 用 tools/fixtures/saves/ 下的真实旧档样本，而不是在用例里现编结构。
extends Node

const FIX := "res://tools/fixtures/saves/"

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "user://save_verify_save.json"
	await get_tree().process_frame
	await _run()
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


func _fixture(name: String) -> Dictionary:
	var f := FileAccess.open(FIX + name, FileAccess.READ)
	if f == null:
		push_error("fixture 缺失：" + name)
		return {}
	var t := f.get_as_text()
	f.close()
	var v: Variant = JSON.parse_string(t)
	return v if v is Dictionary else {}


func _fixture_text(name: String) -> String:
	var f := FileAccess.open(FIX + name, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t


func _wipe(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _run() -> void:
	var now := int(Time.get_unix_time_from_system())

	# ---- A. 版本常量同源 ----
	_check(SaveData.CURRENT_VERSION == G.SAVE_VERSION,
		"SaveData.CURRENT_VERSION(%d) 应与 G.SAVE_VERSION(%d) 同源"
		% [SaveData.CURRENT_VERSION, G.SAVE_VERSION])

	# ---- B. 逐版迁移 ----
	var v1 := SaveData.migrate(_fixture("v1.json"))
	_check(bool(v1["ok"]), "v1 档应可迁移（%s）" % String(v1["err"]))
	_check(int(v1["to"]) == SaveData.CURRENT_VERSION, "v1 应迁到 %d" % SaveData.CURRENT_VERSION)
	_check((v1["steps"] as Array).size() == SaveData.CURRENT_VERSION - 1,
		"v1 应逐级走完 %d 步，实为 %s" % [SaveData.CURRENT_VERSION - 1, str(v1["steps"])])
	var v1d: Dictionary = v1["data"]
	_check(v1d.get("prog") is Dictionary,
		"v1→v2 应把 prog=null 归一成字典（否则后面所有读取都会踩空）")
	_check(int((v1d.get("wallet", {}) as Dictionary).get("gold", -1)) == 100, "迁移不该改动已有数值")

	var v2 := SaveData.migrate(_fixture("v2.json"))
	_check(bool(v2["ok"]), "v2 档应可迁移")
	var v2d: Dictionary = v2["data"]
	var v2items: Dictionary = v2d.get("items", {})
	_check(not v2items.has("gacha_pity"), "v2→v3 应从道具背包清掉 gacha_pity")
	_check(int(((v2d.get("prog", {}) as Dictionary).get("gacha", {}) as Dictionary).get("pity", 0)) == 42,
		"v2 的 gacha_pity 应搬进 prog.gacha.pity，实为 %s"
		% str(((v2d.get("prog", {}) as Dictionary).get("gacha", {}) as Dictionary).get("pity")))
	# 幂等：再迁一次不该改动结果
	var v2again: Dictionary = SaveData.migrate(v2d)["data"]
	_check(JSON.stringify(v2again.get("prog", {})) == JSON.stringify(v2d.get("prog", {})),
		"迁移必须幂等：对已迁移的档再跑不改动内容")

	var v3 := SaveData.migrate(_fixture("v3.json"))
	_check(bool(v3["ok"]), "v3 档应可迁移到 v%d" % SaveData.CURRENT_VERSION)
	_check(str(v3["steps"]) == "[\"v3→v4\", \"v4→v5\", \"v5→v6\", \"v6→v7\"]",
		"v3 应逐级迁到 v7，实为 %s" % str(v3["steps"]))
	_check(int(((v3["data"] as Dictionary).get("wallet", {}) as Dictionary).get("gold", 0)) == 777,
		"v3 迁移不该改动数据")

	# ---- B2. v3→v4 结构落位（P02） ----
	var v3d: Dictionary = v3["data"]
	var v3p: Dictionary = v3d.get("prog", {})
	var v3mw: Dictionary = v3p.get("main_world", {})
	_check(v3mw.get("encounters", null) is Dictionary, "v3→v4 应给 main_world 补出 encounters 对象")
	_check(v3mw.get("respawn_by_map", null) is Dictionary, "v3→v4 应给 main_world 补出 respawn_by_map 对象")
	_check(v3mw.get("bosses_cleared", null) is Array, "v3→v4 应给 main_world 补出 bosses_cleared 数组")
	_check(v3p.get("ledger", null) is Dictionary and (v3p["ledger"] as Dictionary).get("applied", null) is Array,
		"v3→v4 应补出 ledger.applied（奖励事务去重表）")
	_check(v3p.get("flags", null) is Dictionary, "v3→v4 应补出 flags 对象")
	# 旧档带进度：respawn_at 折进 respawn_by_map、done[] 映射成 goals、killed 清掉
	var lpmig_v4 := SaveData.migrate(_fixture("legacy_v3_progress.json"))
	_check(bool(lpmig_v4["ok"]), "带进度的 v3 夹具应可迁移到 v4")
	var lpv4mw: Dictionary = ((lpmig_v4["data"] as Dictionary).get("prog", {}) as Dictionary).get("main_world", {})
	var lpper: Dictionary = (lpv4mw.get("respawn_by_map", {}) as Dictionary)
	_check((lpper.get("broken_slope", {}) as Dictionary).get("2", 0.0) == 1789900000.0,
		"旧单图 respawn_at 应折进 respawn_by_map[broken_slope]，实为 %s" % str(lpper))
	_check(not lpv4mw.has("killed"), "历史遗留的 killed[] 应在 v4 落位时清掉")
	var lpstory: Dictionary = ((lpmig_v4["data"] as Dictionary).get("prog", {}) as Dictionary).get("story", {})
	_check((lpstory.get("goals", {}) as Dictionary).size() == 8,
		"旧 done[] 应映射成 goals 目标状态，实为 %s" % str((lpstory.get("goals", {}) as Dictionary).keys()))

	# ---- B3. v4→v5 装备实例化：旧强化投入等值搬运（P04） ----
	# 硬事实：迁移只搬运不改数值 —— 槽位记整数 uid、实例的 lv/gems/affixes 与旧档逐字段相同、
	# 槽位总加成仍等于"slots[].base + 旧 lv/宝石/词条"推出的期望值、再迁移一次 uid 不变。
	var v4raw := _fixture("v4_equip_progress.json")
	var v4mig := SaveData.migrate(v4raw)
	_check(bool(v4mig["ok"]), "v4 档应可迁移到 v5（%s）" % String(v4mig["err"]))
	_check(str(v4mig["steps"]) == "[\"v4→v5\", \"v5→v6\", \"v6→v7\"]",
		"v4 应逐级迁到 v7，实为 %s" % str(v4mig["steps"]))
	var v4p: Dictionary = (v4mig["data"] as Dictionary).get("prog", {})
	var v4eq: Dictionary = v4p.get("equip", {})
	var v4inv: Dictionary = v4p.get("inventory", {})
	var v4insts: Array = v4inv.get("instances", [])
	var v4old: Dictionary = (v4raw.get("prog", {}) as Dictionary).get("equip", {})
	_check(v4inv.get("instances", null) is Array and v4inv.get("pending", null) is Array,
		"v4→v5 应补出 prog.inventory 的 instances/pending/next_uid 三件套")
	var keep_prog: Dictionary = G.prog
	G.prog = v4p
	for sid3 in ["sword", "armor", "accessory"]:
		var old3: Dictionary = v4old.get(sid3, {})
		var uv: Variant = v4eq.get(sid3)
		_check(uv is int or uv is float,
			"v4→v5 后槽 %s 应记实例 uid（数值），实为 %s" % [sid3, str(uv)])
		var uid3 := int(uv) if (uv is int or uv is float) else 0
		var inst3 := Inventory.find_by_uid(v4insts, uid3)
		_check(not inst3.is_empty(), "槽 %s 的 uid=%d 应能在拥有池里找到实例" % [sid3, uid3])
		_check(String(inst3.get("tpl", "")) == "tpl_%s_basic" % sid3,
			"槽 %s 的实例应指向基础模板 tpl_%s_basic" % [sid3, sid3])
		_check(int(inst3.get("lv", -1)) == int(old3.get("lv", 0)),
			"槽 %s 的强化等级应逐字段搬入（旧 %s → 新 %s）"
			% [sid3, str(old3.get("lv", 0)), str(inst3.get("lv", -1))])
		_check(str(inst3.get("gems", [])) == str(old3.get("gems", [])),
			"槽 %s 的已镶宝石应逐字段搬入（旧 %s → 新 %s）"
			% [sid3, str(old3.get("gems", [])), str(inst3.get("gems", []))])
		_check(str(inst3.get("affixes", [])) == str(old3.get("affixes", [])),
			"槽 %s 的精炼词条应逐字段搬入（旧 %s → 新 %s）"
			% [sid3, str(old3.get("affixes", [])), str(inst3.get("affixes", []))])
		# 等值口径：新模型（模板 base）与旧模型（slots[].base）推出的槽位总加成必须一致
		var exp3 := _expect_slot_bonus(sid3, old3)
		var got3: Dictionary = G.equip_slot_bonus(sid3)
		_check(int(got3.get("atk", 0)) == int(exp3.get("atk", 0))
			and int(got3.get("def", 0)) == int(exp3.get("def", 0))
			and int(got3.get("hp", 0)) == int(exp3.get("hp", 0))
			and is_equal_approx(float(got3.get("crit", 0.0)), float(exp3.get("crit", 0.0))),
			"槽 %s 迁移后总加成应等于 slots[].base 推出的期望值（实为 %s vs %s）"
			% [sid3, str(got3), str(exp3)])
	G.prog = keep_prog
	# 再迁移一次：instances 不该增长、uid 不该变（幂等）
	var v4again: Dictionary = SaveData.migrate(v4mig["data"])["data"]
	var aeq: Dictionary = (v4again.get("prog", {}) as Dictionary).get("equip", {})
	var ainst: Array = ((v4again.get("prog", {}) as Dictionary).get("inventory", {}) as Dictionary).get("instances", [])
	_check(str(aeq) == str(v4eq), "再迁移一次槽位 uid 不得改变（%s → %s）" % [str(v4eq), str(aeq)])
	_check(ainst.size() == v4insts.size(),
		"再迁移一次拥有池条数不得增长（%d → %d）" % [v4insts.size(), ainst.size()])
	_check(SaveData.validate(v4mig["data"], now)["ok"],
		"v4→v5 迁移结果应通过语义校验（%s）" % String(SaveData.validate(v4mig["data"], now)["err"]))
	# ---- B3b. v5→v6 只补经济结构，旧档钱包/道具/装备实例保持逐字段相同 ----
	var v5raw: Dictionary = (v4mig["data"] as Dictionary).duplicate(true)
	v5raw["version"] = 5
	(v5raw["prog"] as Dictionary).erase("economy")
	var v5wallet: Dictionary = (v5raw["wallet"] as Dictionary).duplicate(true)
	var v5items: Dictionary = (v5raw["items"] as Dictionary).duplicate(true)
	var v5inventory: Dictionary = ((v5raw["prog"] as Dictionary)["inventory"] as Dictionary).duplicate(true)
	var v5mig := SaveData.migrate(v5raw)
	_check(bool(v5mig.get("ok", false)) and str(v5mig.get("steps", [])) == "[\"v5→v6\", \"v6→v7\"]",
		"v5 档应逐级迁到 v7")
	var v6data: Dictionary = v5mig.get("data", {})
	var v6prog: Dictionary = v6data.get("prog", {})
	var econ: Dictionary = v6prog.get("economy", {})
	_check(int(econ.get("day", 0)) == 1 and int(econ.get("next_tx", 0)) == 1
		and econ.get("work") is Dictionary and econ.get("orders") is Dictionary,
		"旧档应获默认游戏日、交易号、工作与订单结构")
	_check(JSON.stringify(v6data.get("wallet", {})) == JSON.stringify(v5wallet)
		and JSON.stringify(v6data.get("items", {})) == JSON.stringify(v5items)
		and JSON.stringify(v6prog.get("inventory", {})) == JSON.stringify(v5inventory),
		"v5→v6 不得改旧金币、道具、装备实例")
	_check(bool(SaveData.validate(v6data, now).get("ok", false)),
		"v6 迁移结果须通过存档语义校验")

	# ---- B4. R-05：v5 装备容器的深校验（引用完整性） ----
	# 只验"是不是数组/对象"远远不够：形状全对、但 uid 重复 / 指针悬空 / 跨槽 / 模板不存在 /
	# pending 与拥有池撞号的档，会让换装、回收、掉落分配指错实例，甚至在下次掉落时复用已发出的 uid。
	# 每一例都必须被判非法；同时验证 next_uid 倒退会被**向上修**而不是删物。
	var inst_ok := {"uid": 1, "tpl": "tpl_sword_basic", "slot": "sword", "rarity": 1, "lv": 0, "gems": [], "affixes": []}
	var deep_cases := [
		{"name": "重复 uid",
			"inv": {"instances": [inst_ok.duplicate(true),
				{"uid": 1, "tpl": "tpl_armor_basic", "slot": "armor", "rarity": 1, "lv": 0, "gems": [], "affixes": []}],
				"pending": [], "next_uid": 2}, "equip": {}},
		{"name": "在身指针悬空",
			"inv": {"instances": [], "pending": [], "next_uid": 1}, "equip": {"sword": 9}},
		{"name": "在身指针跨槽",
			"inv": {"instances": [{"uid": 3, "tpl": "tpl_armor_basic", "slot": "armor", "rarity": 1, "lv": 0, "gems": [], "affixes": []}],
				"pending": [], "next_uid": 4}, "equip": {"sword": 3}},
		{"name": "模板不存在",
			"inv": {"instances": [{"uid": 1, "tpl": "tpl_no_such", "slot": "sword", "rarity": 1, "lv": 0, "gems": [], "affixes": []}],
				"pending": [], "next_uid": 2}, "equip": {}},
		{"name": "pending 与拥有池撞号",
			"inv": {"instances": [inst_ok.duplicate(true)],
				"pending": [{"uid": 1, "tpl": "tpl_armor_basic", "slot": "armor", "rarity": 1, "lv": 0, "gems": [], "affixes": []}],
				"next_uid": 2}, "equip": {}},
		{"name": "稀有度非法",
			"inv": {"instances": [{"uid": 1, "tpl": "tpl_sword_basic", "slot": "sword", "rarity": 99, "lv": 0, "gems": [], "affixes": []}],
				"pending": [], "next_uid": 2}, "equip": {}},
	]
	for dc in deep_cases:
		var cv: Dictionary = dc as Dictionary
		var raw5 := {"version": SaveData.CURRENT_VERSION, "wallet": {"gold": 0},
			"prog": {"inventory": (cv["inv"] as Dictionary).duplicate(true),
				"equip": (cv["equip"] as Dictionary).duplicate(true)}}
		var vv := SaveData.validate(SaveData.migrate(raw5)["data"], now)
		_check(not bool(vv["ok"]),
			"R-05 深校验应拒绝「%s」的档（实际放行）" % String(cv["name"]))
	# next_uid 倒退：只向上修（最大 uid + 1），不得删物、不得复用已发出的号
	var reg_raw := {"version": SaveData.CURRENT_VERSION, "prog": {"inventory": {"instances": [
		{"uid": 5, "tpl": "tpl_sword_wolf", "slot": "sword", "rarity": 2, "lv": 3, "gems": [], "affixes": []}],
		"pending": [], "next_uid": 1}, "equip": {"sword": 5}}}
	var reg_mig: Dictionary = SaveData.migrate(reg_raw)["data"]
	var reg_p: Dictionary = reg_mig["prog"]
	var reg_inv: Dictionary = reg_p["inventory"]
	_check(int(reg_inv["next_uid"]) == 6,
		"next_uid 倒退必须被向上修到 最大 uid+1（实为 %s）" % str(reg_inv["next_uid"]))
	_check((reg_inv["instances"] as Array).size() == 1
		and int((reg_inv["instances"] as Array)[0]["uid"]) == 5, "向上修 next_uid 不得删除/改写已有实例")
	_check(int((reg_p["equip"] as Dictionary).get("sword", 0)) == 5, "向上修 next_uid 不得丢掉在身指针")
	var reg_v := SaveData.validate(reg_mig, now)
	_check(bool(reg_v["ok"]), "向上修之后该档应通过校验（%s）" % String(reg_v["err"]))

	# 基线夹具（P00）：新档与真实进度的 v3 样本必须能被读入并通过语义校验，
	# 否则"夹具存在"只说明文件在磁盘上，不说明它是一条可达的存档状态。
	var ng := SaveData.load_payload(_fixture("new_game.json"), now)
	_check(bool(ng["ok"]) and String(ng["mode"]) == "migrated",
		"新档夹具（v3）应可迁移读入（%s）" % String(ng["err"]))
	var ngd: Dictionary = ng["data"]
	_check(int((ngd.get("prog", {}) as Dictionary).get("level", 0)) == 1, "新档夹具等级应为 1")
	_check(String(((ngd.get("prog", {}) as Dictionary).get("story", {}) as Dictionary).get("step", "")) == "s01",
		"新档夹具主线应停在 s01")
	_check(String(((ngd.get("prog", {}) as Dictionary).get("main_world", {}) as Dictionary).get("map_id", "")) == "lorin_wilds",
		"新档夹具应记录主世界地图 lorin_wilds")
	var lp := SaveData.load_payload(_fixture("legacy_v3_progress.json"), now)
	_check(bool(lp["ok"]) and String(lp["mode"]) == "migrated",
		"带进度的 v3 夹具应可迁移读入（%s）" % String(lp["err"]))
	var lpd: Dictionary = lp["data"]
	var lpp: Dictionary = lpd.get("prog", {})
	var lpeq: Dictionary = lpp.get("equip", {})
	_check(lpeq.size() == 3 and lpeq.has("sword") and lpeq.has("armor") and lpeq.has("accessory"),
		"带进度的 v3 夹具应保留三槽装备投入，实为 %s" % str(lpeq.keys()))
	_check((lpp.get("mounts", {}) as Dictionary).get("active", "") == "horse",
		"带进度的 v3 夹具应保留出战坐骑")
	_check((lpp.get("story", {}) as Dictionary).get("done", []).size() == 8,
		"带进度的 v3 夹具应保留已完成的主线步骤")
	var lpmw: Dictionary = lpp.get("main_world", {})
	_check(String(lpmw.get("map_id", "")) == "broken_slope" and lpmw.get("position", []).size() == 2,
		"带进度的 v3 夹具应保留地图位置")

	var vf := SaveData.migrate(_fixture("future.json"))
	_check(not bool(vf["ok"]), "未来版本档不应通过迁移（应显式拒绝）")
	_check(String(vf["err"]).contains("高于"), "拒绝原因应说明版本过高，实为「%s」" % String(vf["err"]))

	# ---- C. 启动路径 load_payload：未来版本可按兼容方式读，但要报告出来 ----
	var lp_cur := SaveData.load_payload(_fixture("v3.json"), now)
	_check(bool(lp_cur["ok"]) and String(lp_cur["mode"]) == "migrated",
		"v3 应走迁移路径（本程序已升到 v%d），实为 %s" % [SaveData.CURRENT_VERSION, String(lp_cur["mode"])])
	var lp_mig := SaveData.load_payload(_fixture("v2.json"), now)
	_check(bool(lp_mig["ok"]) and String(lp_mig["mode"]) == "migrated", "v2 应是 migrated 模式")
	var lp_future := SaveData.load_payload(_fixture("future.json"), now)
	_check(bool(lp_future["ok"]) and String(lp_future["mode"]) == "future",
		"未来版本档在启动路径要能读（不能拿默认档顶掉玩家进度），但必须标成 future 模式")

	# ---- D. 语义校验（含 #24 未来时间水位边界） ----
	_check(not bool(SaveData.validate({"wallet": {"gold": -1}}, now)["ok"]), "负金币应判非法")
	_check(not bool(SaveData.validate({"wallet": {"soul": "10"}}, now)["ok"]), "字符串数量应判非法")
	_check(not bool(SaveData.validate({"items": {"ticket_ten": -3}}, now)["ok"]), "负道具数应判非法")
	_check(not bool(SaveData.validate({"prog": {"pets": "pet_rockturtle"}}, now)["ok"]),
		"prog.pets 不是数组应判非法")
	# v4 嵌套：形状错了会让事务去重/遭遇锁静默失效，必须在闸门处拦住
	_check(not bool(SaveData.validate({"prog": {"ledger": {"applied": {}}}}, now)["ok"]),
		"prog.ledger.applied 不是数组应判非法")
	_check(not bool(SaveData.validate({"prog": {"main_world": {"encounters": []}}}, now)["ok"]),
		"prog.main_world.encounters 不是对象应判非法")
	_check(not bool(SaveData.validate({"prog": {"story": {"done": {}}}}, now)["ok"]),
		"prog.story.done 不是数组应判非法")
	_check(not bool(SaveData.validate({"prog": {"level": 0}}, now)["ok"]), "等级 0 应判非法")
	_check(not bool(SaveData.validate({"city": []}, now)["ok"]), "city 不是对象应判非法")
	_check(bool(SaveData.validate({"prog": {"last_ts": now + 60}}, now)["ok"]),
		"轻微超前（1 分钟）的水位应放行（跨时区/校时误差）")
	_check(bool(SaveData.validate({"prog": {"last_ts": now + SaveData.FUTURE_TS_LIMIT_SEC}}, now)["ok"]),
		"刚好等于容差边界的水位应放行")
	_check(not bool(SaveData.validate({"prog": {"last_ts": now + SaveData.FUTURE_TS_LIMIT_SEC + 1}}, now)["ok"]),
		"超过容差 1 秒的水位应判非法（边界另一侧）")
	_check(not bool(SaveData.validate(_fixture("future_ts.json"), now)["ok"]),
		"未来水位 fixture 必须被拒（它会让按天刷新长期冻结）")

	# ---- E. 导入路径 import_payload：严格拒绝 ----
	var imp_future := SaveData.import_payload(_fixture_text("future.json"), now)
	_check(not bool(imp_future["ok"]), "未来版本存档码应拒绝导入")
	_check(String(imp_future["err"]).contains("当前存档未改动"), "拒绝文案应安抚玩家（当前档未改动）")
	var imp_corrupt := SaveData.import_payload(_fixture_text("corrupt.json"), now)
	_check(not bool(imp_corrupt["ok"]), "截断的 JSON 应拒绝导入")
	var imp_fts := SaveData.import_payload(_fixture_text("future_ts.json"), now)
	_check(not bool(imp_fts["ok"]), "未来时间水位的存档码应拒绝导入")
	_check(String(imp_fts["err"]).contains("超前"), "拒绝原因应点明时间水位异常，实为「%s」" % String(imp_fts["err"]))
	var imp_ok := SaveData.import_payload(_fixture_text("v2.json"), now)
	_check(bool(imp_ok["ok"]), "合法的旧版本存档码应可导入（%s）" % String(imp_ok["err"]))
	var imp_body: Variant = SaveData.import_payload(_fixture_text("v3.json"), now)
	_check(bool(imp_body["ok"]), "当前版本存档码应可导入")

	# ---- F. 备份与原子写盘 ----
	var tpath := "user://save_verify_atomic.json"
	_wipe(tpath)
	_wipe(tpath + ".tmp")
	_write(tpath, "{\"version\":3,\"wallet\":{\"gold\":1}}\n")
	# 备份保留份数：连做 5 次，只应留 BACKUP_KEEP 份
	for i in 5:
		SaveData.backup_file(tpath, 1000 + i)
	var dir := DirAccess.open("user://")
	var baks: Array = []
	for nm in dir.get_files():
		if String(nm).begins_with("save_verify_atomic_backup_"):
			baks.append(String(nm))
	_check(baks.size() <= SaveData.BACKUP_KEEP,
		"备份应只保留 %d 份，实为 %d" % [SaveData.BACKUP_KEEP, baks.size()])
	_check(baks.size() >= 1, "备份应至少生成一份")
	for nm2 in baks:
		_wipe("user://" + nm2)
	var wres := SaveData.write_text_atomic(tpath, "{\"version\":3,\"wallet\":{\"gold\":4242}}\n")
	_check(bool(wres["ok"]), "原子写盘应成功（%s）" % String(wres["err"]))
	var rf := FileAccess.open(tpath, FileAccess.READ)
	var rtext := rf.get_as_text()
	rf.close()
	_check(rtext.contains("4242"), "写盘后内容应更新")
	_check(not FileAccess.file_exists(tpath + ".tmp"), "写盘后临时文件应已被 rename 掉")
	_wipe(tpath)

	# ---- F2. R-04：主档缺失不等于新档（启动恢复从 .tmp/.prev/备份） ----
	var rpath := "user://save_verify_r04.json"
	var rd := DirAccess.open("user://")
	if rd != null:
		for nm3 in rd.get_files():
			if String(nm3).begins_with("save_verify_r04"):
				_wipe("user://" + String(nm3))
	var pk0 := SaveData.pick_readable(rpath, 1000)
	_check(String(pk0["source"]) == "none",
		"主档与所有恢复源都不存在时才应判 none（真·新档），实为 %s" % String(pk0["source"]))
	# 主档缺失但有 .tmp（上次替换中途被打断）→ 必须从残档恢复，而不是当新档清空进度
	_write(rpath + ".tmp", "{\"version\":3,\"wallet\":{\"gold\":77}}\n")
	var pk1 := SaveData.pick_readable(rpath, 1000)
	_check(String(pk1["source"]) == "tmp"
		and int((((pk1["res"] as Dictionary)["data"] as Dictionary).get("wallet", {}) as Dictionary).get("gold", -1)) == 77,
		"主档缺失时应从 .tmp 残档恢复进度，实为 %s" % String(pk1["source"]))
	_wipe(rpath + ".tmp")
	# 主档缺失、只有备份 → 从最近备份恢复
	_write(rpath, "{\"version\":3,\"wallet\":{\"gold\":88}}\n")
	var rbak := SaveData.backup_file(rpath, 1000)
	_check(rbak != "", "前置：应生成一份备份")
	_wipe(rpath)
	var pk2 := SaveData.pick_readable(rpath, 1000)
	_check(String(pk2["source"]) == "backup"
		and int((((pk2["res"] as Dictionary)["data"] as Dictionary).get("wallet", {}) as Dictionary).get("gold", -1)) == 88,
		"主档缺失时应从最近备份恢复进度，实为 %s" % String(pk2["source"]))
	# 正常保存：替换主档、无 .tmp/.prev 残留、并留下滚动备份
	_write(rpath, "{\"version\":3,\"wallet\":{\"gold\":88}}\n")
	var sr := SaveData.save_text(rpath, "{\"version\":3,\"wallet\":{\"gold\":99}}\n", 2000, true)
	_check(bool(sr["ok"]) and FileAccess.file_exists(rpath), "save_text 应成功替换主档（%s）" % String(sr["err"]))
	_check(not FileAccess.file_exists(rpath + ".tmp") and not FileAccess.file_exists(rpath + ".prev"),
		"save_text 成功后不得残留 .tmp/.prev")
	_check(String(sr["backup"]) != "" and FileAccess.file_exists(String(sr["backup"])),
		"正常保存应先备份上一份有效档（滚动备份）")
	# 内容校验失败的写盘必须原地拒绝、原档不变、不留残档
	var keep_text := _read(rpath)
	var bad_sr := SaveData.save_text(rpath, "not json at all", 3000, true)
	_check(not bool(bad_sr["ok"]), "写入非 JSON 内容时 save_text 必须拒绝")
	_check(_read(rpath) == keep_text, "被拒的写盘不得改动原档")
	_check(not FileAccess.file_exists(rpath + ".tmp") and not FileAccess.file_exists(rpath + ".prev"),
		"被拒的写盘不得留下 .tmp/.prev")
	if rd != null:
		var rd2 := DirAccess.open("user://")
		if rd2 != null:
			for nm4 in rd2.get_files():
				if String(nm4).begins_with("save_verify_r04"):
					_wipe("user://" + String(nm4))

	# ---- G. G 层整合：未来版本档 → 备份 + 兼容读取 + 不丢东西 ----
	G.SAVE_PATH = "user://save_verify_save.json"
	_wipe(G.SAVE_PATH)
	_write(G.SAVE_PATH, _fixture_text("future.json"))
	G.save_backup_path = ""
	G.last_load_report = {}
	G._load_save()
	_check(String(G.last_load_report.get("mode", "")) == "future",
		"启动读未来版本档时应记录 future 模式，实为「%s」" % String(G.last_load_report.get("mode", "")))
	_check(G.save_backup_path != "" and FileAccess.file_exists(G.save_backup_path),
		"遇到未来版本档必须先备份原档（备份路径：%s）" % G.save_backup_path)
	_check(int(G.wallet.get("gold", 0)) == 999999,
		"未来版本档仍应按兼容方式读进来（玩家进度不能凭空消失），实为 %d" % int(G.wallet.get("gold", 0)))
	if G.save_backup_path != "":
		_wipe(G.save_backup_path)
	# 未来档包含本程序不认识的字段，自动写回会吞掉它们；兼容读取期间必须锁写。
	var future_text := _read(G.SAVE_PATH)
	_check(G.save_locked and not G.save_game(), "未来版本档兼容读取后必须拒绝自动写回")
	_check(_read(G.SAVE_PATH) == future_text, "未来版本原档及未知字段必须逐字保留")
	var future_home := (load("res://src/ui/GameHome.tscn") as PackedScene).instantiate()
	add_child(future_home)
	await get_tree().process_frame
	_check(not G._modals.is_empty(), "未来版本锁档进入营帐必须显示恢复选项")
	if not G._modals.is_empty():
		var prompt: CanvasLayer = G._modals.back().get("layer")
		var import_button := _button_with_label(prompt, "导入旧档")
		_check(_button_with_label(prompt, "返回标题") != null
			and _button_with_label(prompt, "继 续") == null and import_button != null,
			"未来档提示仅提供返回标题与导入，不能暴露放弃原档的继续按钮")
		if import_button != null:
			var input := InputEventMouseButton.new()
			input.button_index = MOUSE_BUTTON_LEFT
			input.pressed = true
			import_button.gui_input.emit(input)
			await get_tree().process_frame
			_check(future_home.get("_settings") != null and G.save_locked
				and _read(G.SAVE_PATH) == future_text,
				"点击导入旧档应打开设置且保持锁档与原档字节")
	future_home.queue_free()
	await get_tree().process_frame
	# 显式切换到可支持的旧档后应解除锁写，不再残留上一档的可选养成字段。
	G.prog["companions"] = {"active": "pet_rockturtle", "pets": {}}
	G.prog["campaign_growth"] = {"story_revision": {"s01": 2}}
	G.prog["skill_curriculum"] = {"fixture_from_previous_character": true}
	_write(G.SAVE_PATH, _fixture_text("v3.json"))
	G._load_save()
	_check(not G.save_locked and not G.prog.has("companions")
		and not G.prog.has("campaign_growth") and not G.prog.has("skill_curriculum"),
		"读取缺省旧档必须清除上一角色的伙伴、经验版本和授业状态并解除锁写")
	G.prog["level"] = 60
	_check(G.save_game(), "正常路径 save_game 应返回成功（R-04 安全写盘）")
	G.last_load_report = {}
	G._load_save()
	_check(String(G.last_load_report.get("mode", "")) == "current",
		"重新写盘后应回到 current 模式，实为「%s」" % String(G.last_load_report.get("mode", "")))

	# ---- H. 坏档不覆盖玩家档 ----
	_wipe(G.SAVE_PATH)
	_write(G.SAVE_PATH, _fixture_text("corrupt.json"))
	G.wallet = {"gold": 4321, "expedition": 0, "soul": 0, "honor": 0}
	G._load_save()
	_check(int(G.wallet.get("gold", 0)) == 4321, "坏档不该清掉内存里的既有进度")
	var still := FileAccess.open(G.SAVE_PATH, FileAccess.READ)
	var still_text := still.get_as_text()
	still.close()
	_check(still_text.begins_with("{\"version\": 3, \"wallet\""), "坏档读失败不应改写原文件")

	# ---- I. 设置面板导入：拒绝时原档一字不动，成功时备份+替换 ----
	var sp: Control = (load("res://src/ui/SettingsPanel.gd") as GDScript).new()
	add_child(sp)
	await get_tree().process_frame
	_wipe(G.SAVE_PATH)
	_write(G.SAVE_PATH, _fixture_text("v3.json"))
	var before_text := _read(G.SAVE_PATH)
	var bad: Dictionary = sp.do_import_ex(_fixture_text("future.json"))
	_check(not bool(bad["ok"]), "面板导入未来版本应失败")
	_check(_read(G.SAVE_PATH) == before_text, "导入被拒时原存档必须一字不动")
	G.wallet = {"gold": 0, "expedition": 0, "soul": 0, "honor": 0}
	var good: Dictionary = sp.do_import_ex(_fixture_text("v2.json"))
	_check(bool(good["ok"]), "面板导入旧版本档应成功（%s）" % String(good["err"]))
	var after: Variant = JSON.parse_string(_read(G.SAVE_PATH))
	_check(after is Dictionary and int((after as Dictionary).get("version", -1)) == SaveData.CURRENT_VERSION,
		"导入后落盘内容应是当前版本 %d" % SaveData.CURRENT_VERSION)
	_check(int(((after as Dictionary).get("prog", {}) as Dictionary).get("level", 0)) == 3,
		"导入后应保留旧档里的等级")
	G.reload_save()
	_check(int(G.wallet.get("gold", 0)) == 5, "导入后内存应重读为 5，实为 %d" % int(G.wallet.get("gold", 0)))
	sp.queue_free()
	await get_tree().process_frame

	# ---- J. 非法档（语义校验失败）：必须备份原档 + 锁定写盘（A7） ----
	_wipe(G.SAVE_PATH)
	_write(G.SAVE_PATH, _fixture_text("future_ts.json"))
	G.save_backup_path = ""
	G.save_locked = false
	G.last_load_report = {}
	G._load_save()
	_check(String(G.last_load_report.get("mode", "")) == "invalid",
		"未来时间水位档应被判 invalid，实为「%s」" % String(G.last_load_report.get("mode", "")))
	_check(G.save_backup_path != "" and FileAccess.file_exists(G.save_backup_path),
		"校验失败的档同样必须备份原档（备份路径：%s）" % G.save_backup_path)
	_check(G.save_locked, "校验失败后应锁定写盘（内存是默认态，写下去就覆盖玩家真档）")
	var locked_text := _read(G.SAVE_PATH)
	_check(not G.save_game(), "锁写期间 save_game 应返回失败（R-04：调用方据此不显示已入袋）")
	_check(_read(G.SAVE_PATH) == locked_text, "锁写期间 save_game 不得改写原档")
	if G.save_backup_path != "":
		_wipe(G.save_backup_path)
	# 玩家在主界面选了「继续（放弃原档）」之后应能正常落盘
	G.save_locked = false
	G.save_lock_reason = ""
	_check(G.save_game(), "解锁后 save_game 应返回成功")
	_check(_read(G.SAVE_PATH) != locked_text, "解锁后 save_game 应能正常落盘")

	_wipe(G.SAVE_PATH)
	if _fails == 0:
		print("SAVE_OK all tests passed")
	else:
		print("SAVE_FAIL fails=%d" % _fails)


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t


func _button_with_label(node: Node, text: String) -> Control:
	if node is Label and (node as Label).text == text:
		return node.get_parent() as Control
	for child in node.get_children():
		var found := _button_with_label(child, text)
		if found != null:
			return found
	return null


## 用**旧档的权威口径** slots[<slot>].base + 旧装备的 lv/宝石/词条，独立推一遍槽位总加成。
## 与 G.equip_slot_bonus()（走新模型的模板 base）对照，证明 v4→v5 是等值搬运。
func _expect_slot_bonus(slot_id: String, old: Dictionary) -> Dictionary:
	var out := {"atk": 0, "def": 0, "hp": 0, "crit": 0.0,
		"atk_pct": 0.0, "def_pct": 0.0, "maxhp_pct": 0.0, "spd_pct": 0.0, "crit_add": 0.0}
	var base: Dictionary = G.equip_slot_cfg(slot_id).get("base", {})
	var lv := int(old.get("lv", 0))
	var mult := 1.0 + float((G.equip_cfg().get("enhance", {}) as Dictionary).get("pct_per_level", 0.1)) * lv
	for k in base.keys():
		if String(k) == "crit":
			out["crit"] = float(base[k])   # 暴击值不吃强化倍率（与 equip_instance_bonus 同口径）
		else:
			out[k] = int(roundf(float(base[k]) * mult))
	for g in (old.get("gems", []) as Array):
		var gid := String(g)
		var v := G.equip_gem_value(gid)
		if gid.begins_with("gem_atk_"):
			out["atk"] += v
		elif gid.begins_with("gem_def_"):
			out["def"] += v
		elif gid.begins_with("gem_hp_"):
			out["hp"] += v
	for a in (old.get("affixes", []) as Array):
		var ad := a as Dictionary
		var stat := String(ad.get("stat", ""))
		if out.has(stat):
			out[stat] = float(out[stat]) + float(ad.get("v", 0.0))
	return out
