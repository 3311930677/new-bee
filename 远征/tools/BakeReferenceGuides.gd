extends Node
const ROOT:="res://assets/world/reference_complete_20261011/"
var plan:Dictionary
func _ready()->void:
	G.SAVE_PATH="res://shots/reference_complete_20261011/guide_save.json"
	plan=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"layout.json"))
	var hero:=Image.load_from_file("res://image/role/zs/pojun_idle_video_v19.png")
	hero.get_region(Rect2i(0,0,128,128)).save_png(ROOT+"guides/hero_density_reference.png")
	for job:Dictionary in plan.ground_jobs:
		var viewport:=SubViewport.new()
		viewport.size=Vector2i(job.context[2],job.context[3])
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var guide:=Guide.new()
		guide.region=plan.regions[job.map]
		guide.position=-Vector2(job.context[0],job.context[1])
		viewport.add_child(guide)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(ROOT+"guides/"+job.id+".png")
		viewport.queue_free()
		await get_tree().process_frame
	print("COMPLETE_GUIDES_OK ",plan.ground_jobs.size())
	get_tree().quit()
class Guide extends Node2D:
	var region:Dictionary
	func _draw()->void:
		var extent:=Vector2(region.extent[0],region.extent[1])
		draw_rect(Rect2(-64,-64,extent.x+128,extent.y+128),Color("a6ba6b"))
		for route:Dictionary in region.routes:
			var points:=PackedVector2Array()
			for p in route.points:points.append(Vector2(p[0],p[1]))
			var smooth:=PackedVector2Array()
			for i in points.size()-1:
				var a:=points[maxi(i-1,0)];var b:=points[i];var c:=points[i+1];var d:=points[mini(i+2,points.size()-1)]
				for k in 20:
					var t:=k/20.0
					smooth.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
			smooth.append(points[-1])
			for i in smooth.size()-1:
				var a:=smooth[i];var b:=smooth[i+1]
				var fade:=0.0
				if not region.layout.is_empty() and route.kind=="main":fade=smoothstep(1740,2000,(a.y+b.y)*.5)
				var width:=float(route.width)*(1.0-.92*fade)
				var normal:=(b-a).normalized().orthogonal()*width*.5
				draw_colored_polygon(PackedVector2Array([a+normal,b+normal,b-normal,a-normal]),Color(Color("dcc58b"),1.0-fade))
				if fade<.001:draw_circle(a,width*.5,Color("dcc58b"))
		if not region.river.is_empty():
			var river:Dictionary=region.river
			var points:=PackedVector2Array()
			for p in river.points:points.append(Vector2(p[0],p[1]))
			draw_polyline(points,Color("75aeb0"),float(river.half)*2)
			var crossing:Array=river.crossing
			var x:float=(float(crossing[0])+float(crossing[1]))*.5
			var ry:float=points[0].y+(points[-1].y-points[0].y)*x/extent.x
			draw_rect(Rect2(crossing[0],ry-64,float(crossing[1])-float(crossing[0]),128),Color("bfa578"))
