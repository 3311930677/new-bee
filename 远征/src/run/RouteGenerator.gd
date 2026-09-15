# RouteGenerator.gd —— 一局路线生成（玩法文档 §2.6；nodes.json 驱动）
# 结构：起点 → 3 层 × 3 选 1 → BOSS；按权重抽取，三条保底修正，种子确定可复现。
# 保底顺序：事件 → 商店 → 第 2 层精英；后置保底不覆盖前置保底占下的位置。
class_name RouteGenerator


## 生成一局路线。返回 {"layers": [[节点×3]×3], "boss": 节点}；节点含 type/layer/index/cleared。
static func generate(run_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	var cfg := TableCache.nodes_config()
	var layers_cnt := int(cfg.get("layers", 3))
	var per_layer := int(cfg.get("choices_per_layer", 3))
	var grid: Array = []
	for l in layers_cnt:
		var row: Array = []
		for i in per_layer:
			row.append(_weighted_pick(rng, cfg.get("weights", {})))
		grid.append(row)
	_apply_guarantees(rng, grid, cfg.get("guarantee", {}))
	var layers: Array = []
	for l in layers_cnt:
		var nodes := []
		for i in per_layer:
			nodes.append({"type": String(grid[l][i]), "layer": l + 1, "index": i, "cleared": false})
		layers.append(nodes)
	return {
		"layers": layers,
		"boss": {"type": "boss", "layer": layers_cnt + 1, "index": 1, "cleared": false},
	}


static func _weighted_pick(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0
	for t in weights:
		total += int(weights[t])
	if total <= 0:
		return "normal"
	var roll := rng.randi_range(1, total)
	var acc := 0
	for t in weights:
		acc += int(weights[t])
		if roll <= acc:
			return String(t)
	return "normal"


## 保底修正（nodes.json guarantee：run_min_event / run_min_shop / layer2_min_elite）
static func _apply_guarantees(rng: RandomNumberGenerator, grid: Array, g: Dictionary) -> void:
	var protected_pos: Array = []  # 已被保底占用的 [l, i]，后续保底不覆盖
	if int(g.get("run_min_event", 1)) > 0 and not _has_type(grid, "event"):
		var pos := _pick_replace(rng, grid, _all_positions(grid), protected_pos)
		if not pos.is_empty():
			grid[pos[0]][pos[1]] = "event"
			protected_pos.append(pos)
	if int(g.get("run_min_shop", 1)) > 0 and not _has_type(grid, "shop"):
		var pos2 := _pick_replace(rng, grid, _all_positions(grid), protected_pos)
		if not pos2.is_empty():
			grid[pos2[0]][pos2[1]] = "shop"
			protected_pos.append(pos2)
	if int(g.get("layer2_min_elite", 1)) > 0 and grid.size() > 1:
		var l2 := grid[1] as Array
		if not l2.any(func(t): return String(t) == "elite"):
			var row_pos: Array = []
			for i in l2.size():
				row_pos.append([1, i])
			var pos3 := _pick_replace(rng, grid, row_pos, protected_pos)
			if not pos3.is_empty():
				grid[pos3[0]][pos3[1]] = "elite"


static func _has_type(grid: Array, want: String) -> bool:
	for row in grid:
		for t in row:
			if String(t) == want:
				return true
	return false


static func _all_positions(grid: Array) -> Array:
	var out: Array = []
	for l in grid.size():
		for i in grid[l].size():
			out.append([l, i])
	return out


## 从 candidates 选一个替换位：优先普通/宝箱/篝火（低价值节点），避开 protected；
## 偏好类型无候选时取任意非保护位。
static func _pick_replace(rng: RandomNumberGenerator, grid: Array, candidates: Array,
		protected_pos: Array) -> Array:
	var prot := {}
	for p in protected_pos:
		prot["%d_%d" % [p[0], p[1]]] = true
	var free: Array = []  # 非保护位
	for c in candidates:
		if not prot.has("%d_%d" % [c[0], c[1]]):
			free.append(c)
	if free.is_empty():
		return []
	for pref in ["normal", "chest", "bonfire"]:
		var pool: Array = []
		for c in free:
			if String(grid[c[0]][c[1]]) == pref:
				pool.append(c)
		if not pool.is_empty():
			return pool[rng.randi_range(0, pool.size() - 1)]
	return free[rng.randi_range(0, free.size() - 1)]
