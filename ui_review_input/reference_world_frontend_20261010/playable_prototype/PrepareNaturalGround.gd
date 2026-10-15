extends SceneTree
func _initialize()->void:
	const ROOT:="D:/new-bee/远征/assets/world/reference_playable_20261010/"
	var im:=Image.load_from_file(ROOT+"source/town_ground_natural_v1.png")
	var native:=im.get_size()
	var aspect_error:=absf((float(native.x)/native.y)/(1200.0/2112.0)-1.0)
	assert(aspect_error<.005,"Reject a candidate with incompatible aspect ratio instead of stretching it.")
	im.resize(1200,2112,Image.INTERPOLATE_NEAREST)
	assert(im.save_png(ROOT+"ready/town_ground_natural.png")==OK)
	var data:={"world_extent":[1200,2112],"source_native":[native.x,native.y],"runtime":[1200,2112],"requested":[1200,2112],"aspect_error":aspect_error,"tool":"built-in imagegen","status":"ground preview candidate, not a final pixel-grid-certified map","source":"../source/town_ground_natural_v1.png","contains_objects":false,"south_treatment":"tapered worn path fades into grass clearing, no bottom road stripe","technical_processing":"single native nearest-neighbor normalization; no color quantization or painted retouch"}
	FileAccess.open(ROOT+"ready/town_ground_natural_manifest.json",FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
	print("NATURAL_GROUND_READY native=",native," aspect_error=",aspect_error)
	quit()

