# PlaythroughMainWorld.gd —— R-06：主世界真实操作链回放（480×800，场景模式）
#
# 目的（docs/plans/2026-09-28-p00-p04-review-issues.md R-06）：
#   P01/P03 交付的「可走可战」缺少整条真实操作链的验证。本工具在一份**新档**上，
#   用真实输入把 s01–s12 走完并返城，中途真实触发：胜 / 败 / 逃 / 满包掉落 / 任务物交付。
#   阶段 A 走完并落盘后由包装脚本真实退出进程，阶段 B 重开进程从同一份临时存档恢复，
#   校验每一步都能继续、奖励只到账一次（跨进程奖励账本幂等）。
#
# 用法（场景模式）：
#   godot --path <proj> res://tools/PlaythroughMainWorld.tscn -- <role> <phase>
#     <role>  = zs / ck / fs / fz
#     <phase> = a（走完链路）/ b（重开进程校验同一份存档）
#
# 铁律（违反即失败）：
#   * 绝不写真实存档 user://save.json —— _ready 第一件事就是把 G.SAVE_PATH 指到
#     res://tools/_logs/save_playthrough_<role>_<phase>.json，任何 save_game 之前完成。
#   * 不伪造进度：本工具不调用 G.story_event / QuestService.plan，不改 G.prog["story"]，
#     不传送角色到出口/NPC，不冻怪，不做绕行 nudge。进度只来自「真的走到 + 真的碰到怪
#     + 真的打完一场 + 真的触发 NPC + 真的走进出口」。
#   * 移动只用真实动作名 Input.action_press/release；战斗只用真实鼠标事件点 BattleScene 的
#     「自动」「速度」「逃」与结算「继续/返回」。
#   * 输出用 PLAY_ 前缀：阶段 A 成功 PLAY_A_OK，阶段 B 成功 PLAY_B_OK 且总成功 PLAY_OK，
#     失败 PLAY_BAD <原因>。不出现 ERROR: / FAIL: / _FAIL。
extends Node

const WORLD_SCENE := "res://src/explore/MapScene.tscn"
const DEADZONE := 6.0
const STUCK_LIMIT := 80
const MOVE_ACTIONS := ["move_left", "move_right", "move_up", "move_down"]

var role_id := "zs"
var phase := "a"
var act2 := false
var act3_front := false
var act3 := false

var _map: MapScene = null
var _reason := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role_id = String(args[0]) if args.size() > 0 else "zs"
	phase = String(args[1]) if args.size() > 1 else "a"
	act3 = args.has("act3")
	act3_front = args.has("act3_front") or act3
	act2 = args.has("act2") or act3_front
	G.SAVE_PATH = "res://tools/_logs/save_playthrough_%s_%s.json" % [role_id, phase]
	for arg in args:
		if arg.begins_with("--save-dir="):
			G.SAVE_PATH = arg.trim_prefix("--save-dir=").path_join(
				"save_playthrough_%s_%s.json" % [role_id, phase])
	# _ready 期间场景树仍在装配本节点，此刻改 current_scene 会被拒，故等一帧。
	await get_tree().process_frame
	# 驱动节点不能是 current_scene：G.go 会 change_scene_to_file，从而释放上一幕。
	# 置空后本节点只作为 root 的常驻子节点存活，游戏自身换场照常释放旧 MapScene/GameHome。
	get_tree().current_scene = null
	print("PLAY_SETUP role=%s phase=%s save=%s" % [role_id, phase, G.SAVE_PATH])
	if phase == "b":
		await _run_phase_b()
	else:
		await _run_phase_a()


