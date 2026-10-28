extends Node
const OUT := "res://shots/full_issue_fix_20261024/"
const Curio := preload("res://src/ui/CurioLorePanel.gd")
const Market := preload("res://src/ui/ExchangePanel.gd")
var checks := 0
var failures := 0
var capture := false
var photos: Array[String] = []

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FULL_FIX_FAIL "+detail)

func frames(n := 5) -> void:
	for i in n:await get_tree().process_frame

func drop(node: Node) -> void:
	remove_child(node)
	node.queue_free()
	await frames(3)

func photo(id: String) -> void:
	if not capture:return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(OUT+id+".png")==OK,"photo "+id)
	photos.append(id)

func state() -> String:
	return JSON.stringify([G.wallet,G.items,G.prog])

func fixture() -> void:
	G.SAVE_PATH = "res://tools/_logs/full_issue_fix_save.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.player_name = "全量修复验收"
	G.set_meta("ui_review_mode",true)
	G.wallet = {"gold":100000,"expedition":1234567,"soul":0,"honor":2000}

func _ready() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUT)
	fixture()
	get_window().unresizable = false
	get_window().min_size = Vector2i(320,480)
	for height in [640,800,960,1067,1280]:
		get_window().size = Vector2i(480,height)
		get_window().content_scale_size = Vector2i(480,height)
		var safe := Rect2(8,36,464,height-76)
		G.set_meta("test_safe_rect",safe)
		await frames()
		await verify_login(height,safe)
		await verify_currencies(height,safe)
		await verify_pets(height,safe)
		await verify_market(height,safe)
		await verify_curio_layout(height,safe)
	G.remove_meta("test_safe_rect")
	await verify_curio_transactions()
	var file := FileAccess.open("res://tools/_logs/full_issue_fix_ui_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"photos":photos},"\t"))
	file.close()
	print("FULL_ISSUE_FIX_UI_OK checks=%d failures=%d photos=%d"%[checks,failures,photos.size()])
	Audio.stop_bgm();Audio.set_suspended(true)
	await get_tree().create_timer(.2).timeout
	await frames(8)
	get_tree().quit(0 if failures==0 else 1)

func verify_login(height: int, safe: Rect2) -> void:
	var login := preload("res://src/ui/Login.tscn").instantiate()
	add_child(login)
	await frames(8)
	var view: Control = login._chest
	check(view._backdrop.material==null,"login has no blur/fade filler")
	check(view._backdrop.texture.resource_path.contains("full_issue_fix_20261024"),"new full-height login art")
	check(safe.encloses(login._paper.get_global_rect()),"login card safe %d"%height)
	check(safe.encloses(view._go.get_global_rect()) and view._go.size.y>=56,"login action safe %d"%height)
	check(login._account.size.y>=56 and login._password.size.y>=56,"login fields retain touch size")
	var secret: bool = login._password.secret
	view._eye.pressed.emit()
	check(login._password.secret!=secret,"password visibility toggles")
	if height in [640,1067,1280]:await photo("login_%d"%height)
	login._password.grab_focus()
	view.layout(safe,300.0)
	await frames()
	check(login._paper.get_global_rect().end.y<=safe.end.y-300+1,"keyboard keeps form above keyboard %d"%height)
	check(view._form_scroll.size.y>0,"keyboard form scroll stays usable")
	check(view._form_scroll.get_global_rect().encloses(login._password.get_global_rect()),"focused password is fully visible above keyboard %d"%height)
	if height in [640,1067]:await photo("login_keyboard_%d"%height)
	view.layout(safe,0.0)
	await frames()
	check(view._guest.visible and view._header.visible==(safe.size.y>=700),"keyboard restore %d"%height)
	await drop(login)

func verify_currencies(height: int,safe: Rect2) -> void:
	for id in ["gold","expedition","soul","honor"]:
		var before := state()
		var panel := preload("res://src/ui/CurrencyPanel.gd").new()
		panel.currency_id = id
		add_child(panel)
		await frames(8)
		check(panel._tabs.is_empty(),"single currency card has no cross-currency tabs")
		check(panel.currency_id==id and str(G.wallet[id]) in panel._balance.text,"exact selected balance "+id)
		check(safe.encloses(panel._frame.get_global_rect()),"currency safe "+id+str(height))
		check(panel._scroll.size.y>=48,"currency body scroll remains useful")
		check(panel._frame.size.y<=650.5,"currency height capped")
		check(state()==before,"reading currency is pure")
		if height==1067:await photo("currency_"+id)
		await drop(panel)

func verify_pets(height: int,safe: Rect2) -> void:
	for owned in [false,true]:
		G.prog.pets = []
		if owned:
			for pet in TableCache.pets():G.prog.pets.append(String(pet.id))
		var codex := preload("res://src/ui/CodexPanel.gd").new()
		add_child(codex)
		await frames(5)
		for index in codex._pets.size():
			codex._deck.go(index,true)
			await frames(4)
			var view: Control = codex._chest
			var sprite: TextureRect = view._art
			var anchor: Vector2 = sprite.position+view._pet_anchor/view._anchor_canvas*sprite.size
			var pedestal_center: float = view._pedestal.position.x+view._pedestal.size.x*.5
			check(absf(anchor.x-pedestal_center)<=1.1,"pet support is centered "+str(index))
			check(absf(anchor.x-(view._shadow.position.x+view._shadow.size.x*.5))<=1.1,"pet shadow shares anchor")
			var bounds := Rect2(preload("res://src/ui/NameTagLayout.gd").opaque_bounds(sprite.texture))
			var scale := sprite.size/sprite.texture.get_size()
			var visible_rect := Rect2(sprite.position+bounds.position*scale,bounds.size*scale)
			check(Rect2(Vector2.ZERO,view.shell.stage.size).encloses(visible_rect),"pet silhouette fully visible %d %d"%[height,index])
			check(safe.encloses(view.shell.back.get_global_rect()),"codex return safe")
			if height==800 or (height in [640,1067] and index==1):
				await photo("pet_%d_%d_%s"%[height,index,"owned" if owned else "silhouette"])
		await drop(codex)

func verify_market(height: int,safe: Rect2) -> void:
	var market := Market.new()
	add_child(market)
	await frames(8)
	check(market.entries().size()==5,"market keeps all five configured products")
	check(market._grid.columns==2,"phone market is two columns")
	check(safe.encloses(market._panel.get_global_rect()),"market frame safe %d"%height)
	var before := state()
	market.open_product("enhance_stone")
	await frames(6)
	check(state()==before,"opening product does not buy")
	check(safe.encloses(market._detail.get_global_rect()),"product detail safe "+str(market._detail.get_global_rect())+" in "+str(safe))
	if height==1067:await photo("honor_product_detail")
	market.close_product()
	if height in [640,1067]:await photo("honor_market_%d"%height)
	if height==800:
		market.open_product("enhance_stone")
		await frames()
		var honor := int(G.wallet.honor)
		var amount := G.item_count("enhance_stone")
		market.confirm_purchase()
		market.confirm_purchase()
		check(int(G.wallet.honor)==honor-80 and G.item_count("enhance_stone")==amount+3,"one confirmation buys exactly once")
		market.close_product()
		G.wallet.honor = 0
		market.open_product("lock_rune")
		await frames()
		check(market._confirm.disabled,"insufficient honor blocks confirmation")
		var insufficient := state()
		market.confirm_purchase()
		check(state()==insufficient,"insufficient purchase does not mutate state")
		G.wallet.honor = 2000
	await drop(market)

func verify_curio_layout(height: int,safe: Rect2) -> void:
	var curio := Curio.new()
	add_child(curio)
	await frames()
	var before := state()
	for page in ["overview","lore","appraise","history"]:
		curio.navigate(page)
		await frames()
		check(safe.encloses(curio._frame.get_global_rect()),"curio "+page+" safe "+str(height))
		check(curio._scroll.size.y>=48,"curio scroll body useful "+page)
		check(safe.encloses(curio._back.get_global_rect()) and curio._back.size.y>=60,"curio return accessible")
		if height==1067:await photo("curio_"+page)
	check(state()==before,"all curio navigation is read-only")
	await drop(curio)

func verify_curio_transactions() -> void:
	fixture()
	var curio := Curio.new()
	add_child(curio)
	await frames()
	for count in [0,2,3,20]:
		G.prog.flags.curio_appraised_count = count
		G.prog.flags.curio_history = []
		for i in 6:G.prog.flags.curio_history.append("第%d鉴【测试古匣】→ 奖励已入包，记录为只读。"%i)
		var before := state()
		curio.navigate("overview")
		await frames()
		check(not curio._status.text.contains("/3"),"cumulative count is separate from goal")
		curio.navigate("history")
		curio._open_record(5)
		curio.back()
		curio.back()
		check(state()==before,"history viewing never grants rewards")
	curio.navigate("lore")
	var wallet := G.wallet.duplicate(true)
	curio.resonate()
	curio.resonate()
	check(int(G.wallet.gold)==int(wallet.gold)+180 and int(G.wallet.honor)==int(wallet.honor)+30,"first lore reward once")
	var rewarded := state()
	curio.back()
	curio.resonate()
	check(state()==rewarded,"already resonated lore is read-only")
	curio.navigate("appraise")
	var gold := int(G.wallet.gold)
	var count := int(G.prog.flags.curio_appraised_count)
	curio.appraise()
	curio.appraise()
	check(int(G.wallet.gold)==gold-260 and int(G.prog.flags.curio_appraised_count)==count+1,"one appraisal charge per result")
	var result := state()
	curio.back()
	check(state()==result,"result confirmation only returns")
	curio._select_tier("rare")
	# A separate appraisal observes the current backend cooldown.
	G.prog.flags["curio_last_ts"] = G.now_ts()-61
	gold = int(G.wallet.gold)
	curio.appraise()
	check(int(G.wallet.gold)==gold-680,"rare cost preserved")
	await drop(curio)
