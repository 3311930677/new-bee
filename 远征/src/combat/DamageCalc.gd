# DamageCalc.gd —— 伤害/治疗纯函数（玩法文档 §2.2，可单测）
# 伤害 = ATK² / (8×DEF + ATK)，暴击 ×暴伤，治疗 = HP%×MaxHP + 系数×ATK，下限 1
class_name DamageCalc


## 基础伤害（整数运算；atk 为生效攻击——技能倍率 k 先乘入 atk）
static func basic_damage(atk: int, def: int) -> int:
	var a := maxi(atk, 0)
	var d := maxi(def, 0)
	var denom := 8 * d + a
	if denom <= 0:
		return 1
	return maxi(1, a * a / denom)


## 暴击伤害（crit_dmg 如 1.5 / 1.75）
static func crit_damage(dmg: int, crit_dmg: float) -> int:
	return maxi(1, int(float(dmg) * crit_dmg))


## 治疗量 = hp_pct×MaxHP + atk_k×ATK
static func heal_amount(max_hp: int, atk: int, hp_pct: float, atk_k: float) -> int:
	return int(float(max_hp) * hp_pct + float(atk) * atk_k)
