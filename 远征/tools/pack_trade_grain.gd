## Reproducible packing for the imagegen wheat-sack source. Run with Godot --headless --script.
extends SceneTree

const SOURCE := "res://image/first_act/source/itm_trade_grain_generated.png"
const OUTPUT := "res://image/generated_201_333/ready/icons/itm_trade_grain.png"


func _init() -> void:
	var source := Image.new()
	if source.load(SOURCE) != OK:
		push_error("TRADE_GRAIN_SOURCE_MISSING")
		quit(1)
		return
	var bounds := source.get_used_rect()
	if bounds.size.x < 1 or bounds.size.y < 1:
		push_error("TRADE_GRAIN_EMPTY")
		quit(1)
		return
	var content := source.get_region(bounds)
	var factor := minf(42.0 / float(content.get_width()), 44.0 / float(content.get_height()))
	var w := maxi(1, roundi(content.get_width() * factor))
	var h := maxi(1, roundi(content.get_height() * factor))
	content.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var output := Image.create_empty(48, 48, false, Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	output.blit_rect(content, Rect2i(Vector2i.ZERO, Vector2i(w, h)),
		Vector2i((48 - w) / 2, (48 - h) / 2))
	if output.save_png(OUTPUT) != OK:
		push_error("TRADE_GRAIN_PACK_FAILED")
		quit(1)
		return
	print("TRADE_GRAIN_PACKED 48x48")
	quit(0)
