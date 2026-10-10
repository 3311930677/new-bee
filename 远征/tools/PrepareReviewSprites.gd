extends Node
## Native import rasterization into the required 64px showcase grid; originals stay intact.
const Fix:=preload("res://src/ui/ReviewFixUI.gd")
func _ready() -> void:
	G.SAVE_PATH="res://shots/full_review_fixes_20261009/sprite_import_save.json"
	var viewport:=SubViewport.new();viewport.size=Vector2i(64,64);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var picture:=TextureRect.new();picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;picture.size=Vector2(60,60);picture.position=Vector2(2,1);viewport.add_child(picture)
	var regions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Fix.ROOT+"regions.json"))
	var sources:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Fix.ROOT+"source_regions.json"))
	DirAccess.make_dir_recursive_absolute(Fix.ROOT+"pet_show")
	for pet in TableCache.pets():
		var id:=String(pet.id)
		var entry:Dictionary=sources[id]
		var source:=AtlasTexture.new();source.atlas=load(Fix.ROOT+String(entry.file))
		source.region=Rect2(entry.rect[0],entry.rect[1],entry.rect[2],entry.rect[3])
		picture.texture=source
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		var file:="pet_show/"+id+".png"
		var err:=viewport.get_texture().get_image().save_png(Fix.ROOT+file)
		if err!=OK:push_error("PET_IMPORT "+id);get_tree().quit(1);return
		regions[id]={"file":file,"source_size":[64,64],"rect":[0,0,64,64]}
	var out:=FileAccess.open(Fix.ROOT+"regions.json",FileAccess.WRITE);out.store_string(JSON.stringify(regions,"\t"))
	print("PET_IMPORT_OK 10 sprites 64x64");get_tree().quit()