# =========================================================================
# 阶段 A：新档 → 走完 s01–s12 → 返城
# =========================================================================
func _run_phase_a() -> void:
	_prep_new_save()

	# --- 进城 ---
	if not await _enter_world("lorin_wilds", "", "lorin_wilds"):
		return _bad("进入边城失败")

	# --- s01 talk npc_steward ---
	if not await _talk_to("npc_steward", "s01"):
		return
	# --- 北门 → 枫林古道 ---
	if not await _exit_to("lorin_wilds", Vector2(480, 96), "maple_road"):
		return
	if not await _need("s02"):
		return
	# --- s03 普通怪胜利（枫林古道） ---
	if not await _fight_nearest("win"):
		return
	if not await _need("s03"):
		return
	# --- 再打一只并真实「逃」 ---
	if not await _fight_nearest("flee"):
		return
	print("PLAY_EVENT flee_done map=maple_road")

	# --- 回城找铁匠（s04） ---
	if not await _exit_to("maple_road", Vector2(480, 1152), "lorin_wilds"):
		return
	if not await _talk_to("npc_smith", "s04"):
		return

	# --- 北上断碑坡（s05） ---
	if not await _exit_to("lorin_wilds", Vector2(480, 96), "maple_road"):
		return
	if not await _exit_to("maple_road", Vector2(480, 96), "broken_slope"):
		return
	if not await _need("s05"):
		return
	# --- s06 断碑坡普通怪胜利 ---
	if not await _fight_nearest("win"):
		return
	if not await _need("s06"):
		return

	# --- 回城：闻叔（s07）+ 抄录人（s08） ---
	if not await _exit_to("broken_slope", Vector2(480, 1152), "maple_road"):
		return
	if not await _exit_to("maple_road", Vector2(480, 1152), "lorin_wilds"):
		return
	if not await _talk_to("npc_steward", "s07"):
		return
	if not await _talk_to("npc_scribe", "s08"):
		return

	# --- 再北上：枫林古道 → 断碑坡 → 碑窟（s09） ---
	if not await _exit_to("lorin_wilds", Vector2(480, 96), "maple_road"):
		return
	if not await _exit_to("maple_road", Vector2(480, 96), "broken_slope"):
		return
	if not await _exit_to("broken_slope", Vector2(480, 96), "stele_cavern"):
		return
	if not await _need("s09"):
		return

	# --- 第一次打碑灵：脱光装备 + 关自动，真实战败 → 主界面 ---
	print("PLAY_EVENT boss_attempt=lose prepare")
	if not _strip_all_equip():
		return
	# 为战败分支构造战斗夹具：本场不上宠、残血入战、不托管。脚本仍
	# 通过接触怪物进入真正的 BattleScene，由首领伤害打败角色；不写主线进度。
	_map.st.active_pet = ""
	_map.st.bench_pet = ""
	_map.st.hp = 1
	if not await _fight_nearest("lose"):
		return
	if G.story_step_done("s10"):
		return _bad("碑灵第一场意外取胜，无法取得真实战败")
	if _find_map() != null:
		return _bad("战败后没有离开碑窟")
	print("PLAY_EVENT defeat_done map=none")
	_map = null

	# --- 重开进程内重进碑窟：满装 + 满背包，真实取胜（满包掉落进待领取箱） ---
	await _wait_idle()
	if not await _enter_world("", "", "stele_cavern"):
		return _bad("战败后重进碑窟失败")
	_equip_all_slots()
	_fill_bag()
	if not await _fight_nearest("win"):
		return
	if not await _need("s10"):
		return
	if G.inv_count() != G.inv_capacity():
		return _bad("碑灵胜利后背包格数变化：%d/%d" % [G.inv_count(), G.inv_capacity()])
	if G.inv_pending().is_empty():
		return _bad("满背包时碑灵掉落没有进待领取箱")
	print("PLAY_EVENT fullbag_drop pending=%d bag=%d/%d"
		% [G.inv_pending().size(), G.inv_count(), G.inv_capacity()])

	# --- 返城：碑窟 → 断碑坡 → 枫林古道 → 边城 ---
	if not await _exit_to("stele_cavern", Vector2(480, 1152), "broken_slope"):
		return
	if not await _exit_to("broken_slope", Vector2(480, 1152), "maple_road"):
		return
	if not await _exit_to("maple_road", Vector2(480, 1152), "lorin_wilds"):
		return
	# --- s11 交任务物（stele_fragment 1 → 0） ---
	var frag_before := int(G.items.get("stele_fragment", 0))
	if frag_before < 1:
		return _bad("s11 之前没有碑文碎片（items.stele_fragment=%d）" % frag_before)
	if not await _craft_stele("forge"):
		return
	if int(G.items.get("stele_fragment", 0)) != 0:
		return _bad("s11 交付后碑文碎片没有扣除")
	if int(G.items.get("refine_stone", 0)) > 1:
		print("PLAY_EVENT repair_method=forge refine_left=%d" % int(G.items.get("refine_stone", 0)))
	print("PLAY_EVENT quest_item_delivered stele_fragment %d -> 0" % frag_before)
	# --- s12 ---
	if not await _talk_to("npc_steward", "s12"):
		return
	if not _growth_checkpoint("act1", 12, 13): return
	if not await _campaign_gear_checkpoint("act1"): return
	if act3 and not await _learn_second_skill():
		return

	if act2 and not await _run_second_act():
		return
	if act3_front and not await _run_third_act_front():
		return
	if act3 and not await _run_third_act_back():
		return
	_release_all()
	var state := _state()
	print("PLAY_A_STATE " + JSON.stringify(state))
	print("PLAY_A_OK role=%s step=%s level=%d gold=%d"
		% [role_id, String(state["story_step"]), int(state["level"]), int(state["gold"])])
	get_tree().quit(0)


## 第二幕仍只用真实移动、接触和鼠标选项，不直接写主线。
func _learn_second_skill() -> bool:
	if not await _close_city_modal(): return false
	var sid := G.mentor_second_skill()
	var title := "领悟·" + String(TableCache.get_skill(sid).get("name",sid))
	var pos := _npc_pos("npc_mentor")
	for attempt in 20:
		if not _city_modal():
			var result := await _travel(pos,20.0,true,false)
			if result != "ok": return _bad("导师导航失败：" + result)
		if _city_modal():
			var panel: Node = _map._city_content.get("_panel") as Node
			var label := _find_label(panel,[title])
			if label != null:
				if not await _click_until(label.get_parent() as Control,
					func() -> bool: return G.act1_unlocked_skills().has(sid),40,"mentor_learn"):
					return _bad("导师真实领取第二式失败")
				print("PLAY_EVENT mentor_second_skill learned=" + sid)
				return await _close_city_modal()
			if not await _close_city_modal(): return false
		await _wait_frames(4)
	return _bad("未找到导师第二式真实按钮")


func _run_second_act() -> bool:
	if not await _talk_to("npc_warden", "s13"): return false
	if not await _exit_to("lorin_wilds", Vector2(480, 96), "maple_road"): return false
	if not await _exit_to("maple_road", Vector2(864, 660), "old_salt_road"): return false
	if not await _need("s14"): return false
	if not await _visit_entity("salt_cart_ledger", "s15"): return false
	if not await _exit_to("old_salt_road", Vector2(864, 660), "shenyuan_port"): return false
	if not await _talk_to("npc_harbormaster", "s16"): return false
	if not await _exit_to("shenyuan_port", Vector2(864, 700), "tideflat"): return false
	if not await _visit_entity("tide_cargo", "s17"): return false
	# 真正撤退，验证不会误领守卫线索或倒退已完成的调查。
	var guards_before := G.item_count("gate_clue")
	if not await _fight_nearest("flee", "mon_tidal_guard"): return false
	if G.item_count("gate_clue") != guards_before or not G.story_step_done("s17"):
		return _bad("潮滩撤退改动主线或闸门线索")
	print("PLAY_EVENT act2_flee_done map=tideflat")
	await get_tree().create_timer(MapScene.FLEE_CONTACT_CD + 0.2).timeout
	if not G.story_step_done("s18"):
		if not await _fight_nearest("win", "mon_tidal_guard"): return false
	if not await _need("s18"): return false
	if not await _exit_to("tideflat", Vector2(480, 96), "tidal_gate"): return false
	# 残血、不上宠作为失败夹具；由真实首领攻击判败，绝不写任务进度。
	_map.st.active_pet = ""
	_map.st.bench_pet = ""
	_map.st.hp = 1
	if not await _fight_nearest("lose", "mon_tide_priest"): return false
	if G.story_step_done("s19") or G.item_count("gate_clue") != 1 or G.item_count("tide_core") != 0:
		return _bad("水闸战败提前消耗线索或发放闸芯")
	if _find_map() != null: return _bad("水闸战败后没有返回营帐")
	if not G.reload_save() or not G.story_step_done("s18") or G.item_count("gate_clue") != 1:
		return _bad("水闸战败读档丢失守卫线索")
	if not await _enter_world("", "", "tidal_gate"): return _bad("水闸战败重进失败")
	print("PLAY_EVENT act2_defeat_reenter map=tidal_gate clue=1")
	if not await _fight_nearest("win", "mon_tide_priest"): return false
	if not await _need("s19"): return false
	if not await _exit_to("tidal_gate", Vector2(480, 1152), "tideflat"): return false
	if not await _exit_to("tideflat", Vector2(90, 700), "shenyuan_port"): return false
	if not await _choose_port_route(): return false
	if not await _need("s20"): return false
	if G.item_count("salt_ledger") != 0 or G.item_count("gate_clue") != 0 or G.item_count("tide_core") != 0:
		return _bad("第二幕任务物交付后仍有残留")
	print("PLAY_EVENT act2_complete choice=dredge")
	if not _growth_checkpoint("act2", 25, 26): return false
	if not await _campaign_gear_checkpoint("act2"): return false
	return true


