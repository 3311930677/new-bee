# 在独立 SubViewport 中运行现有 ShotRunner，绕开桌面显示器窗口高度上限。
# 用法：godot --path . res://tools/OffscreenShotRunner.tscn -- \
#       --scene=main_world --size=720x1600 --out=<png>
extends SubViewport


func _enter_tree() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--size="):
			continue
		var parts := arg.trim_prefix("--size=").split("x")
		if parts.size() != 2:
			push_error("SHOT_SIZE_INVALID %s" % arg)
			get_tree().quit(1)
			return
		var w := int(parts[0])
		var h := int(parts[1])
		if w < 480 or h < 800 or w > 1440 or h > 3200:
			push_error("SHOT_SIZE_OUT_OF_RANGE %dx%d" % [w, h])
			get_tree().quit(1)
			return
		size = Vector2i(w, h)
		break
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST


func _ready() -> void:
	add_child((load("res://tools/ShotRunner.tscn") as PackedScene).instantiate())
