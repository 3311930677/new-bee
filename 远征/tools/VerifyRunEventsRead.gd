extends Node
func _ready() -> void:
	G.SAVE_PATH="res://tools/_logs/save_verify_run_events.json"
	var ok:=G.reload_save()
	RouteScene.pending_run={"resume":true}
	var route:=preload("res://src/run/RouteScene.tscn").instantiate() as RouteScene
	add_child(route)
	await get_tree().process_frame
	await get_tree().process_frame
	ok=ok and route.st.gold==110 and route.st.theme=="snow" and route._map!=null
	if route._map!=null:ok=ok and route._map._interactable==null and String(route._map._prog.get("event_choice",""))=="work"
	print("RUN_EVENTS_READ_OK" if ok else "RUN_EVENTS_READ_FAIL")
	get_tree().quit(0 if ok else 1)
