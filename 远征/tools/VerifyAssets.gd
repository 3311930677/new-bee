# VerifyAssets.gd —— 必需资源契约回归（场景模式：godot --headless --path . res://tools/VerifyAssets.tscn）
#
# 口径（问题 #32、#33、#41）：必需资源清单要**从数据和显式映射推导**，然后做正向存在性校验；
# 反向扫描目录只用来报告"有文件但没人登记"，不用于发现"已删文件"（扫不出来）。
# 以前这里只覆盖几个分类，且流派图标是手抄的 5 个名字——表里加了 summon 也测不出来。
#
# 注意：不要求 reserved 内容（例如尚未接线的无尽 Boss）一定有素材，那会把"还没做"判成"坏了"。
extends Node


func _ready() -> void:
	var miss: Array = []
	var hit := 0
	var checked := 0
	var names: Array = []
	_add_all(names, _required_names())
	# 去重（多个分类会引用同一张图）
	var uniq: Array = []
	var seen := {}
	for n in names:
		var k := String(n)
		if k.is_empty() or seen.has(k):
			continue
		seen[k] = true
		uniq.append(k)
	for n2 in uniq:
		checked += 1
		if G.res_tex(String(n2)) == null:
			miss.append(String(n2))
		else:
			hit += 1
	# 主世界贴图按显式路径加载，不都经过名称索引；同样必须纳入资源契约。
	var world_paths := {}
	var craft := preload("res://src/ui/CraftUI.gd")
	var props := preload("res://src/world/WorldPropArt.gd")
	world_paths[craft.BACKGROUND] = true
	world_paths[props.SIGN_PATH] = true
	world_paths[props.ATLAS_PATH] = true
	world_paths[props.STORY_ATLAS_PATH] = true
	world_paths[props.RETURN_ATLAS_PATH] = true
	for art_list in preload("res://src/ui/SkillShowcase.gd").ART_BY_ROLE.values():
		for art_name in art_list:
			world_paths["res://image/generated_362_xajh/ready/fx/e_effect_%s.png" % String(art_name)] = true
	for map_v in (TableCache.main_world_config().get("maps", {}) as Dictionary).values():
		var map: Dictionary = map_v
		var leader := String(map.get("monster_sprite", ""))
		if not leader.is_empty(): world_paths[leader] = true
		for path_v in (map.get("monster_sprite_paths", {}) as Dictionary).values():
			var path := String(path_v)
			if not path.is_empty(): world_paths[path] = true
		for optional_v in (map.get("optional_bosses", []) as Array):
			var path := String((optional_v as Dictionary).get("sprite_path", ""))
			if not path.is_empty(): world_paths[path] = true
	for path in world_paths:
		checked += 1
		if not ResourceLoader.exists(String(path)) or not (load(String(path)) is Texture2D):
			miss.append("path:" + String(path))
		else:
			hit += 1

	print("素材命中 %d / %d" % [hit, checked])
	if miss.size() > 0:
		print("MISS: " + ", ".join(miss))
		print("ASSETS_FAIL")
	else:
		print("ASSETS_OK all textures resolved")
	# 反向库存：只报告，不判失败、不删文件（问题 #31）
	var unregistered := _count_unregistered_ready()
	if unregistered > 0:
		print("NOTE: ready/ 下有 %d 张图未被 res_tex 索引登记（属库存信息，不判失败）" % unregistered)
	get_tree().quit(0 if miss.is_empty() else 1)


func _add_all(dst: Array, src: Array) -> void:
	for s in src:
		dst.append(String(s))


## 必需资源清单：全部从数据表 / 代码里的显式映射推导
func _required_names() -> Array:
	var out: Array = []
	var maps_cfg: Dictionary = TableCache.maps_config()
	var themes: Dictionary = maps_cfg.get("themes", {})
	# 8 主题战斗背景（直接读 maps.json 的 battle_bg 字段，避免与素材命名规则脱节）
	for tid in themes:
		var bg_name := String((themes[tid] as Dictionary).get("battle_bg", ""))
		if bg_name != "":
			out.append(bg_name)
	# 秘境插画（world_<theme> 8 张）：图志 / 出征卡面直接吃
	for tid3 in themes:
		out.append("world_%s" % tid3)
	# 各主题怪物（maps.json monsters + boss）
	for tid2 in themes:
		var th2: Dictionary = themes[tid2]
		for m in th2.get("monsters", []):
			out.append(String(m))
		if String(th2.get("boss", "")) != "":
			out.append(String(th2.get("boss", "")))
	# 地图交互物件
	for n in ["node_chest", "node_event", "node_shop", "node_campfire", "node_start", "node_boss"]:
		out.append(n)
	# 宠物（pets.json 全量）。<pid>_art / <pid>_evo 是**可选**的更精细立绘：
	# 图鉴与战斗都是"有就用、没有就退回 <pid>"，所以不能当作必需资源（否则等于把
	# "可以更好"判成"坏了"）。
	for p in TableCache.pets():
		out.append(String((p as Dictionary).get("id", "")))
	# NPC idle 四帧条（主城像素小人；旅人共用 npc_guest_idle）
	for nd in TableCache.city_config().get("npcs", []):
		out.append("%s_idle" % String((nd as Dictionary).get("id", "")))
	out.append("npc_guest_idle")
	# 岳教头授业面板使用独立半身像，避免资源漏接后悄悄回退为守卫。
	out.append("npc_mentor_portrait")
	var port := TableCache.city_config_for("shenyuan_port")
	for nd in port.get("npcs", []):
		out.append("%s_idle" % String((nd as Dictionary).get("id", "")))
	for bd in port.get("buildings", []):
		out.append("city_%s" % String((bd as Dictionary).get("id", "")))
	# P06 断碑营地常驻交易点，图丢失会退回通用路牌，视觉验收必须拦住。
	out.append("trade_stall")
	# 段位徽章：从 data/arena.json 的 ranks 推导（以前根本没人检查这 5 张）
	for r in TableCache.arena_config().get("ranks", []):
		out.append(String((r as Dictionary).get("id", "")))
	# 流派图标：直接读 TraitPicker.SCHOOL_ART —— 它才是流派图标的唯一事实来源。
	# 手抄一份名字到测试里，就等于"实现改了测试不知道"（#33 就是这么漏的）。
	out.append_array(_enum_art_values())
	# 运行时道具图标：所有会被玩家看到的道具（背包/掉落/商店/兑换）
	out.append_array(_item_icon_names())
	# 自定义敌人（不走怪物池、运行时动态构造的那批）：构造器在 G，显式登记
	for n3 in _custom_enemy_names():
		out.append(n3)
	# 主城建筑
	for b in TableCache.city_config().get("buildings", []):
		out.append(String((b as Dictionary).get("icon", "")))
	return out


