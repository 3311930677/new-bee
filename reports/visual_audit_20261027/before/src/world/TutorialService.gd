## 新手引导服务（11 步剧情融合式交互引导 + 状态持久化 + 跳过/恢复/重温 + 完训奖励）
class_name TutorialService
extends RefCounted

const STEPS := [
	{
		"id": "step_01_role",
		"index": 1,
		"speaker": "边城执事·闻叔",
		"title": "第1步 · 命途立世（主城角色与姿态）",
		"body": "欢迎来到昭元边城！城门拱洞下伫立着你当前执掌的命途角色。点按城门角色可切换五向立姿，随时检视破军、穿杨、霜语、晨星四职风采。",
		"action_hint": "实操任务：点「实操演示」切换立姿，或点「下一步」",
		"scene": "home",
		"panel": "home",
		"page_badge": "当前页面：主城总览 · 城门命途舞台",
		"highlight": [164, 442, 152, 136],
		"event": "role_inspected",
	},
	{
		"id": "step_02_move",
		"index": 2,
		"speaker": "边城执事·闻叔",
		"title": "第2步 · 踏足街巷（出征探索大世界）",
		"body": "底部中央的「出征」大印是步入昭元边城与外野的唯一总入口。进入地图后可用摇杆或 WASD 自由行走，靠近发光器物与路牌即可交互。",
		"action_hint": "实操任务：点「实操演示」进入主世界，推动摇杆或按方向键移动",
		"scene": "home",
		"panel": "home",
		"page_badge": "当前页面：主城总览 · 底部【出征】大印",
		"highlight": [164, 658, 152, 128],
		"event": "player_moved",
	},
	{
		"id": "step_03_npc",
		"index": 3,
		"speaker": "边城执事·闻叔",
		"title": "第3步 · 主线传书（寻访NPC与章节目标）",
		"body": "已为你自动打开【任务卷宗】！上方「主线传书」记载着当前章节要务（如寻访闻叔、铁匠陈铁山、药师苏木）。点「行路图」可直看目标所在区域。",
		"action_hint": "实操任务：查看上方「主线传书」，点「下一步」看委托",
		"scene": "world",
		"panel": "quests",
		"page_badge": "已自动切页 ▶ 任务卷宗 · 主线传书",
		"highlight": [28, 136, 424, 152],
		"event": "npc_talked",
	},
	{
		"id": "step_04_quest",
		"index": 4,
		"speaker": "边城执事·闻叔",
		"title": "第4步 · 边城委托（追踪信标与信使交付）",
		"body": "下方「边城委托」列出可接取的悬赏与支线。点击「追踪」后路牌与地图会亮起方向信标；达标后的日常支线更可直接「信使交付」免去跑图！",
		"action_hint": "实操任务：点「实操演示」接取委托，或点「下一步」",
		"scene": "home",
		"panel": "quests",
		"page_badge": "当前页面 ▶ 任务卷宗 · 边城委托与信使交付",
		"highlight": [28, 336, 424, 280],
		"event": "quest_tracked",
	},
	{
		"id": "step_05_battle",
		"index": 5,
		"speaker": "边城教头·雷烈",
		"title": "第5步 · 演武切磋（战斗机制与段位试炼）",
		"body": "已自动切换至【演武场】！战斗中角色自动普攻攒能，点选招式可施放职业绝技并支持 ×1/×2/×4/×8 倍速。在此与机关傀儡切磋可演练连招、赢取演武荣誉！",
		"action_hint": "实操任务：点「实操演示」进入野外，打一场真实战斗",
		"scene": "battle",
		"panel": "arena",
		"page_badge": "已自动切页 ▶ 演武场 · 傀儡切磋与武艺试炼",
		"highlight": [24, 148, 432, 248],
		"event": "battle_started",
	},
	{
		"id": "step_06_reward",
		"index": 6,
		"speaker": "边城教头·雷烈",
		"title": "第6步 · 校场射艺（迎风控弦与鉴宝玩法）",
		"body": "已自动进入【校场射艺 · 演武靶场】！观察顶部风向旗偏转、将准星逆风微调，并在蓄力金区松手即可正中十环，斩获金币、荣誉与【百步穿杨】称号！",
		"action_hint": "实操任务：点「实操演示」试射十环，或点「下一步」",
		"scene": "battle",
		"panel": "archery",
		"page_badge": "已自动切页 ▶ 校场射艺 · 演武靶场小游戏",
		"highlight": [20, 96, 440, 356],
		"event": "battle_won",
	},
	{
		"id": "step_07_equip",
		"index": 7,
		"speaker": "铁匠铺·老周",
		"title": "第7步 · 披坚执锐（背包穿戴与词条对比）",
		"body": "已自动切换至【行旅背包】！点选战利品兵刃即可在下方详情区直观对比当前穿戴装备的战力、强化等级与特殊词条，一键「穿戴」立刻提升战力。",
		"action_hint": "实操任务：查看下方装备详情与穿戴区，点「下一步」",
		"scene": "bag",
		"panel": "bag",
		"page_badge": "已自动切页 ▶ 行旅背包 · 装备穿戴与属性对比",
		"highlight": [16, 488, 448, 296],
		"event": "equip_worn",
	},
	{
		"id": "step_08_growth",
		"index": 8,
		"speaker": "铁匠铺·老周",
		"title": "第8步 · 百炼成钢（六维养成与灵宠羁绊）",
		"body": "已自动切换至【人物养成】！这里汇总了装备强化精炼、职业天赋、技能书研习、灵宠羁绊喂养、坐骑与称号六大成长线，顶部还会智能推荐当前可升项目。",
		"action_hint": "实操任务：查看六大养成线与推荐栏，点「下一步」",
		"scene": "growth",
		"panel": "growth",
		"page_badge": "已自动切页 ▶ 人物养成 · 六维成长枢纽",
		"highlight": [24, 340, 432, 390],
		"event": "growth_opened",
	},
	{
		"id": "step_09_map_switch",
		"index": 9,
		"speaker": "驿站车夫·老马",
		"title": "第9步 · 古道远行（地区行路图与驿车直达）",
		"body": "已自动打开【地区行路图】！全图直观展示 12 处边城与外野的连通拓扑。点「寻迹」可定位当前任务目的地，点选任意已探索区域即可免费「乘驿车前往」！",
		"action_hint": "实操任务：点「实操演示」定位区域，或点「下一步」",
		"scene": "home",
		"panel": "worlds",
		"page_badge": "已自动切页 ▶ 地区行路图 · 区域拓扑与驿车",
		"highlight": [20, 72, 440, 412],
		"event": "map_switched",
	},
	{
		"id": "step_10_return_town",
		"index": 10,
		"speaker": "边城执事·闻叔",
		"title": "第10步 · 易职整备（随时重选角色与备份）",
		"body": "已自动打开【设置】面板！在「常规」与「旅人」页顶部均可随时点击「重选角色 · 易职」无损切换四大职业，也可在此重温新手指引或导出备份存档码。",
		"action_hint": "实操任务：记住「重选角色·易职」入口，点「下一步」",
		"scene": "home",
		"panel": "settings",
		"page_badge": "已自动切页 ▶ 设置 · 重选角色与存档管理",
		"highlight": [24, 182, 432, 108],
		"event": "returned_home",
	},
	{
		"id": "step_11_goals",
		"index": 11,
		"speaker": "边城执事·闻叔",
		"title": "第11步 · 远征启程（领取完训启程贺礼）",
		"body": "已返回【主城总览】！请先在野外赢得一场战斗，亲手走通探索与整备。回城后点击「完成引导 · 领礼」，领取金币×300、远征币×30、强化石×3、口粮×2。",
		"action_hint": "实操任务：赢得一场野外战斗，再领取启程贺礼",
		"scene": "home",
		"panel": "home",
		"page_badge": "已返回 ▶ 主城总览 · 领取启程贺礼",
		"highlight": [68, 592, 344, 76],
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
	if not tut.has("field_battle_won"):
		tut["field_battle_won"] = false
	if not tut.has("field_moved"):
		tut["field_moved"] = false
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
		"field_battle_won": false,
		"field_moved": false,
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
	if idx == 1 and not bool(tut.get("field_moved", false)):
		return {"ok": false, "finished": false, "reason": "先在主世界移动一次"}
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
	if not bool(tut.get("field_battle_won", false)):
		return {"ok": false, "finished": false, "reason": "先在野外赢得一场战斗"}
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
	if event_name == "battle_won":
		var progress := ensure_state(host)
		progress["field_battle_won"] = true
		if host.has_method("save_game"):
			host.save_game()
	if event_name == "player_moved":
		ensure_state(host)["field_moved"] = true
	var step := current_step(host)
	if String(step.get("event", "")) == event_name:
		advance(host, true)
		return true
	return false
