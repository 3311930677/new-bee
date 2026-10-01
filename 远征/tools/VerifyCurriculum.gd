extends "res://tools/VerifyCompanions.gd"

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_curriculum.json"
	await _run()
	print("CURRICULUM_OK" if _fails == 0 else "CURRICULUM_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)

func _reset(role_id: String) -> void:
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = role_id
	G.prog.level = 42
	_chapter(28)
	G.wallet.gold = 1665
	G.ensure_starter_equip(true)
	G.mentor_state().unlocked.append(G.mentor_second_skill())
	_check(G.save_game() and G.reload_save(), "旧档基线可读写")

func _battle(role_id: String) -> BattleSim:
	var sim := BattleSim.new()
	sim.setup(721, {"role_id": role_id, "level": 42, "active_pet": "", "unlocked_skills": G.act1_unlocked_skills(), "skill_variants": G.act1_skill_variants()},
		{"theme": "forest", "custom_mon": {"id": "fixture", "name": "试招者", "base": {"hp": 5000, "atk": 10, "def": 3, "spd": 0.8}, "skills": []}})
	return sim

func _effective(sim: BattleSim, sid: String) -> bool:
	for event in sim.events:
		if event.get("t", "") == "curriculum_effective" and event.get("skill", "") == sid: return true
	return false

func _canonical(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

func _run() -> void:
	for rid in ["zs", "ck", "fs", "fz"]:
		_reset(rid)
		var initial := G.prog.duplicate(true)
		_check(G.act1_unlocked_skills().size() == 2 and G.prog == initial and not G.prog.has("skill_curriculum"), "旧档查询不自动送招或写新状态")
		var entries := MentorCurriculum.rows(rid)
		_check(entries.size() == 3, "每职业三招配置完整")
		var last := String(entries[2].id)
		_check(not G.curriculum_apply(last, "learn").ok and G.wallet.gold == 1665, "不能跳过前一式")
		for entry in entries:
			var sid := String(entry.id)
			G.prog.level = int(entry.level) - 1
			_check(MentorCurriculum.status(G, sid) == "level" and not G.curriculum_apply(sid, "learn").ok, "等级门槛拒绝并不扣费")
			G.prog.level = 42
			var story: Dictionary = G.prog.story.duplicate(true)
			_chapter(int(String(entry.after).trim_prefix("s")) - 1)
			_check(MentorCurriculum.status(G, sid) == "story" and not G.curriculum_apply(sid, "learn").ok, "剧情门槛拒绝")
			G.prog.story = story
			var wallet: Dictionary = G.wallet.duplicate(true)
			G.wallet.gold = int(entry.gold) - 1
			_check(not G.curriculum_apply(sid, "learn").ok and not sid in MentorCurriculum.unlocked(G.prog, rid), "学费不足没有半解锁")
			G.wallet = wallet
			_check(G.curriculum_apply(sid, "learn").ok and G.reload_save() and sid in G.act1_unlocked_skills(), "学习实际落盘重读")
			_check(not G.curriculum_apply(sid, "learn").ok and not G.curriculum_apply(sid, "choose", "swift").ok, "重复学习与未熟练选分支拒绝")
			var sim := _battle(rid)
			if sid == "fz_jinghua": sim.role_unit().add_buff("atk_down", 90, {"pct": 0.2})
			_cast(sim, sid)
			_check(_effective(sim, sid), "十二招真实技能结算都有实效事件：" + sid)
			for i in int(entry.mastery_target):
				var eid := "verify_%s_%d" % [sid, i]
				_check(G.curriculum_report_effective([sid, sid], eid).size() == 1, "同场双上报只计一次")
				_check(G.curriculum_report_effective([sid], eid).is_empty(), "同遭遇重放不刷熟练")
			_check(G.curriculum_report_effective([sid], "extra_" + sid).is_empty(), "满熟练不无限记账")
			_check(not G.curriculum_apply(sid, "choose", "invalid").ok, "未知分支拒绝")
			_check(G.curriculum_apply(sid, "choose", "swift").ok, "熟练后二选一")
			var branched := _battle(rid)
			for slot in branched.role_unit().skills:
				if String(slot.def.id) != sid: continue
				var base := TableCache.get_skill(sid)
				_check(int(slot.def.cost) == int(base.cost) + int(entry.variants.swift.cost_delta) and is_equal_approx(float(slot.def.cd), float(base.cd) - 2.0), "战斗读取选中分支消耗与冷却")
				_check(is_equal_approx(float(slot.def.k), snappedf(float(base.k) * float(entry.variants.swift.get("k_mult", 1.0)), 0.001)), "分支倍率读取副本")
		_check(G.act1_unlocked_skills().size() == 5 and G.wallet.gold == 1165, "五式完整且三招总500金")
		_check(MentorCurriculum.validate(G.prog.skill_curriculum, G.prog), "完整状态严格校验")
		var expected: Variant = _canonical([G.prog, G.wallet, G.items])
		_check(G.save_game() and G.reload_save() and _canonical([G.prog, G.wallet, G.items]) == expected, "完整分支与旧投入读档一致")
		_check(G.curriculum_apply(last, "reset").ok and G.wallet.gold == 1045 and MentorCurriculum.status(G, last) == "choose", "120金重置保留熟练")
		_check(G.curriculum_apply(last, "choose", "steady").ok, "重置后正常再选")
		if rid == "fz":
			var empty := _battle(rid)
			_cast(empty, "fz_jinghua")
			_check(not _effective(empty, "fz_jinghua"), "零清除不能刷熟练")
		var root: Dictionary = G.prog.skill_curriculum.duplicate(true)
		var broken := root.duplicate(true)
		broken.unlocked.append("made_up_skill")
		_check(not MentorCurriculum.validate(broken, G.prog), "未知解锁拒绝")
		broken = root.duplicate(true)
		broken.mastery[last] = 2.5
		_check(not MentorCurriculum.validate(broken, G.prog), "小数熟练拒绝")
		broken = root.duplicate(true)
		broken.encounters.clear()
		_check(not MentorCurriculum.validate(broken, G.prog), "熟练与遭遇账目不一致拒绝")
		broken = root.duplicate(true)
		broken.variants[last] = "unknown"
		_check(not MentorCurriculum.validate(broken, G.prog), "未知分支拒绝")
		G.save_locked = true
		var locked: Variant = _canonical([G.prog, G.wallet])
		_check(not G.curriculum_apply(last, "reset").ok and G.curriculum_report_effective([last], "locked").is_empty() and _canonical([G.prog, G.wallet]) == locked, "存档锁下没有成长或消费")
		G.save_locked = false
	_reset("zs")
	var sid := String(MentorCurriculum.rows("zs")[0].id)
	var host := FailingHost.new()
	host.prog = G.prog.duplicate(true)
	host.wallet = G.wallet.duplicate(true)
	host.selected_role = "zs"
	var before: Variant = _canonical([host.prog, host.wallet])
	_check(not MentorCurriculum.apply(host, sid, "learn").ok and host.writes == 1 and _canonical([host.prog, host.wallet]) == before, "学习写失败一次写入且全回滚")
	_check(MentorCurriculum.apply(host, sid, "learn", "", false).ok, "为失败注入设置已解锁基线")
	before = _canonical([host.prog, host.wallet])
	_check(MentorCurriculum.report(host, [sid], "failed").is_empty() and host.writes == 2 and _canonical([host.prog, host.wallet]) == before, "熟练写失败不吞遭遇也不增长")
	MentorCurriculum.report(host, [sid], "one", false)
	MentorCurriculum.report(host, [sid], "two", false)
	before = _canonical([host.prog, host.wallet])
	_check(not MentorCurriculum.apply(host, sid, "choose", "swift").ok and _canonical([host.prog, host.wallet]) == before, "分支写失败回滚")
	MentorCurriculum.apply(host, sid, "choose", "swift", false)
	before = _canonical([host.prog, host.wallet])
	_check(not MentorCurriculum.apply(host, sid, "reset").ok and _canonical([host.prog, host.wallet]) == before, "重置写失败金币与选择一起回滚")
	host.free()
	await _verify_ui()

func _verify_ui() -> void:
	var city := CityScene.new()
	add_child(city)
	await get_tree().process_frame
	city._open_curriculum_panel()
	await get_tree().process_frame
	for entry in MentorCurriculum.rows("zs"):
		var button := _find_action(city._panel, "detail", String(entry.id))
		_check(button != null and button.get_global_rect().end.x <= 480 and button.get_global_rect().end.y <= 800, "三式真实入口在屏内")
	city._close_panel()
	city._open_curriculum_skill(String(MentorCurriculum.rows("zs")[0].id))
	await get_tree().process_frame
	var sid := String(MentorCurriculum.rows("zs")[0].id)
	var learn := _find_action(city._panel, "learn", sid)
	_check(learn != null and city._curriculum_story_name("s12") == "边城复命", "学习条件显示实际任务名")
	_press(learn)
	await get_tree().process_frame
	_check(sid in G.act1_unlocked_skills() and G.wallet.gold == 1565, "导师学习回调只扣一次学费")
	G.curriculum_report_effective([sid], "ui_one")
	G.curriculum_report_effective([sid], "ui_two")
	city._close_panel()
	city._open_curriculum_skill(sid)
	await get_tree().process_frame
	_press(_find_action(city._panel, "choose", sid, "swift"))
	await get_tree().process_frame
	_check(MentorCurriculum.state(G.prog).variants.get(sid, "") == "swift", "分支按钮绑定正确选择而非循环末项")
	_press(_find_action(city._panel, "reset", sid))
	await get_tree().process_frame
	_check(MentorCurriculum.status(G, sid) == "choose" and G.wallet.gold == 1445, "真实重置回调扣120金保留熟练")
	_press(_find_action(city._panel, "choose", sid, "steady"))
	await get_tree().process_frame
	_check(MentorCurriculum.state(G.prog).variants.get(sid, "") == "steady" and G.reload_save(), "再次选择与读档都保存新分支")
	city.queue_free()
	await get_tree().process_frame

func _find_action(root: Node, action: String, sid: String, choice := "") -> Control:
	for child in root.get_children():
		if child is Control and child.get_meta("curriculum_action", "") == action and child.get_meta("curriculum_skill", "") == sid and (choice.is_empty() or child.get_meta("curriculum_choice", "") == choice): return child
		var found := _find_action(child, action, sid, choice)
		if found != null: return found
	return null

class FailingHost extends "res://src/autoload/G.gd":
	var writes := 0
	func save_game() -> bool:
		writes += 1
		return false
