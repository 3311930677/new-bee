extends Node
## 正式版主城首页预览：双击 tools/LaunchTownHome.cmd（480×800）或 LaunchTownHomeTall.cmd（480×1067）。
## 注意“出征”会切到主世界 MapScene（同样使用隔离存档）。
## 使用演示数据，存档路径指向 shots 下的隔离文件，不碰玩家存档。
const OUT := "res://shots/town_home_20261013/"


func _ready() -> void:
	G.SAVE_PATH = OUT + "isolated_save.json"
	G.set_meta("ui_review_mode", true)
	G._init_state_defaults()
	G.player_name = "沈舟"
	G.prog.level = 32
	G.prog.exp = int(G.exp_to_next(32) * 0.62)
	G.wallet = {"gold": 125480, "expedition": 120, "soul": 3860, "honor": 900}
	G.save_locked = false
	# 打开正式版营帐（GameHome 挂主城首页），入口都是真实面板
	add_child(load("res://src/ui/GameHome.tscn").instantiate())
