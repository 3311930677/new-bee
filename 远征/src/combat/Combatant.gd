# Combatant.gd —— 战斗单位：属性/站位/能量/普攻/生命与 buff 容器（玩法文档 §1.3 §2.1 §2.3）
# 确定性铁律：时间全用整数 tick（1 tick = 1/30s），伤害全整数，随机全走 sim.rng。
class_name Combatant
extends RefCounted

const ROW_FRONT := 0
const ROW_BACK := 1
const MAX_ENERGY := 100
const BASIC_INTERVAL_TICKS := 60  # 普攻基准 2.0s = 60 ticks（÷SPD 在 getter 计算）

var uid: int = 0
var kind: String = ""            # "role" / "monster" / "pet"
var side: String = ""            # "ally" / "enemy"
var name: String = ""
var data: Dictionary = {}        # 原始数据表行
var row: int = ROW_FRONT
var col: int = 2

# 基础属性（词条被动加成在构建时烧入 base_*；战斗中动态增益走 getter）
var base_max_hp: int = 1
var base_atk: int = 1
var base_def: int = 0
var base_spd: float = 1.0
var base_crit: float = 0.05
var crit_dmg: float = 1.5
var energy_gain_pct: float = 0.0   # 词条：能量获取加成
var cc_resist: float = 0.0         # 控制抗性（词条/怪物词条）

var hp: int = 1
var alive: bool = true
var energy: int = 0                # 仅 role 使用
var attack_range: String = "melee" # "melee" / "range"
var ai_type: String = "basic"      # 怪物 AI：basic / front / back / boss

var attack_timer: int = 0
var first_basic_done: bool = false # 词条"先发制人"
var rampage_stacks: int = 0        # 词条"越战越勇"
var once_flags: Dictionary = {}    # 词条一次性标记（如回光返照）
var deathproof_buff: bool = false  # 换宠免死
var traits: TraitSystem = null     # 仅我方 role 持有

var buffs: Array[Dictionary] = []  # {type, dur(ticks, -1 永久), stacks, val}
var skills: Array[Dictionary] = [] # {id, def, cd_left(ticks)}


func _init(p_uid: int, p_kind: String, p_side: String, p_data: Dictionary) -> void:
	uid = p_uid
	kind = p_kind
	side = p_side
	data = p_data
	name = String(p_data.get("name", "单位"))


# ---------- 生效属性（buff + 动态词条合并） ----------
func get_max_hp() -> int:
	return base_max_hp


func get_atk() -> int:
	var pct := 0.0
	for b in buffs:
		match String(b.type):
			"atk_up": pct += float(b.val.get("pct", 0.0))
			"atk_down": pct -= float(b.val.get("pct", 0.0))
	if traits != null:
		pct += traits.dynamic_atk_pct(self)
	if kind == "monster" and ai_type == "boss" and float(hp) / float(get_max_hp()) < 0.3:
		pct += 0.3  # BOSS 阶段狂暴
	return maxi(1, int(float(base_atk) * (1.0 + pct)))


func get_def() -> int:
	var pct := 0.0
	for b in buffs:
		match String(b.type):
			"def_up": pct += float(b.val.get("pct", 0.0))
			"def_break": pct -= float(b.val.get("pct", 0.0))
	return maxi(0, int(float(base_def) * (1.0 + pct)))


func get_spd() -> float:
	var pct := 0.0
	for b in buffs:
		match String(b.type):
			"spd_up": pct += float(b.val.get("pct", 0.0))
			"slow": pct -= float(b.val.get("pct", 0.0))
	if traits != null:
		pct += traits.dynamic_spd_pct(self)
	return maxf(0.3, base_spd * (1.0 + pct))


func get_crit() -> float:
	var add := 0.0
	for b in buffs:
		if String(b.type) == "crit_up":
			add += float(b.val.get("pct", 0.0))
	return clampf(base_crit + add, 0.0, 0.95)


func basic_threshold() -> int:
	return maxi(10, int(float(BASIC_INTERVAL_TICKS) / get_spd()))


# ---------- 状态查询 ----------
func is_controlled() -> bool:
	return has_buff("stun") or has_buff("fear")


func can_act() -> bool:
	return alive and not is_controlled()


func has_buff(type: String) -> bool:
	for b in buffs:
		if String(b.type) == type:
			return true
	return false


func get_buff(type: String) -> Dictionary:
	for b in buffs:
		if String(b.type) == type:
			return b
	return {}


func buff_pct_sum(type: String) -> float:
	var s := 0.0
	for b in buffs:
		if String(b.type) == type:
			s += float(b.val.get("pct", 0.0))
	return s


func cc_duration_ticks(dur_s: float) -> int:
	var dur := dur_s
	if traits != null:
		dur *= 1.0 + traits.cc_dur_pct()
	return int(dur * 30.0)


