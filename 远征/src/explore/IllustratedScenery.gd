extends RefCounted
## Authored independent sprites: feet, draw order, and solid footprints agree.
static func setup(map: Node) -> void:
	var cfg: Dictionary = map.get("_main_cfg")
	var world: Node2D = map.get("_world")
	for row: Dictionary in cfg.get("illustrated_scenery", []):
		var path := String(row.get("texture", ""))
		var art: Texture2D = G.visual_texture(path)
		if art == null:
			push_error("Illustrated scenery missing: " + path)
			continue
		var prop := Prop.new()
		prop.name = "Illustrated_" + String(row.get("id", "prop"))
		prop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		prop.position = Vector2(float(row.at[0]), float(row.at[1]))
		prop.display_size = Vector2(float(row.size[0]),float(row.size[1]))
		prop.art = art
		prop.canopy = bool(row.get("canopy",false))
		world.add_child(prop)
		if row.has("footprint"):
			var footprint := Vector2(float(row.footprint[0]),float(row.footprint[1]))
			var body := StaticBody2D.new()
			body.collision_layer = 2
			body.collision_mask = 0
			var collider := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = footprint
			collider.shape = shape
			collider.position = Vector2(0,-footprint.y*0.5)
			body.add_child(collider)
			prop.add_child(body)

class Prop extends Node2D:
	var art: Texture2D
	var display_size := Vector2(64,64)
	var canopy := false
	var opacity := 1.0
	func _process(delta: float) -> void:
		if not canopy: return
		var hero := get_tree().get_first_node_in_group("reference_hero") as Node2D
		var rect := Rect2(global_position-Vector2(display_size.x*0.5,display_size.y),display_size)
		var behind := hero != null and rect.grow(-8).has_point(hero.global_position)
		var target := 0.4 if behind else 1.0
		var next := move_toward(opacity,target,delta*3.0)
		if not is_equal_approx(next,opacity):
			opacity = next
			queue_redraw()
	func _draw() -> void:
		draw_texture_rect(art,Rect2(Vector2(-display_size.x*0.5,-display_size.y),display_size),false,Color(1,1,1,opacity))
