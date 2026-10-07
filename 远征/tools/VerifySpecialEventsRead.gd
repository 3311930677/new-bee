extends Node
const Events := preload("res://src/world/SpecialEventService.gd")
func _ready() -> void:
	G.SAVE_PATH="res://tools/_logs/save_verify_special_resume.json"
	var ok:=G.reload_save()
	var saved:=Events.record(G,"misdelivered_invitation")
	ok=ok and String(saved.get("phase",""))=="battle" and String(saved.get("branch",""))=="chase"
	var pending:Dictionary=saved.get("battle",{})
	ok=ok and not pending.is_empty() and int(pending.get("seed",0))==61061
	var resumed:=Events.prepare_battle(G,"misdelivered_invitation","maple_road",{"role_id":"zs","level":1})
	ok=ok and bool(resumed.get("ok",false)) and resumed.get("battle",{})==pending
	if ok:
		ok=bool(Events.resolve_battle(G,"misdelivered_invitation","maple_road",String(pending.token),"victory").ok)
	if ok:
		ok=bool(Events.action(G,"misdelivered_invitation","lorin_wilds","partner").ok)
	var gold:=int(G.wallet.gold)
	ok=ok and not bool(Events.action(G,"misdelivered_invitation","lorin_wilds","gear").ok) and int(G.wallet.gold)==gold
	print("SPECIAL_EVENTS_READ_OK second_process=true" if ok else "SPECIAL_EVENTS_READ_FAIL")
	get_tree().quit(0 if ok else 1)
