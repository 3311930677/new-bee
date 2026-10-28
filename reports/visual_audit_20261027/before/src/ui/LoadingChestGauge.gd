extends Control
const UI:=preload("res://src/ui/TravelChestUI.gd")
var lit_blade:ColorRect
var _track:ColorRect
var ratio:=0.0
var _lantern:TextureRect
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	_track=ColorRect.new()
	_track.color=UI.BRONZE
	_track.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_track)
	lit_blade=ColorRect.new()
	lit_blade.color=UI.GOLD
	lit_blade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(lit_blade)
	_lantern=TextureRect.new();_lantern.texture=ReferenceWorldArt.texture("lantern")
	_lantern.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_lantern.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_lantern.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;_lantern.size=Vector2(24,30)
	_lantern.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_lantern)
	resized.connect(_layout)
	_layout()
func _layout() -> void:
	_track.position=Vector2(0,size.y-6)
	_track.size=Vector2(size.x,6)
	lit_blade.position=Vector2(1,size.y-5)
	lit_blade.size=Vector2(maxf(0,size.x-2)*ratio,4)
	if _lantern!=null:_lantern.position=Vector2(clampf(lit_blade.size.x-12,0,maxf(0,size.x-24)),size.y-38)
func set_ratio(value:float) -> void:ratio=clampf(value,0,1);_layout()
func fill_width() -> float:return lit_blade.size.x
