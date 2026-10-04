extends Node
func _ready()->void:
	G.SAVE_PATH="res://tools/_logs/save_verify_world_commissions.json"
	var posting:=FileAccess.get_file_as_string("res://tools/_logs/world_commission_resume_id.txt")
	var ok:=G.reload_save()
	var record:Dictionary=WorldCommission.state(G).get(posting,{})
	var step:=WorldCommission.current(record)
	ok=ok and int(record.get("progress",0))==1 and String(record.get("choice",""))=="tide" and String(step.get("map",""))=="tideflat"
	ok=ok and bool(WorldCommission.action(G,posting,"tideflat",String(step.get("id",""))).get("ok",false))
	ok=ok and bool(WorldCommission.claim(G,posting,"shenyuan_port").ok)
	var gold:=int(G.wallet.gold)
	ok=ok and not bool(WorldCommission.claim(G,posting,"shenyuan_port").ok) and int(G.wallet.gold)==gold
	var oaths:=preload("res://src/world/OathService.gd")
	var key:="rift_mine_road|"+WorldCommission.day()
	ok=ok and String(oaths.state(G).get("current",""))=="conquest" and String(oaths.objective(G,key).get("id",""))=="harvest"
	for id in ["shelter","conquest","harvest"]:
		ok=ok and bool(G.prog.get("flags",{}).get("oath_pattern_"+id,false))
	if not ok:push_error("FAIL: 第二进程委托路线/现场进度/单次报酬")
	print("WORLD_COMMISSIONS_READ_OK" if ok else "WORLD_COMMISSIONS_READ_FAIL")
	get_tree().quit(0 if ok else 1)