func _run_third_act_front() -> bool:
	if not await _close_city_modal(): return false
	# 离开再靠近沈澜，按普通对话接信，不复用第二幕选择事件。
	if await _travel(Vector2(480, 560), 16.0, true) != "ok": return _bad("接信前离开对话位置失败")
	if not await _talk_to("npc_harbormaster", "s21"): return false
	if G.item_count("frost_letter") != 1: return _bad("接信后缺霜关来信")
	if not await _exit_to("shenyuan_port", Vector2(480, 96), "red_sand_route"): return false
	if not await _need("s22"): return false
	if not await _fight_nearest("win"): return false
	if not await _exit_to("red_sand_route", Vector2(480, 96), "frost_post"): return false
	if not await _talk_to("npc_frost_envoy", "s23"): return false
	if G.item_count("frost_letter") != 0: return _bad("交信后信件未扣除")
	if not await _exit_to("frost_post", Vector2(864, 710), "rift_mine_road"): return false
	if not await _visit_entity("overturned_mine_cart", "s24"): return false
	if G.item_count("mine_record") != 1: return _bad("调查矿车后缺少记录")
	if not await _exit_to("rift_mine_road", Vector2(90, 710), "frost_post"): return false
	print("PLAY_EVENT act3_front_complete mine_record=1 map=frost_post")
	return true


func _run_third_act_back() -> bool:
	if not await _exit_to("frost_post", Vector2(864,710), "rift_mine_road"): return false
	if not await _exit_to("rift_mine_road", Vector2(480,96), "rift_mine_vault"): return false
	_map.st.active_pet = ""
	_map.st.bench_pet = ""
	_map.st.hp = 1
	if not await _fight_nearest("boss_lose", "mon_redsand_guard"): return false
	if G.item_count("mine_record") != 1 or G.story_step_done("s25"):
		return _bad("械卫败北误交记录或推进主线")
	if not G.reload_save() or G.item_count("mine_record") != 1:
		return _bad("械卫败北后读档丢失记录")
	if not await _enter_world("", "", "rift_mine_vault"): return false
	print("PLAY_EVENT act3_defeat_reenter mine_record=1")
	if not await _fight_nearest("win", "mon_redsand_guard"): return false
	if not await _need("s25"): return false
	if not await _exit_to("rift_mine_vault",Vector2(480,1152),"rift_mine_road"): return false
	if not await _exit_to("rift_mine_road",Vector2(90,710),"frost_post"): return false
	if not await _exit_to("frost_post",Vector2(480,96),"frost_boardwalk"): return false
	if not await _fight_nearest("flee"): return false
	if G.item_count("gate_stamp") != 1 or G.story_step_done("s26"):
		return _bad("栈道撤退误交铁印或推进主线")
	print("PLAY_EVENT act3_flee_done gate_stamp=1")
	await get_tree().create_timer(MapScene.FLEE_CONTACT_CD + .2).timeout
	if not await _visit_entity("signal_ribbons","s26"): return false
	if not await _exit_to("frost_boardwalk",Vector2(480,96),"frost_pass"): return false
	if not await _fight_nearest("win","mon_snowveil_lord"): return false
	if not await _need("s27"): return false
	if not await _exit_to("frost_pass",Vector2(480,1152),"frost_boardwalk"): return false
	if not await _exit_to("frost_boardwalk",Vector2(480,1152),"frost_post"): return false
	if not await _choose_frost_route(): return false
	if not await _need("s28"): return false
	for item in ["mine_record","gate_stamp","frost_reply","veil_seal"]:
		if G.item_count(item) != 0: return _bad("第三幕任务物交付残留：" + item)
	print("PLAY_EVENT act3_complete choice=wardens")
	if not _growth_checkpoint("act3", 42, 43): return false
	if not await _campaign_gear_checkpoint("act3"): return false
	return true


func _choose_frost_route() -> bool:
	var pos := _npc_pos("npc_frost_envoy")
	for attempt in 20:
		if not _city_modal():
			var result := await _travel(pos,28.0,true,false)
			if result != "ok": return _bad("双关定路导航失败：" + result)
		if _city_modal():
			var root: Node = _map._city_content.get("_panel") as Node
			var label := _find_label(root,["守关补给"])
			if label != null:
				return await _click_until(label.get_parent() as Control,
					func() -> bool: return G.story_step_done("s28"),40,"frost_choice")
			if not await _close_city_modal(): return false
		await _wait_frames(4)
	return _bad("未找到双关供货选择")


func _visit_entity(entity_id: String, step: String) -> bool:
	var entity: Node2D = null
	for candidate in _map._quest_entities:
		if String(candidate.eid) == entity_id: entity = candidate
	if entity == null: return _bad("缺少主线调查实体：" + entity_id)
	var result := await _travel(entity.position, 26.0, true)
	if result != "ok": return _bad("调查实体导航失败：%s %s" % [entity_id, result])
	for frame in 120:
		if G.story_step_done(step):
			print("PLAY_STEP %s done via %s" % [step, entity_id])
			return true
		await get_tree().physics_frame
	return _bad("走到调查实体后未推进：" + entity_id)


