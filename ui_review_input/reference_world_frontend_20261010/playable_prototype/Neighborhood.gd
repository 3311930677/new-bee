extends RefCounted
static func build(scene,layout:Dictionary)->Array:
	var records:Array=[]
	var floor:=GroundGuide.new()
	floor.layout=layout
	floor.z_index=-10
	scene.world.add_child(floor)
	for b:Dictionary in layout.buildings:
		var at:=Vector2(float(b.anchor[0]),float(b.anchor[1]))
		var size:=Vector2(float(b.size[0]),float(b.size[1]))
		var body:Node2D
		if bool(b.get("passable",false)):
			body=Node2D.new()
			body.position=at
			scene.world.add_child(body)
			var portal:=float(b.get("portal_width",160))
			var wing_width:=(size.x-portal)*.5
			for side in [-1,1]:
				scene.static_rectangle(at+Vector2(side*(size.x+portal)*.25,0),Vector2(wing_width,40),Vector2(0,-28))
		else:
			body=scene.static_rectangle(at,Vector2(size.x*.9,40),Vector2(0,-28))
		if b.id=="hall":
			scene.hall=body
			var art:=Sprite2D.new()
			art.texture=scene.texture(scene.asset_root+"hall.png")
			art.position=Vector2(0,-size.y*.5)
			body.add_child(art)
		else:
			var proxy:=HouseProxy.new()
			proxy.data=b
			body.add_child(proxy)
		var nameplate:=Label.new()
		var font:=SystemFont.new()
		font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
		nameplate.add_theme_font_override("font",font)
		nameplate.add_theme_font_size_override("font_size",16)
		nameplate.add_theme_color_override("font_color",Color("f6eed8"))
		nameplate.add_theme_color_override("font_outline_color",Color("352b22"))
		nameplate.add_theme_constant_override("outline_size",4)
		nameplate.text=String(b.name)+(" · 新素材" if b.id=="hall" else " · 尺寸占位")
		nameplate.position=Vector2(-size.x*.5,12)
		nameplate.size=Vector2(size.x,30)
		nameplate.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(nameplate)
		records.append({"data":b,"node":body,"plate":nameplate})
	for p in layout.trees:
		scene.add_tree(Vector2(float(p[0]),float(p[1])))
	for item:Dictionary in layout.reserved_interactions:
		var at:=Vector2(item.position[0],item.position[1])
		var node:Node2D
		if item.kind=="npc":
			var physical:=StaticBody2D.new()
			physical.position=at
			scene.world.add_child(physical)
			var shape:=CollisionShape2D.new()
			var circle:=CircleShape2D.new()
			circle.radius=12
			shape.shape=circle
			physical.add_child(shape)
			scene.obstacles.append({"position":at,"radius":12.0,"type":"circle"})
			node=physical
		else:
			node=Node2D.new()
			node.position=at
			scene.world.add_child(node)
		var visual:=InteractionProxy.new()
		visual.kind=String(item.kind)
		node.add_child(visual)
		var plate:=Label.new()
		var font:=SystemFont.new()
		font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
		plate.add_theme_font_override("font",font)
		plate.add_theme_font_size_override("font_size",16)
		plate.add_theme_color_override("font_color",Color("fff1d0"))
		plate.add_theme_color_override("font_outline_color",Color("352b22"))
		plate.add_theme_constant_override("outline_size",4)
		plate.text=String(item.name)
		plate.position=Vector2(-80,-68)
		plate.size=Vector2(160,28)
		plate.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		plate.visible=false
		node.add_child(plate)
		scene.interactables.append({"data":item,"node":node,"plate":plate})
	add_exit(scene,layout.exit,true)
	return records
static func add_exit(scene,data:Dictionary,north:bool)->void:
	var marker:=ExitProxy.new()
	marker.north=north
	marker.z_index=3
	marker.position=Vector2(data.at[0],data.at[1])
	marker.art=scene.texture(scene.asset_root+"signpost.png")
	var sign_at:Array=data.get("sign_at",data.at)
	marker.sign_offset=Vector2(sign_at[0],sign_at[1])-marker.position
	scene.world.add_child(marker)
	var plate:=Label.new()
	var font:=SystemFont.new()
	font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	plate.add_theme_font_override("font",font)
	plate.add_theme_color_override("font_color",Color("fff1d0"))
	plate.add_theme_color_override("font_outline_color",Color("352b22"))
	plate.add_theme_constant_override("outline_size",4)
	plate.text=String(data.label)
	plate.position=marker.sign_offset+Vector2(-130,-96)
	plate.size=Vector2(260,30)
	plate.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	marker.add_child(plate)
	scene.exit_marker=marker
	scene.exit_plate=plate

