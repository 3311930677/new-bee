extends Node

var _fails := 0

func _check(ok: bool, detail: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + detail)

func _luma(c: Color) -> float:
	var linear := c.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b

func _button(node: Node, words: String) -> Control:
	if node is Label and node.text == words:
		return node.get_parent() as Control
	for child in node.get_children():
		var found := _button(child, words)
		if found != null: return found
	return null

func _has_words(node: Node, words: String) -> bool:
	if node is Label and node.text == words: return true
	for child in node.get_children():
		if _has_words(child, words): return true
	return false

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_visual_refresh.json"
	for height in [800, 1067]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(480, height)
		add_child(viewport)
		var page := Control.new()
		page.size = Vector2(480, height)
		viewport.add_child(page)
		G.page_background(page)
		var veil := G.veil(page, 0.78)
		await get_tree().process_frame
		_check(veil.size.is_equal_approx(Vector2(480, height)), "Veil must cover its own viewport at %d" % height)
		var background := page.get_node("PageBackground") as TextureRect
		_check(background.size.is_equal_approx(Vector2(480, height)), "Scenic background must cover %d" % height)
		var popup := G.show_info_popup(page, "长文阅读", ["协战技能：裂山、破阵、回风斩、战吼、断罪。", "训练需三次协战，重训消耗宠粮。", "对应技能必须真实生效；冷却十二秒，无负面时不消耗触发。"], page)
		await get_tree().process_frame
		await get_tree().process_frame
		_check(popup.get_viewport() == viewport, "Popup must render and receive input in its anchor viewport")
		var panel := popup.get_child(1) as Control
		_check(panel != null and panel.position.y >= 0 and panel.position.y + panel.size.y <= height, "Popup card must fit viewport")
		G.close_info_popup(popup)
		var paragraphs := ["强化等级不会因失败降低；失败扣本次金币与强化石。每次失败增加成功率，成功后清零。", "宝石共有三种颜色、五个等级；镶嵌、拆除与合成在宝石页操作。镶嵌成功才收取费用。", "精炼会重洗词条。用锁符保护中意的词条，已锁词条会在下一次精炼时保留。", "每种武器的强化独立保存；护甲和饰品全队共用。完成装配后，确认当前职业对应的武器槽位，再进行养成。"]
		var reading := G.show_info_popup(page, "装备规则", paragraphs, page)
		await get_tree().process_frame
		var deck := reading.find_child("ReadingPages", true, false) as Control
		_check(deck != null, "Long rules must use a paged reader")
		if deck != null:
			var next := _button(reading, "下一页")
			_check(next != null, "Paged reading needs a touchable next-page control")
			if next != null:
				var click := InputEventMouseButton.new()
				click.pressed = true
				click.button_index = MOUSE_BUTTON_LEFT
				next.gui_input.emit(click)
				_check(int(deck.get("current")) == 1, "Next page must show the remaining rules")
			for words in paragraphs:
				_check(_has_words(reading, words), "Reading pages must preserve every original paragraph")
		G.close_info_popup(reading)
		var growth := GrowthPanel.new()
		page.add_child(growth)
		growth._open("equip")
		await get_tree().process_frame
		await get_tree().process_frame
		var sub: Control = growth.get("_sub")
		_check(sub != null and absf(sub.global_position.y) < 1.0, "Nested full-screen page must not be centered twice")
		_check(not growth.get_child(0).visible, "Opening a growth subpage must hide its parent contents")
		growth.queue_free()
		page.queue_free()
		viewport.queue_free()
		await get_tree().process_frame
	for ink in [G.TEXT_DARK, G.TEXT_MUTED, G.C_GAIN_INK, G.paper_ink(G.equip_rarity_color(2))]:
		var contrast := (_luma(G.PARCHMENT) + 0.05) / (_luma(ink) + 0.05)
		_check(contrast >= 4.5, "Paper body/auxiliary ink must meet 4.5:1 (%.2f)" % contrast)
	_check(not G.ui_blocked, "Closing nested viewport popups must release modal input lock")
	print("VISUAL_REFRESH_OK" if _fails == 0 else "VISUAL_REFRESH_FAIL %d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
