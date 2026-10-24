extends Control
## Android-only diagnostic entry enabled by the emulator export feature.
## Production presets exclude this directory and do not enable the feature.
var snapshots: Array[Dictionary] = []
const OUT := "user://android_ui_audit/"

func frames(count := 16) -> void:
	for i in count: await get_tree().process_frame

func _ready() -> void:
	if OS.get_name() != "Android" or not OS.has_feature("android_ui_audit"):
		get_tree().quit(1)
		return
	G.SAVE_PATH="user://android_ui_audit_isolated.json"
	G.save_locked=true
	G._init_state_defaults()
	G.save_locked=true
	G.selected_role="zs"
	G.player_name="安卓适配巡检"
	G.gm_unlocked=true
	G.prog.level=60
	G.set_meta("ui_review_mode",true)
	G.wallet={"gold":1234567,"expedition":234567,"soul":34567,"honor":4567}
	for stat in ["atk","def","hp"]:
		for tier in range(1,6): G.items["gem_%s_%d" % [stat,tier]]=9
	DirAccess.make_dir_recursive_absolute(OUT)
	print("ANDROID_UI_AUDIT_START ",preload("res://src/ui/DeviceLayoutInfo.gd").text(self))
	var loading:=preload("res://src/ui/LoadScreen.gd").new()
	loading.auto_advance=false
	add_child(loading)
	await frames(30)
	await snapshot("loading",loading)
	await drop(loading)
	var login:=preload("res://src/ui/Login.tscn").instantiate()
	add_child(login)
	await frames()
	await snapshot("login",login)
	print("ANDROID_IME feature=",DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD)," enabled=",login._account.virtual_keyboard_enabled)
	login._account.grab_focus()
	DisplayServer.virtual_keyboard_show("qa",get_viewport().get_screen_transform()*login._account.get_global_rect())
	await get_tree().create_timer(1.5).timeout
	await snapshot("login_keyboard",login)
	print("ANDROID_IME_HEIGHT ",DisplayServer.virtual_keyboard_get_height())
	DisplayServer.virtual_keyboard_hide()
	await drop(login)
	var home:=preload("res://src/ui/GameHome.tscn").instantiate()
	# This lock protects the disposable test save, not a corrupt-save condition.
	# Do not provoke the real recovery dialog while creating the home page.
	G.save_locked=false
	add_child(home)
	G.save_locked=true
	await frames(30)
	await snapshot("town",home)
	var click:=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	var entries := [
		["activity","_open_activities","_activities",false],
		["bag","_open_bag","_bag",false],
		["gathering","_open_gathering","_gathering",false],
		["settings","_open_settings","_settings",true],
		["growth","_open_growth","_growth",false],
		["codex","_open_codex","_codex",true],
		["gacha","_open_gacha","_gacha",false],
		["exchange","_open_exchange","_exchange",false],
		["quests","_open_quests","_quests",false],
		["world","_open_worlds","_worlds",true],
		["arena","_open_arena","_arena",false],
	]
	for entry in entries:
		if entry[3]: home.call(entry[1],click)
		else: home.call(entry[1])
		await frames(24)
		var panel:Control=home.get(entry[2])
		if panel!=null:
			if entry[0]=="bag":
				panel.call("_select_tab","gem")
				await frames()
			await snapshot(entry[0],panel)
		else: print("ANDROID_UI_MISSING_ENTRY ",entry[0])
		home.call("_close_subpanels_except","")
		while not G._modals.is_empty(): G.close_info_popup_by_id(int(G._modals.back().id))
		home.call("_set_home_content_visible",true)
		await frames(3)
	var file:=FileAccess.open(OUT+"runtime.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"os":OS.get_name(),"version":OS.get_version(),"display":preload("res://src/ui/DeviceLayoutInfo.gd").text(self),"screens":snapshots},"\t"))
	file.close()
	print("ANDROID_UI_AUDIT_COMPLETE screens=",snapshots.size())
	# Allow native ADB taps to exercise the real input connection after the audit.
	while is_inside_tree():
		await get_tree().create_timer(.5).timeout
		if not FileAccess.file_exists(OUT+"request.json"): continue
		var request:Variant=JSON.parse_string(FileAccess.get_file_as_string(OUT+"request.json"))
		DirAccess.remove_absolute(OUT+"request.json")
		if request is Dictionary and request.get("page","")=="login":
			if is_instance_valid(home): await drop(home)
			login=preload("res://src/ui/Login.tscn").instantiate()
			add_child(login)
			await frames(30)
			print("ANDROID_MANUAL_LOGIN_READY account=",login._account.get_global_rect())

func drop(node:Node) -> void:
	remove_child(node)
	node.queue_free()
	await frames(3)

func snapshot(id:String,page:Control) -> void:
	await RenderingServer.frame_post_draw
	var path:=OUT+id+".png"
	get_viewport().get_texture().get_image().save_png(path)
	var outliers:Array[Dictionary]=[]
	var safe:=G.ui_safe_rect(page)
	collect(page,safe,outliers)
	snapshots.append({"id":id,"safe":str(safe),"outliers":outliers})
	print("ANDROID_UI_PAGE ",id," safe=",safe," outliers=",outliers.size())

func collect(node:Node,safe:Rect2,outliers:Array[Dictionary]) -> void:
	if node is CanvasItem and not node.is_visible_in_tree(): return
	if node is BaseButton and not node.disabled and node.size.x>8 and node.size.y>8:
		var scrolling:=false
		var ancestor:=node.get_parent()
		while ancestor!=null:
			# RegionChestMap intentionally pans a graph inside a clipped viewport.
			if ancestor is ScrollContainer or (ancestor is Control and ancestor.clip_contents): scrolling=true;break
			ancestor=ancestor.get_parent()
		if not scrolling and not safe.grow(1).encloses(node.get_global_rect()):
			outliers.append({"path":str(node.get_path()),"text":str(node.text) if node is Button else str(node.name),"rect":str(node.get_global_rect())})
	for child in node.get_children(): collect(child,safe,outliers)
