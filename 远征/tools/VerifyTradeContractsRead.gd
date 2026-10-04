extends Node
const C:=preload("res://src/world/TradeContracts.gd")
func _ready()->void:
	G.SAVE_PATH="res://tools/_logs/save_verify_trade_contracts.json"
	var ok:=G.reload_save()
	var record:Dictionary=C.state(G).get("bridge_iron|1",{})
	ok=ok and record.get("status","")=="active" and C.validate(C.state(G)) and G.wallet.gold==9940
	ok=ok and not C.sign(G,"bridge_iron","self","city_market").ok
	G.prog.main_world.map_id="old_salt_road"
	ok=ok and C.action(G,"bridge_iron|1","aid").ok
	G.prog.main_world.map_id=C.map_for("shenyuan_market")
	G.items.trade_iron=2
	var expected:=9940+int(record.payout)+60
	ok=ok and C.action(G,"bridge_iron|1","deliver","shenyuan_market").ok and G.wallet.gold==expected
	ok=ok and G.reload_save() and C.state(G)["bridge_iron|1"].status=="done"
	print("TRADE_CONTRACTS_READ_OK" if ok else "TRADE_CONTRACTS_READ_FAIL")
	get_tree().quit(0 if ok else 1)
