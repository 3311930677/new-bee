extends Node
## Disposable playable fixture; never changes the player's normal save path.
func _ready()->void:
	G.SAVE_PATH="res://shots/reference_complete_20261011/playable_preview_save.json"
	G._init_state_defaults();G.save_locked=false
	G.selected_role="zs";G.player_name="行旅人";G.account="预览旅人"
	G.prog.level=12;G.wallet={"gold":9999,"expedition":1200,"soul":300,"honor":100}
	G.city.built=["hall","gate","stable","barracks","storehouse","forge","archive","kennel","shrine"]
	G.prog.tips_seen={"deploy":true};G.collect_pet("pet_rockturtle")
	G.enter_main_world("lorin_wilds")