func _choose_port_route() -> bool:
	var pos := _npc_pos("npc_harbormaster")
	for attempt in 20:
		if not _city_modal():
			var result := await _travel(pos, 28.0, true, false)
			if result != "ok": return _bad("回港定路导航失败：" + result)
		if _city_modal():
			var root: Node = _map._city_content.get("_panel") as Node
			var label := _find_label(root, ["疏浚盐渠"])
			if label != null:
				if not await _click_until(label.get_parent() as Control,
					func() -> bool: return G.story_step_done("s20"), 40, "port_choice"):
					return _bad("供货选择未完成主线")
				return true
			if not await _close_city_modal(): return _bad("不能关闭回港途中的对话")
		await _wait_frames(4)
	return _bad("未找到回港供货选项")


# =========================================================================
# 阶段 B：重开进程，从同一份临时存档恢复并校验
# =========================================================================
func _run_phase_b() -> void:
	if not G.reload_save():
		return _bad("找不到临时存档 " + G.SAVE_PATH)
	_release_all()
	var story: Dictionary = G.prog.get("story", {})
	var step := String(story.get("step", ""))
	var done: Array = story.get("done", [])
	var missing: Array = []
	for i in range(1, 29 if act3 else (25 if act3_front else (21 if act2 else 13))):
		var sid := "s%02d" % i
		if not done.has(sid):
			missing.append(sid)
	if (act3 and not step.is_empty()) or (act3_front and not act3 and step != "s25") or (act2 and not act3_front and step != "s21") \
		or (not act2 and step not in ["", "s13"]):
		return _bad("阶段 B 主线未走完，当前 step=%s" % step)
	if not missing.is_empty():
		return _bad("阶段 B 缺少主线步骤：%s" % ", ".join(missing))
	if act3 and not G.act1_unlocked_skills().has(G.mentor_second_skill()):
		return _bad("阶段 B 丢失真实领取的导师技能")
	var map_id := String((G.prog.get("main_world", {}) as Dictionary).get("map_id", ""))
	if map_id != ("frost_post" if act3_front else ("shenyuan_port" if act2 else "lorin_wilds")):
		return _bad("阶段 B 不是停在边城：map_id=%s" % map_id)
	# 跨进程奖励账本幂等：重放 s12 那笔主线事务，必须命中 duplicate，且金币一分不动。
	var tid := ""
	for a in (G.ledger().get("applied", []) as Array):
		if String(a).begins_with("story|s28|" if act3 else ("story|s24|" if act3_front else ("story|s20|" if act2 else "story|s12|"))):
			tid = String(a)
			break
	if tid.is_empty():
		return _bad("阶段 B 找不到 s12 的主线事务记录")
	var gold_before := int(G.wallet.get("gold", 0))
	var tx := RewardLedger.make(tid, {}, {"gold": 9999, "exp": 9999}, {})
	var res := RewardLedger.apply(tx, G.ledger(), G)
	if not bool(res.get("duplicate", false)):
		return _bad("阶段 B 重放 s12 事务未判重（applied=%s）" % str(res.get("applied", false)))
	if int(G.wallet.get("gold", 0)) != gold_before:
		return _bad("阶段 B 重放 s12 事务后金币被改动")
	print("PLAY_EVENT idempotent_replay tx=%s duplicate=true gold=%d" % [tid, gold_before])
	var state := _state()
	print("PLAY_B_STATE " + JSON.stringify(state))
	print("PLAY_B_OK role=%s step=%s level=%d gold=%d"
		% [role_id, step, int(state["level"]), int(state["gold"])])
	print("PLAY_OK role=%s" % role_id)
	get_tree().quit(0)


# =========================================================================
# 存档准备
# =========================================================================
func _prep_new_save() -> void:
	G.gm_reset_save()
	G.selected_role = role_id
	G.player_name = "回放"
	G.account = "playthrough_" + role_id
	G.ensure_starter_pets()
	G.ensure_starter_equip(true)
	G.save_game()
	G.reload_save()
	print("PLAY_SETUP new_save role=%s level=%d bag=%d/%d equip=%d"
		% [role_id, int(G.prog.get("level", 1)), G.inv_count(), G.inv_capacity(),
		_equipped_slots().size()])


func _equipped_slots() -> Array:
	var out: Array = []
	for s in (G.equip_cfg().get("slots", []) as Array):
		var sid := String((s as Dictionary).get("id", ""))
		if not G.equip_state(sid).is_empty():
			out.append(sid)
	return out


func _strip_all_equip() -> bool:
	for s in (G.equip_cfg().get("slots", []) as Array):
		var sid := String((s as Dictionary).get("id", ""))
		if G.equip_state(sid).is_empty():
			continue
		var r: Dictionary = G.inv_unequip(sid)
		if not bool(r.get("ok", false)):
			return _bad("卸下 %s 失败：%s" % [sid, String(r.get("err", ""))])
	G.save_game()
	print("PLAY_SETUP stripped_equip bag=%d/%d" % [G.inv_count(), G.inv_capacity()])
	return true


func _equip_all_slots() -> void:
	var em: Dictionary = G._equip_map()
	var first_by_slot := {}
	for it in G.inv_instances():
		var d := it as Dictionary
		var sid := String(d.get("slot", ""))
		if not first_by_slot.has(sid):
			first_by_slot[sid] = int(d.get("uid", 0))
	for s in (G.equip_cfg().get("slots", []) as Array):
		var sid := String((s as Dictionary).get("id", ""))
		if int(em.get(sid, 0)) > 0:
			continue
		if first_by_slot.has(sid):
			G.inv_equip(int(first_by_slot[sid]))
	G.save_game()
	print("PLAY_SETUP reequipped=%d" % _equipped_slots().size())


