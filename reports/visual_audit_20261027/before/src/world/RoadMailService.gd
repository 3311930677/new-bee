## 通关后归路邮驿：纯状态机。世界场景只上报已触达的实体，存档与奖励由 G 负责。
class_name RoadMailService
extends RefCounted

const ID_BOARD := "road_mail_board"
const ID_CLUE := "road_mail_sand_signal"
const ID_TRACE := "road_mail_stone_trace"
const ID_QUICK := "road_mail_quick_marker"
const ID_SAFE := "road_mail_safe_shelter"
const ID_SAFE_HAZARD := "road_mail_safe_courier"
const ID_DELIVER := "road_mail_port_receiver"

static func ensure(raw: Variant) -> Dictionary:
	var out: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
	if not out.has("status"): out["status"] = "idle"
	if not out.has("phase"): out["phase"] = ""
	if not out.has("route"): out["route"] = ""
	if not out.has("run_id"): out["run_id"] = ""
	if not out.has("run_seq"): out["run_seq"] = 0
	if not out.has("last_claim_day"): out["last_claim_day"] = 0
	if not out.has("deliveries"): out["deliveries"] = 0
	if not out.has("archive") or not (out["archive"] is Array): out["archive"] = []
	if not out.has("observed_clues") or not (out["observed_clues"] is Array): out["observed_clues"] = []
	if not out.has("solution"): out["solution"] = ""
	if not out.has("encounter"): out["encounter"] = ""
	if not out.has("penalty_gold"): out["penalty_gold"] = 0
	return out

static func letter(raw: Variant) -> String:
	var s := ensure(raw)
	if String(s["status"]) in ["active", "delivered"]:
		return String(s.get("letter", ""))
	if int(s["deliveries"]) > 0:
		var archive: Array = s["archive"]
		if not archive.is_empty(): return String((archive.back() as Dictionary).get("reply", ""))
	return "青姨托你送出第一封迟到的信：收件人在沉渊港北岸修桥，等着霜关的消息。"

static func visible(eid: String, raw: Variant, day: int, unlocked: bool) -> bool:
	if not unlocked: return false
	var s := ensure(raw)
	var status := String(s["status"])
	var phase := String(s["phase"])
	match eid:
		ID_BOARD:
			return status == "active" or status == "delivered" or not (s["archive"] as Array).is_empty() or \
				(status in ["idle", "claimed"] and day > int(s["last_claim_day"]))
		ID_CLUE:
			return status == "active" and phase == "travel"
		ID_TRACE:
			return status == "active" and phase == "clue" and not "stone" in (s["observed_clues"] as Array)
		ID_QUICK:
			return status == "active" and phase == "clue" and String(s["route"]) == "quick"
		ID_SAFE:
			return status == "active" and phase == "clue" and String(s["route"]) == "safe"
		ID_SAFE_HAZARD:
			return status == "active" and phase == "hazard" and String(s["route"]) == "safe"
		ID_DELIVER:
			return status == "active" and phase == "pass"
	return false

static func goal(raw: Variant, day: int) -> String:
	var s := ensure(raw)
	if String(s["status"]) == "delivered":
		return "信已送达；回霜关归路邮驿结算"
	if String(s["status"]) == "active":
		match String(s["phase"]):
			"travel": return "到赤砂商路查看路标与风沙痕迹"
			"clue":
				return "查看风蚀石的旧痕，或付 18 金请驿亭引路；再到东侧驿亭" if String(s["route"]) == "safe" \
					else "查看风蚀石的旧痕，或付 18 金请驿亭引路；再到西侧路标"
			"hazard":
				return "到东侧驿亭照顾受伤信使" if String(s["route"]) == "safe" else \
					"击退赤砂路上的伏沙蝎，护住邮袋"
			"pass": return "把邮袋送到沉渊港的收信人"
	if int(s["last_claim_day"]) >= day:
		return "今日回信已收好；歇脚后可接下一趟"
	return "从霜关驿的归路邮驿接下一封信"

