# BattleSim.gd —— 确定性战斗模拟核心（玩法文档 §2.0 §2.1）
# 纯逻辑无场景依赖：30 tick/s 固定步进、种子随机、整数伤害。
# UI 层（BattleScene）每渲染帧按速度倍率步进并消费 events。
class_name BattleSim
extends RefCounted

const TICK_RATE := 30
const MAX_TICKS := 30 * 300  # 5 分钟硬上限（防死循环）

var rng := RandomNumberGenerator.new()
var units: Array[Combatant] = []
var cast_queue: Array[Dictionary] = []
var last_cast: Dictionary = {}        # uid -> {skill_id, tick}
var tick_count: int = 0
var events: Array[Dictionary] = []    # UI 消费（headless 模拟可关）
var record_events := true
var finished := false
var result := ""                      # "" / "victory" / "defeat"
var auto_mode := false                # 托管
var role_focus_target_uid := -1        # 玩家“攻”指令指定目标；不覆盖嘲讽/混乱与近战前排规则
var potions_left := 0                 # 治疗药剂
var potion_cd_ticks := 0              # 药剂 CD（8 秒一瓶，防连点误用）
const POTION_CD := 8 * 30
## 药剂回复比例（占最大生命）。表现层「道具页」直接读它写详情，避免两处各写一份 0.35。
const POTION_HEAL_PCT := 0.35
var pet_bench_id := ""                # 替补宠物 id
var pet_swap_used := false
var enemy_scale := 1.0                # 层难度 ×(1+0.12N)
var pet_level := 1                    # 宠物等级随人物等级（v0 简化；有 pet_stats 快照时以快照为准）
var pet_stats: Dictionary = {}        # 局外宠物养成快照 {pid: {level, stat_mult, growth_mult}}
## 组建失败原因（空主题池等）：调用方据此拒绝开战，别让「一 tick 就判胜」的空战斗照发奖励
var setup_error := ""
## 世界主题规则（C 批，maps.json themes.<id>.rule）：纯表驱动，规则 id + params。
## 八个世界只差数值、玩法元素从第 1 个世界起就全见过，这是当前最大的「新鲜感缺口」。
var theme_id := ""
var theme_rule: Dictionary = {}
var rule_timer := 0        # 距下次触发的 tick 数（测试把它置 1 即可精确验证一次）
var _next_uid := 1
var _by_uid: Dictionary = {}

var role_uid: int = 0


# ---------- 组建 ----------
## ally_cfg: {role_id, level, traits[], active_pet, bench_pet, hp_override, potions}
## enemy_cfg: {theme, node_type("normal"/"elite"/"boss"), layer(1..3), enemy_mult,
##             solo, display_level}; solo 明雷按显示等级成长，历练仍按层数成长。
##   enemy_mult 由调用方（苦行局）给，默认 1.0；模拟器不自己读表，保持内核无配置依赖。
func setup(seed: int, ally_cfg: Dictionary, enemy_cfg: Dictionary) -> void:
	rng.seed = seed
	role_focus_target_uid = -1
	theme_id = String(enemy_cfg.get("theme", "forest"))
	theme_rule = TableCache.theme_rule(theme_id)
	rule_timer = rule_interval_ticks()
	enemy_scale = 1.0 + 0.12 * float(int(enemy_cfg.get("layer", 1)))
	if bool(enemy_cfg.get("solo", false)) and int(enemy_cfg.get("display_level", 0)) > 0:
		enemy_scale = 1.0 + 0.16 * float(int(enemy_cfg.get("display_level", 1)) - 1)
	enemy_scale *= maxf(0.1, float(enemy_cfg.get("enemy_mult", 1.0)))
	pet_level = maxi(1, int(ally_cfg.get("level", 1)))
	pet_stats = ally_cfg.get("pet_stats", {})
	_build_role(ally_cfg)
	if String(ally_cfg.get("active_pet", "")) != "":
		_build_pet(String(ally_cfg.active_pet), false)
	if String(ally_cfg.get("bench_pet", "")) != "":
		pet_bench_id = String(ally_cfg.bench_pet)
	potions_left = int(ally_cfg.get("potions", 0))
	var cm: Variant = enemy_cfg.get("custom_mon", null)
	if cm is Dictionary and not (cm as Dictionary).is_empty():
		_build_custom_mon(cm as Dictionary)   # 演武场等：不走怪物池，直接给对手数据
	else:
		_build_enemies(String(enemy_cfg.get("theme", "forest")),
			String(enemy_cfg.get("node_type", "normal")),
			String(enemy_cfg.get("lead_mon", "")), bool(enemy_cfg.get("solo", false)))
	# 开场词条钩子
	for u in units:
		if u.traits != null:
			u.traits.on_battle_start(self, u)
	emit({"t": "ready", "units": units.map(func(u): return u.uid)})


