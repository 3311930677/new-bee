## 新手引导服务（11 步剧情融合式交互引导 + 状态持久化 + 跳过/恢复/重温 + 完训奖励）
class_name TutorialService
extends RefCounted

const STEPS := [
	{
		"id": "step_01_role",
		"index": 1,
		"speaker": "边城执事·闻叔",
		"title": "初入昭元 · 认识命途角色",
		"body": "欢迎来到昭元边城！城门前伫立着你所选的命途角色，点按人物可切换五向姿态，顶栏「易职」可随时切换四大职业。",
		"action_hint": "可点按城门前的主角切换朝向，或点「下一步」继续",
		"scene": "home",
		"highlight": [164, 440, 152, 154],
		"event": "role_inspected",
	},
	{
		"id": "step_02_move",
		"index": 2,
		"speaker": "边城执事·闻叔",
		"title": "踏足街巷 · 移动与地图探索",
		"body": "点击主城下方「出征」即可步入昭元边城与外野。使用左下角摇杆或 WASD/方向键移动，靠近发光地物即可调查。",
		"action_hint": "点按底部「出征」进入大世界，或在地图中移动角色",
		"scene": "home",
		"highlight": [174, 668, 132, 124],
		"event": "player_moved",
	},
	{
		"id": "step_03_npc",
		"index": 3,
		"speaker": "边城执事·闻叔",
		"title": "街坊寻访 · 与 NPC 交谈",
		"body": "走近头顶带有名字与话泡标识的闻叔或镇民，点击右侧交互键（或空格/回车）即可展开交谈，获取边城风物与任务线索。",
		"action_hint": "在城内走近 NPC 交谈，或点「下一步」继续了解",
		"scene": "world",
		"highlight": [140, 260, 200, 160],
		"event": "npc_talked",
	},
	{
		"id": "step_04_quest",
		"index": 4,
		"speaker": "边城执事·闻叔",
		"title": "使命在肩 · 接取与追踪任务",
		"body": "点击任务条打开「任务卷宗」可查看主线与支线。追踪任务后，各路口路牌与地区行路图都会浮现「主线/支线」方向信标！",
		"action_hint": "点击主城任务条查看任务卷宗，或追踪任意支线委托",
		"scene": "home",
		"highlight": [80, 598, 320, 68],
		"event": "quest_tracked",
	},
	{
		"id": "step_05_battle",
		"index": 5,
		"speaker": "边城教头·雷烈",
		"title": "兵刃初试 · 基础战斗与招式",
		"body": "在外野接触敌影即刻开战。角色会自动普攻积攒能量，点按下方招式图标可施放职业绝技，也可随时切换 ×1/×2 战斗倍速。",
		"action_hint": "前往枫林古道接触敌影体验战斗，或点「下一步」",
		"scene": "battle",
		"highlight": [24, 620, 432, 120],
		"event": "battle_started",
	},
	{
		"id": "step_06_reward",
		"index": 6,
		"speaker": "边城教头·雷烈",
		"title": "凯旋归囊 · 战斗奖励与战利品",
		"body": "击败敌人可斩获角色经验、金币、强化石与随机词条装备。挑战区域精英与首领更会掉落稀有兵刃与突破晶石。",
		"action_hint": "赢得一场战斗查收战利品，或点「下一步」",
		"scene": "battle",
		"highlight": [60, 240, 360, 240],
		"event": "battle_won",
	},
	{
		"id": "step_07_equip",
		"index": 7,
		"speaker": "铁匠铺·老周",
		"title": "披坚执锐 · 装备穿戴与属性对比",
		"body": "打开顶栏右侧「背包」，点选战利品即可直观对比当前穿戴装备的战力与属性差异，点击「穿戴」立即强化战力。",
		"action_hint": "点击顶栏「背包」查看或穿戴装备",
		"scene": "bag",
		"highlight": [354, 42, 54, 62],
		"event": "equip_worn",
	},
	{
		"id": "step_08_growth",
		"index": 8,
		"speaker": "铁匠铺·老周",
		"title": "百炼成钢 · 角色六维养成",
		"body": "在底栏「养成」或主城「铁匠铺」中，可消耗旅途所得升级职业天赋、强化精炼兵刃、研习技能书并培养协战伙伴。",
		"action_hint": "点击左下角「养成」或「铁匠铺」查看成长线",
		"scene": "growth",
		"highlight": [10, 700, 82, 92],
		"event": "growth_opened",
	},
	{
		"id": "step_09_map_switch",
		"index": 9,
		"speaker": "驿站车夫·老马",
		"title": "古道远行 · 地图切换与驿车直达",
		"body": "走向地图边缘的路牌即可切换相邻区域；打开主城「世界」或野外「地区行路图」，已探索区域还能免费「乘驿车前往」！",
		"action_hint": "点击主城「世界」查看地区行路图，或经路牌切换地图",
		"scene": "home",
		"highlight": [180, 326, 120, 48],
		"event": "map_switched",
	},
	{
		"id": "step_10_return_town",
		"index": 10,
		"speaker": "边城执事·闻叔",
		"title": "烽火归城 · 返回主城与信使交付",
		"body": "完成外野探索后，可随时返回主城整备、在集市兑换补给；已达标的简单支线还能在任务卷宗内直接「信使交付」免去跑图。",
		"action_hint": "从野外返回主城或查看主城设施",
		"scene": "home",
		"highlight": [316, 260, 118, 48],
		"event": "returned_home",
	},
	{
		"id": "step_11_goals",
		"index": 11,
		"speaker": "边城执事·闻叔",
		"title": "远征启程 · 昭元长卷与后续目标",
		"body": "恭喜完成新手指引！点击「领取启程礼」可获金币×300、远征币×30、强化石×3、口粮×2。愿你在昭元四幕征途中披荆斩棘！",
		"action_hint": "点击「完成引导 · 领启程礼」正式开启远征",
		"scene": "home",
		"highlight": [80, 598, 320, 68],
		"event": "tutorial_completed",
	},
]

