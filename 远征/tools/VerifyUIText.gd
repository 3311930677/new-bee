extends Node
var failures := 0
var checks := 0

func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+detail)

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_ui_text.json"
	G._init_state_defaults()
	G.save_locked = false
	G.set_meta("ui_review_mode",false)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480,800)
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	var page := Control.new()
	page.size = Vector2(480,800)
	viewport.add_child(page)
	G.register_ui_page(page)
	var body := Label.new()
	body.text = "领取解锁返回"
	body.add_theme_font_override("font",G.font_reg)
	body.add_theme_constant_override("outline_size",4)
	page.add_child(body)
	var small_art := G.serif_label("按钮",18)
	small_art.add_theme_font_override("font",G.font_art)
	page.add_child(small_art)
	var art := G.serif_label("行旅营帐",34)
	page.add_child(art)
	var sprite := TextureRect.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	page.add_child(sprite)
	# Pages may add then synchronously remove transient text before the deferred policy runs.
	var transient := Label.new()
	page.add_child(transient)
	transient.free()
	await _frames()
	_check(body.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR,"inherited text escapes nearest sampling")
	_check(body.get_theme_constant("outline_size")==1,"small glyphs keep their counters instead of heavy outlines")
	_check(small_art.get_theme_font("font")==G.font_reg,"brush face is replaced only at compact size")
	_check(art.get_theme_font("font")==G.font_art,"large calligraphy remains available")
	_check(sprite.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"art texture filtering is preserved")
	G.ensure_starter_equip(true)
	G.inv_grant_equip({"tpl":"tpl_sword_wolf","rarity":1,"n":G.inv_capacity()+2},false)
	var pending_uid := int(G.inv_pending()[0].uid)
	_check(not bool(G.inv_claim(pending_uid).get("ok",false)),"full bag rejects claiming")
	_check(page.get_node_or_null("RewardRibbon")==null,"failed claim has no success effect")
	for item in G.inv_instances():
		if not G.inv_worn_uids().has(int(item.uid)):
			G.inv_sell(int(item.uid),true)
			break
	var result := G.inv_claim(pending_uid)
	_check(bool(result.get("ok",false)),"available slot commits the real claim")
	var ribbon := page.get_node_or_null("RewardRibbon") as Control
	_check(ribbon!=null and ribbon.mouse_filter==Control.MOUSE_FILTER_IGNORE,"success feedback never captures input")
	var count := G.inv_count()
	_check(not bool(G.inv_claim(pending_uid).get("ok",false)) and G.inv_count()==count,"repeated claim cannot duplicate inventory")
	var before := G.prog.duplicate(true)
	G.present_reward("名号解锁","行路人","unlock")
	_check(page.get_node_or_null("RewardRibbon").kind=="unlock","unlock receives its distinct celebration")
	_check(G.prog==before,"presentation cannot modify progression")
	await get_tree().create_timer(2.9).timeout
	_check(page.get_node_or_null("RewardRibbon")==null,"transient celebration cleans up")
	page.queue_free()
	await _frames()
	print("UI_TEXT_OK checks=%d failures=%d" % [checks,failures])
	get_tree().quit(0 if failures==0 else 1)

func _frames() -> void:
	for i in 4: await get_tree().process_frame
