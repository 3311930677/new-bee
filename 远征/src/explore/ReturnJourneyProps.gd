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

static func draw_prop(canvas: CanvasItem, art: String, variant := "") -> void:
	canvas.draw_set_transform(Vector2(0,3),0,Vector2(1,.28))
	canvas.draw_circle(Vector2.ZERO,22,Color(0,0,0,.28))
	canvas.draw_set_transform(Vector2.ZERO)
	match art:
		"return_lamp":
			canvas.draw_rect(Rect2(-17,-7,34,9),Color("655e50"))
			if variant=="marker":
				canvas.draw_rect(Rect2(-15,-43,30,39),Color("869c9c"))
				canvas.draw_rect(Rect2(-11,-39,22,4),Color("c3ddda"))
				canvas.draw_line(Vector2(-9,-19),Vector2(9,-29),Color("2d545f"),3)
				canvas.draw_line(Vector2(5,-29),Vector2(9,-29),Color("2d545f"),3)
			else:
				canvas.draw_rect(Rect2(-4,-66,8,62),Color("68563e"))
				canvas.draw_rect(Rect2(-15,-66,30,7),Color("aa8b54"))
				canvas.draw_rect(Rect2(-11,-58,22,23),Color("453e37"))
				canvas.draw_rect(Rect2(-7,-54,14,15),Color("ffce73") if variant=="beacon" else Color("778276"))
				if variant=="beacon":
					canvas.draw_circle(Vector2(0,-46),33,Color(1,.76,.32,.12))
		"return_letter":
			canvas.draw_rect(Rect2(-19,-24,38,25),Color("d5c298"))
			canvas.draw_line(Vector2(-18,-22),Vector2(0,-9),Color("97795b"),2)
			canvas.draw_line(Vector2(18,-22),Vector2(0,-9),Color("97795b"),2)
			canvas.draw_rect(Rect2(8,-24,10,8),Color("eee1bd"))
		"return_tidebud", "return_snowflower":
			if art=="return_snowflower":
				# Windblown snow and rooted soil at the boardwalk's snow line.
				canvas.draw_polygon(PackedVector2Array([Vector2(-30,0),Vector2(-22,-14),Vector2(-5,-20),Vector2(19,-15),Vector2(30,0)]),PackedColorArray([Color("e2edf0")]))
				canvas.draw_rect(Rect2(-20,-6,40,6),Color("887b69"))
			var flower:=Color("8dc6b6") if art=="return_tidebud" else Color("ddd6f0")
			for i in 3:
				var at:=Vector2(-15+i*15,-9-(i%2)*9)
				canvas.draw_line(at,at+Vector2(0,-20),Color("5b8778"),3)
				canvas.draw_rect(Rect2(at+Vector2(-10,-13),Vector2(10,5)),Color("719e85"))
				canvas.draw_rect(Rect2(at+Vector2(2,-17),Vector2(9,5)),Color("90b79b"))
				canvas.draw_rect(Rect2(at+Vector2(-7,-26),Vector2(15,8)),flower)
				canvas.draw_rect(Rect2(at+Vector2(-3,-30),Vector2(7,16)),flower)
				canvas.draw_rect(Rect2(at+Vector2(-2,-24),Vector2(5,5)),Color("e5be79"))
		"return_rune":
			canvas.draw_rect(Rect2(-24,-9,48,11),Color("514e49"))
			canvas.draw_rect(Rect2(-18,-48,36,39),Color("566574"))
			canvas.draw_rect(Rect2(-21,-51,42,6),Color("ad9f82"))
			var color:=Color("dcc894") if variant=="trace" else Color("8db9c1")
			if variant=="quiet": color=Color("859294")
			canvas.draw_line(Vector2(-9,-37),Vector2(8,-17),color,3)
			canvas.draw_line(Vector2(8,-37),Vector2(-9,-17),color,3)
			canvas.draw_rect(Rect2(-3,-30,6,6),Color("dfe6da"))
		"return_mailbox":
			canvas.draw_rect(Rect2(-4,-40,8,40),Color("5e5140"))
			canvas.draw_rect(Rect2(-22,-61,44,31),Color("597988"))
			canvas.draw_rect(Rect2(-25,-66,50,7),Color("b8a679"))
			canvas.draw_rect(Rect2(-13,-55,26,5),Color("273c49"))
			for i in 3: canvas.draw_rect(Rect2(-13+i*10,-43,6,8),[Color("91b991"),Color("80bacb"),Color("d6ddeb")][i])
