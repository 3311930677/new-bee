extends Node
func _ready() -> void:
	for slope in [0.06, 0.08, 0.10, 0.12, 0.16]:
		for lv in [5, 15, 35, 60]:
			var wins := 0
			var ticks := 0
			for seed_value in 3:
				var sim := BattleSim.new()
				sim.record_events = false
				sim.setup(seed_value+7, {"role_id":"zs", "level":lv, "active_pet":"pet_emberling", "traits":["tr_atk_up_m", "tr_bleed_1", "tr_bleed_2", "tr_deep_wound"], "potions":2}, {"theme":"forest", "node_type":"boss", "layer":3, "enemy_mult":(1.0+slope*(lv-1))/(1.0+.16*(lv-1))})
				sim.auto_mode = false
				while not sim.finished:
					var role := sim.role_unit()
					if role != null and role.hp < role.get_max_hp()*.45: sim.use_potion()
					sim.step()
				if sim.result == "victory": wins += 1
				ticks += sim.tick_count
			print("SAMPLE slope=",slope," level=",lv," boss_wins=",wins,"/3 seconds=",ticks/90.0)
	get_tree().quit()