## action ∈ accept_quick / accept_safe / inspect / trace / pass_observe / pass_supply /
##          hazard_battle / hazard_help / hazard_escort / deliver / claim。
## 仅返回下一状态，拒绝时不改调用方数据；map_id 在此校验，避免直接调用跳关。
static func transition(raw: Variant, action: String, map_id: String, day: int) -> Dictionary:
	var s := ensure(raw)
	var status := String(s["status"])
	var phase := String(s["phase"])
	if action in ["accept_quick", "accept_safe"]:
		if map_id != "frost_post" or status not in ["idle", "claimed"] \
				or day <= int(s["last_claim_day"]): return {"ok": false, "reason": "not_available"}
		var seq := int(s["run_seq"]) + 1
		s["run_seq"] = seq
		s["run_id"] = "mail|%d|%d" % [day, seq]
		s["accepted_day"] = day
		s["route"] = "quick" if action == "accept_quick" else "safe"
		s["status"] = "active"
		s["phase"] = "travel"
		s["letter"] = "给阿澜：北岸栈桥修好了，霜关的灯还亮着。等你回信。" if int(s["deliveries"]) == 0 \
			else "给沉渊港守路人：今日的霜关仍有灯火，请把沿途路况带回来。"
		s["reply"] = ""
		s["observed_clues"] = []
		s["solution"] = ""
		s["encounter"] = ""
		s["penalty_gold"] = 0
		return {"ok": true, "next": s, "line": "邮袋已收好。先去赤砂商路辨认旧路标。"}
	if action == "inspect":
		if map_id != "red_sand_route" or status != "active" or phase != "travel":
			return {"ok": false, "reason": "wrong_step"}
		s["phase"] = "clue"
		s["observed_clues"] = ["sand"]
		return {"ok": true, "next": s, "line": "沙痕指向两条旧路；按接单时选的路，去处理前方路况。"}
	if action == "trace":
		if map_id != "red_sand_route" or status != "active" or phase != "clue" \
				or "stone" in (s["observed_clues"] as Array):
			return {"ok": false, "reason": "wrong_step"}
		(s["observed_clues"] as Array).append("stone")
		return {"ok": true, "next": s, "line": "风蚀石背面的刻痕与路标缺口相合。现在可以自己辨路，不必购买补给。"}
	if action in ["pass_observe", "pass_supply"]:
		if map_id != "red_sand_route" or status != "active" or phase != "clue":
			return {"ok": false, "reason": "wrong_step"}
		if action == "pass_observe" and not "stone" in (s["observed_clues"] as Array):
			return {"ok": false, "reason": "need_trace"}
		s["phase"] = "hazard"
		s["solution"] = "observe" if action == "pass_observe" else "supply"
		return {"ok": true, "next": s, "cost_gold": 18 if action == "pass_supply" else 0,
			"line": "你照刻痕校正路标。前方还有一段危险路。" if action == "pass_observe" else \
				"驿亭收下 18 金并给你路图；前方仍需护住邮袋。"}
	if action == "hazard_battle":
		if map_id != "red_sand_route" or status != "active" or phase != "hazard" \
				or String(s["route"]) != "quick":
			return {"ok": false, "reason": "wrong_step"}
		s["phase"] = "pass"
		s["encounter"] = "ambush"
		return {"ok": true, "next": s, "line": "伏沙蝎已退，信封仍完好。"}
	if action in ["hazard_help", "hazard_escort"]:
		if map_id != "red_sand_route" or status != "active" or phase != "hazard" \
				or String(s["route"]) != "safe":
			return {"ok": false, "reason": "wrong_step"}
		s["phase"] = "pass"
		s["encounter"] = "help" if action == "hazard_help" else "escort"
		s["penalty_gold"] = 0 if action == "hazard_help" else 20
		return {"ok": true, "next": s, "cost_gold": 12 if action == "hazard_help" else 0,
			"line": "你花 12 金包扎信使，按时送往港口。" if action == "hazard_help" else \
				"你扶着信使慢行到港口；本趟报酬少 20 金。"}
	if action == "deliver":
		if map_id != "shenyuan_port" or status != "active" or phase != "pass":
			return {"ok": false, "reason": "wrong_step"}
		s["status"] = "delivered"
		s["phase"] = ""
		s["reply"] = "阿澜说：我以为那盏灯早灭了。请告诉守灯的人，港口这边也会留一盏。" \
			if int(s["deliveries"]) == 0 else "港口守路人报平安：这条路今天也有人走过，我会继续留灯。"
		return {"ok": true, "next": s, "line": String(s["reply"])}
	if action == "claim":
		if map_id != "frost_post" or status != "delivered":
			return {"ok": false, "reason": "wrong_step"}
		s["status"] = "claimed"
		s["last_claim_day"] = day
		s["deliveries"] = int(s["deliveries"]) + 1
		var archive: Array = s["archive"]
		archive.append({"run_id": String(s["run_id"]), "day": day,
			"route": String(s["route"]), "letter": String(s.get("letter", "")),
			"reply": String(s.get("reply", "")), "solution": String(s.get("solution", "")),
			"encounter": String(s.get("encounter", ""))})
		if archive.size() > 8: archive.pop_front()
		s["archive"] = archive
		return {"ok": true, "next": s, "reward": {"gold": maxi(0, 160 - int(s.get("penalty_gold", 0))), "item:pet_food": 1},
			"line": "霜关收下回信。归路邮驿记下了这次往返。"}
	return {"ok": false, "reason": "unknown"}
