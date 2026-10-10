extends Node2D
## The river and crossing follow current map geometry, preserving the original quest conditions.
const RIVER_Y:=578.0
const CROSSING:=Vector2(440,560)
var _state:=""
var _wait:=0.0
var _river:Dictionary={}
var _width:=960.0
var _bridge_texture:Texture2D
func setup(cfg:Dictionary)->void:
	_river=(cfg.get("river",{}) as Dictionary).duplicate(true)
	_width=float(cfg.get("map_cols",20))*48.0
	var path:="res://assets/world/reference_complete_20261011/ready/bridge.png"
	if String(cfg.get("art_profile",""))=="reference_complete" and ResourceLoader.exists(path):_bridge_texture=load(path)
	_state=""
	_wait=0
	queue_redraw()
func center_y(x:float)->float:
	var points:Array=_river.get("points",[])
	if points.size()>=2:
		var a:=Vector2(points[0][0],points[0][1])
		var b:=Vector2(points[-1][0],points[-1][1])
		return lerpf(a.y,b.y,clampf((x-a.x)/maxf(1,b.x-a.x),0,1))
	return float(_river.get("y",RIVER_Y))
func crossing()->Vector2:
	var span:Array=_river.get("crossing",[CROSSING.x,CROSSING.y])
	return Vector2(span[0],span[1])
static func lane_open(side:String)->bool:
	var record:=QuestService.side_get(G.act1_state(),"a1_trade_bridge")
	return G.story_step_done("s12") and String(record.get("status",""))==QuestService.SIDE_DONE and String(record.get("branch_flags",{}).get("a1_trade_bridge_step_3",""))==side
func _process(delta:float)->void:
	_wait-=delta
	if _wait>0:return
	_wait=.3
	var west:=lane_open("west")
	var east:=lane_open("east")
	var s12:=G.story_step_done("s12")
	var state:=str(s12)+str(west)+str(east)
	if state==_state:return
	_state=state
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_build_river_blocks(west,east)
	if not s12:return
	var gap:=crossing()
	var axis:=(gap.x+gap.y)*.5
	for side in ["west","east"]:
		var lane:=BridgeLane.new()
		var x:=axis+(-120 if side=="west" else 120)
		lane.position=Vector2(x,center_y(x))
		lane.open=west if side=="west" else east
		lane.fine=_bridge_texture!=null
		lane.set_meta("aftermath_bridge",side)
		add_child(lane)
func _build_river_blocks(open_west:bool,open_east:bool)->void:
	var gap:=crossing()
	var axis:=(gap.x+gap.y)*.5
	var spans:Array=[[0.0,gap.x],[gap.y,_width]]
	if open_west:spans=_cut(spans,axis-145,axis-95)
	if open_east:spans=_cut(spans,axis+95,axis+145)
	var height:=float(_river.get("half",22.0))*2.0
	for span:Array in spans:
		var x:=float(span[0])
		while x<float(span[1]):
			var end:=minf(x+32,float(span[1]))
			var center:=(x+end)*.5
			var body:=StaticBody2D.new()
			body.collision_layer=2
			body.collision_mask=0
			body.position=Vector2(center,center_y(center))
			var shape:=CollisionShape2D.new()
			var rect:=RectangleShape2D.new()
			rect.size=Vector2(end-x,maxf(height+2,absf(center_y(end)-center_y(x))+height))
			shape.shape=rect
			body.add_child(shape)
			add_child(body)
			x=end
static func _cut(spans:Array,a:float,b:float)->Array:
	var result:Array=[]
	for span:Array in spans:
		if b<=span[0] or a>=span[1]:
			result.append(span)
			continue
		if a>span[0]:result.append([span[0],a])
		if b<span[1]:result.append([b,span[1]])
	return result
func _draw()->void:
	if _bridge_texture==null:return
	var gap:=crossing()
	var x:=(gap.x+gap.y)*.5
	draw_texture_rect(_bridge_texture,Rect2(x-(gap.y-gap.x)*.5,center_y(x)-64,gap.y-gap.x,128),false)
class BridgeLane extends StaticBody2D:
	var open:=false
	var fine:=false
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
		if fine:
			var id:="bridge" if open else "barricade"
			var size:=Vector2(50,128) if open else Vector2(92,60)
			draw_texture_rect(ReferenceWorldArt.texture(id),Rect2(-size*.5,size),false)
			return
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
