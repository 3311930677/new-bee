extends SceneTree
func _initialize()->void:
	var base:=ProjectSettings.globalize_path("res://screenshots/")
	var before:=Image.load_from_file(base+"town_south_before.png")
	var after:=Image.load_from_file(base+"town_south_end.png")
	before.convert(Image.FORMAT_RGBA8)
	after.convert(Image.FORMAT_RGBA8)
	var board:=Image.create(960,800,false,Image.FORMAT_RGBA8)
	board.blit_rect(before,Rect2i(0,0,480,800),Vector2i.ZERO)
	board.blit_rect(after,Rect2i(0,0,480,800),Vector2i(480,0))
	assert(board.save_png(base+"town_south_comparison.png")==OK)
	print("SOUTH_GROUND_COMPARISON_OK: before left, after right")
	quit()

