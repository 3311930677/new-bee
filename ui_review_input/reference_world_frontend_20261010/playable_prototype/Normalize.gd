extends SceneTree
const ROOT := "D:/new-bee/远征/assets/world/reference_playable_20261010/"
var manifest:Dictionary={}
func _initialize()->void:
	for id in ["meadow","plaza"]:
		var im:=Image.load_from_file(ROOT+"source/"+id+".png")
		var native:=im.get_size()
		assert(native==Vector2i(1024,1536))
		im.resize(512,768,Image.INTERPOLATE_NEAREST)
		assert(im.save_png(ROOT+"ready/"+id+".png")==OK)
		manifest[id]={"native":[native.x,native.y],"ready":[512,768],"logical_extent":[512,768],"scale":0.5,"alpha":false}
	var sheet:=Image.load_from_file(ROOT+"source/props.png")
	var specs:=[
		["tree",Rect2i(0,0,720,850),192],
		["bush",Rect2i(720,0,534,850),48],
		["rock",Rect2i(0,850,627,404),44],
		["log",Rect2i(627,850,627,404),48]]
	for spec in specs:
		var im:=sheet.get_region(spec[1])
		key_magenta(im)
		var trim:=im.get_used_rect()
		im=im.get_region(trim)
		var native:=im.get_size()
		var height:=int(spec[2])
		var width:=roundi(float(native.x)*float(height)/float(native.y))
		im.resize(width,height,Image.INTERPOLATE_NEAREST)
		assert(im.save_png(ROOT+"ready/"+spec[0]+".png")==OK)
		manifest[spec[0]]={"native_sheet":[sheet.get_width(),sheet.get_height()],"extraction_rect":[spec[1].position.x,spec[1].position.y,spec[1].size.x,spec[1].size.y],"trim":[trim.position.x,trim.position.y,trim.size.x,trim.size.y],"ready":[width,height],"anchor":[width*.5,height],"alpha":true}
	var hall:=Image.load_from_file(ROOT+"source/hall.png")
	var hall_native:=hall.get_size()
	key_magenta(hall)
	var hall_trim:=hall.get_used_rect()
	hall=hall.get_region(hall_trim)
	# Door measured on the corrected source: approximately 292 source pixels.
	var hall_width:=420
	var hall_height:=roundi(float(hall.get_height())*hall_width/float(hall.get_width()))
	var door_height:=292.0*hall_width/float(hall.get_width())
	hall.resize(hall_width,hall_height,Image.INTERPOLATE_NEAREST)
	assert(hall.save_png(ROOT+"ready/hall.png")==OK)
	manifest.hall={"native":[hall_native.x,hall_native.y],"trim":[hall_trim.position.x,hall_trim.position.y,hall_trim.size.x,hall_trim.size.y],"ready":[hall_width,hall_height],"anchor":[hall_width*.5,hall_height],"door_height_approx":door_height,"nominal_blueprint_width":320,"status":"prototype enlarged uniformly for doorway scale; full-town spacing not yet checked","alpha":true}
	var sign:=Image.load_from_file("D:/new-bee/远征/assets/world/sunny_travel_20261010/ready/signpost.png")
	var sign_native:=sign.get_size()
	sign.resize(61,64,Image.INTERPOLATE_NEAREST)
	assert(sign.save_png(ROOT+"ready/signpost.png")==OK)
	manifest.signpost={"native":[sign_native.x,sign_native.y],"ready":[61,64],"anchor":[30.5,64],"alpha":true,"source":"existing sunny_travel signpost; reused, not newly generated"}
	var errors:=0
	for id in manifest:
		var im:=Image.load_from_file(ROOT+"ready/"+id+".png")
		var magenta:=0
		if bool(manifest[id].alpha):
			for y in im.get_height():
				for x in im.get_width():
					var c:=im.get_pixel(x,y)
					if c.a>0 and is_magenta(c):magenta+=1
			if magenta>0:errors+=1
		manifest[id]["magenta_residual_pixels"]=magenta
	var output:=FileAccess.open(ROOT+"ready/manifest.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(manifest,"  "))
	print("ASSET_NORMALIZE_OK items=",manifest.size()," magenta_failures=",errors)
	quit(errors)
func is_magenta(c:Color)->bool:
	return c.r>.15 and c.b>.15 and c.r>c.g*1.4 and c.b>c.g*1.4
func key_magenta(im:Image)->void:
	im.convert(Image.FORMAT_RGBA8)
	for y in im.get_height():
		for x in im.get_width():
			if is_magenta(im.get_pixel(x,y)):
				im.set_pixel(x,y,Color.TRANSPARENT)

