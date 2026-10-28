extends Node
## 20261026 全页面体验审查:新手页 → 主城全部面板 → 18 张主世界地图 → 战斗与结算。
## 运行:godot --path . res://tools/FullPlayAudit.tscn
## 输出:shots/full_play_20261026/*.png + audit_report.json

const OUT := "res://shots/full_play_20261026/"
const MAP_LIST := [
	"lorin_wilds", "maple_road", "broken_slope", "old_salt_road", "shenyuan_port",
	"tideflat", "tidal_gate", "stele_cavern", "red_sand_route", "frost_post",
	"rift_mine_road", "rift_mine_vault", "frost_pass", "frost_boardwalk",
	"abyss_ring", "stele_entry", "stele_resonance", "stele_core",
]
const HOME_PAGES := [
	"growth", "growth:talent", "growth:equip", "growth:pet", "growth:skill",
	"growth:mount", "growth:title", "bag", "quests", "gathering", "activities",
	"worlds", "arena", "archery", "companion", "shop", "journal", "oath",
	"avatar", "gacha", "exchange", "curio", "mail", "trade:city", "trade:port",
	"trade:frost", "contract", "fishing:salt", "fishing:port", "fishing:tide",
	"fishing:frost", "journey", "relic_hunt", "settings", "tutorial", "deploy",
]

var current: Node = null
var report := {"steps": [], "errors": []}

func frames(n := 6) -> void:
	for i in n:
		await get_tree().process_frame

func pause(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func shot(name: String, bottom := false) -> void:
	await RenderingServer.frame_post_draw
	var node := current if current != null else self
	if bottom:
		for sc in node.find_children("*", "ScrollContainer", true, false):
			sc.scroll_vertical = 1000000
		await frames(3)
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := OUT + name + ".png"
	if img.save_png(ProjectSettings.globalize_path(path)) != OK:
		print("FULLPLAY_SHOT_FAIL ", name)
	report["steps"].append({"name": name, "t": Time.get_ticks_msec() / 1000.0})

func clean() -> void:
	if current != null and is_instance_valid(current):
		current.queue_free()
		await frames(2)
	current = null

func attach(node: Node) -> void:
	current = node
	add_child(node)
	await frames(8)

func fixture() -> void:
	G.SAVE_PATH = ProjectSettings.globalize_path(OUT + "_isolated_save.json")
	G.save_locked = false
	G._init_state_defaults()
	G.set_meta("ui_review_mode", true)
	G.gm_unlocked = true
	G.gm_grant_all()
	G.gm_unlock_all_features()
	G.selected_role = "zs"
	G.player_name = "沈舟"
	G.prog.level = 35
	G.wallet = {"gold": 128400, "expedition": 2310, "soul": 860, "honor": 1240}
	G.ensure_starter_pets()
	G.ensure_starter_equip(true)
	G.mount_buy("horse")
	G.mount_set_riding(false, false)
	G.prog.main_world = {"map_id": "lorin_wilds"}
	G.prog.flags["act3_supply_choice"] = "merchant"

func home_with(page: String) -> void:
	await clean()
	var home := preload("res://src/ui/GameHome.tscn").instantiate()
	await attach(home)
	if not page.is_empty():
		home.open_gm_feature(page)
		await frames(10)

func make_map(id: String) -> Node:
	G.gm_world_open = true
	G.prog.main_world = {"map_id": id}
	var run := RunState.new()
	run.setup({"role_id": "zs", "theme": String(TableCache.main_world_map(id).get("theme", "forest")), "level": 35, "seed": 71})
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": id, "run": run, "node": {"type": "normal", "layer": 1, "index": 0}}
	return preload("res://src/explore/MapScene.tscn").instantiate()

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_window().size = Vector2i(480, 800)
	fixture()
	await frames(10)

	# ---- 新手流程页面 ----
	var load_node := preload("res://src/ui/LoadScreen.gd").new()
	load_node.auto_advance = false
	await attach(load_node)
	await shot("s01_loading")
	await clean()

	await attach(preload("res://src/ui/Title.tscn").instantiate())
	await pause(0.8)
	await shot("s02_title")
	await clean()

	await attach(preload("res://src/ui/Login.tscn").instantiate())
	await frames(10)
	await shot("s03_login")
	await clean()

	await attach(preload("res://src/ui/CreateRole.tscn").instantiate())
	await frames(10)
	await shot("s04_createrole")
	await clean()

	# ---- 主城与全部面板 ----
	await home_with("")
	await shot("s05_home")
	await home_with("tutorial")
	await shot("s06_tutorial")
	for page: String in HOME_PAGES:
		await home_with(page)
		var tag := "s07_" + page.replace(":", "_")
		await shot(tag)
		await shot(tag + "_bottom", true)
		report["steps"].append({"name": tag, "page": page})

	# ---- 四种货币卡 ----
	for id in ["gold", "expedition", "soul", "honor"]:
		await clean()
		var card := preload("res://src/ui/CurrencyPanel.gd").new()
		card.currency_id = id
		await attach(card)
		await shot("s08_currency_" + id)

	# ---- 世界地图 18 张 ----
	for mid in MAP_LIST:
		await clean()
		await attach(make_map(String(mid)))
		await pause(0.4)
		await shot("s09_map_" + String(mid))

	# ---- 战斗(默认全屏表现) ----
	await clean()
	fixture()
	BattleScene.pending_cfg = {
		"ally": {"role_id": "zs", "level": 35, "traits": [], "potions": 3},
		"enemy": {"theme": "forest", "node_type": "normal", "layer": 1},
		"seed": 71,
	}
	await attach(preload("res://src/battle/BattleScene.tscn").instantiate())
	await pause(1.0)
	await shot("s10_battle_start")
	await pause(6.0)
	await shot("s11_battle_mid")
	if current != null and "sim" in current:
		report["battle_sim_result"] = str(current.sim.result)
	await pause(6.0)
	await shot("s12_battle_late")
	if current != null and "sim" in current:
		report["battle_sim_result_late"] = str(current.sim.result)
	await clean()

	# ---- 战斗结算(胜/负) ----
	for win in [true, false]:
		await clean()
		var view := preload("res://src/battle/BattleSettlementView.gd").new()
		view.report = {
			"win": win, "title": "凯旋战报" if win else "整备再战", "role_name": "破军",
			"level": 35, "hp_left": 2345, "hp_max": 5678, "pet_name": "青鸾", "seconds": 63.4,
			"best_hit": 23456, "damage_out": 456789, "damage_in": 23456,
			"rewards": {"gold": 12345, "expedition": 2345, "soul": 345, "exp": 4567},
		}
		await attach(view)
		await shot("s13_settlement_" + ("win" if win else "lose"))
		await clean()

	var f := FileAccess.open(ProjectSettings.globalize_path(OUT + "audit_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	print("FULLPLAY_OK steps=", report["steps"].size())
	get_tree().quit()
