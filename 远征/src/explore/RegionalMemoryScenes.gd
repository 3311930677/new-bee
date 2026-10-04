extends RefCounted
const Art := preload("res://src/world/WorldPropArt.gd")

static func draw_scene(canvas: CanvasItem,region: String,tier: int) -> void:
	match region:
		"zhaoyuan":
			Art.supplementary(canvas,"road_ledger",78)
			if tier>=2:
				canvas.draw_set_transform(Vector2(48,0))
				Art.supplementary(canvas,"lantern",72)
				canvas.draw_set_transform(Vector2.ZERO)
		"shenyuan":
			Art.supplementary(canvas,"tide_board",78)
			if tier>=2:
				canvas.draw_set_transform(Vector2(44,0))
				Art.supplementary(canvas,"letter",25)
				canvas.draw_set_transform(Vector2.ZERO)
		"frost":
			Art.supplementary(canvas,"watch_table",66)
			if tier>=2:
				canvas.draw_set_transform(Vector2(-37,0))
				Art.supplementary(canvas,"lantern",52)
				canvas.draw_set_transform(Vector2.ZERO)
