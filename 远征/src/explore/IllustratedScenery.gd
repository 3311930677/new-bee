extends RefCounted
## Authored independent sprites: feet, draw order, and solid footprints agree.
const KitV4 := preload("res://src/ui/KitV4.gd")

static func _regional_override(map_id: String, path: String, idx: int) -> Texture2D:
	if map_id in ["abyss_ring", "stele_entry", "stele_resonance", "stele_core"]:
		if path.ends_with("stele_mid_a.png"):
			return KitV4.commercial_tex("f06a_abyss_pillar_1")
		if path.ends_with("stele_mid_b.png"):
			return KitV4.commercial_tex("f06a_abyss_pillar_2")
	elif map_id in ["rift_mine_road", "rift_mine_vault"]:
		if path.ends_with("boulder_a.png"):
			return KitV4.commercial_tex("f05b_ore_crystal_1")
		if path.ends_with("boulder_b.png"):
			return KitV4.commercial_tex("f05a_mine_timber")
		if path.ends_with("rock_m_0.png"):
			return KitV4.commercial_tex("f05b_ore_crystal_2" if idx % 2 == 1 else "f05b_ore_crystal_1")
	elif map_id == "stele_cavern":
		if path.ends_with("stele_mid_a.png"):
			return KitV4.commercial_tex("f02a_broken_stele_2" if idx % 2 == 1 else "f02a_broken_stele_1")
	elif map_id == "old_salt_road":
		if path.ends_with("044_deco_desert_cactus.png"):
			return KitV4.commercial_tex("f03a_salt_crystal_1")
		if path.ends_with("045_deco_desert_sandstone.png"):
			return KitV4.commercial_tex("f03a_salt_crystal_2" if idx % 2 == 1 else "f03a_salt_crystal_1")
	elif map_id == "red_sand_route":
		if path.ends_with("044_deco_desert_cactus.png"):
			return KitV4.commercial_tex("f04b_dry_shrub_1" if idx % 2 == 0 else "f04b_dry_shrub_2")
		if path.ends_with("045_deco_desert_sandstone.png"):
			return KitV4.commercial_tex("f04a_sandstone_2" if idx % 2 == 1 else "f04a_sandstone_1")
	return null

static func setup(map: Node) -> void:
	var cfg: Dictionary = map.get("_main_cfg")
	var map_id := String(map.get("_main_map_id"))
	var world: Node2D = map.get("_world")
	var idx := 0
	for row: Dictionary in cfg.get("illustrated_scenery", []):
		var path := String(row.get("texture", ""))
		var art: Texture2D = _regional_override(map_id, path, idx)
		if art == null:
			art = G.visual_texture(path)
		idx += 1
		if art == null:
			push_error("Illustrated scenery missing: " + path)
			continue
		var prop := Prop.new()
		prop.name = "Illustrated_" + String(row.get("id", "prop"))
		prop.texture_filter = preload("res://src/world/WorldPresentation.gd").sampling()
		prop.position = Vector2(float(row.at[0]), float(row.at[1]))
		prop.display_size = Vector2(float(row.size[0]),float(row.size[1]))*preload("res://src/world/WorldPresentation.gd").SCENERY_ENLARGEMENT
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
