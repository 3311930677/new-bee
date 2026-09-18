# VerifyAssets.gd —— 检查本轮接线素材的 res_tex 命中率
# godot --headless --path . res://tools/VerifyAssets.tscn
extends Node


func _ready() -> void:
	var miss: Array = []
	var hit := 0
	var names: Array = []
	var maps_cfg: Dictionary = TableCache.maps_config()
	# 8 主题战斗背景（直接读 maps.json 的 battle_bg 字段，避免与素材命名规则脱节）
	for tid in maps_cfg.get("themes", {}):
		var th: Dictionary = maps_cfg["themes"][tid]
		var bg_name := String(th.get("battle_bg", ""))
		if bg_name != "":
			names.append(bg_name)
	# 流派图标
	for s in ["school_bleed", "school_crit", "school_thorns", "school_control", "school_energy"]:
		names.append(s)
	# 地图交互物件
	for n in ["node_chest", "node_event", "node_shop", "node_campfire"]:
		names.append(n)
	# 宠物（pets.json 全量）
	for p in TableCache.pets():
		names.append(String(p.get("id", "")))
	# 秘境插画（world_<theme> 8 张）：图志 / 出征卡面直接吃
	for tid3 in maps_cfg.get("themes", {}):
		names.append("world_%s" % tid3)
	# NPC idle 四帧条（主城像素小人；旅人共用 npc_guest_idle）
	for nd in TableCache.city_config().get("npcs", []):
		names.append("%s_idle" % String((nd as Dictionary).get("id", "")))
	names.append("npc_guest_idle")
	# 各主题怪物（maps.json monsters + boss）
	for tid2 in maps_cfg.get("themes", {}):
		var th2: Dictionary = maps_cfg["themes"][tid2]
		for m in th2.get("monsters", []):
			names.append(String(m))
		if String(th2.get("boss", "")) != "":
			names.append(String(th2.get("boss", "")))
	for n2 in names:
		if n2 == "":
			continue
		if G.res_tex(n2) == null:
			miss.append(n2)
		else:
			hit += 1
	print("素材命中 %d / %d" % [hit, hit + miss.size()])
	if miss.size() > 0:
		print("MISS: " + ", ".join(miss))
		print("ASSETS_FAIL")
	else:
		print("ASSETS_OK all textures resolved")
	get_tree().quit(0 if miss.is_empty() else 1)
