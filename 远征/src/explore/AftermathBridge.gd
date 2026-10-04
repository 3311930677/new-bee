extends Node2D
var _state:=""
var _wait:=0.0
func _process(delta:float)->void:
	_wait-=delta
	if _wait>0:return
	_wait=.3
	var record:=QuestService.side_get(G.act1_state(),"a1_trade_bridge")
	var complete:=String(record.get("status",""))==QuestService.SIDE_DONE
	var branch:=String(record.get("branch_flags",{}).get("a1_trade_bridge_step_3",""))
	var state:=str(G.story_step_done("s12"))+str(complete)+branch
	if state==_state:return
	_state=state
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if not G.story_step_done("s12"):return
	for side in ["west","east"]:
		var lane:=BridgeLane.new()
		lane.position=Vector2(380 if side=="west" else 620,590)
		lane.open=complete and branch==side
		lane.set_meta("aftermath_bridge",side)
		add_child(lane)
class BridgeLane extends StaticBody2D:
	var open:=false
	func _ready()->void:
		collision_layer=2
		collision_mask=0
		var spans:=[Rect2(-60,-30,120,60)] if not open else [Rect2(-60,-30,35,60),Rect2(25,-30,35,60)]
		for area in spans:
			var shape:=CollisionShape2D.new()
			var rect:=RectangleShape2D.new()
			rect.size=area.size
			shape.shape=rect
			shape.position=area.get_center()
			add_child(shape)
	func _draw()->void:
		draw_rect(Rect2(-60,-30,120,60),Color("406c71"))
		for y in [-18,0,18]:draw_line(Vector2(-56,y),Vector2(56,y-6),Color("9ab7b2",.7),2)
		for y in [-34,30]:draw_rect(Rect2(-65,y,130,4),Color("8e8d73"))
		if open:
			for y in range(-40,41,10):
				draw_rect(Rect2(-24,y,48,8),Color("aa8352"))
				draw_line(Vector2(-22,y),Vector2(22,y),Color("d2b181"),1)
			for x in [-26,26]:
				draw_line(Vector2(x,-43),Vector2(x,43),Color("5a4431"),3)
				draw_colored_polygon(PackedVector2Array([Vector2(x-4,-42),Vector2(x+4,-42),Vector2(x,-33)]),Color("d5a863"))
		else:
			for y in [-37,32]:
				draw_rect(Rect2(-26,y,52,8),Color("725b40"))
				draw_rect(Rect2(-22,y,20,8),Color("b8a27b"))