# ---------- buff 生命周期 ----------
func add_buff(type: String, dur_ticks: int, val: Dictionary = {}) -> void:
	var stack_add: int = int(val.get("stacks", 1))
	var stack_cap: int = int(val.get("stack_cap", 5))
	for b in buffs:
		if String(b.type) == type:
			# 同类刷新时长并叠层
			if dur_ticks >= 0:
				b.dur = maxi(int(b.dur), dur_ticks)
			b.stacks = mini(int(b.stacks) + stack_add, stack_cap)
			return
	var entry := {"type": type, "dur": dur_ticks, "stacks": mini(stack_add, stack_cap), "val": val}
	buffs.append(entry)


func remove_buff(type: String) -> void:
	for i in range(buffs.size() - 1, -1, -1):
		if String(buffs[i].type) == type:
			buffs.remove_at(i)


func dispel_debuffs() -> int:
	var removed := 0
	for i in range(buffs.size() - 1, -1, -1):
		var t := String(buffs[i].type)
		if t in ["bleed", "poison", "stun", "fear", "confusion", "slow", "def_break", "atk_down"]:
			buffs.remove_at(i)
			removed += 1
	return removed


func tick_buffs(sim: BattleSim) -> void:
	for i in range(buffs.size() - 1, -1, -1):
		var b: Dictionary = buffs[i]
		# 持续伤害：每 tick val.atk×pct/30（快照施放者 ATK）
		var t := String(b.type)
		if t == "bleed" or t == "poison":
			# 每秒 atk×pct×stacks：按 tick 浮点累积，acc≥1 才结算整数伤害（防小额毒被下限放大）
			var acc := float(b.val.get("acc", 0.0))
			acc += (float(int(b.val.get("atk", 1))) * float(b.val.get("pct", 0.0))
				* float(int(b.stacks)) / 30.0)
			if acc >= 1.0:
				var dot := int(acc)
				acc -= float(dot)
				_direct_damage(dot, self, sim, true)
			b.val["acc"] = acc
		if int(b.dur) > 0:
			b.dur = int(b.dur) - 1
			if int(b.dur) == 0:
				buffs.remove_at(i)
				sim.emit({"t": "buff_end", "uid": uid, "buff": t})


# ---------- 伤害与治疗 ----------
## 直伤入口（dot/反伤走此路，不再触发受击钩子，防无限循环）
func _direct_damage(dmg: int, src: Combatant, sim: BattleSim, is_dot := false) -> int:
	if not alive or dmg <= 0:
		return 0
	if has_buff("invincible"):
		sim.emit({"t": "immune", "uid": uid})
		return 0
	hp = maxi(0, hp - dmg)
	sim.emit({"t": "dmg", "src": src.uid if src != null else -1, "uid": uid,
		"amount": dmg, "crit": false, "dot": is_dot})
	if hp == 0:
		_on_lethal(sim)
	return dmg


## 正式伤害入口（技能/普攻；含潜伏减伤/护盾/反伤/吸血/受击词条钩子）
func take_damage(dmg: int, src: Combatant, sim: BattleSim, is_crit := false) -> int:
	if not alive or dmg <= 0:
		return 0
	if has_buff("invincible"):
		sim.emit({"t": "immune", "uid": uid})
		return 0
	var final := dmg
	if has_buff("lurk"):
		final = maxi(1, final / 2)  # 潜伏：受击减半
	# 护盾吸收
	for i in range(buffs.size() - 1, -1, -1):
		var b: Dictionary = buffs[i]
		if String(b.type) == "shield":
			var pool: int = int(b.val.get("pool", 0))
			var absorb := mini(pool, final)
			b.val["pool"] = pool - absorb
			final -= absorb
			if int(b.val.get("pool", 0)) <= 0:
				buffs.remove_at(i)
			if final <= 0:
				sim.emit({"t": "shield_absorb", "uid": uid, "amount": absorb})
				return 0
	hp = maxi(0, hp - final)
	sim.emit({"t": "dmg", "src": src.uid if src != null else -1, "uid": uid,
		"amount": final, "crit": is_crit, "dot": false})
	# 反伤（buff 与词条共用路径；反伤不再触发受击钩子）
	var reflect_pct := buff_pct_sum("thorns")
	if traits != null:
		reflect_pct += traits.reflect_pct()
	if src != null and src.alive and reflect_pct > 0.0:
		src._direct_damage(maxi(1, int(float(final) * reflect_pct)), self, sim)
	# 吸血：按攻击方自己的 lifesteal 结算、回攻击方（与上一段反伤的取向对称；
	# 历史 bug：曾读受击方的 buff，导致「打带吸血的敌人反而给玩家回血」）
	var lifesteal := (src.buff_pct_sum("lifesteal") if src != null else 0.0)
	if src != null and src.alive and lifesteal > 0.0:
		src.heal(maxi(1, int(float(final) * lifesteal)), self, sim)
	# 受击词条（以伤换伤回血）
	if traits != null:
		traits.on_behit(sim, self, src, final)
	if hp == 0:
		_on_lethal(sim)
	return final


func _on_lethal(sim: BattleSim) -> void:
	# 免死（换宠 buff）
	if deathproof_buff:
		deathproof_buff = false
		remove_buff("deathproof")
		hp = 1
		sim.emit({"t": "deathproof", "uid": uid})
		return
	# 词条：回光返照（每场 1 次）
	if traits != null and traits.prevent_death(sim, self):
		return
	alive = false
	hp = 0
	sim.emit({"t": "death", "uid": uid})


