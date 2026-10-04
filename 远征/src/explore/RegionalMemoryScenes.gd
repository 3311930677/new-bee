extends RefCounted

static func draw_scene(canvas:CanvasItem,region:String,tier:int)->void:
	match region:
		"zhaoyuan":
			# 路簿与灯架：托付时留出下一位巡界人的第二盏灯。
			canvas.draw_rect(Rect2(-43,-10,86,9),Color("655746"))
			canvas.draw_rect(Rect2(-27,-36,54,26),Color("dbc798"))
			for y in [-30,-23,-16]:canvas.draw_line(Vector2(-21,y),Vector2(16,y),Color("7b7660"),2)
			for x in ([-40,40] if tier>=2 else [-40]):
				canvas.draw_line(Vector2(x,-5),Vector2(x,-77),Color("6b533a"),7)
				canvas.draw_rect(Rect2(x-14,-75,28,8),Color("b49a68"))
				canvas.draw_rect(Rect2(x-10,-62,20,23),Color("433b2e"))
				canvas.draw_rect(Rect2(x-6,-58,12,15),Color("f5cd83"))
				canvas.draw_circle(Vector2(x,-50),22,Color(1,.75,.35,.12))
		"shenyuan":
			# 港务潮纸有真实水线与缆绳，第二档增设可供短程船查阅的副图。
			canvas.draw_rect(Rect2(-41,-69,82,65),Color("75573d"))
			canvas.draw_rect(Rect2(-35,-63,70,50),Color("d9cba2"))
			for i in 3:
				canvas.draw_polyline(PackedVector2Array([Vector2(-29,-50+i*12),Vector2(-10,-54+i*12),Vector2(13,-47+i*12),Vector2(29,-53+i*12)]),Color("537d86"),2)
			for x in [-32,32]:canvas.draw_line(Vector2(x,-2),Vector2(x,15),Color("65543f"),6)
			canvas.draw_arc(Vector2(-37,7),17,0,TAU,20,Color("b69c70"),4)
			if tier>=2:
				canvas.draw_rect(Rect2(27,-32,25,34),Color("d6c08f"))
				canvas.draw_line(Vector2(31,-20),Vector2(47,-20),Color("507982"),2)
		"frost":
			# 轮岗桌留下可辨的工帽、交接名牌和热汤，不再复用路标。
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-42,-42),Vector2(42,-42),Vector2(48,-15),Vector2(-48,-15)]),Color("6c5140"))
			for x in [-34,34]:canvas.draw_line(Vector2(x,-15),Vector2(x,5),Color("504336"),7)
			canvas.draw_rect(Rect2(-24,-39,28,19),Color("99b3b3"))
			for y in [-34,-28]:canvas.draw_line(Vector2(-20,y),Vector2(0,y),Color("4a6d75"),2)
			canvas.draw_circle(Vector2(26,-30),10,Color("d5ab62"))
			canvas.draw_line(Vector2(14,-24),Vector2(39,-24),Color("b7884d"),3)
			if tier>=2:
				canvas.draw_circle(Vector2(-14,-57),9,Color("b79974"))
				canvas.draw_circle(Vector2(-14,-58),5,Color("e5d2a8"))
				for x in [-39,39]:canvas.draw_rect(Rect2(x-4,-63,8,16),Color("bed5d0"))
