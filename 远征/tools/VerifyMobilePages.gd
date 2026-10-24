extends Node
const OUT := "res://shots/mobile_fixes_20261024/"
var fails := 0
var checks := 0
var capture := false
func check(ok: bool, words: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("MOBILE_PAGE_FAIL "+words)
func frames(count := 4) -> void:
	for i in count: await get_tree().process_frame
func photo(name: String) -> void:
	if capture:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT+name+".png")
func drop(node: Node) -> void:
	remove_child(node)
	node.queue_free()
	await frames()
func _ready() -> void:
	G.SAVE_PATH="res://tools/_logs/mobile_pages_save.json"
	G._init_state_defaults()
	G.save_locked=false
	G.set_meta("ui_review_mode",true)
	G.selected_role="zs"
	G.player_name="布局验收"
	G.wallet={"gold":1234567,"expedition":23456,"soul":3456,"honor":456}
	capture="--capture-mobile" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUT)
	for height in [800,960,1067]:
		get_window().size=Vector2i(480,height)
		await frames()
		var safe:=Rect2(8,36,464,height-64)
		G.set_meta("test_safe_rect",safe)
		var loading:=preload("res://src/ui/LoadScreen.gd").new()
		loading.auto_advance=false
		add_child(loading)
		await frames(12)
		check(safe.encloses(loading._gauge.get_global_rect()),"loading gauge safe")
		check(safe.encloses(loading._hint_l.get_global_rect()),"loading hint safe")
		await photo("loading_%d"%height)
		await drop(loading)
		var title:=preload("res://src/ui/Title.tscn").instantiate()
		add_child(title)
		await frames(10)
		await photo("title_%d"%height)
		await drop(title)
		var login:=preload("res://src/ui/Login.tscn").instantiate()
		add_child(login)
		await frames(10)
		check(safe.encloses(login._account.get_global_rect()),"account inside cutout safe area")
		check(safe.encloses(login._password.get_global_rect()),"password inside cutout safe area")
		await photo("login_%d"%height)
		login._chest.layout(safe,300)
		await frames()
		check(login._account.get_global_rect().end.y<=safe.end.y-300,"keyboard keeps account available")
		await photo("keyboard_%d"%height)
		await drop(login)
		var dialog:=preload("res://src/ui/TravelChestUI.gd").Modal.new()
		dialog.heading="行旅告示"
		dialog.lines=["离开营帐前，请确认行囊与补给。".repeat(12)]
		dialog.choices=["查看行囊","继续出发"]
		add_child(dialog)
		await frames(8)
		check(safe.encloses(dialog._frame.get_global_rect()),"long dialog safe")
		check(dialog._scroll.size.y>100,"long dialog remains scrollable")
		await photo("dialog_%d"%height)
		await drop(dialog)
		BattleScene.pending_cfg={"ally":{"role_id":"zs","level":20,"traits":[],"potions":2},"enemy":{"theme":"forest","node_type":"normal","layer":1},"presentation":"classic_inline","seed":71}
		var battle:=preload("res://src/battle/BattleScene.tscn").instantiate() as BattleScene
		add_child(battle)
		battle.set_process(false)
		await frames()
		battle.sim.result="victory"
		battle._show_result()
		await frames(6)
		var settlement:=battle.get_node("SettlementModal") as Control
		check(safe.encloses(settlement.get_global_rect()),"settlement safe")
		check(absf(settlement.get_global_rect().get_center().y-safe.get_center().y)<1,"settlement centered on long phone")
		await photo("settlement_%d"%height)
		await drop(battle)
	G.remove_meta("test_safe_rect")
	get_window().size=Vector2i(480,800)
	await frames()
	var home:=preload("res://src/ui/GameHome.tscn").instantiate()
	add_child(home)
	await frames(8)
	for item in home._wallet_labels:
		item.button.pressed.emit()
		await frames()
		check(not G._modals.is_empty(),"currency entry opens modal "+String(item.key))
		if G._modals.is_empty(): continue
		var modal: Dictionary=G._modals.back()
		var currency: Control=modal.layer.get_child(0)
		check(currency.currency_id==item.key,"actual entry selects correct currency "+String(item.key))
		var event:=InputEventKey.new()
		event.keycode=KEY_ESCAPE
		event.pressed=true
		G._unhandled_input(event)
		await frames()
		check(not G.ui_blocked,"ESC removes only the currency modal")
	await drop(home)
	print("MOBILE_PAGES_OK checks=%d fails=%d"%[checks,fails])
	await frames()
	get_tree().quit(0 if fails==0 else 1)