func heal(amount: int, src: Combatant, sim: BattleSim) -> int:
	if not alive or amount <= 0:
		return 0
	var amt := amount
	if traits != null:
		amt = int(float(amt) * (1.0 + traits.heal_taken_pct()))
	amt = mini(amt, get_max_hp() - hp)
	if amt <= 0:
		return 0
	hp += amt
	sim.emit({"t": "heal", "src": src.uid if src != null else -1, "uid": uid, "amount": amt})
	return amt


func gain_energy(v: int) -> void:
	if kind != "role":
		return
	energy = mini(MAX_ENERGY, energy + maxi(0, int(float(v) * (1.0 + energy_gain_pct))))


# ---------- 普攻目标选择（§1.3 定稿：近战限前排；远程任意排默认最低血；嘲讽强制转火） ----------
func pick_basic_target(sim: BattleSim) -> Combatant:
	# 嘲讽优先
	var taunt_b := get_buff("taunt")
	if not taunt_b.is_empty():
		var taunter: Combatant = sim.unit_by_uid(int(taunt_b.val.get("src_uid", -1)))
		if taunter != null and taunter.alive:
			return taunter
	var enemies := sim.alive_units("enemy" if side == "ally" else "ally")
	if enemies.is_empty():
		return null
	# 混乱：随机目标（任意方，不含自身），伤害减半在结算处
	if has_buff("confusion"):
		var all: Array[Combatant] = []
		for u in sim.units:
			if u.alive and u != self:
				all.append(u)
		if all.is_empty():
			return null
		return all[sim.rng.randi_range(0, all.size() - 1)]
	# 敌方 AI 目标规则（§2.5）；我方单位统一 basic 规则
	if side == "enemy":
		match ai_type:
			"front":
				var front := _filter_row(enemies, ROW_FRONT)
				if not front.is_empty():
					return front[0]
				return enemies[0]
			"back":
				var back := _filter_row(enemies, ROW_BACK)
				if not back.is_empty():
					return lowest_hp(back)
				return lowest_hp(enemies)
			_:  # basic / boss：最低血
				return lowest_hp(enemies)
	# 我方：近战限敌方前排（§1.3）；敌方前排全灭时战场推进，可攻击任意存活单位
	if attack_range == "melee":
		var front := _filter_row(enemies, ROW_FRONT)
		if front.is_empty():
			return lowest_hp(enemies)
		return lowest_hp(front)
	return lowest_hp(enemies)


func _filter_row(units: Array[Combatant], want_row: int) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for u in units:
		if u.row == want_row:
			out.append(u)
	return out


func lowest_hp(units: Array[Combatant]) -> Combatant:
	var best: Combatant = units[0]
	for u in units:
		if u.hp < best.hp:
			best = u
	return best


# ---------- 普攻执行 ----------
func do_basic_attack(sim: BattleSim) -> void:
	var target := pick_basic_target(sim)
	if target == null:
		return
	first_basic_done = true
	var atk := get_atk()
	var dmg := DamageCalc.basic_damage(atk, target.get_def())
	var crit_chance := get_crit()
	if traits != null:
		crit_chance += traits.crit_vs_full_hp_bonus(target)   # 弱点洞悉（P1-12）
	var is_crit := sim.rng.randf() < crit_chance
	if is_crit:
		dmg = DamageCalc.crit_damage(dmg, crit_dmg)
	var halved := false
	if has_buff("confusion"):
		dmg = maxi(1, dmg / 2)
		halved = true
	# 词条：先发制人（本场首次普攻 ×2）
	if traits != null and not once_flags.has("first_strike"):
		once_flags["first_strike"] = true
		if traits.has_first_strike():
			dmg *= 2
	# 词条出手修正（处决者/碎冰等与技能共用——修「处决者只对技能生效」，P1-12）
	if traits != null:
		dmg = traits.modify_outgoing(self, target, dmg, false, false)
	sim.emit({"t": "basic", "src": uid, "uid": target.uid, "halved": halved})
	target.take_damage(dmg, self, sim, is_crit)
	# 怪物附带效果（毒/流血/减速按概率）
	if kind == "monster" and data.has("on_hit") and target.alive:
		var proc: Dictionary = data.on_hit
		if sim.rng.randf() < float(proc.get("chance", 0.0)):
			var ptype := String(proc.get("type", ""))
			var dur := int(float(proc.get("dur", 2.0)) * 30.0)
			match ptype:
				"poison", "bleed":
					target.add_buff(ptype, dur, {"pct": proc.get("pct", 0.03), "atk": atk,
						"stacks": 1, "stack_cap": 3})
				"slow":
					target.add_buff("slow", dur, {"pct": proc.get("pct", 0.2)})
			sim.emit({"t": "proc", "src": uid, "uid": target.uid, "buff": ptype})
	# 词条命中钩子（普攻）
	if traits != null:
		traits.on_hit(sim, self, target, dmg, is_crit, false)
		if is_crit:
			traits.on_crit(sim, self, target)
	# 普攻 +20 能量
	gain_energy(20)
