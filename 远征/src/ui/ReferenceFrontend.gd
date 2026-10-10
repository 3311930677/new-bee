extends RefCounted
const ROOT:="res://assets/world/reference_complete_20261011/source/"
static func backdrop(parent:Control,id:String)->TextureRect:
	G.register_ui_page(parent)
	var image:=TextureRect.new();image.name="ReferenceFrontendBackground"
	image.texture=load(ROOT+"frontend_"+id+".png")
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_SCALE if id=="login_portrait" else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(image)
	return image
static func traveller(parent:Control)->AnimatedSprite2D:
	var hero:=AnimatedSprite2D.new();hero.name="ExistingTraveller"
	hero.sprite_frames=load("res://image/role/zs/pojun_walk_frames.tres")
	hero.animation=&"idle_up";hero.frame=0;hero.scale=Vector2.ONE*.65
	hero.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(hero)
	return hero
