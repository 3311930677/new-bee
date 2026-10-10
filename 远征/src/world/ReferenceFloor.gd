extends Node2D
## Two 2x-density halves stay below common mobile texture-size limits.
var routes:Array=[]
var extent:=Vector2.ZERO
var top:Texture2D
var bottom:Texture2D
func setup(id:String,cfg:Dictionary)->void:
	routes=cfg.get("flat_routes",[])
	extent=Vector2(float(cfg.map_cols)*48,float(cfg.map_rows)*48)
	top=ReferenceWorldArt.texture(id+"_floor_top")
	bottom=ReferenceWorldArt.texture(id+"_floor_bottom")
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;z_index=-20
func _draw()->void:
	var half:=Vector2(extent.x,extent.y*.5)
	draw_texture_rect(top,Rect2(Vector2.ZERO,half),false)
	draw_texture_rect(bottom,Rect2(Vector2(0,half.y),half),false)
