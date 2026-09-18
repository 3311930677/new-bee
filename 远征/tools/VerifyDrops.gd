# VerifyDrops.gd —— 战斗掉落表回归
extends Node

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "user://save_verify_drops.json"
	await _run()
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


func _run() -> void:
	var drops: Dictionary = TableCache.drops_config().get("drops", {})
	var bad: Array = []
	for tier in ["normal", "elite", "boss"]:
		var rows: Variant = drops.get(tier, [])
		if not (rows is Array) or (rows as Array).is_empty():
			bad.append(tier + ":缺表")
			continue
		for r in (rows as Array):
			var d := r as Dictionary
			var iid := String(d.get("item", ""))
			if not G.ITEM_NAMES.has(iid):
				bad.append(tier + ":" + iid + " 未登记")
			var ch := float(d.get("chance", 0.0))
			if ch <= 0.0 or ch > 1.0:
				bad.append(tier + ":" + iid + " 概率非法")
			var lv := int(d.get("min", 1))
			var hv := int(d.get("max", 1))
			if lv < 1 or hv < lv:
				bad.append(tier + ":" + iid + " 数量非法")
	_check(bad.is_empty(), "掉落表问题：%s" % str(bad))

	# B. 必出条目：精英必出强化石、首领必出精炼石（多轮掷表均应命中）
	for i in 12:
		var got_e := G.roll_drops("elite")
		var has_es := false
		for r in got_e:
			if String((r as Dictionary).get("item", "")) == "enhance_stone":
				has_es = true
		_check(has_es, "精英必出强化石（第 %d 轮为空）" % (i + 1))

	# C. 掉落入账：掷出的每一件都能进库存，数量 ≥1
	G.items = {"ticket_sweep": 1}
	var got := G.roll_drops("boss")
	_check(not got.is_empty(), "首领掷表应至少出一件")
	for r in got:
		var d := r as Dictionary
		var iid := String(d.get("item", ""))
		var n := int(d.get("n", 1))
		var before := G.item_count(iid)
		G.grant_item(iid, n)
		_check(G.item_count(iid) == before + n, "%s 未入账" % iid)
	_check(G.item_count("refine_stone") >= 2, "首领必出精炼石 ×2")

	if _fails == 0:
		print("DROPS_OK all tests passed")
	else:
		print("DROPS_FAIL fails=%d" % _fails)