## 读 TraitPicker 的 SCHOOL_ART 常量值（不手抄名字）
func _enum_art_values() -> Array:
	var out: Array = []
	var scr: GDScript = load("res://src/ui/TraitPicker.gd")
	if scr == null:
		return out
	var consts: Dictionary = scr.get_script_constant_map()
	var art: Variant = consts.get("SCHOOL_ART", {})
	if art is Dictionary:
		for k in (art as Dictionary):
			out.append(String((art as Dictionary)[k]))
	return out


## 所有会出现在界面上的道具**图标名**。
## 注意三种来源的命名口径不同，别一锅端：
##   · 背包/商店/掉落：id 无前缀、素材名是 itm_<id>（gem_* 与素材同名）→ 走 G.item_icon()
##   · 兑换表：自带 icon 字段，直接用它（give 的键是 item_xxx 的**授予**命名，不是素材名）
func _item_icon_names() -> Array:
	var out: Array = []
	var scr: GDScript = load("res://src/autoload/G.gd")
	if scr != null:
		var consts: Dictionary = scr.get_script_constant_map()
		var names_map: Variant = consts.get("ITEM_NAMES", {})
		if names_map is Dictionary:
			for k in (names_map as Dictionary):
				out.append(G.item_icon(String(k)))   # 背包会列出全部已登记道具
	var drops: Variant = TableCache.drops_config().get("drops", {})
	if drops is Dictionary:
		for tier in (drops as Dictionary):
			for row in (drops as Dictionary)[tier]:
				var iid := String((row as Dictionary).get("item", ""))
				if iid != "":
					out.append(G.item_icon(iid))
	for r2 in G.shop_items():
		var sid := String((r2 as Dictionary).get("item", ""))
		if sid != "":
			out.append(G.item_icon(sid))
	# 兑换表没有独立的配置访问器，直接读文件（测试里读盘一次无所谓）
	var exf := FileAccess.open("res://data/exchange.json", FileAccess.READ)
	var ex: Variant = []
	if exf != null:
		var exv: Variant = JSON.parse_string(exf.get_as_text())
		exf.close()
		if exv is Dictionary:
			ex = (exv as Dictionary).get("entries", [])
	if ex is Array:
		for e in ex:
			var icon := String((e as Dictionary).get("icon", ""))
			if icon != "":
				out.append(icon)
	return out


## 运行时动态构造的敌人（不在 maps.json 里）。加新的这类敌人时**必须**在这里登记，
## 否则"战斗里出现红色程序占位体"这种事故不会有任何回归挡住（问题 #41 的教训）。
func _custom_enemy_names() -> Array:
	return ["mon_arena_dummy"]


## 反向库存：ready/ 下有多少 png 没被 res_tex 索引收进来（只报告，不删）
func _count_unregistered_ready() -> int:
	var batches := ["generated_001_100", "generated_101_200", "generated_201_333",
		"generated_334_341", "generated_342_353"]
	var n := 0
	for b in batches:
		var root := "res://image/%s/ready" % b
		if not DirAccess.dir_exists_absolute(root):
			continue
		n += _count_dir(root)
		for sub in DirAccess.get_directories_at(root):
			n += _count_dir("%s/%s" % [root, sub])
	return n


func _count_dir(path: String) -> int:
	var n := 0
	var d := DirAccess.open(path)
	if d == null:
		return 0
	for f in d.get_files():
		if not String(f).ends_with(".png"):
			continue
		var nm := String(f).get_basename()
		if not nm.begins_with("frame_") and G.res_path(nm) == "":
			n += 1
	return n