const COMPLETION_REWARD := {
	"gold": 300,
	"expedition": 30,
	"items": {
		"enhance_stone": 3,
		"pet_food": 2,
	}
}


static func total_steps() -> int:
	return STEPS.size()


static func ensure_state(host: Object) -> Dictionary:
	if host == null or not ("prog" in host):
		return _default_state()
	var prog: Dictionary = host.prog
	if not (prog.get("tutorial") is Dictionary):
		var st := _default_state()
		# 老存档兼容：如果主线已推进过 s03 或等级 >= 5，默认标记已完成，不打扰老档或测试夹具；
		# 老档玩家仍可随时在「设置 -> 旅人 -> 新手指引」重温全部 11 步教程。
		var done_arr: Array = prog.get("story", {}).get("done", [])
		var lv := int(prog.get("level", 1))
		if done_arr.size() >= 3 or lv >= 5:
			st["completed"] = true
			st["step_idx"] = STEPS.size() - 1
		prog["tutorial"] = st
	var tut: Dictionary = prog["tutorial"]
	if not tut.has("step_idx"):
		tut["step_idx"] = 0
	if not tut.has("completed"):
		tut["completed"] = false
	if not tut.has("skipped"):
		tut["skipped"] = false
	if not tut.has("reward_claimed"):
		tut["reward_claimed"] = false
	if not (tut.get("seen_steps") is Array):
		tut["seen_steps"] = []
	tut["step_idx"] = clampi(int(tut.get("step_idx", 0)), 0, STEPS.size() - 1)
	return tut


static func _default_state() -> Dictionary:
	return {
		"step_idx": 0,
		"completed": false,
		"skipped": false,
		"reward_claimed": false,
		"seen_steps": [],
	}


