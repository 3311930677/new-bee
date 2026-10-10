extends Node
const Art:=preload("res://src/world/SunnyTravelArt.gd")
func _ready() -> void:
	G.SAVE_PATH="res://shots/world_art_samples_20261010/bake_isolated_save.json"
	G.set_meta("sunny_baking",true)
	var manifest:Dictionary={}
	for id in ["lorin_wilds","maple_road"]:
		var cfg:=TableCache.main_world_map(id)
		var extent:=Vector2(cfg.map_cols*48,cfg.map_rows*48)
		var extras:=Art.extras_for(cfg)
		var art:=Art.ground(id,extent,cfg.flat_routes,extras).get_image()
		if art.save_png(Art.ROOT+id+"_floor.png")!=OK:push_error("SUNNY_BAKE_FAIL "+id);get_tree().quit(1);return
		manifest[id]={"route_hash":Art.route_hash(cfg.flat_routes,extras),"extent":[extent.x,extent.y],"source":"procedural_v2"}
	var file:=FileAccess.open(Art.ROOT+"ground_manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"\t"))
	print("SUNNY_BAKE_OK 2 procedural floors; routes, plazas and river signed")
	get_tree().quit()
