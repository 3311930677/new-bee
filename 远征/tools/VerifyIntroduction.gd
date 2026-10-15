extends Node
const OUT := "res://shots/introduction_20261015/"
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("INTRO_FAIL: " + message)

func settle() -> void:
	for i in 5: await get_tree().process_frame

func click(button: Control) -> void:
	var point := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame
	await settle()

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	G.SAVE_PATH = OUT + "isolated_save.json"
	G.set_meta("ui_review_mode", true)
	for height in [800, 1067]:
		get_window().size = Vector2i(480, height)
		await settle()
		var page := preload("res://src/ui/IntroductionPanel.gd").new()
		var closed := [0]
		page.closed.connect(func(): closed[0] += 1)
		add_child(page)
		await settle()
		var view := page.get_child(0)
		check(view._previous.disabled, "首章上一章禁用")
		await click(view._previous)
		check(page._deck.current == 0, "首章不循环到末章")
		for index in 3:
			await click(view._tabs.get_child(index))
			check(page._deck.current == index, "页签真实点击切页")
			check(view._counter.text == "%d / 3" % (index + 1), "页码与内容同步")
			check(view._description.get_line_count() >= 2, "正文保留完整内容")
			check(view._body.size.y <= view._scroll.size.y, "正文无需滚动即可完整阅读")
			check(view._scroll.get_global_rect().end.y < view._footer.get_global_rect().position.y, "正文不压翻页区")
			if index == 1: check(view._annotations.get_child_count() == 4, "四位旅人均有实时姓名职业")
			if index == 2: check(page._route_preview.progress == 1.0, "地图路线完整显示")
			await RenderingServer.frame_post_draw
			check(get_viewport().get_texture().get_image().save_png(OUT + ["world", "travelers", "route"][index] + "_%d.png" % height) == OK, "界面截图")
		check(view._next.disabled, "末章下一章禁用")
		await click(view._next)
		check(page._deck.current == 2, "末章不循环到首章")
		await click(view._previous)
		check(page._deck.current == 1, "上一章真实点击")
		await click(view._next)
		check(page._deck.current == 2, "下一章真实点击")
		get_viewport().gui_release_focus()
		var key := InputEventAction.new()
		key.action = "ui_left"
		key.pressed = true
		get_viewport().push_input(key, true)
		await settle()
		check(page._deck.current == 1, "键盘方向键切页")
		key = InputEventAction.new()
		key.action = "ui_cancel"
		key.pressed = true
		get_viewport().push_input(key, true)
		await settle()
		check(closed[0] == 1, "返回键发出关闭信号")
		var safe := Rect2(8, 44, 464, height - 78)
		view.layout(safe)
		await settle()
		check(safe.encloses(view._back.get_global_rect()), "返回位于安全区")
		check(safe.encloses(view._footer.get_global_rect()), "翻页位于安全区")
		check(safe.encloses(view._scroll.get_global_rect()), "正文位于安全区")
		await click(view._back)
		check(closed[0] == 2, "返回按钮发出关闭信号")
		page.queue_free()
		await settle()
	print("INTRODUCTION_CHECKS ", checks, " FAILURES ", failures)
	get_tree().quit(1 if failures else 0)