static func should_show(host: Object) -> bool:
	if host == null:
		return false
	if host.has_meta("ui_review_mode") and bool(host.get_meta("ui_review_mode")) and not bool(host.get_meta("force_tutorial_shot", false)):
		return false
	var tut := ensure_state(host)
	if bool(tut.get("completed", false)) or bool(tut.get("skipped", false)):
		return false
	return true


static func current_step(host: Object) -> Dictionary:
	var tut := ensure_state(host)
	var idx := clampi(int(tut.get("step_idx", 0)), 0, STEPS.size() - 1)
	return STEPS[idx]


static func step_at(idx: int) -> Dictionary:
	return STEPS[clampi(idx, 0, STEPS.size() - 1)]


static func advance(host: Object, save: bool = true) -> Dictionary:
	var tut := ensure_state(host)
	var idx := clampi(int(tut.get("step_idx", 0)), 0, STEPS.size() - 1)
	var cur_id := String(STEPS[idx].get("id", ""))
	var seen: Array = tut.get("seen_steps", [])
	if not seen.has(cur_id):
		seen.append(cur_id)
	tut["seen_steps"] = seen
	if idx + 1 < STEPS.size():
		tut["step_idx"] = idx + 1
		if save and host.has_method("save_game"):
			host.save_game()
		return {"ok": true, "finished": false, "step_idx": int(tut["step_idx"]), "reward_granted": false}
	return complete(host, save)


static func prev(host: Object, save: bool = false) -> Dictionary:
	var tut := ensure_state(host)
	var idx := clampi(int(tut.get("step_idx", 0)), 0, STEPS.size() - 1)
	tut["step_idx"] = maxi(0, idx - 1)
	if save and host.has_method("save_game"):
		host.save_game()
	return {"ok": true, "step_idx": int(tut["step_idx"])}


static func skip(host: Object, save: bool = true) -> Dictionary:
	var tut := ensure_state(host)
	tut["skipped"] = true
	if save and host.has_method("save_game"):
		host.save_game()
	return {"ok": true, "skipped": true}


static func restart(host: Object, save: bool = true) -> Dictionary:
	var tut := ensure_state(host)
	tut["step_idx"] = 0
	tut["completed"] = false
	tut["skipped"] = false
	if save and host.has_method("save_game"):
		host.save_game()
	return {"ok": true, "step_idx": 0}


static func complete(host: Object, save: bool = true) -> Dictionary:
	var tut := ensure_state(host)
	var seen: Array = tut.get("seen_steps", [])
	for s in STEPS:
		var sid := String(s.get("id", ""))
		if not seen.has(sid):
			seen.append(sid)
	tut["seen_steps"] = seen
	tut["step_idx"] = STEPS.size() - 1
	tut["completed"] = true
	tut["skipped"] = false
	var granted := false
	if not bool(tut.get("reward_claimed", false)):
		tut["reward_claimed"] = true
		granted = true
		if "wallet" in host and host.wallet is Dictionary:
			host.wallet["gold"] = int(host.wallet.get("gold", 0)) + int(COMPLETION_REWARD.gold)
			host.wallet["expedition"] = int(host.wallet.get("expedition", 0)) + int(COMPLETION_REWARD.expedition)
		if host.has_method("add_item"):
			for k in COMPLETION_REWARD.items:
				host.add_item(String(k), int(COMPLETION_REWARD.items[k]))
		elif "items" in host and host.items is Dictionary:
			for k in COMPLETION_REWARD.items:
				host.items[String(k)] = int(host.items.get(String(k), 0)) + int(COMPLETION_REWARD.items[k])
	if save and host.has_method("save_game"):
		host.save_game()
	return {
		"ok": true,
		"finished": true,
		"step_idx": int(tut["step_idx"]),
		"reward_granted": granted,
		"reward_text": "金币+300 · 远征币+30 · 强化石×3 · 口粮×2",
	}


static func notify_event(host: Object, event_name: String) -> bool:
	if not should_show(host):
		return false
	var step := current_step(host)
	if String(step.get("event", "")) == event_name:
		advance(host, true)
		return true
	return false
