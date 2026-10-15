extends Node
## 正式版主城首页验收：godot --path . res://tools/VerifyTownHome.tscn
## 实例化 GameHome（挂 TownHome 视图），逐个真实点击入口，确认打开 GameHome 原有面板、关闭后首页恢复；
## 输出 shots/town_home_20261013/official_<高度>.png。使用隔离存档，不碰玩家存档。
const OUT := "res://shots/town_home_20261013/"

var page: Control
var view: Control
var checks := 0
var failures := 0


func check(ok: bool, words: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TOWN_FAIL: " + words)


func click(control: Control) -> void:
	var pos := control.get_global_rect().get_center()
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = pos
		ev.global_position = pos
		ev.pressed = down
		ev.button_index = MOUSE_BUTTON_LEFT
		get_viewport().push_input(ev, true)
		await get_tree().process_frame


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	G.SAVE_PATH = OUT + "isolated_save.json"
	G.set_meta("ui_review_mode", true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for height in [800, 1067]:
		get_window().size = Vector2i(480, height)
		await frames(2)
		G._init_state_defaults()
		G.save_locked = false
		G.selected_role = "zs"
		G.player_name = "沈舟"
		G.prog.level = 32
		G.prog.exp = int(G.exp_to_next(32) * 0.62)
		G.wallet = {"gold": 125480, "expedition": 120, "soul": 3860, "honor": 900}
		page = load("res://src/ui/GameHome.tscn").instantiate()
		add_child(page)
		await frames(3)
		view = page._chest_view
		check(view.name == "TownHome", "GameHome 挂载的是主城首页视图")
		check(page._anim != null and page._anim.is_playing(), "主角待机动画在播")
		check(page._wallet_labels.size() == 4, "顶栏四币")
		for e in page._wallet_labels:
			check(e.label.text == UI_fmt(int(G.wallet[e.key])), "货币数字来自钱包 " + e.key)
		var safe := page.get_viewport_rect()
		for c in _hot_controls():
			check(safe.encloses(c.get_global_rect()), "入口在屏内 " + c.name)
			check(c.size.x >= 44 and c.size.y >= 44, "热区不小于 44 " + c.name)
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT + "official_%d.png" % height)

		# 每个入口：点击 -> 对应面板出现 -> 关闭 -> 首页内容恢复
		var cases := [
			["Plaque_gacha", "_gacha"], ["Plaque_arena", "_arena"], ["Plaque_craft", "_growth"],
			["Plaque_exchange", "_exchange"], ["Plaque_world", "_worlds"],
			["AvatarEntry", "_avatar_panel"], ["Rail_bag", "_bag"], ["QuestSummary", "_quests"],
			["Navigation_养成", "_growth"], ["Navigation_伙伴", "_codex"],
			["Navigation_活动", "_activities"], ["Navigation_设置", "_settings"],
		]
		for cs in cases:
			var node := view.find_child(cs[0], true, false) as Control
			check(node != null, "找到入口 " + cs[0])
			if node == null:
				continue
			await click(node)
			await frames(3)
			var panel: Control = page.get(cs[1])
			check(panel != null, "%s 打开 %s" % [cs[0], cs[1]])
			check(not view.content.visible, "%s 打开后首页内容隐藏" % cs[0])
			if panel != null:
				if cs[1] == "_activities":
					panel.go_back()
				else:
					panel.closed.emit()
			await frames(3)
			check(page.get(cs[1]) == null, "%s 关闭" % cs[1])
			check(view.content.visible, "%s 关闭后首页恢复" % cs[1])
		# 铁匠铺直达装备页
		await click(view.find_child("Plaque_craft", true, false))
		await frames(3)
		check(page._growth != null and page._growth._sub != null, "铁匠铺直达养成·装备")
		await RenderingServer.frame_post_draw
		if height == 800:
			get_viewport().get_texture().get_image().save_png(OUT + "official_craft.png")
		if page._growth != null:
			page._growth.closed.emit()
		await frames(3)
		# 货币说明弹窗
		await click(page._wallet_labels[0].button)
		await frames(2)
		check(page._chest_dialog != null, "点货币打开行囊与货币")
		page._close_chest_dialog()
		await frames(2)
		# 小聚未解锁时不绕过剧情
		await click(view.find_child("Rail_gathering", true, false))
		await frames(2)
		check(page._gathering == null, "未解锁小聚不打开")
		await get_tree().create_timer(1.6).timeout
		# ESC：首页打开设置，再按关闭
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.pressed = true
		page._unhandled_input(esc)
		check(page._settings != null, "首页 ESC 打开设置")
		page._unhandled_input(esc)
		await frames(2)
		check(page._settings == null, "再按 ESC 关闭设置")
		# 刷新：改数据后关闭面板，顶栏跟着变
		G.wallet["gold"] = 7
		page._open_bag()
		page._bag.closed.emit()
		await frames(2)
		check(page._wallet_labels[0].label.text == "7", "关闭面板后货币刷新")
		page.queue_free()
		await frames(3)
	print("TOWN_HOME_VERIFY_OK checks=%d" % checks if failures == 0 else "TOWN_HOME_VERIFY_FAIL failures=%d checks=%d" % [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)


func UI_fmt(n: int) -> String:
	return preload("res://src/ui/TravelChestUI.gd").format_number(n)


func _hot_controls() -> Array[Control]:
	var out: Array[Control] = []
	for n in ["AvatarEntry", "QuestSummary", "ReturnToWorld", "Rail_bag", "Rail_gathering",
			"Navigation_养成", "Navigation_伙伴", "Navigation_活动", "Navigation_设置",
			"Plaque_gacha", "Plaque_arena", "Plaque_craft", "Plaque_exchange", "Plaque_world"]:
		var c := view.find_child(n, true, false) as Control
		check(c != null, "存在 " + n)
		if c != null:
			out.append(c)
	for e in page._wallet_labels:
		out.append(e.button)
	return out
