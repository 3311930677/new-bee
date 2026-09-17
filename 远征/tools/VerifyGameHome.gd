# VerifyGameHome.gd —— 主城冒烟（场景模式：godot --headless --path . res://tools/VerifyGameHome.tscn）
# 覆盖：G 存档读写往返（四币）/ 主城顶栏钱包 / 世界图志 + 宠物图鉴浮层 /
#       出征筹备 DEPLOY（默认预填、未解锁世界与未收集宠物的门禁、解锁后交互、出征配置）
extends Node

var _fails := 0
var _got_cfg := {}   # confirmed 信号回填（lambda 不能写回局部变量，用成员）


func _ready() -> void:
	G.SAVE_PATH = "user://save_verify_home.json"  # 别污染真实存档
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


func _drop_confirm(dp) -> void:
	for c in dp.confirmed.get_connections():
		dp.confirmed.disconnect(c["callable"])


func _run() -> void:
	# 基线：只解锁主世界（forest）、只有初始伙伴。门禁断言必须建立在确定状态上，
	# 不能依赖环境里那份存档（跑过出征/路线图用例后它已经推进过了）。
	G.prog = {"level": 1, "exp": 0, "worlds_unlocked": 1, "world_cleared": {}, "pets": []}
	G.ensure_starter_pets()
	G.wallet = {"gold": 0, "expedition": 0, "soul": 0, "honor": 0}
	G.save_game()

	# ---- A. G 存档读写往返（四币） ----
	G.wallet = {"gold": 111, "expedition": 22, "soul": 3, "honor": 7}
	G.save_game()
	G.wallet = {"gold": 0, "expedition": 0, "soul": 0, "honor": 0}
	G._load_save()
	_check(int(G.wallet.get("gold", 0)) == 111 and int(G.wallet.get("expedition", 0)) == 22
		and int(G.wallet.get("soul", 0)) == 3 and int(G.wallet.get("honor", 0)) == 7,
		"读档应恢复钱包四币，实为 %s" % str(G.wallet))
	G.wallet = {"gold": 0, "expedition": 0, "soul": 0, "honor": 0}
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
	_check(wallet_txt.contains("金") and wallet_txt.contains("远征")
		and wallet_txt.contains("魂石") and wallet_txt.contains("荣誉"),
		"顶栏应显示钱包四币（金/远征/魂石/荣誉），实为「%s」" % wallet_txt)

	# ---- C. DEPLOY 浮层构建、默认预填与门禁 ----
	home._on_expedition(_click())
	_check(home._deploy != null, "点出征入口应打开 DEPLOY 浮层")
	if home._deploy != null:
		var dp = home._deploy
		# 断开 GameHome 的真实出征连接（后面会 emit confirmed，避免真的切场景）
		_drop_confirm(dp)
		# 三页签各自一屏一项的轮播：卡片按「步骤:选项id」登记，切页签才建对应那页
		_check(dp._cards.size() == 8, "秘境页应有 8 张卡，实为 %d" % dp._cards.size())
		_check(dp._theme == "forest" and dp._role == "zs" and dp._active_pet == "pet_rockturtle",
			"应预填 forest/zs/岩龟出战，实为 %s/%s/%s" % [dp._theme, dp._role, dp._active_pet])

		# 门禁 A：未解锁世界 / 未收集宠物应压灰（locked 元标记）
		_check(bool(dp._cards["0:snow"].get_meta("locked", false)), "未解锁世界卡（snow）应标记 locked")
		_check(not bool(dp._cards["0:forest"].get_meta("locked", false)), "主世界卡（forest）不应 locked")
		dp._goto_step(1)
		_check(dp._cards.size() == 4, "人物页应有 4 张卡，实为 %d" % dp._cards.size())
		dp._goto_step(2)
		_check(dp._cards.size() == 8, "宠物页应有 8 张卡，实为 %d" % dp._cards.size())
		_check(bool(dp._cards["2:pet_holydeer"].get_meta("locked", false)), "未收集宠物卡应标记 locked")
		_check(not bool(dp._cards["2:pet_rockturtle"].get_meta("locked", false)), "初始宠物卡不应 locked")

		# 门禁 B：点它们应被拒绝并给出解锁提示
		dp._select_theme("snow")
		_check(dp._theme == "forest", "点未解锁世界应被拒绝，实为 %s" % dp._theme)
		_check(dp._hint.text.contains("未解锁"), "拒绝选世界应提示解锁条件，实为「%s」" % dp._hint.text)
		dp._select_pet("pet_holydeer")
		_check(dp._active_pet == "pet_rockturtle", "点未收集宠物应被拒绝，实为 %s" % dp._active_pet)
		_check(dp._hint.text.contains("未收集"), "拒绝选宠物应提示收集途径，实为「%s」" % dp._hint.text)

		# 关掉，用 GM 全解锁后重开——卡片锁态是构建期写死的，必须重建才会刷新
		home._deploy.canceled.emit()
		_check(home._deploy == null, "取消后浮层应关闭（GameHome 释放引用）")
		G.gm_unlock_all_worlds()
		G.gm_unlock_all_pets()
		home._on_expedition(_click())
		dp = home._deploy
		_check(dp != null, "解锁后应能重开 DEPLOY 浮层")
		if dp != null:
			_drop_confirm(dp)
			_check(not bool(dp._cards["0:snow"].get_meta("locked", false)), "解锁后 snow 卡应解除 locked")
			dp._goto_step(2)
			_check(not bool(dp._cards["2:pet_frostwolf"].get_meta("locked", false)), "收集后 frostwolf 卡应解除 locked")

			# ---- D. 选择交互（解锁后全部可选） ----
			dp._select_theme("snow")
			_check(dp._theme == "snow", "解锁后应能选 snow，实为 %s" % dp._theme)
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
			_check(dp._hint.text.contains("选宠物"), "正常选择后提示应回到本页常规文案，实为「%s」" % dp._hint.text)

			# ---- E. 出征校验与配置 ----
			_got_cfg = {}
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
				_check(int(_got_cfg.get("level", 0)) == int(G.prog.get("level", 1)),
					"出征配置的等级应取存档等级，实为 %s" % str(_got_cfg.get("level")))

	# ---- F. 取消关闭 ----
	if home._deploy != null:
		home._deploy.canceled.emit()
		_check(home._deploy == null, "取消后浮层应关闭（GameHome 释放引用）")

	# ---- G. 世界图志 / 宠物图鉴浮层 ----
	home._open_worlds(_click())
	_check(home._worlds != null, "点「世界」入口应打开世界图志浮层")
	if home._worlds != null:
		_check(home._worlds.get_child_count() >= 3, "世界图志应有横幅/面板/返回等内容")
		home._worlds.closed.emit()
		_check(home._worlds == null, "关闭后应释放世界图志引用")
		await get_tree().process_frame
	home._open_codex(_click())
	_check(home._codex != null, "点「图鉴」入口应打开宠物图鉴浮层")
	if home._codex != null:
		_check(home._codex.get_child_count() >= 3, "宠物图鉴应有横幅/面板/返回等内容")
		home._codex.closed.emit()
		_check(home._codex == null, "关闭后应释放宠物图鉴引用")
		await get_tree().process_frame

	home.queue_free()
	await get_tree().process_frame

	# ---- H. 养成主线：通关世界 → 解锁下一世界 + 解封对应宠物 ----
	G.prog = {"level": 1, "exp": 0, "worlds_unlocked": 1, "world_cleared": {}, "pets": []}
	G.ensure_starter_pets()
	_check(G.owns_pet("pet_rockturtle"), "初始伙伴应保底在册（老存档 pets 为空也不至于无宠可带）")
	_check(G.is_world_unlocked("forest") and not G.is_world_unlocked("snow"), "初始只应解锁主世界 forest")
	_check(not G.owns_pet("pet_thunderhawk") and not G.owns_pet("pet_frostwolf"),
		"初始不应拥有通关奖励宠物")
	var opened := G.on_world_cleared("forest")
	_check(opened != "", "通关 forest 应解锁下一世界并返回新世界名，实为「%s」" % opened)
	_check(G.is_world_cleared("forest"), "通关后应标记 world_cleared")
	_check(G.is_world_unlocked("snow"), "通关 forest 后 snow 应解锁")
	_check(G.owns_pet("pet_thunderhawk"), "通关 forest 应解封该世界的对应宠物 thunderhawk")
	_check(not G.owns_pet("pet_frostwolf"), "未通关 snow 不应提前解封 frostwolf")
	_check(not G.is_world_unlocked("volcano"), "一次只应推进一界，volcano 仍应锁定")

	# 经验与升级（逐级结算）
	G.prog["level"] = 1
	G.prog["exp"] = 0
	var need := G.exp_to_next(1)
	_check(need > 0, "1 级应有升级所需经验")
	_check(G.gain_exp(need) == 1 and int(G.prog["level"]) == 2, "加满需求经验应升 1 级，实为 %s" % str(G.prog["level"]))
	_check(G.gain_exp(need * 3) >= 1, "溢出经验应继续升级")
	_check(G.exp_to_next(G.level_cap()) == 0, "满级不应再有升级需求")

	# ---- I. GM 口令与一键满配 ----
	G.gm_unlocked = false
	_check(not G.gm_check_password("@tsz20060707"), "错口令不应解锁")
	_check(not G.gm_unlocked, "错口令不应置位 gm_unlocked")
	_check(G.gm_check_password("@tsz20060706"), "对口令 @tsz20060706 应解锁")
	_check(G.gm_unlocked, "对口令应置位 gm_unlocked")

	G.gm_grant_all()
	_check(int(G.prog.get("level", 0)) == G.level_cap(),
		"一键满配应满级 %d，实为 %s" % [G.level_cap(), str(G.prog.get("level"))])
	_check(int(G.prog.get("worlds_unlocked", 0)) == G.world_count(),
		"一键满配应解锁全部 %d 个世界" % G.world_count())
	# 「解锁」和「已通关」是两种状态：一键满配只管解锁，不伪造通关记录
	_check(G.is_world_unlocked("castle"), "一键满配后最后一界 castle 应可出征")
	_check(not G.is_world_cleared("castle"), "一键满配不该把没打过的 castle 记成已通关（解锁≠通关）")
	_check(G.cleared_world_count() == 1,
		"此时通关数应仍是 1（前面只打掉 forest），实为 %d" % G.cleared_world_count())
	G.gm_clear_all_worlds()
	_check(G.cleared_world_count() == G.world_count(),
		"「全部标记已通关」应把 %d 个世界都记上，实为 %d" % [G.world_count(), G.cleared_world_count()])
	_check(G.is_world_cleared("castle") and G.is_world_cleared("forest"),
		"标记通关后 castle 与 forest 都应算已通关")
	_check(G.is_world_unlocked("forest"), "标记通关不该把世界反过来锁掉")
	var all_owned := true
	for p in TableCache.pets():
		if not G.owns_pet(String((p as Dictionary).get("id", ""))):
			all_owned = false
	_check(all_owned, "一键满配应收集全部宠物")
	_check(int(G.wallet.get("gold", 0)) >= 99999 and int(G.wallet.get("honor", 0)) >= 99999,
		"一键满配应把四币管够，实为 %s" % str(G.wallet))

	# 单步工具 + 复位
	G.gm_reset_save()
	_check(int(G.prog.get("level", 0)) == 1 and int(G.prog.get("worlds_unlocked", 0)) == 1, "复位应回到 1 级、仅解锁主世界")
	_check(G.owns_pet("pet_rockturtle") and not G.owns_pet("pet_frostwolf"), "复位后只应留初始伙伴")
	_check(int(G.wallet.get("gold", 0)) == 0, "复位应清空钱包")
	G.gm_add_currency(50)
	_check(int(G.wallet.get("gold", 0)) == 50 and int(G.wallet.get("honor", 0)) == 50, "加币应对四币同时生效")
	G.gm_max_level()
	_check(int(G.prog.get("level", 0)) == G.level_cap(), "单独满级指令应生效")

	# 解锁文案
	_check(G.pet_unlock_text("pet_rockturtle") == "初始伙伴", "初始伙伴的解锁文案应为「初始伙伴」")
	_check(G.pet_unlock_text("pet_frostwolf").begins_with("通关"),
		"世界解锁宠物的文案应说明通关条件，实为「%s」" % G.pet_unlock_text("pet_frostwolf"))

	if _fails == 0:
		print("GAME_HOME_OK all tests passed")
	else:
		print("GAME_HOME_FAIL fails=%d" % _fails)