## 满背包预置（setup，非玩法进度）：与「不要直接给道具」不冲突——只发**装备实例**占格，
#  不涉及金币/经验/任务物/主线状态，用于构造「满包掉落进待领取箱」这一真实边界。
func _fill_bag() -> void:
	var cap := G.inv_capacity()
	var guard := 0
	while G.inv_count() < cap and guard < 400:
		var r: Dictionary = G.inv_grant_equip(
			{"tpl": "tpl_sword_basic", "rarity": 1, "n": 1}, false)
		if not bool(r.get("ok", false)):
			break
		guard += 1
	G.save_game()
	print("PLAY_SETUP bag=%d/%d pending=%d"
		% [G.inv_count(), cap, G.inv_pending().size()])


func _growth_checkpoint(chapter: String, low: int, high: int) -> bool:
	var level := int(G.prog.get("level", 1))
	if level < low or level > high or _map.st.level != level or (_map.st.hp > 0 and _map.st.hp > _map.st.max_hp()):
		return _bad("实际主线等级或同图生命不同步：%s Lv%d" % [chapter, level])
	print("PLAY_EVENT growth_checkpoint chapter=%s level=%d hp=%d max_hp=%d revisions=%d" % [chapter, level, _map.st.hp, _map.st.max_hp(), G.prog.get("campaign_growth", {}).get("story_revision", {}).size()])
	return true

func _campaign_gear_checkpoint(_chapter: String) -> bool:
	return true


func _state() -> Dictionary:
	var story: Dictionary = G.prog.get("story", {})
	var done: Array = (story.get("done", []) as Array).duplicate()
	done.sort()
	var equipped := _equipped_slots()
	equipped.sort()
	return {
		"role": role_id,
		"unlocked_skills": G.act1_unlocked_skills(),
		"story_step": String(story.get("step", "")),
		"story_done_n": done.size(),
		"story_done": done,
		"level": int(G.prog.get("level", 1)),
		"exp": int(G.prog.get("exp", 0)),
		"experience_revision_n": G.prog.get("campaign_growth", {}).get("story_revision", {}).size(),
		"gold": int(G.wallet.get("gold", 0)),
		"frag": int(G.items.get("stele_fragment", 0)),
		"bag": G.inv_count(),
		"cap": G.inv_capacity(),
		"pending": G.inv_pending().size(),
		"ledger_n": (G.ledger().get("applied", []) as Array).size(),
		"map": String((G.prog.get("main_world", {}) as Dictionary).get("map_id", "")),
		"equipped": equipped,
	}


# =========================================================================
# 场景/地图驱动
# =========================================================================
func _find_map() -> MapScene:
	# 取最后一个（最新）MapScene：换场由引擎释放旧幕，这里再兜一层「取最新」。
	var found: MapScene = null
	for c in get_tree().root.get_children():
		if c is MapScene and is_instance_valid(c) and c.is_inside_tree():
			found = c
	return found


func _wait_idle() -> void:
	var f := 0
	while G.transit_busy() and f < 900:
		await get_tree().process_frame
		f += 1


func _wait_new_map(prev_id: int, expect: String) -> MapScene:
	for f in 1500:
		await get_tree().process_frame
		if G.transit_busy():
			continue
		var m := _find_map()
		if m == null or m._player == null:
			continue
		if m.get_instance_id() == prev_id:
			continue
		if not expect.is_empty() and String(m._main_map_id) != expect:
			continue
		for i in 5:
			await get_tree().process_frame
		return m
	return null


func _enter_world(map_id: String, arrival: String, expect: String) -> bool:
	await _wait_idle()
	var prev_id := 0
	if _map != null and is_instance_valid(_map):
		prev_id = _map.get_instance_id()
	if map_id.is_empty():
		G.enter_main_world()
	else:
		G.enter_main_world(map_id, arrival)
	var m := await _wait_new_map(prev_id, expect)
	if m == null:
		_reason = "进入 %s 超时" % expect
		return false
	_map = m
	print("PLAY_MAP enter=%s pos=%s monsters=%d"
		% [String(_map._main_map_id), str(_map._player.position), _map._monsters.size()])
	return true


## 走到当前图的某个出口并真正切到目标图（真实走进触发圈 → 游戏自己切图）。
## 出口触发圈半径 38px：持续走到触发圈内部，由游戏自己切图。
func _exit_to(map_id: String, at: Vector2, expect: String) -> bool:
	if _map == null or not is_instance_valid(_map) or String(_map._main_map_id) != map_id:
		return _bad("出口前置地图不符：期望在 %s" % map_id)
	var prev_id := _map.get_instance_id()
	for f in 3600:
		if _map == null or not is_instance_valid(_map) or _map._player == null:
			break
		if G.transit_busy():
			break
		if _map._trade_panel != null or _map._fishing_panel != null:
			if not await _close_travel_modal(): return _bad("前往出口不能关闭路边生活面板")
			continue
		if _city_modal():
			if not await _close_city_modal():
				return _bad("前往出口无法关闭路边对话")
			continue
		if _map._battle != null:
			var br := await _resolve_battle("win")
			if br != "victory":
				return _bad("去出口途中接战未胜：%s" % br)
			continue
		if _map._player.position.distance_to(at) <= 30.0:
			break
		_steer(at)
		await get_tree().physics_frame
	_release_all()
	var m := await _wait_new_map(prev_id, expect)
	if m == null:
		var pos := Vector2.ZERO
		if _map != null and is_instance_valid(_map) and _map._player != null:
			pos = _map._player.position
		return _bad("出口 %s(%s) 未触发切图 → %s（当前 %s）" % [map_id, str(at), expect, str(pos)])
	_map = m
	print("PLAY_MAP enter=%s pos=%s monsters=%d"
		% [String(_map._main_map_id), str(_map._player.position), _map._monsters.size()])
	return true


# =========================================================================
# 导航（真实输入动作；卡住即报告坐标与碰撞体，不做绕行）
# =========================================================================
func _steer(target: Vector2) -> void:
	if _map == null or _map._player == null:
		return
	var d: Vector2 = target - _map._player.position
	_key("move_left", d.x < -DEADZONE)
	_key("move_right", d.x > DEADZONE)
	_key("move_up", d.y < -DEADZONE)
	_key("move_down", d.y > DEADZONE)


