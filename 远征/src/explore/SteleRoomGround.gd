extends Node2D

var _signature:=""
var _wait:=0.0
var flat_floor := false

func _process(delta:float)->void:
	_wait-=delta
	if _wait>0:return
	_wait=.3
	var flags:Dictionary=G.prog.get("flags",{})
	var signature:=str(flags.get("act1_stele_clue",false))+str(flags.get("act1_stele_seat_1",false))+str(flags.get("act1_stele_seat_2",false))
	if signature!=_signature:
		_signature=signature
		queue_redraw()

func _draw()->void:
	if not flat_floor: _draw_floor()
	_draw_state()

func _draw_floor() -> void:
	# 三处石缝围着听声堂，侧壁碑座围着回响庭，北端收束到碑心。
	# 墙面为地形底图，通行与机关碰撞仍由原场景统一控制。
	draw_rect(Rect2(0,0,960,1248),Color("232b32"))
	var rooms:=[Rect2(160,795,640,350),Rect2(210,555,540,175),Rect2(260,125,440,345)]
	for room in rooms:
		draw_rect(room.grow(18),Color("4c5254"))
		draw_rect(room.grow(8),Color("777269"))
		draw_rect(room,Color("3b4549"))
		var row_index:=0
		for y in range(int(room.position.y),int(room.end.y),40):
			for x in range(int(room.position.x),int(room.end.x),72):
				var offset:=0 if row_index%2==0 else 28
				var tile:=Rect2(x+offset,y,68,36).intersection(room)
				draw_rect(tile,Color("465054") if (x/72+row_index)%3!=0 else Color("4f5654"))
				draw_line(tile.position,tile.position+Vector2(tile.size.x,0),Color("626a67"),1)
			row_index+=1
	for connector in [Rect2(405,700,150,125),Rect2(405,440,150,145),Rect2(405,1120,150,128)]:
		draw_rect(connector,Color("555c58"))
		for y in range(int(connector.position.y),int(connector.end.y),26):
			draw_line(Vector2(connector.position.x,y),Vector2(connector.end.x,y),Color("788075"),2)

func _draw_state() -> void:
	var flags:Dictionary=G.prog.get("flags",{})
	var heard:=bool(flags.get("act1_stele_clue",false))
	var aligned:=bool(flags.get("act1_stele_seat_2",false))
	for at in [Vector2(210,940),Vector2(480,955),Vector2(750,940)]:
		for radius in [24,35,46]:
			draw_arc(at,float(radius),PI*.12,PI*.88,16,Color("93b9ba",.65 if heard else .2),2)
		draw_line(at+Vector2(-10,-17),at+Vector2(5,4),Color("1d3039"),4)
		draw_line(at+Vector2(5,4),at+Vector2(-3,19),Color("a1a58c"),2)
	for at in [Vector2(315,680),Vector2(650,610)]:
		draw_circle(at,42,Color("2b373f"))
		draw_arc(at,38,0,TAU,32,Color("b4aa87"),3)
		draw_line(at+Vector2(-25,0),at+Vector2(25,0),Color("82b9b6") if aligned else Color("707877"),4)
	var heart:=Vector2(480,315)
	for radius in [48,72,96]:
		draw_arc(heart,float(radius),0,TAU,48,Color("83afb1",.45 if aligned else .16),2)
	for i in 8:
		var axis:=Vector2.UP.rotated(float(i)*TAU/8)
		draw_line(heart+axis*82,heart+axis*99,Color("c0ad80"),3)
	for at in [Vector2(187,1080),Vector2(773,1080),Vector2(235,705),Vector2(725,705),Vector2(282,450),Vector2(678,450)]:
		draw_rect(Rect2(at-Vector2(13,28),Vector2(26,48)),Color("69716c"))
		draw_rect(Rect2(at-Vector2(17,29),Vector2(34,7)),Color("a8a08c"))
		draw_circle(at-Vector2(0,15),4,Color("9dcccf") if heard else Color("7b877f"))
