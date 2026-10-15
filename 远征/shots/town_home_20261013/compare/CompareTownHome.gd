extends Node
## 对比截图：把 TownHome.gd 的背景与坐标常量临时换回“边城夜景”版本，渲染旧版首页。
## 正式代码不改；输出 compare/old_800.png、old_1067.png。
const DIR := "res://shots/town_home_20261013/compare/"

# 换背景前的常量（与 16:02 版 TownHome.gd 一致，底栏修正保留，便于只比背景）
const OLD := {
	"const CORE_H := 720.0": "const CORE_H := 800.0",
	"const BG_TOP_EXT := 200.0": "const BG_TOP_EXT := 136.0",
	"const CORE_Y_800 := 40.0": "const CORE_Y_800 := 0.0",
	"const SKY := Color(\"03266c\")": "const SKY := Color(\"092561\")",
	"[\"gacha\", \"酒馆\", \"tavern\", Vector2(130, 150)]": "[\"gacha\", \"酒馆\", \"tavern\", Vector2(112, 146)]",
	"[\"arena\", \"竞技场\", \"arena\", Vector2(352, 150)]": "[\"arena\", \"竞技场\", \"arena\", Vector2(362, 164)]",
	"[\"craft\", \"铁匠铺\", \"anvil\", Vector2(108, 268)]": "[\"craft\", \"铁匠铺\", \"anvil\", Vector2(104, 290)]",
	"[\"exchange\", \"集市\", \"market\", Vector2(372, 284)]": "[\"exchange\", \"集市\", \"market\", Vector2(380, 304)]",
	"[\"world\", \"世界\", \"gate\", Vector2(240, 350)]": "[\"world\", \"世界\", \"gate\", Vector2(240, 396)]",
	"const HERO_FEET := Vector2(240, 556)": "const HERO_FEET := Vector2(240, 614)",
}
const OLD_FIRES := """const FIRES := [
	["s", Vector2(194, 584)], ["s", Vector2(288, 584)],
	["xs", Vector2(142, 588)], ["xs", Vector2(338, 588)],
	["xs", Vector2(240, 438)],
]"""


func _ready() -> void:
	G.SAVE_PATH = DIR + "isolated_save.json"
	G.set_meta("ui_review_mode", true)
	G._init_state_defaults()
	G.player_name = "沈舟"
	G.prog.level = 32
	G.prog.exp = int(G.exp_to_next(32) * 0.62)
	G.wallet = {"gold": 125480, "expedition": 120, "soul": 3860, "honor": 900}

	var src := FileAccess.get_file_as_string("res://src/ui/home/TownHome.gd")
	for k in OLD:
		assert(src.contains(k), "常量没找到：" + k)
		src = src.replace(k, OLD[k])
	var a := src.find("const FIRES := [")
	var b := src.find("]\n", src.find("\n]", a)) + 1
	src = src.substr(0, a) + OLD_FIRES + src.substr(b)
	src = src.replace('load(DIR + "home_bg_tall.png")',
		'ImageTexture.create_from_image(Image.load_from_file("%sold_bg_tall.png"))' % DIR)
	var script := GDScript.new()
	script.source_code = src
	if script.reload() != OK:
		push_error("COMPARE_SCRIPT_FAIL")
		get_tree().quit(1)
		return

	for height in [800, 1067]:
		get_window().size = Vector2i(480, height)
		await get_tree().process_frame
		var home := Control.new()
		home.set_script(script)
		add_child(home)
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(DIR + "old_%d.png" % height)
		home.queue_free()
		await get_tree().process_frame
	print("COMPARE_OK")
	get_tree().quit()