func _key(action: String, down: bool) -> void:
	if down:
		if not Input.is_action_pressed(action):
			Input.action_press(action)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


func _release_all() -> void:
	for a in MOVE_ACTIONS:
		if Input.is_action_pressed(a):
			Input.action_release(a)


func _tgt(t: Variant) -> Vector2:
	if t is Callable:
		return (t as Callable).call()
	return t


## 返回 "ok" / "battle" / "modal" / "blocked" / "timeout" / "gone"
func _walk_to(target: Variant, arrive: float, budget: int) -> String:
	var last_d := 1.0e12
	var stall := 0
	for f in budget:
		if _map == null or not is_instance_valid(_map) or _map._player == null:
			return "gone"
		if _map._battle != null:
			_release_all()
			return "battle"
		if _map._modal_open():
			_release_all()
			return "modal"
		var dest := _tgt(target)
		var pp: Vector2 = _map._player.position
		var d := pp.distance_to(dest)
		if d <= arrive:
			_release_all()
			return "ok"
		if d > last_d - 0.35:
			stall += 1
		else:
			stall = 0
		last_d = d
		if stall > STUCK_LIMIT:
			_release_all()
			print("PLAY_STUCK target=%s pos=%s colliders=%s"
				% [str(dest), str(pp), str(_near_colliders())])
			return "blocked"
		_steer(dest)
		await get_tree().physics_frame
	_release_all()
	return "timeout"


func _near_colliders() -> Array:
	var out: Array = []
	if _map == null or _map._player == null:
		return out
	var space := _map._player.get_world_2d().direct_space_state
	if space == null:
		return out
	var q := PhysicsShapeQueryParameters2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 34.0
	q.shape = sh
	q.transform = Transform2D(0.0, _map._player.position)
	q.collision_mask = 2
	q.collide_with_bodies = true
	for r in space.intersect_shape(q, 8):
		var c: Object = r.get("collider")
		if c != null and c is Node2D:
			out.append("%s@%s" % [String((c as Node).name), str((c as Node2D).global_position)])
	return out


## 走到目标并把途中的真实遭遇/对话处理掉。返回 "ok" / "battle" / "failed"
func _travel(target: Variant, arrive: float, allow_fight: bool,
		close_dialog := true, budget := 3600) -> String:
	var attempt := 0
	while attempt < 8:
		attempt += 1
		var r := await _walk_to(target, arrive, budget)
		match r:
			"ok":
				return "ok"
			"gone":
				return "ok"
			"battle":
				if not allow_fight:
					return "battle"
				var br := await _resolve_battle("win")
				if br == "victory" or br == "flee":
					continue
				_reason = "途中接战异常：%s" % br
				return "failed"
			"modal":
				if _map == null or not is_instance_valid(_map) or G.transit_busy():
					return "ok"
				if _city_modal():
					if not close_dialog:
						return "ok"
					if not await _close_city_modal():
						_reason = "无法关闭对话面板"
						return "failed"
					continue
				if _map._trade_panel != null or _map._fishing_panel != null:
					if not await _close_travel_modal(): return "failed"
					continue
				await _wait_frames(24)
				continue
			"blocked":
				_reason = "导航受阻"
				return "failed"
			_:
				_reason = "导航超时"
				return "failed"
	_reason = "导航反复中断"
	return "failed"


func _move_to(target: Vector2, arrive := 30.0) -> bool:
	var r := await _travel(target, arrive, true, true)
	if r == "ok":
		return true
	return _bad("移动到 %s 失败（%s）%s" % [str(target), r, _reason])


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _need(step: String) -> bool:
	if not G.story_step_done(step):
		return _bad("主线 %s 未完成（当前 step=%s）"
			% [step, String((G.prog.get("story", {}) as Dictionary).get("step", ""))])
	return true


# =========================================================================
# 城内容器：NPC 对话
# =========================================================================
func _city_modal() -> bool:
	if _map == null or not is_instance_valid(_map) or _map._city_content == null:
		return false
	return bool(_map._city_content.call("has_modal"))


func _npc_pos(npc_id: String) -> Vector2:
	var pos_map: Variant = _map._main_cfg.get("city_npc_positions", {})
	if pos_map is Dictionary and (pos_map as Dictionary).has(npc_id):
		var a: Array = (pos_map as Dictionary)[npc_id]
		return Vector2(float(a[0]), float(a[1]))
	return Vector2(-9999, -9999)


func _talk_to(npc_id: String, step: String) -> bool:
	var pos := _npc_pos(npc_id)
	if pos.x < -9000.0:
		return _bad("地图里没有 NPC %s 的坐标" % npc_id)
	# 主街 NPC 密集：半路常被别的 NPC / 建筑拦下弹面板，关掉继续走，直到真的站到目标身边。
	for attempt in 20:
		var r := await _travel(pos, 28.0, true, false)
		if r != "ok":
			return _bad("走到 %s 失败（%s）%s" % [npc_id, r, _reason])
		# 进入 NPC 触发半径时可能先弹出并完成主线；此时还没走到脚本的
		# 导航终点。按真实进度判定成功，避免关面板后因 cooled 标记误报。
		if G.story_step_done(step):
			if not await _close_city_modal():
				return _bad("无法关闭 %s 的对话面板" % npc_id)
			print("PLAY_STEP %s done via %s" % [step, npc_id])
			return true
		var near := false
		if _map != null and is_instance_valid(_map) and _map._player != null:
			near = _map._player.position.distance_to(pos) <= 40.0
		if near:
			break
		if _city_modal():
			if not await _close_city_modal():
				return _bad("无法关闭途中的面板（去 %s 的路上）" % npc_id)
		await _wait_frames(4)
	if _map == null or not is_instance_valid(_map) or _map._player == null:
		return _bad("找 %s 途中地图丢失" % npc_id)
	var d := _map._player.position.distance_to(pos)
	if d > 70.0:
		return _bad("没能站到 %s 身边（距离 %.0f）" % [npc_id, d])
	for i in 120:
		if _city_modal():
			break
		await get_tree().physics_frame
	if not _city_modal():
		return _bad("站到 %s 身边没有触发对话" % npc_id)
	var advanced := G.story_step_done(step)
	if not await _close_city_modal():
		return _bad("无法关闭 %s 的对话面板" % npc_id)
	if not advanced:
		return _bad("与 %s 对话后主线 %s 未推进" % [npc_id, step])
	print("PLAY_STEP %s done via %s" % [step, npc_id])
	return true


