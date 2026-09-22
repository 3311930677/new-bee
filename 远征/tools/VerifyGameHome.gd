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

	# ESC：主界面打开设置，不应直接跳到创角页；设置内再次 ESC 才关闭浮层
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	home._unhandled_input(esc)
	_check(home._settings != null, "主界面 ESC 应打开设置浮层，而不是直接进创角页")
	if home._settings != null:
		home._unhandled_input(esc)
		await get_tree().process_frame
	_check(home._settings == null, "设置浮层内 ESC 应关闭设置")

	# ---- C. DEPLOY 浮层构建、默认预填与门禁 ----
	home._on_expedition(_click())
	_check(home._deploy != null, "点出征入口应打开 DEPLOY 浮层")
	if home._deploy != null:
		var dp = home._deploy
		# 断开 GameHome 的真实出征连接（后面会 emit confirmed，避免真的切场景）
		_drop_confirm(dp)
		# 三页签各自一屏一项的轮播：卡片按「步骤:选项id」登记；虚拟化后**卡用到才建**
		_check(dp._cards.size() >= 1 and dp._cards.size() <= 3,
			"秘境页首开只应预建少量卡（虚拟化），实为 %d" % dp._cards.size())
		_check(dp._theme == "forest" and dp._role == "zs" and dp._active_pet == "pet_rockturtle",
			"应预填 forest/zs/岩龟出战，实为 %s/%s/%s" % [dp._theme, dp._role, dp._active_pet])

		# 门禁 A：未解锁世界 / 未收集宠物应压灰（locked 元标记）；翻页把卡建出来再查
		dp._deck.go(1, true)   # 翻到 snow
		_check(bool(dp._cards["0:snow"].get_meta("locked", false)), "未解锁世界卡（snow）应标记 locked")
		dp._deck.go(0, true)
		_check(not bool(dp._cards["0:forest"].get_meta("locked", false)), "主世界卡（forest）不应 locked")
		dp._goto_step(1)
		for i in 4:
			dp._deck.go(i, true)
		_check(dp._cards.size() == 4, "人物页翻满后应有 4 张卡，实为 %d" % dp._cards.size())
		dp._goto_step(2)
		for i in 8:
			dp._deck.go(i, true)
		_check(dp._cards.size() == 8, "宠物页翻满后应有 8 张卡，实为 %d" % dp._cards.size())
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
			dp._deck.go(1, true)   # 翻到 snow（虚拟化：卡用到才建）
			_check(not bool(dp._cards["0:snow"].get_meta("locked", false)), "解锁后 snow 卡应解除 locked")
			dp._goto_step(2)
			for i in 8:
				dp._deck.go(i, true)
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
			_check(dp._hint.text == "", "正常选择后提示行应清空（说明文案已收进 ? 弹层），实为「%s」" % dp._hint.text)

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

	# ---- J. 图鉴收集里程（轮次 20） ----
	# 收集本身此前没有任何回报；里程把"收了几只"换成可领取奖励。
	# 这里守三件事：未达标不给领、达标只能领一次、领完要落盘。
	G.prog["pets"] = ["pet_rockturtle"]
	G.prog["codex_claimed"] = []
	G.wallet = {"gold": 0, "expedition": 0, "soul": 0, "honor": 0}
	G.items = {}
	G.save_game()
	var ms := G.codex_milestones()
	_check(ms.size() >= 3, "codex.json 应有至少 3 档收集里程，实为 %d" % ms.size())
	var max_need := 0
	var monotonic := true
	var prev_need := 0
	for m in ms:
		var need_m := int((m as Dictionary).get("need", 0))
		if need_m <= prev_need:
			monotonic = false
		prev_need = need_m
		max_need = maxi(max_need, need_m)
	_check(monotonic, "里程档位应严格递增（按 need 升序）")
	_check(max_need <= TableCache.pets().size(),
		"最高里程 need=%d 不应超过宠物总数 %d（否则永远领不到）" % [max_need, TableCache.pets().size()])
	_check(G.codex_next_ready().is_empty(), "只集 1 只时不应有可领取里程")
	var first_need := int((ms[0] as Dictionary).get("need", 0))
	var deny := G.codex_claim(String((ms[0] as Dictionary).get("id", "")))
	_check(not bool(deny["ok"]), "数量不足时不应允许领取")
	_check(int(G.wallet.get("soul", 0)) == 0 and int(G.wallet.get("honor", 0)) == 0,
		"被拒的领取不能有任何部分发放")

	# 凑到达标数量 → 可领取
	var all_ids: Array = []
	for p in TableCache.pets():
		all_ids.append(String((p as Dictionary).get("id", "")))
	G.prog["pets"] = all_ids.slice(0, first_need)
	var ready := G.codex_next_ready()
	_check(not ready.is_empty(), "达标后应出现可领取里程")
	var soul_before := int(G.wallet.get("soul", 0))
	var claim := G.codex_claim(String(ready.get("id", "")))
	_check(bool(claim["ok"]), "达标后应能领取（err=%s）" % String(claim.get("err", "")))
	_check(int(G.wallet.get("soul", 0)) > soul_before, "领取后魂晶应入账")
	_check((claim.get("lines", []) as Array).size() > 0, "领取应返回奖励明细文案")
	var again := G.codex_claim(String(ready.get("id", "")))
	_check(not bool(again["ok"]), "同一档里程不应能重复领取")
	_check(G.codex_claimed().has(String(ready.get("id", ""))), "已领记录应写进 prog.codex_claimed")

	# 领完所有档：逐档领取，且最后一档的奖励真的到账
	G.prog["pets"] = all_ids
	var guard := 0
	while not G.codex_next_ready().is_empty() and guard < 20:
		var r2 := G.codex_next_ready()
		var c2 := G.codex_claim(String(r2.get("id", "")))
		_check(bool(c2["ok"]), "逐档领取应成功（%s）" % String(r2.get("id", "")))
		guard += 1
	_check(G.codex_next_ready().is_empty(), "全部领取后不应再有可领里程")
	_check(G.codex_claimed().size() == ms.size(),
		"已领记录应覆盖全部 %d 档，实为 %d" % [ms.size(), G.codex_claimed().size()])
	_check(int(G.wallet.get("honor", 0)) > 0, "里程奖励里的荣誉应入账")

	# 落盘往返：已领记录必须跟着存档走，否则重进游戏能再领一次
	G.save_game()
	G.prog["codex_claimed"] = []
	G._load_save()
	_check(G.codex_claimed().size() == ms.size(), "读档后已领记录应保留，实为 %d" % G.codex_claimed().size())
	_check(G.codex_next_ready().is_empty(), "读档后不应又冒出可领取里程（防重复领奖）")

	# 面板层：进度行文案与领取按钮可用态
	G.prog["pets"] = ["pet_rockturtle"]
	G.prog["codex_claimed"] = []
	var codex: Control = (load("res://src/ui/CodexPanel.gd") as GDScript).new()
	add_child(codex)
	await get_tree().process_frame
	var ms_label := codex.get("_ms_l") as Label
	var ms_text := ms_label.text if ms_label != null else ""
	_check(ms_label != null and ms_text.begins_with("收集里程"),
		"图鉴应显示收集里程行，实为「%s」" % ms_text)
	_check((codex.get("_claim_btn") as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"没有可领奖励时领取按钮不应可点")
	G.prog["pets"] = all_ids.slice(0, first_need)
	codex._refresh_milestone()
	_check((codex.get("_claim_btn") as Control).mouse_filter == Control.MOUSE_FILTER_STOP,
		"有可领奖励时领取按钮应可点")
	codex._on_claim()
	_check(G.codex_claimed().size() == 1, "从面板点领取应真的领到一档")
	codex.queue_free()
	await get_tree().process_frame

	# ---- K. 出征补给（轮次 21） ----
	# 药剂本来固定 2 瓶，玩家没有"为这趟远征投资"的取舍；加带补给把金币变成战前选择。
	# 守两条：金币在出征时才结算（加带/返回不扣钱），超上限与余额不足整单拒绝。
	G.prog["pets"] = ["pet_rockturtle"]
	G.prog["worlds_unlocked"] = 1
	G.selected_role = "zs"
	var base_p := G.run_potions_base()
	var max_p := G.run_potions_max()
	_check(base_p >= 1 and max_p > base_p, "补给口径应 base≥1 且 max>base（base=%d max=%d）" % [base_p, max_p])
	var p0 := G.run_supply_price(0)
	var p1 := G.run_supply_price(1)
	_check(p0 > 0 and p1 > p0, "加带单价应随数量递增（%d → %d）" % [p0, p1])
	G.wallet["gold"] = 0
	var deny_pay := G.buy_run_supply_pack(1)
	_check(not bool(deny_pay["ok"]), "金币不足时不应结算成功")
	_check(int(G.wallet["gold"]) == 0, "被拒的补给不能扣钱")
	var over := G.buy_run_supply_pack(max_p - base_p + 1)
	_check(not bool(over["ok"]), "超过上限的加带应被拒绝")
	G.wallet["gold"] = 99999
	var total_want := 0
	for i in (max_p - base_p):
		total_want += G.run_supply_price(i)
	var okk := G.buy_run_supply_pack(max_p - base_p)
	_check(bool(okk["ok"]) and int(okk["total"]) == total_want,
		"加带到上限应按递增单价求和（实为 %d，应为 %d）" % [int(okk["total"]), total_want])
	_check(int(G.wallet["gold"]) == 99999 - total_want, "应恰好扣一次总价")

	# 面板：加带只计数不扣钱；点「出征」才一次结算；取消返回更不该扣
	G.wallet["gold"] = 99999
	var dp: Control = (load("res://src/ui/DeployPanel.gd") as GDScript).new()
	add_child(dp)
	await get_tree().process_frame
	_drop_confirm(dp)
	var gold_before := int(G.wallet["gold"])
	dp._add_supply()
	dp._add_supply()
	_check(int(dp.get("_extra_potions")) == 2, "点两次补给应记 2 瓶，实为 %d" % int(dp.get("_extra_potions")))
	_check(int(G.wallet["gold"]) == gold_before, "加带阶段不应扣钱（金币在出征时才结算）")
	_got_cfg = {}
	dp.confirmed.connect(func(cfg): _got_cfg = cfg)
	dp._on_confirm()
	_check(not _got_cfg.is_empty(), "确认后应发出出征配置")
	_check(int(_got_cfg.get("potions", -1)) == base_p + 2,
		"出征配置里的药剂应为 base+2=%d，实为 %d" % [base_p + 2, int(_got_cfg.get("potions", -1))])
	_check(int(G.wallet["gold"]) == gold_before - (p0 + p1),
		"出征时应一次结算两瓶的递增总价（%d）" % (p0 + p1))
	dp.queue_free()
	await get_tree().process_frame
	var dp2: Control = (load("res://src/ui/DeployPanel.gd") as GDScript).new()
	add_child(dp2)
	await get_tree().process_frame
	var gold2 := int(G.wallet["gold"])
	dp2._add_supply()
	dp2.canceled.emit()
	_check(int(G.wallet["gold"]) == gold2, "取消返回不应扣补给钱")
	dp2.queue_free()
	await get_tree().process_frame

	# ---- L. 苦行（轮次 22） ----
	# 出征前可选的难度/收益开关：敌人更强、本局收益同倍放大。守三件事：
	# 面板能把开关带进出口配置、RunState 的收益倍率作用在唯一入口 add_reward 上、
	# 战斗内核只吃"倍率数字"而不会自己去读表。
	var ac := G.ascetic_cfg()
	_check(not ac.is_empty(), "nodes.json 应声明 ascetic 段")
	var em := float(ac.get("enemy_mult", 0.0))
	var rm := float(ac.get("reward_mult", 0.0))
	_check(em > 1.0, "苦行的敌人倍率应 >1（实为 %.2f）" % em)
	_check(rm > 1.0, "苦行的收益倍率应 >1（实为 %.2f）" % rm)
	# RunState：默认局收益 = 表值；苦行局按倍率放大，且五币同时生效
	var st_n := RunState.new()
	st_n.setup({"theme": "forest", "role_id": "zs", "level": 1, "seed": 20260920})
	var row: Dictionary = TableCache.nodes_config().get("rewards", {}).get("normal", {})
	st_n.add_reward("normal")
	_check(st_n.gold == int(row.get("gold", 0)),
		"普通局收益应等于表值（实为 %d）" % st_n.gold)
	var st_a := RunState.new()
	st_a.setup({"theme": "forest", "role_id": "zs", "level": 1, "seed": 20260920, "ascetic": true})
	_check(st_a.ascetic, "配置里 ascetic=true 应被 RunState 接住")
	st_a.add_reward("normal")
	_check(st_a.gold == roundi(float(row.get("gold", 0)) * rm),
		"苦行局金币应 ×%.2f（期望 %d，实为 %d）"
		% [rm, roundi(float(row.get("gold", 0)) * rm), st_a.gold])
	_check(st_a.expedition == roundi(float(row.get("expedition", 0)) * rm)
		and st_a.honor == roundi(float(row.get("honor", 0)) * rm),
		"远征币与荣誉也应同倍放大")
	_check(is_equal_approx(st_n.enemy_mult(), 1.0), "普通局敌人倍率应为 1.0")
	_check(absf(st_a.enemy_mult() - em) < 0.0001, "苦行局敌人倍率应等于表值 %.2f" % em)
	# BattleSim：只有传进来的 enemy_mult 起作用（内核不读表）
	var base_sim := BattleSim.new()
	base_sim.setup(1, {"role_id": "zs", "level": 3, "traits": [], "active_pet": ""},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	var asc_sim := BattleSim.new()
	asc_sim.setup(1, {"role_id": "zs", "level": 3, "traits": [], "active_pet": ""},
		{"theme": "forest", "node_type": "normal", "layer": 1, "enemy_mult": em})
	_check(absf(asc_sim.enemy_scale - base_sim.enemy_scale * em) < 0.0001,
		"战斗内核应按传入倍率缩放敌人（%.3f vs %.3f）" % [asc_sim.enemy_scale, base_sim.enemy_scale * em])
	# 面板：开关能把 ascetic 带进出口配置
	G.wallet["gold"] = 5000
	var dp3: Control = (load("res://src/ui/DeployPanel.gd") as GDScript).new()
	add_child(dp3)
	await get_tree().process_frame
	_drop_confirm(dp3)
	_check(not bool(dp3.get("_ascetic")), "苦行默认应为关")
	dp3._toggle_ascetic()
	_check(bool(dp3.get("_ascetic")), "点一下应开启苦行")
	_got_cfg = {}
	dp3.confirmed.connect(func(cfg): _got_cfg = cfg)
	dp3._on_confirm()
	_check(bool(_got_cfg.get("ascetic", false)), "出征配置应带上 ascetic=true")
	var st_cfg := RunState.new()
	st_cfg.setup(_got_cfg)
	_check(st_cfg.ascetic and absf(st_cfg.enemy_mult() - em) < 0.0001,
		"面板配置直接喂给 RunState 也应生效")
	dp3._toggle_ascetic()
	_check(not bool(dp3.get("_ascetic")), "再点一下应关闭苦行")
	dp3.queue_free()
	await get_tree().process_frame

	if _fails == 0:
		print("GAME_HOME_OK all tests passed")
	else:
		print("GAME_HOME_FAIL fails=%d" % _fails)