func new_uid() -> int:
	_next_uid += 1
	return _next_uid - 1


func _build_role(cfg: Dictionary) -> void:
	var role := TableCache.get_role(String(cfg.get("role_id", "zs")))
	if role.is_empty():
		push_error("BattleSim 角色不存在：%s" % String(cfg.get("role_id", "")))
		return
	var stats := TableCache.role_stats(String(cfg.role_id), int(cfg.get("level", 1)))
	var ts := TraitSystem.new(cfg.get("traits", []))
	var gb0: Dictionary = cfg.get("growth", {}) if cfg.get("growth") is Dictionary else {}
	# 血上限走唯一口径（含局外成长；与 RunState.max_hp 共用，P1-6）
	stats.max_hp = TraitSystem.role_max_hp(String(cfg.role_id), int(cfg.get("level", 1)),
		cfg.get("traits", []), gb0)
	# 词条被动烧入其余基础属性
	stats.atk = int(float(stats.atk) * (1.0 + ts.passive_atk_pct()))
	stats.def = int(float(stats.def) * (1.0 + ts.passive_def_pct()))
	stats.spd = stats.spd * (1.0 + ts.passive_spd_pct())
	stats.crit += ts.passive_crit_add()
	# 局外养成加成（天赋/装备/坐骑/称号聚合，由 G.gd 计算后传入；缺省不影响）
	var gb: Dictionary = gb0
	if not gb.is_empty():
		stats.atk = int(float(stats.atk) * (1.0 + float(gb.get("atk_pct", 0.0))) + float(gb.get("atk_add", 0.0)))
		stats.def = int(float(stats.def) * (1.0 + float(gb.get("def_pct", 0.0))) + float(gb.get("def_add", 0.0)))
		stats.spd = stats.spd * (1.0 + float(gb.get("spd_pct", 0.0)))
		stats.crit += float(gb.get("crit_add", 0.0))
	var u := Combatant.new(new_uid(), "role", "ally", role)
	u.traits = ts
	u.base_max_hp = maxi(1, int(stats.max_hp))
	u.base_atk = maxi(1, int(stats.atk))
	u.base_def = maxi(0, int(stats.def))
	u.base_spd = stats.spd
	u.base_crit = clampf(stats.crit, 0.0, 0.95)
	u.crit_dmg = ts.crit_dmg_override() if ts.crit_dmg_override() > 0 else 1.5
	u.energy_gain_pct = ts.passive_energy_gain_pct() + float(gb.get("energy_pct", 0.0))
	u.cc_resist = clampf(ts.passive_cc_resist(), 0.0, 0.9)
	u.attack_range = String(role.get("attack_range", "melee"))
	u.row = Combatant.ROW_FRONT if u.attack_range == "melee" else Combatant.ROW_BACK
	u.col = 2
	u.hp = u.base_max_hp
	# HP 跨节点延续。哨兵口径：-1 = 无续血（满血开局）；>= 0 一律有效。
	# 0 必须钳到 1（濒危续战）：人物阵亡但宠物清场时，0 血开局等于必死——
	# 药剂救不回来（heal 拒绝治疗 hp<=0 的单位），下一个节点白给（A6）。
	var hp_override := int(cfg.get("hp_override", -1))
	if hp_override >= 0:
		u.hp = clampi(hp_override, 1, u.base_max_hp)
	role_uid = u.uid
	var allowed_v: Variant = cfg.get("unlocked_skills")
	var allowed: Array = allowed_v if allowed_v is Array else []
	var variants_v: Variant = cfg.get("skill_variants", {})
	var variants: Dictionary = variants_v if variants_v is Dictionary else {}
	for sid in role.get("skills", []):
		# unlocked_skills 只在主世界显式传入；其他玩法不传，继续保留完整五技。
		if cfg.has("unlocked_skills") and not allowed.has(String(sid)):
			continue
		var sd := TableCache.get_skill(String(sid))
		if not sd.is_empty():
			if variants.has(String(sid)) and variants[String(sid)] is Dictionary:
				sd = _apply_skill_variant(sd, variants[String(sid)] as Dictionary)
			# 技能书等级：每级 k+5%（skillbook.json），局外升级局内生效
			var slv := int((cfg.get("skill_levels", {}) as Dictionary).get(String(sid), 1))
			if slv > 1:
				sd = sd.duplicate()
				var k_per := float(TableCache.skillbook_config().get("k_per_level", 0.05))
				sd["k"] = snappedf(float(sd.get("k", 0.0)) * (1.0 + k_per * float(slv - 1)), 0.001)
			u.skills.append({"id": String(sid), "def": sd, "cd_left": 0})
	_add_unit(u)