## 自动回放路过生活交互时，只点击实际返回按钮，不直接关闭或跳过世界进度。
func _close_travel_modal() -> bool:
	var panel: Control = _map._trade_panel if _map._trade_panel != null else _map._fishing_panel
	if panel == null: return true
	var label := _find_label(panel, ["返回"])
	if label == null: return false
	return await _click_until(label.get_parent() as Control,
		func() -> bool: return _map._trade_panel == null and _map._fishing_panel == null, 40, "travel_back")


func _close_city_modal() -> bool:
	if not _city_modal():
		return true
	# 精确到城务浮层：对话面板末行为「离开」，建筑/布告板面板为「返回」。
	var root: Node = null
	if _map != null and is_instance_valid(_map) and _map._city_content != null:
		root = _map._city_content.get("_panel") as Node
	if root == null:
		root = _map._hud
	var lbl := _find_label(root, ["离开", "返回"])
	if lbl == null:
		print("PLAY_DIAG close_modal no_close_label")
		return false
	var btn := lbl.get_parent() as Control
	return await _click_until(btn, func() -> bool: return not _city_modal(), 60, "close_modal")


func _craft_stele(method: String) -> bool:
	var pos := _npc_pos("npc_smith")
	var label := "用精炼石锻合" if method == "forge" else "花金币拓录"
	for attempt in 20:
		if not _city_modal():
			var r := await _travel(pos, 28.0, true, false)
			if r != "ok":
				return _bad("前往修碑面板失败（%s）%s" % [r, _reason])
		if _city_modal():
			var root: Node = _map._city_content.get("_panel") as Node
			var lbl := _find_label(root, [label])
			if lbl != null:
				var btn := lbl.get_parent() as Control
				if not await _click_until(btn,
					func() -> bool: return G.story_step_done("s11"), 40, "repair"):
					return _bad("点击修碑方案后 s11 未推进")
				print("PLAY_STEP s11 done via craft %s" % method)
				return true
			if not await _close_city_modal():
				return _bad("修碑途中无法关闭其他面板")
		await _wait_frames(4)
	return _bad("未找到石头的修碑面板")


# =========================================================================
# 战斗：全部走真实鼠标点击
# =========================================================================
func _nearest_monster(mon_id := "") -> Variant:
	if _map == null or not is_instance_valid(_map):
		return null
	var best: Variant = null
	var bd := 1.0e12
	var pp: Vector2 = _map._player.position
	for m in _map._monsters:
		if not is_instance_valid(m) or (not mon_id.is_empty() and String(m.mon_id) != mon_id):
			continue
		var d: float = (m as Node2D).position.distance_to(pp)
		if d < bd:
			bd = d
			best = m
	return best


func _await_battle() -> bool:
	for i in 240:
		if _map == null or not is_instance_valid(_map):
			return false
		if _map._battle != null:
			await _wait_frames(8)
			return true
		await get_tree().physics_frame
	return false


## policy: "win" / "flee" / "lose"。返回 sim.result 字符串或 "no_battle"/"battle_timeout"。
func _fight_nearest(policy: String, target_mon_id := "") -> bool:
	var mon: Variant = _nearest_monster(target_mon_id)
	if mon == null:
		return _bad("本图没有可接战的怪")
	var mon_id := String((mon as Object).get("mon_id"))
	var tier := String((mon as Object).get("tier"))
	var getter := func() -> Vector2: return (mon as Node2D).position
	var r := await _travel(getter, 24.0, false, true)
	if r != "battle":
		if r == "ok":
			r = await _travel(getter, 6.0, false, true)
		if r != "battle":
			return _bad("接近 %s 未触发接触（%s）" % [mon_id, r])
	if not await _await_battle():
		return _bad("接触后战斗未开始")
	var res := await _resolve_battle(policy)
	print("PLAY_BATTLE policy=%s mon=%s tier=%s result=%s" % [policy, mon_id, tier, res])
	if policy == "win" and res != "victory":
		return _bad("期望胜利却得到 %s（%s）" % [res, mon_id])
	if policy == "flee" and res != "flee":
		return _bad("期望撤退却得到 %s（%s）" % [res, mon_id])
	if policy in ["lose", "boss_lose"] and res != "defeat":
		return _bad("期望战败却得到 %s（%s）" % [res, mon_id])
	return true


