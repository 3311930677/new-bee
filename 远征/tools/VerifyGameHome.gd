# VerifyGameHome.gd —— 主城冒烟（场景模式：godot --headless --path . res://tools/VerifyGameHome.tscn）
# 覆盖：G 存档读写往返 / 主城顶栏钱包三币 / 出征筹备 DEPLOY 浮层（默认预填、选择交互、出征配置）
extends Node

var _fails := 0
var _got_cfg := {}   # confirmed 信号回填（lambda 不能写回局部变量，用成员）


func _ready() -> void:
	await _run()
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


func _click() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev


func _run() -> void:
	# ---- A. G 存档读写往返（先备份现场，测试后还原） ----
	var wallet_bak: Dictionary = G.wallet.duplicate()
	G.wallet = {"gold": 111, "expedition": 22, "soul": 3}
	G.save_game()
	G.wallet = {"gold": 0, "expedition": 0, "soul": 0}
	G._load_save()
	_check(int(G.wallet.get("gold", 0)) == 111 and int(G.wallet.get("expedition", 0)) == 22
		and int(G.wallet.get("soul", 0)) == 3, "读档应恢复钱包三币，实为 %s" % str(G.wallet))
	G.wallet = wallet_bak
	G.save_game()

	# ---- B. 主城构建 + 顶栏钱包 ----
	G.selected_role = "zs"
	var packed: PackedScene = load("res://src/ui/GameHome.tscn")
	var home: Control = packed.instantiate()
	add_child(home)
	await get_tree().process_frame
	_check(home._anim != null and home._anim.is_playing(), "角色待机动画应播放")
	_check(home._deploy == null, "开局不应有 DEPLOY 浮层")
	var wallet_txt := ""
	for c in home.get_children():
		if c is HBoxContainer:
			for l in c.get_children():
				if l is Label:
					wallet_txt += (l as Label).text
	_check(wallet_txt.contains("金") and wallet_txt.contains("远征币") and wallet_txt.contains("魂石"),
		"顶栏应显示钱包三币，实为「%s」" % wallet_txt)

	# ---- C. DEPLOY 浮层构建与默认预填 ----
	home._on_expedition(_click())
	_check(home._deploy != null, "点远征入口应打开 DEPLOY 浮层")
	if home._deploy != null:
		var dp = home._deploy
		# 断开 GameHome 的真实出征连接（E 组会 emit confirmed，避免真的切场景）
		for c in dp.confirmed.get_connections():
			dp.confirmed.disconnect(c["callable"])
		_check(dp._theme_btns.size() == 8, "应有 8 个秘境按钮，实为 %d" % dp._theme_btns.size())
		_check(dp._role_btns.size() == 4, "应有 4 个人物按钮，实为 %d" % dp._role_btns.size())
		_check(dp._pet_btns.size() == 8, "应有 8 个宠物按钮，实为 %d" % dp._pet_btns.size())
		_check(dp._theme == "forest" and dp._role == "zs" and dp._active_pet == "pet_rockturtle",
			"应预填 forest/zs/岩龟出战，实为 %s/%s/%s" % [dp._theme, dp._role, dp._active_pet])

		# ---- D. 选择交互 ----
		dp._select_theme("snow")
		dp._select_role("ck")
		dp._select_pet("pet_frostwolf")  # 有出战 → 进替补
		_check(dp._bench_pet == "pet_frostwolf", "第二只宠物应进替补位")
		dp._select_pet("pet_foxfire")    # 已有替补 → 替换替补
		_check(dp._bench_pet == "pet_foxfire", "第三只应替换替补位")
		dp._select_pet("pet_rockturtle")  # 点出战 → 替补转正
		_check(dp._active_pet == "pet_foxfire" and dp._bench_pet == "",
			"取消出战应由替补转正，实为 %s/%s" % [dp._active_pet, dp._bench_pet])
		dp._select_pet("pet_foxfire")     # 唯一出战再点 → 清空
		_check(dp._active_pet == "", "再点唯一出战应清空出战位")

		# ---- E. 出征校验与配置 ----
		dp.confirmed.connect(func(cfg: Dictionary): _got_cfg = cfg)
		dp._on_confirm()
		_check(_got_cfg.is_empty(), "无出战宠物时出征应被拦截")
		dp._select_pet("pet_holydeer")
		dp._on_confirm()
		_check(not _got_cfg.is_empty(), "补齐出战后出征应通过")
		if not _got_cfg.is_empty():
			_check(String(_got_cfg.get("theme", "")) == "snow" and String(_got_cfg.get("role_id", "")) == "ck"
				and String(_got_cfg.get("active_pet", "")) == "pet_holydeer",
				"出征配置应带所选秘境/人物/宠物，实为 %s" % str(_got_cfg))

	# ---- F. 取消关闭 ----
	if home._deploy != null:
		home._deploy.canceled.emit()
		_check(home._deploy == null, "取消后浮层应关闭（GameHome 释放引用）")

	home.queue_free()
	await get_tree().process_frame

	if _fails == 0:
		print("GAME_HOME_OK all tests passed")
	else:
		print("GAME_HOME_FAIL fails=%d" % _fails)
