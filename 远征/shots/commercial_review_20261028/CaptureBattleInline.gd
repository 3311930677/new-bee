extends "res://tools/CurrentVisualAudit.gd"
## 主世界实际使用的 classic_inline 战斗表现补拍。

func _ready() -> void:
	OUT = "res://shots/commercial_review_20261028/extra/"
	get_window().size = Vector2i(480, 800)
	fixture()
	await frames(10)
	for theme in ["forest", "frost"]:
		BattleScene.pending_cfg = {
			"ally": {"role_id": "zs", "level": 35, "traits": [], "potions": 3},
			"enemy": {"theme": theme, "node_type": "elite" if theme == "frost" else "normal", "layer": 1},
			"presentation": "classic_inline", "seed": 71,
		}
		await attach(preload("res://src/battle/BattleScene.tscn").instantiate())
		await pause(1.2)
		await shot("x05_battle_inline_" + theme + "_start")
		await pause(5.0)
		await shot("x05_battle_inline_" + theme + "_mid")
		await clean()
	print("COMMERCIAL_BATTLE_OK")
	get_tree().quit()