class GroundGuide extends Node2D:
	var layout:Dictionary
	var geometry_only:=false
	var painted_ground:Texture2D
	func _ready()->void:
		if not geometry_only:
			var path:=ProjectSettings.globalize_path("res://../../../远征/assets/world/reference_playable_20261010/ready/town_ground_natural.png")
			if FileAccess.file_exists(path):
				var im:=Image.load_from_file(path)
				if im.get_size()==Vector2i(layout.world_size[0],layout.world_size[1]):
					painted_ground=ImageTexture.create_from_image(im)
		queue_redraw()
	func _draw()->void:
		var extent:=Vector2(layout.world_size[0],layout.world_size[1])
		if painted_ground!=null:
			draw_texture_rect(painted_ground,Rect2(Vector2.ZERO,extent),false)
			return
		draw_rect(Rect2(Vector2.ZERO,extent),Color("9fb965"))
		# Spatial guide only: not approved ground art.
		for r:Dictionary in layout.routes:
			var points:=PackedVector2Array()
			for p in r.points:points.append(Vector2(float(p[0]),float(p[1])))
			if r.kind=="main":
				points[0].y=-64
				points[-1].x+=float(layout.south_ground.tail_offset_x)
				points[-1].y=minf(extent.y-70,float(layout.south_ground.fade_end)+40)
			var smooth:=PackedVector2Array()
			for i in points.size()-1:
				var a:=points[maxi(i-1,0)]
				var b:=points[i]
				var c:=points[i+1]
				var d:=points[mini(i+2,points.size()-1)]
				for step in 16:
					var t:=float(step)/16.0
					smooth.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
			smooth.append(points[-1])
			for i in smooth.size()-1:
				var a:=smooth[i]
				var b:=smooth[i+1]
				var fade_a:=smoothstep(float(layout.south_ground.fade_start),float(layout.south_ground.fade_end),a.y) if r.kind=="main" else 0.0
				var fade_b:=smoothstep(float(layout.south_ground.fade_start),float(layout.south_ground.fade_end),b.y) if r.kind=="main" else 0.0
				var normal:=(b-a).normalized().orthogonal()
				var wa:=float(r.width)*.5*(1.0-.93*fade_a)
				var wb:=float(r.width)*.5*(1.0-.93*fade_b)
				var alpha:=1.0-(fade_a+fade_b)*.5
				draw_colored_polygon(PackedVector2Array([a+normal*wa,b+normal*wb,b-normal*wb,a-normal*wa]),Color(Color("dcc58b"),alpha))
				if fade_a<.001:draw_circle(a,wa,Color("dcc58b"))
		# Extent guide is intentionally not a physical wall or a final painted background.
		draw_rect(Rect2(Vector2(2,2),extent-Vector2(4,4)),Color("839b52"),false,2)

class InteractionProxy extends Node2D:
	var kind:="npc"
	func _draw()->void:
		if kind=="npc":
			draw_circle(Vector2(0,-38),7,Color("e0c6a0"))
			draw_rect(Rect2(-9,-30,18,28),Color("527b78"))
			draw_line(Vector2(-5,-2),Vector2(-5,3),Color("514434"),3)
			draw_line(Vector2(5,-2),Vector2(5,3),Color("514434"),3)
		else:
			draw_rect(Rect2(-14,-20,28,20),Color("997654"))
			draw_rect(Rect2(-10,-17,20,11),Color("e5d8ac"))
class ExitProxy extends Node2D:
	var north:=true
	var art:Texture2D
	var sign_offset:=Vector2.ZERO
	func _draw()->void:
		if art!=null:draw_texture(art,sign_offset-Vector2(art.get_width()*.5,art.get_height()))
class HouseProxy extends Node2D:
	var data:Dictionary
	func _draw()->void:
		var w:=float(data.size[0])
		var h:=float(data.size[1])
		var top:=-h
		var eave_y:=top+h*.48
		var roof_color:=Color("64736b")
		var wall_color:=Color("bfac85")
		if data.id=="forge":roof_color=Color("73675e")
		if data.id=="archive":roof_color=Color("5d6e78")
		if data.id=="shrine":roof_color=Color("827a67")
		draw_rect(Rect2(-w*.5,top,w,h),Color("4d5b43"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-w*.5,eave_y),Vector2(-w*.40,top),Vector2(w*.40,top),Vector2(w*.5,eave_y)]),roof_color)
		draw_rect(Rect2(-w*.40,eave_y,w*.80,h*.44),wall_color)
		if data.id=="gate":
			var portal:=float(data.get("portal_width",160))
			draw_rect(Rect2(-portal*.5,-120,portal,120),Color("dcc58b"))
		elif data.id=="shrine":
			draw_rect(Rect2(-w*.46,-50,w*.92,42),Color("c2b99a"))
		else:
			var door_h:=minf(88,h*.48)
			draw_rect(Rect2(-28,-8-door_h,56,door_h),Color("604f3b"))
			draw_rect(Rect2(-28,-8-door_h,56,door_h),Color("d4c19a"),false,2)
		draw_rect(Rect2(-w*.43,-8,w*.86,8),Color("d1c3a0"))
		draw_rect(Rect2(-w*.5,top,w,h),Color("e3d7b5"),false,2)

