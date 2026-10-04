class_name ReturnJourneyProps
extends Node2D

var map_id := ""
var _state := ""
var _timer := 0.0

func _process(delta: float) -> void:
	_timer-=delta
	if _timer>0: return
	_timer=.25
	var state:=JSON.stringify(G.prog.get("flags",{}))
	if state==_state: return
	_state=state
	for child in get_children(): child.queue_free()
	var flags: Dictionary=G.prog.get("flags",{})
	var cfg:=TableCache.main_world_map(map_id)
	for eid in cfg.get("entities",{}):
		var row: Dictionary=cfg.entities[eid]
		var qid:=String(row.get("quest",""))
		if not qid.begins_with("a4_") or G.side_status_of(qid)!=QuestService.SIDE_DONE: continue
		var art:=String(row.get("art",""))
		var variant:=""
		if art=="return_lamp": variant=String(flags.get("act4_waylight",""))
		elif art=="return_rune": variant=String(flags.get("act4_rune_memory",""))
		elif art=="return_letter": continue # The letter was returned to its owner.
		elif art=="frost_courier": art="return_mailbox"
		var prop:=Prop.new()
		prop.position=Vector2(float(row.at[0]),float(row.at[1]))
		prop.art=art
		prop.variant=variant
		add_child(prop)

class Prop extends Node2D:
	var art:=""
	var variant:=""
	func _draw() -> void:
		ReturnJourneyProps.draw_prop(self,art,variant)

const Art := preload("res://src/world/WorldPropArt.gd")

static func draw_prop(canvas: CanvasItem, art: String, variant := "") -> void:
	match art:
		"return_lamp":
			if variant=="marker": Art.supplementary(canvas,"rune",56)
			else:
				Art.supplementary(canvas,"lantern",76,Color.WHITE if variant=="beacon" else Color("929e9c"))
				if variant=="beacon": canvas.draw_circle(Vector2(8,-42),18,Color(1,.76,.32,.10))
		"return_letter": Art.supplementary(canvas,"letter",30)
		"return_tidebud": Art.supplementary(canvas,"tidebud",43)
		"return_snowflower": Art.supplementary(canvas,"snowflower",43)
		"return_rune":
			var tint:=Color("efcb96") if variant=="trace" else Color.WHITE
			if variant=="quiet": tint=Color("859294")
			Art.supplementary(canvas,"rune",58,tint)
		"return_mailbox": Art.supplementary(canvas,"mailbox",68)
