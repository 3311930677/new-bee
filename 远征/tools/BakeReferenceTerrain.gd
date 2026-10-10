extends Node
const ROOT:="res://assets/world/reference_complete_20261011/"
func _ready()->void:
	G.SAVE_PATH="res://shots/reference_complete_20261011/terrain_save.json"
	G.save_locked=true
	var plan:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"layout.json"))
	var sheet:=Image.load_from_file(ROOT+"source/ground_materials.png")
	var half:=Vector2i(sheet.get_width()/2,sheet.get_height()/2)
	var names:=["grass","shade","soil","water"]
	for i in 4:
		var crop:=sheet.get_region(Rect2i(Vector2i(i%2,i/2)*half,half))
		crop.save_png(ROOT+"ready/material_"+names[i]+".png")
	# Road masks are authored once, not rebuilt while the player walks.
	for id in plan.regions:
		var region:Dictionary=plan.regions[id]
		var w:=int(region.extent[0]);var h:=int(region.extent[1])
		var routes:Array=region.routes
		var distances:=SunnyTravelArt._road_field(Vector2(w,h),routes,w,h)
		var edge:=FastNoiseLite.new()
		edge.seed=411
		edge.frequency=.035
		var shade:=FastNoiseLite.new()
		shade.seed=713
		shade.frequency=.008
		var mask:=Image.create(w,h,false,Image.FORMAT_RGBA8)
		var river:Dictionary=region.river
		for y in h:
			for x in w:
				var d:=distances[y*w+x]-edge.get_noise_2d(x,y)*13.0
				var tail:=0.0
				if id=="lorin_wilds" and y>1740:
					tail=smoothstep(1740,2000,float(y))
					var center:=600.0+70.0*tail
					d=absf(float(x)-center)-68.0*(1.0-.9*tail)-edge.get_noise_2d(x,y)*13
				var road:=clampf((4.0-d)/8.0,0,1)*(1.0-tail)
				var water:=0.0
				if not river.is_empty():
					var points:Array=river.points
					var ry:=lerpf(float(points[0][1]),float(points[-1][1]),float(x)/maxf(1,w))
					var bank:=absf(float(y)-ry)-float(river.half)-edge.get_noise_2d(x,y)*2.0
					water=clampf((2.0-bank)/4.0,0,1)
				var tone:=clampf(.5+shade.get_noise_2d(x,y)*.25,0,1)
				mask.set_pixel(x,y,Color(road,water,tone,1))
		mask.save_png(ROOT+"ready/"+id+"_mask.png")
	print("REFERENCE_MASKS_OK")
	get_tree().quit()