## 导师分支只改技能表副本。数值项集中在这里，按钮、AI 与真正结算读取同一份 def。
func _apply_skill_variant(base: Dictionary, mod: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	out["cost"] = maxi(0, int(out.get("cost", 0)) + int(mod.get("cost_delta", 0)))
	out["cd"] = maxf(0.5, float(out.get("cd", 0.0)) + float(mod.get("cd_delta", 0.0)))
	out["k"] = snappedf(float(out.get("k", 0.0)) * float(mod.get("k_mult", 1.0)), 0.001)
	var em := float(mod.get("effect_mult", 1.0))
	var effect_v: Variant = out.get("effect", {})
	if effect_v is Dictionary and not is_equal_approx(em, 1.0):
		var effect := effect_v as Dictionary
		for key in ["pct", "hp_pct", "atk_k"]:
			if effect.has(key):
				effect[key] = snappedf(float(effect[key]) * em, 0.001)
	return out


func _build_pet(pet_id: String, is_bench_swap: bool) -> void:
	var pet := TableCache.get_pet(pet_id)
	if pet.is_empty():
		push_warning("宠物不存在：%s" % pet_id)
		return
	var base: Dictionary = pet.get("base", {})
	# 宠物养成快照优先（升级/突破/资质），否则沿用人物等级（v0 简化）
	var growth: Dictionary = pet.get("growth", {})
	var ps: Dictionary = pet_stats.get(pet_id, {})
	var gl := float(int(ps.get("level", pet_level)) - 1)
	var gmult := float(ps.get("growth_mult", 1.0))
	var owner := unit_by_uid(role_uid)
	var stat_pct := 0.0
	if owner != null and owner.traits != null:
		stat_pct = owner.traits.pet_stat_pct()
	var mult := (1.0 + stat_pct) * float(ps.get("stat_mult", 1.0))
	var u := Combatant.new(new_uid(), "pet", "ally", pet)
	u.base_max_hp = maxi(1, int((float(int(base.get("hp", 50))) + float(growth.get("hp", 0)) * gl * gmult) * mult))
	u.base_atk = maxi(1, int((float(int(base.get("atk", 10))) + float(growth.get("atk", 0)) * gl * gmult) * mult))
	u.base_def = maxi(0, int((float(int(base.get("def", 5))) + float(growth.get("def", 0)) * gl * gmult) * mult))
	u.base_spd = float(base.get("spd", 1.0))
	u.base_crit = 0.05
	u.attack_range = String(pet.get("attack_range", "melee"))
	u.row = Combatant.ROW_FRONT if u.attack_range == "melee" else Combatant.ROW_BACK
	u.col = 1
	u.hp = u.base_max_hp
	if is_bench_swap:
		u.deathproof_buff = true  # 换上获免死 1 次
	for sk in pet.get("skills", []):
		u.skills.append({"id": String(sk.get("id", "")), "def": sk, "cd_left": 0})
	_add_unit(u)


## maps.json 顶层 spawn 段（**不在主题条目里**）：编成数量表驱动（B4）
static func _spawn_cfg(node_type: String) -> Dictionary:
	var v: Variant = TableCache.maps_config().get("spawn", {})
	if v is Dictionary:
		var d := v as Dictionary
		var sub: Variant = d.get(node_type, {})
		return sub if sub is Dictionary else {}
	return {}


## BOSS 召唤上限（maps.json spawn.boss.summon_cap）
static func spawn_summon_cap() -> int:
	return maxi(1, int(_spawn_cfg("boss").get("summon_cap", 6)))


## 杂兵补位：前排 col1 → 后排 col2 → 后排 col1/3（与原本精英/BOSS 的补位一致）
func _spawn_adds(pick: Callable, n: int) -> void:
	var slots := [[Combatant.ROW_FRONT, 1], [Combatant.ROW_BACK, 2],
		[Combatant.ROW_BACK, 1], [Combatant.ROW_BACK, 3]]
	for i in n:
		var p: Array = slots[i % slots.size()]
		_spawn_monster(pick.call(), int(p[0]), int(p[1]))


## lead_mon：探索层撞到的那只怪（遇敌继承——撞谁谁领头，其余仍按池随机补位）
func _build_enemies(theme: String, node_type: String, lead_mon := "", solo := false) -> void:
	var tc := TableCache.theme_config(theme)
	var pool: Array = tc.get("monsters", [])
	if pool.is_empty():
		# 空池 = 组不出战斗：显式报错交给调用方拒绝开战，别再「一 tick 判胜还照发奖励」
		setup_error = "主题怪物池为空：%s" % theme
		push_error(setup_error)
		return
	var pick := func() -> String:
		return String(pool[rng.randi_range(0, pool.size() - 1)])
	# 主世界明雷是一只具体的地图怪：接触谁就与谁交战；历练编成保持原样。
	if solo and node_type in ["normal", "elite", "boss"]:
		_spawn_monster(lead_mon if lead_mon != "" else pick.call(),
			Combatant.ROW_FRONT, 2, 1.0, 1.0, node_type)
		return
	match node_type:
		"elite":
			var ec: Dictionary = TableCache.nodes_config().get("enemy", {})
			var hp_atk := float(ec.get("elite_hp_atk_mult", 1.8))
			var def_m := float(ec.get("elite_def_mult", 1.3))
			var sp := _spawn_cfg("elite")
			var n_elite := maxi(1, int(sp.get("elite_count", 1)))
			var e_cols := [2, 1]
			for i in n_elite:
				var elite := _spawn_monster(
					lead_mon if (i == 0 and lead_mon != "") else pick.call(),
					Combatant.ROW_FRONT, int(e_cols[i % e_cols.size()]), hp_atk, def_m, "elite")
				if elite != null:      # 怪物 id 失效时不再空引用（原代码直接 _apply_elite_affix(null)）
					_apply_elite_affix(elite)
			_spawn_adds(pick, int(sp.get("adds", 2)))
		"boss":
			var sp := _spawn_cfg("boss")
			var n_boss := maxi(1, int(sp.get("boss_count", 1)))
			for i in n_boss:
				_spawn_monster(String(tc.get("boss", "")), Combatant.ROW_FRONT,
					2 if i == 0 else 1, 1.0, 1.0, "boss")
			_spawn_adds(pick, int(sp.get("adds", 2)))
		_:
			var nc: Variant = _spawn_cfg("normal").get("count", [3, 4])
			var lo := 3
			var hi := 4
			if nc is Array and (nc as Array).size() >= 2:
				lo = int((nc as Array)[0])
				hi = maxi(lo, int((nc as Array)[1]))
			var n := rng.randi_range(lo, hi)
			var front_cols := [2, 1]
			var back_cols := [2, 1, 3]
			var fi := 0
			var bi := 0
			for i in n:
				var mon_id: String = (lead_mon if i == 0 and lead_mon != "" else pick.call())
				if i % 2 == 0 and fi < front_cols.size():
					_spawn_monster(mon_id, Combatant.ROW_FRONT, int(front_cols[fi]))
					fi += 1
				else:
					_spawn_monster(mon_id, Combatant.ROW_BACK, int(back_cols[bi % back_cols.size()]))
					bi += 1


## 演武场等模式的"自定义对手"：不走怪物池，直接给一份怪物数据（name/base/skills/tier）
func _build_custom_mon(d: Dictionary) -> void:
	var base: Dictionary = d.get("base", {})
	var u := Combatant.new(new_uid(), "monster", "enemy", d)
	u.base_max_hp = maxi(1, int(base.get("hp", 100)))
	u.base_atk = maxi(1, int(base.get("atk", 12)))
	u.base_def = maxi(0, int(base.get("def", 6)))
	u.base_spd = float(base.get("spd", 1.0))
	u.base_crit = 0.05
	u.attack_range = String(d.get("attack_range", "melee"))
	u.ai_type = String(d.get("ai", "boss"))
	u.row = Combatant.ROW_FRONT
	u.col = 2
	u.hp = u.base_max_hp
	for sk in d.get("skills", []):
		u.skills.append({"id": String(sk.get("id", "")), "def": sk, "cd_left": 0})
	_add_unit(u)


## tier 回写进 u.data（normal/elite/boss）：立绘高度 / 紫晕 / 名签三处表现全靠它（B4）。
## 坑：TableCache 返回的是**缓存引用**，必须 duplicate 后再写，否则这只精英会污染整张表。
func _spawn_monster(mon_id: String, row: int, col: int, hp_atk_mult := 1.0,
		def_mult := 1.0, tier := "normal") -> Combatant:
	var m := TableCache.get_monster(mon_id)
	if m.is_empty():
		push_warning("怪物不存在：%s" % mon_id)
		return null
	m = m.duplicate(true)
	m["tier"] = tier
	var base: Dictionary = m.get("base", {})
	var u := Combatant.new(new_uid(), "monster", "enemy", m)
	u.base_max_hp = maxi(1, int(float(int(base.get("hp", 50))) * hp_atk_mult * enemy_scale))
	u.base_atk = maxi(1, int(float(int(base.get("atk", 10))) * hp_atk_mult * enemy_scale))
	u.base_def = maxi(0, int(float(int(base.get("def", 5))) * def_mult * enemy_scale))
	u.base_spd = float(base.get("spd", 1.0))
	u.base_crit = 0.05
	u.attack_range = String(m.get("attack_range", "melee"))
	u.ai_type = String(m.get("ai", "basic"))
	u.row = row
	u.col = col
	u.hp = u.base_max_hp
	for sk in m.get("skills", []):
		u.skills.append({"id": String(sk.get("id", "")), "def": sk, "cd_left": 0})
	_add_unit(u)
	return u


func _apply_elite_affix(elite: Combatant) -> void:
	match rng.randi_range(0, 3):
		0:
			elite.add_buff("lifesteal", -1, {"pct": 0.20})
		1:
			elite.add_buff("thorns", -1, {"pct": 0.15})
		2:
			elite.add_buff("spd_up", -1, {"pct": 0.30})
		3:
			elite.add_buff("def_up", -1, {"pct": 0.40})


func _add_unit(u: Combatant) -> void:
	units.append(u)
	_by_uid[u.uid] = u


# ---------- 查询 ----------
func unit_by_uid(uid: int) -> Combatant:
	return _by_uid.get(uid, null)


func alive_units(side: String) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for u in units:
		if u.alive and u.side == side:
			out.append(u)
	return out


## 经典“攻”指令只改玩家普攻的选敌优先级，不另写伤害或攻速规则。
func set_role_focus_target(uid: int) -> bool:
	var target := unit_by_uid(uid)
	if target == null or not target.alive or target.side != "enemy":
		return false
	role_focus_target_uid = uid
	return true


func has_boss() -> bool:
	for u in units:
		if u.alive and u.side == "enemy" and u.ai_type == "boss":
			return true
	return false


func role_unit() -> Combatant:
	return unit_by_uid(role_uid)


func emit(e: Dictionary) -> void:
	if record_events:
		events.append(e)


# ---------- 指令（玩家输入，经校验后入队） ----------
func cast_skill(uid: int, skill_id: String) -> bool:
	var u := unit_by_uid(uid)
	if u == null:
		return false
	# 必须从该单位的技能栏取最终 def：这里已经叠好技能书等级与导师分支。
	# 旧实现重新读 TableCache 原表，导致按钮施放时所有局外加成都被静默抹掉。
	var sd: Dictionary = {}
	for slot_v in u.skills:
		var slot := slot_v as Dictionary
		if String(slot.get("id", "")) == skill_id:
			sd = slot.get("def", {})
			break
	if sd.is_empty():
		return false
	if not SkillSystem.can_cast(self, u, sd):
		return false
	SkillSystem.enqueue_cast(self, u, sd)
	return true


func use_potion() -> bool:
	if potions_left <= 0 or finished or potion_cd_ticks > 0:
		return false
	var role := role_unit()
	if role == null or not role.alive:
		return false
	# 满血喝药：直接拒绝，不扣瓶也不进 CD（地图侧早有拦截，战斗内漏了这条）
	if role.hp >= role.get_max_hp():
		return false
	potions_left -= 1
	potion_cd_ticks = POTION_CD
	var amt := DamageCalc.heal_amount(role.get_max_hp(), 0, POTION_HEAL_PCT, 0.0)
	role.heal(amt, role, self)
	return true


func swap_pet() -> bool:
	if pet_bench_id.is_empty() or pet_swap_used or finished:
		return false
	# 当前出战宠退场（本局不可再上）
	for i in range(units.size() - 1, -1, -1):
		if units[i].kind == "pet" and units[i].side == "ally":
			emit({"t": "pet_leave", "uid": units[i].uid})
			_by_uid.erase(units[i].uid)
			units.remove_at(i)
	pet_swap_used = true
	_build_pet(pet_bench_id, true)
	emit({"t": "pet_enter", "id": pet_bench_id})
	return true


# ---------- 主循环（§2.1 一帧时序） ----------
func step() -> void:
	if finished:
		return
	# 0. 药剂 CD 计时（防连点误用）
	if potion_cd_ticks > 0:
		potion_cd_ticks -= 1
	# 1. BuffSystem.tick
	for u in units:
		if u.alive:
			u.tick_buffs(self)
	# 2. 施法队列推进（前摇）
	for i in range(cast_queue.size() - 1, -1, -1):
		var e: Dictionary = cast_queue[i]
		e.windup = int(e.windup) - 1
		if int(e.windup) <= 0:
			cast_queue.remove_at(i)
			SkillSystem.resolve_cast(self, e)
	# 3. 词条 on_tick
	for u in units:
		if u.alive and u.traits != null:
			u.traits.on_tick(self, u)
	# 4. 普攻计时 + CD 计时
	for u in units:
		if not u.alive:
			continue
		for s in u.skills:
			if int(s.cd_left) > 0:
				s.cd_left = int(s.cd_left) - 1
		if u.can_act():
			u.attack_timer += 1
			if u.attack_timer >= u.basic_threshold():
				u.attack_timer = 0
				u.do_basic_attack(self)
				# 宠物攻击触发主人共鸣词条
				if u.kind == "pet":
					var owner := role_unit()
					if owner != null and owner.traits != null:
						owner.traits.on_pet_hit(self, owner, u, 10)
	# 5. AI/托管指令
	for u in units:
		if not u.alive:
			continue
		if u.side == "enemy" or u.kind == "pet":
			MonsterAI.decide(self, u)
		elif auto_mode:
			MonsterAI.decide_auto(self, u)
	# 6. 世界主题规则（C 批）：周期类规则在这里 tick；揭示半径那条在 MapScene 侧生效
	_apply_theme_rule()
	# 6.5 首领阶段（P03）：只在单位数据表带 phases 时生效（历练首领没有 phases，行为不变）
	_apply_phases()
	# 7. 死亡/胜负判定
	tick_count += 1
	if alive_units("enemy").is_empty():
		finished = true
		result = "victory"
		emit({"t": "victory"})
	elif alive_units("ally").is_empty():
		finished = true
		result = "defeat"
		emit({"t": "defeat"})
	elif tick_count >= MAX_TICKS:
		# 到硬上限判「平局」：演武场据此不扣分；PVE 由 MapScene 显式按败处理（口径 D3）
		finished = true
		result = "draw"
		emit({"t": "timeout"})


## 跑完整场（headless 模拟/TTK 用）
func run_to_end() -> String:
	while not finished:
		step()
	return result


## 状态哈希（确定性对拍用）
func hash_state() -> int:
	var h := (tick_count * 31 + role_focus_target_uid + 1) % 2147483647
	for u in units:
		h = (h * 31 + u.uid * 1000003 + u.hp * 7919 + u.energy) % 2147483647
	return h


# ---------- 首领阶段（P03，表驱动） ----------
## 施加一个 buff 规格 {type, dur(秒, <=0 表永久), pct}。技能 after.self_buff 与首领阶段共用，
## 保证「破绽 / 硬直 / 加速」三条路径的时长与数值口径只有一处。
func apply_buff_spec(u: Combatant, spec: Dictionary) -> void:
	if u == null or not u.alive:
		return
	var t := String(spec.get("type", ""))
	if t.is_empty():
		return
	var dur := float(spec.get("dur", 0.0))
	var ticks := -1 if dur <= 0.0 else maxi(1, int(dur * float(TICK_RATE)))
	var val := {}
	var pct := float(spec.get("pct", 0.0))
	if pct != 0.0:
		val["pct"] = pct
	u.add_buff(t, ticks, val)
	emit({"t": "buff", "uid": u.uid, "buff": t, "dur": ticks})


## 首领阶段：血量跌破阈值时解锁技能 / 永久增益 / 自身状态，并广播 onphase 横幅事件。
## 只触发一次（记在 once_flags），阈值按整数血量比例判定，无随机 → 不影响历练与确定性对拍。
func _apply_phases() -> void:
	for u in units:
		if not u.alive or u.side != "enemy":
			continue
		var phases: Variant = u.data.get("phases")
		if not (phases is Array):
			continue
		var max_hp := maxi(1, u.get_max_hp())
		for ph in (phases as Array):
			if not (ph is Dictionary):
				continue
			var p := ph as Dictionary
			var flag := "phase_" + String(p.get("id", ""))
			if u.once_flags.has(flag):
				continue
			if float(u.hp) / float(max_hp) > float(p.get("hp_below", 0.0)):
				continue
			u.once_flags[flag] = true
			_enter_phase(u, p)


func _enter_phase(u: Combatant, p: Dictionary) -> void:
	# 解锁技能（同 id 已在技能表里就跳过，避免阶段重复加后技能栏出现两条同名）
	for sk in p.get("add_skills", []):
		if not (sk is Dictionary):
			continue
		var sid := String((sk as Dictionary).get("id", ""))
		var dup := false
		for s in u.skills:
			if String(s.get("id", "")) == sid:
				dup = true
				break
		if not dup and not sid.is_empty():
			u.skills.append({"id": sid, "def": sk, "cd_left": 0})
	# 永久增益（dur <= 0 → 永久；不随阶段回退）
	var buffs_v: Variant = p.get("buffs")
	if buffs_v is Dictionary:
		for k in (buffs_v as Dictionary):
			var spec: Variant = (buffs_v as Dictionary)[k]
			var d := (spec as Dictionary).duplicate() if spec is Dictionary else {}
			d["type"] = String(k)
			d["dur"] = 0.0
			apply_buff_spec(u, d)
	# 自身状态（碎碑硬直等）：走同一套施法后自身状态的口径
	var sb: Variant = p.get("self_buff")
	if sb is Dictionary:
		apply_buff_spec(u, sb as Dictionary)
	emit({"t": "phase", "uid": u.uid, "id": String(p.get("id", "")),
		"name": String(p.get("name", "")), "announce": String(p.get("announce", ""))})


## 死亡钩子（P05-C，表驱动）：单位阵亡后检查存活敌首领**已进入**的阶段里有没有 on_death，
## 命中死者 id 就执行该阶段的死后反应（例：失路兽「迷路低吼」召出的影狼先死 → 首领获得
## 4 秒破绽）。一条阶段钩子只触发一次；阶段未进入（once_flags 无 phase_<id>）不响应——
## 影狼在阶段前被别的途径召出来时不该白给破绽。
func notify_death(dead: Combatant) -> void:
	if dead == null or dead.side != "enemy" or dead.data.is_empty():
		return
	var mid := String(dead.data.get("id", ""))
	if mid.is_empty():
		return
	for u in units:
		if u == dead or not u.alive or u.side != "enemy":
			continue
		var phases: Variant = u.data.get("phases")
		if not (phases is Array):
			continue
		for ph in (phases as Array):
			if not (ph is Dictionary):
				continue
			var p := ph as Dictionary
			var pid := String(p.get("id", ""))
			if not u.once_flags.has("phase_" + pid):
				continue
			var od_v: Variant = p.get("on_death")
			if not (od_v is Dictionary):
				continue
			var od := od_v as Dictionary
			if String(od.get("mon_id", "")) != mid:
				continue
			var flag := "on_death_%s_%s" % [pid, mid]
			if u.once_flags.has(flag):
				continue
			u.once_flags[flag] = true
			var sb: Variant = od.get("self_buff")
			if sb is Dictionary:
				apply_buff_spec(u, sb as Dictionary)
			# 复用 phase 事件：表现层已有阶段横幅 + 破绽「绽」飘字两条通道，
			# 事件 id 加 _break 后缀只作区分，不参与任何状态判定。
			emit({"t": "phase", "uid": u.uid, "id": pid + "_break",
				"name": String(p.get("name", "")), "announce": String(od.get("announce", ""))})


# ---------- 世界主题规则（C 批，表驱动） ----------
func rule_params() -> Dictionary:
	var p: Variant = theme_rule.get("params", {})
	return p if p is Dictionary else {}


## 周期规则的间隔（tick）。0 / 负 = 该主题没有周期规则。
func rule_interval_ticks() -> int:
	return int(float(rule_params().get("interval", 0.0)) * float(TICK_RATE))


## 最大生命者（火山灼烧挑它；双向——敌我都可能中招，不是纯福利）
func highest_max_hp_unit() -> Combatant:
	var best: Combatant = null
	for u in units:
		if not u.alive:
			continue
		if best == null or u.get_max_hp() > best.get_max_hp():
			best = u
	return best


## 每条规则 = 一处 match 分支 + 一段表参数。后续世界照这个模板往里加。
func _apply_theme_rule() -> void:
	if theme_rule.is_empty():
		return
	var prm := rule_params()
	match String(theme_rule.get("id", "")):
		"volcano_burn":
			if not _rule_timer_tick():
				return
			var victim := highest_max_hp_unit()
			if victim == null:
				return
			var dmg := maxi(1, int(float(victim.get_max_hp()) * float(prm.get("hp_pct", 0.02))))
			# src 传 null：环境伤害**不占击杀归属**（on_kill 不会因灼烧收尾误记），
			# 也不触发受击钩子（与 A1 的「死人不再被奶回来」解耦）
			victim._direct_damage(dmg, null, self, true)
			emit({"t": "theme_rule", "rule": "volcano_burn", "uid": victim.uid, "amount": dmg})
		"snow_slip":
			if not _rule_timer_tick():
				return
			var dur := int(float(prm.get("dur", 2.0)) * float(TICK_RATE))
			var affected := alive_units("ally") + alive_units("enemy")
			for u in affected:
				u.add_buff("slow", dur, {"pct": prm.get("pct", 0.15)})
			emit({"t": "theme_rule", "rule": "snow_slip", "uid": -1, "amount": affected.size()})
		_:
			pass   # 其余规则不作用在战斗 tick 上（如深渊揭示半径在 MapScene 侧）


## 周期倒计时：到点返回 true 并重置。没配 interval 的规则永不触发。
func _rule_timer_tick() -> bool:
	if rule_interval_ticks() <= 0:
		return false
	rule_timer -= 1
	if rule_timer > 0:
		return false
	rule_timer = rule_interval_ticks()
	return true


# ---------- 战斗内动作：击退一排（岩龟冲撞等） ----------
func knock_back(t: Combatant) -> void:
	if t.row != Combatant.ROW_FRONT:
		return
	# 同列后排空位才退
	for u in units:
		if u.alive and u.side == t.side and u.row == Combatant.ROW_BACK and u.col == t.col:
			return
	t.row = Combatant.ROW_BACK
	emit({"t": "knockback", "uid": t.uid})


# ---------- 战斗召唤（BOSS 技能） ----------
func summon_monsters(caster: Combatant, mon_id: String, count: int, cap: int) -> void:
	var enemies := alive_units("enemy")
	var n := mini(count, cap - enemies.size())
	if n <= 0:
		return
	var cols := [3, 1, 4, 0]
	var ci := 0
	for i in n:
		_spawn_monster(mon_id, Combatant.ROW_BACK, int(cols[ci % cols.size()]))
		ci += 1
	emit({"t": "summon", "uid": caster.uid, "count": n})
