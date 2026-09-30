## Reproducible packing for the imagegen roadside stall source. Run with Godot --headless --script.
extends SceneTree

const SOURCE := "res://image/first_act/source/trade_stall_generated.png"
const OUTPUT := "res://image/generated_201_333/ready/maps/trade_stall.png"


func _init() -> void:
	var source := Image.new()
	if source.load(SOURCE) != OK:
		push_error("TRADE_STALL_SOURCE_MISSING")
		quit(1)
		return
	var bounds := source.get_used_rect()
	if bounds.size.x < 1 or bounds.size.y < 1:
		push_error("TRADE_STALL_EMPTY")
		quit(1)
		return
	var content := source.get_region(bounds)
	var factor := minf(108.0 / float(content.get_width()), 90.0 / float(content.get_height()))
	var w := maxi(1, roundi(content.get_width() * factor))
	var h := maxi(1, roundi(content.get_height() * factor))
	content.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var output := Image.create_empty(112, 96, false, Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	output.blit_rect(content, Rect2i(Vector2i.ZERO, Vector2i(w, h)),
		Vector2i((112 - w) / 2, 96 - h - 2))
	if output.save_png(OUTPUT) != OK:
		push_error("TRADE_STALL_PACK_FAILED")
		quit(1)
		return
	print("TRADE_STALL_PACKED 112x96")
	quit(0)
