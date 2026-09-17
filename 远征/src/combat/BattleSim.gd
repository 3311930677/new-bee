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
var potions_left := 0                 # 治疗药剂
var potion_cd_ticks := 0              # 药剂 CD（8 秒一瓶，防连点误用）
const POTION_CD := 8 * 30
var pet_bench_id := ""                # 替补宠物 id
var pet_swap_used := false
var enemy_scale := 1.0                # 层难度 ×(1+0.12N)
var pet_level := 1                    # 宠物等级随人物等级（v0 简化；有 pet_stats 快照时以快照为准）
var pet_stats: Dictionary = {}        # 局外宠物养成快照 {pid: {level, stat_mult, growth_mult}}
var _next_uid := 1
var _by_uid: Dictionary = {}

var role_uid: int = 0


# ---------- 组建 ----------
## ally_cfg: {role_id, level, traits[], active_pet, bench_pet, hp_override, potions}
## enemy_cfg: {theme, node_type("normal"/"elite"/"boss"), layer(1..3)}
func setup(seed: int, ally_cfg: Dictionary, enemy_cfg: Dictionary) -> void:
	rng.seed = seed
	enemy_scale = 1.0 + 0.12 * float(int(enemy_cfg.get("layer", 1)))
	pet_level = maxi(1, int(ally_cfg.get("level", 1)))
	pet_stats = ally_cfg.get("pet_stats", {})
	_build_role(ally_cfg)
	if String(ally_cfg.get("active_pet", "")) != "":
		_build_pet(String(ally_cfg.active_pet), false)
	if String(ally_cfg.get("bench_pet", "")) != "":
		pet_bench_id = String(ally_cfg.bench_pet)
	potions_left = int(ally_cfg.get("potions", 0))
	_build_enemies(String(enemy_cfg.get("theme", "forest")),
		String(enemy_cfg.get("node_type", "normal")),
		String(enemy_cfg.get("lead_mon", "")))
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
	# 词条被动烧入基础属性
	stats.max_hp = int(float(stats.max_hp) * (1.0 + ts.passive_maxhp_pct()))
	stats.atk = int(float(stats.atk) * (1.0 + ts.passive_atk_pct()))
	stats.def = int(float(stats.def) * (1.0 + ts.passive_def_pct()))
	stats.spd = stats.spd * (1.0 + ts.passive_spd_pct())
	stats.crit += ts.passive_crit_add()
	# 局外养成加成（天赋/装备/坐骑/称号聚合，由 G.gd 计算后传入；缺省不影响）
	var gb: Dictionary = cfg.get("growth", {})
	if not gb.is_empty():
		stats.max_hp = int(float(stats.max_hp) * (1.0 + float(gb.get("maxhp_pct", 0.0))) + float(gb.get("hp_add", 0)))
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
	# HP 跨节点延续
	var hp_override := int(cfg.get("hp_override", -1))
	if hp_override > 0:
		u.hp = mini(hp_override, u.base_max_hp)
	role_uid = u.uid
	for sid in role.get("skills", []):
		var sd := TableCache.get_skill(String(sid))
		if not sd.is_empty():
			# 技能书等级：每级 k+5%（skillbook.json），局外升级局内生效
			var slv := int((cfg.get("skill_levels", {}) as Dictionary).get(String(sid), 1))
			if slv > 1:
				sd = sd.duplicate()
				var k_per := float(TableCache.skillbook_config().get("k_per_level", 0.05))
				sd["k"] = snappedf(float(sd.get("k", 0.0)) * (1.0 + k_per * float(slv - 1)), 0.001)
			u.skills.append({"id": String(sid), "def": sd, "cd_left": 0})
	_add_unit(u)


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


## lead_mon：探索层撞到的那只怪（遇敌继承——撞谁谁领头，其余仍按池随机补位）
func _build_enemies(theme: String, node_type: String, lead_mon := "") -> void:
	var tc := TableCache.theme_config(theme)
	var pool: Array = tc.get("monsters", [])
	if pool.is_empty():
		push_error("主题无怪物池：%s" % theme)
		return
	var pick := func() -> String:
		return String(pool[rng.randi_range(0, pool.size() - 1)])
	match node_type:
		"elite":
			var ec: Dictionary = TableCache.nodes_config().get("enemy", {})
			var hp_atk := float(ec.get("elite_hp_atk_mult", 1.8))
			var def_m := float(ec.get("elite_def_mult", 1.3))
			var elite := _spawn_monster(lead_mon if lead_mon != "" else pick.call(),
				Combatant.ROW_FRONT, 2, hp_atk, def_m)
			_apply_elite_affix(elite)
			_spawn_monster(pick.call(), Combatant.ROW_FRONT, 1)
			_spawn_monster(pick.call(), Combatant.ROW_BACK, 2)
		"boss":
			_spawn_monster(String(tc.get("boss", "")), Combatant.ROW_FRONT, 2)
			_spawn_monster(pick.call(), Combatant.ROW_FRONT, 1)
			_spawn_monster(pick.call(), Combatant.ROW_BACK, 2)
		_:
			var n := 3 + (1 if rng.randf() < 0.5 else 0)
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


func _spawn_monster(mon_id: String, row: int, col: int, hp_atk_mult := 1.0,
		def_mult := 1.0) -> Combatant:
	var m := TableCache.get_monster(mon_id)
	if m.is_empty():
		push_warning("怪物不存在：%s" % mon_id)
		return null
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
	var sd := TableCache.get_skill(skill_id)
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
	potions_left -= 1
	potion_cd_ticks = POTION_CD
	var amt := DamageCalc.heal_amount(role.get_max_hp(), 0, 0.35, 0.0)
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
	# 6. 死亡/胜负判定
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
		finished = true
		result = "defeat"
		emit({"t": "timeout"})


## 跑完整场（headless 模拟/TTK 用）
func run_to_end() -> String:
	while not finished:
		step()
	return result


## 状态哈希（确定性对拍用）
func hash_state() -> int:
	var h := tick_count
	for u in units:
		h = (h * 31 + u.uid * 1000003 + u.hp * 7919 + u.energy) % 2147483647
	return h


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