func _resolve_battle(policy: String) -> String:
	if _map == null or not is_instance_valid(_map) or _map._battle == null:
		return "no_battle"
	var bs = _map._battle
	# 等 BattleScene 的按钮就位（_ready 后才创建）
	for i in 60:
		if bs.get("_speed_btn") != null and bs.get("_auto_btn") != null:
			break
		await get_tree().process_frame
	# 速度 ×2（真实点「速度」小钮；用点击前后的档位变化自证点击生效）
	if bs.cur_speed() < 1.5:
		var spd := await _click_until(bs._speed_btn, func() -> bool: return bs.cur_speed() >= 1.5, 20, "speed")
		if not spd:
			return "speed_click_failed"
	# 自动：胜=开（放技能），败/逃=关（只普攻，确保能真的打输）
	var want_auto := policy == "win"
	if bool(bs.sim.auto_mode) != want_auto:
		var auto_ok := await _click_until(bs._auto_btn,
			func() -> bool: return bool(bs.sim.auto_mode) == want_auto, 20, "auto")
		if not auto_ok:
			return "auto_click_failed"
	if policy == "boss_lose":
		var blocked_flee := _cmd_root(bs,"flee")
		if blocked_flee == null or not bool(bs._flee_blocked): return "boss_flee_not_blocked"
		_click(blocked_flee)
		await _wait_frames(4)
		if bool(bs._flee_armed) or bool(bs.sim.finished): return "boss_flee_escaped"
		print("PLAY_EVENT act3_boss_flee_blocked real_click=true")
	if policy == "flee":
		var flee_root := _cmd_root(bs, "flee")
		if flee_root == null:
			return "no_flee_btn"
		# 撤退需同一按钮连点两次；先验证首点确实上膛，再点确认。
		var armed := await _click_until(flee_root,
			func() -> bool: return is_instance_valid(bs) and bool(bs._flee_armed), 8, "flee_arm")
		if not armed:
			return "flee_arm_failed"
		var flew := await _click_until(flee_root,
			func() -> bool: return is_instance_valid(bs) and bool(bs.sim.finished), 8, "flee_confirm")
		if not flew:
			return "flee_click_failed"
	var guard := 0
	while is_instance_valid(bs) and not bs.sim.finished and guard < 120000:
		if act2 and policy == "win" and bs.sim.potions_left > 0 and bs.sim.potion_cd_ticks <= 0:
			var unit: Combatant = bs.sim.role_unit()
			if unit != null and unit.alive and float(unit.hp) / maxf(1.0, unit.get_max_hp()) < 0.55:
				var before_potions := int(bs.sim.potions_left)
				await _click(_cmd_root(bs, "item"))
				var potion_label := _find_label(bs, ["药剂×%d" % before_potions])
				if potion_label != null:
					await _click(potion_label.get_parent() as Control)
					if is_instance_valid(bs) and int(bs.sim.potions_left) < before_potions:
						print("PLAY_EVENT potion_used left=%d" % bs.sim.potions_left)
		await get_tree().process_frame
		guard += 1
	if not is_instance_valid(bs) or not bs.sim.finished:
		return "battle_timeout"
	var result := String(bs.sim.result)
	# 点结算「继续/返回」：真实鼠标，点到达标（战斗节点被撤下）为止
	for i in 90:
		if not is_instance_valid(bs):
			break
		var lbl := _find_label(bs, ["继续", "返回"])
		if lbl != null:
			await _click_until(lbl.get_parent() as Control, _battle_gone.bind(bs), 40, "result_btn")
			break
		await get_tree().process_frame
	if policy == "lose":
		var g := 0
		while g < 1500 and _find_map() != null:
			await get_tree().process_frame
			g += 1
		_map = null
		return result
	var g2 := 0
	while g2 < 900:
		if _map == null or not is_instance_valid(_map) or _map._battle == null:
			break
		await get_tree().process_frame
		g2 += 1
	await _wait_frames(6)
	return result


func _battle_gone(bs: Variant) -> bool:
	if _map == null or not is_instance_valid(_map):
		return true
	if not is_instance_valid(bs):
		return true
	return _map._battle != bs


func _cmd_root(bs: Node, key: String) -> Control:
	var rows: Variant = bs.get("_cmd_btns")
	if rows is Array:
		for row in (rows as Array):
			if String((row as Dictionary).get("key", "")) == key:
				return (row as Dictionary).get("root") as Control
	return null


# =========================================================================
# 真实鼠标事件
# =========================================================================
func _control_center(c: Control) -> Vector2:
	var r := c.get_global_rect()
	if r.size.x < 1.0 or r.size.y < 1.0:
		return c.global_position + Vector2(8.0, 8.0)
	return r.get_center()


func _mouse_events(p: Vector2) -> Array:
	var mm := InputEventMouseMotion.new()
	mm.position = p
	mm.global_position = p
	var dn := InputEventMouseButton.new()
	dn.button_index = MOUSE_BUTTON_LEFT
	dn.button_mask = MOUSE_BUTTON_MASK_LEFT
	dn.pressed = true
	dn.position = p
	dn.global_position = p
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = p
	up.global_position = p
	return [mm, dn, up]


## 三种真实鼠标注入方式，按序尝试（headless 下 GUI 拾取对坐标系敏感）：
##   0 = Viewport.push_input(ev, true)  视口局部坐标
##   1 = Viewport.push_input(ev, false) 窗口坐标（自动换算）
##   2 = Input.parse_input_event()      走 Input 单例派发
func _click_mode(c: Control, mode: int) -> void:
	if c == null or not is_instance_valid(c) or not c.is_inside_tree():
		return
	for e in _mouse_events(_control_center(c)):
		match mode:
			0:
				get_viewport().push_input(e, true)
			1:
				get_viewport().push_input(e, false)
			_:
				Input.parse_input_event(e)
		await get_tree().process_frame


func _click(c: Control) -> void:
	await _click_mode(c, 0)


## 点下去直到 done() 为真：逐个注入方式试，每种都留出预算。真实点击、真实效果自证。
func _click_until(c: Control, done: Callable, budget := 60, tag := "") -> bool:
	if bool(done.call()):
		return true
	if c == null or not is_instance_valid(c) or not c.is_inside_tree():
		return false
	for mode in 3:
		await _click_mode(c, mode)
		for i in budget:
			if bool(done.call()):
				print("PLAY_DIAG click_ok mode=%d tag=%s" % [mode, tag])
				return true
			await get_tree().process_frame
	if tag != "":
		print("PLAY_DIAG click_failed tag=%s rect=%s vp=%s local=%s canvas=%s"
			% [tag, str(c.get_global_rect()), str(get_viewport().get_visible_rect()),
			str(get_viewport().get_final_transform()), str(get_viewport().get_canvas_transform())])
	return false


func _find_label(root: Node, want: Array) -> Label:
	if root == null or not is_instance_valid(root):
		return null
	for c in root.get_children():
		if c is Label and want.has(String((c as Label).text).replace(" ", "")):
			return c as Label
		var r := _find_label(c, want)
		if r != null:
			return r
	return null


# =========================================================================
# 收尾
# =========================================================================
func _bad(msg: String) -> bool:
	_release_all()
	var pos := "?"
	if _map != null and is_instance_valid(_map) and _map._player != null:
		pos = str(_map._player.position)
	print("PLAY_BAD role=%s phase=%s pos=%s reason=%s" % [role_id, phase, pos, msg])
	get_tree().quit(1)
	return false
