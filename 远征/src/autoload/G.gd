# G.gd —— 全局单例：主题、字体、共享状态
extends Node

# ---------- 配色（模仿参考游戏：暖棕 + 羊皮纸 + 金） ----------
const BG_DEEP := Color("2a1f14")        # 深棕黑（选人底）
const BANNER := Color("5a3a1e")          # 棕色横幅
const PARCHMENT := Color("e8d5a3")       # 羊皮纸底
const GOLD := Color("f0c060")            # 金字/金边
const GOLD_BRIGHT := Color("ffd97a")     # 选中亮金
const NAME_GREEN := Color("84c48c")      # 角色名（柔玉绿，非荧光绿）
const LV_ORANGE := Color("f0a030")      # 等级橙
const TEXT_DARK := Color("3a2a14")      # 羊皮纸上的深字
const TEXT_LIGHT := Color("f5ead0")      # 深底上的浅字

# ---------- 参考风（创建角色页）配色 ----------
const WOOD := Color("6b4a28")            # 木框/顶栏棕
const WOOD_DARK := Color("4a3018")       # 木框暗部
const GOLD_BTN := Color("e8b84a")        # 金色实心按钮
const GOLD_BTN_EDGE := Color("8a6220")   # 金按钮描边
const INPUT_BG := Color("cdc4ab")        # 输入框灰米底
const INPUT_BG_FOCUS := Color("ece5cf")
const BOX_BG := Color("c2b79b")          # 选择框底
const BOX_EDGE := Color("7c5f2c")        # 选择框描边

# ---------- 浮层背景（§46 遮罩不该是一整块死黑纯灰） ----------
# 全项目浮层统一走这两个工厂，禁止再各自 new ColorRect 写一个灰色。
# 底色是深棕（与羊皮纸同调），再叠一层暗角：中心让位给内容，四角自然压暗。
const VEIL := Color("241a10")                 # 浮层底：深棕，不用纯黑
const VEIL_MODAL_A := 0.72                    # 弹窗级：能看见底下的场景轮廓
const VEIL_TAKEOVER_A := 0.94                 # 接管级：结果/结算整屏，底下不该透出来
const VEIL_VIGNETTE_A := 0.55                 # 暗角强度（相对弹窗级：弹窗 0.55、接管 0.72）
const VEIL_GRID := 8.0                        # 斜纹间距（远看是布纹，近看无规律）

# ---------- 字体 ----------
# 黑体：界面正文/按钮/数字（清晰优先）；宋体（站酷小薇）：标题/横幅/书卷文字（自然手写感）
const FONT_REG := "res://assets/fonts/NotoSansSC-Regular.otf"
const FONT_BOLD := "res://assets/fonts/NotoSansSC-Bold.otf"
const FONT_SERIF := "res://assets/fonts/ZCOOLXiaoWei-Regular.ttf"
var font_reg: FontFile
var font_bold: FontFile
var font_serif: FontFile

# 字号阶梯（统一收敛，禁止随手调参；层间比例 13/16/18/22/30/56）
const FS_XS := 13    # 角标 / 最小辅助
const FS_SM := 16    # 提示 / 描述文字
const FS_MD := 18    # 按钮 / 输入框 / 正文
const FS_LG := 22    # 面板标题 / 特写字段（角色名）
const FS_BIG := 30   # 木匾 / 区块标题
const FS_HERO := 56  # 主界面大标题

# ---------- UI 规格（§6 有限尺寸：同一层级只用同一档，禁止逐页手调宽高） ----------
# 按钮三档：主操作 / 次操作 / 返回关闭；页面里能用的就这三种高度，不再各自为政
const BTN_L := Vector2(190, 52)   # 主操作：开始切磋 / 登录 / 确认
const BTN_M := Vector2(148, 44)   # 次操作：换对手 / 切换 / 上传
const BTN_S := Vector2(120, 38)   # 返回 / 关闭
const ICON_RAIL := 36.0           # 主页圆形入口图标（圆底 60）
const ICON_WALLET := 18.0         # 资源栏图标
const ICON_MARK := 28.0           # 建筑/卡片角标图标

# ---------- 共享状态 ----------
var account := ""           # 登录账号（游客登录时为"游客"）
var gender := "男"          # 玩家选择性别
var selected_role := ""     # "zs" / "ck" / "fs" / "fz"
var avatar_id := ""         # 职业头像 id；为空时跟随当前职业
var avatar_custom := ""     # 上传的自定义头像文件名（user://avatars/ 下）；空串=没上传过
var avatar_use_custom := false   # 当前是否使用自定义头像（选职业头像后仍保留上传的图）
var player_name := ""       # 玩家起的名字
var roles: Array = []       # data/roles.json 内容

# ---------- 存档与钱包（user://save.json；四币 + 角色档案 + 养成进度） ----------
# 用 var 而非 const：自动化测试会把 SAVE_PATH 指向临时文件，避免污染真实存档
var SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2
var wallet := {"gold": 0, "expedition": 0, "soul": 0, "honor": 0}

# ---------- 道具库存（最小实现：id -> 数量；券类先行，后续道具沿用） ----------
var items := {"ticket_ten": 0, "ticket_sweep": 1}

## 道具显示名（委托/兑换/提示共用；没有登记的一律回落到 id，不静默编名字）
const ITEM_NAMES := {
	"ticket_ten": "十连券", "ticket_sweep": "扫荡券",
	"enhance_stone": "强化石", "refine_stone": "精炼石", "lock_rune": "锁定符",
	"pet_food": "宠物粮", "break_crystal": "突破晶", "aptitude_fruit": "资质果",
}


func item_name(id: String) -> String:
	return String(ITEM_NAMES.get(id, id))


func item_count(id: String) -> int:
	return int(items.get(id, 0))


## 发放道具（数量下限 0）
func grant_item(id: String, n: int) -> void:
	items[id] = maxi(0, item_count(id) + n)
	save_game()


## 消耗道具：不足则不动并返回 false
func consume_item(id: String, n: int) -> bool:
	if item_count(id) < n:
		return false
	items[id] = item_count(id) - n
	save_game()
	return true


## 战斗掉落掷表（data/drops.json，按档位）；返回 [{item, n}]
func roll_drops(tier: String) -> Array:
	var rows: Variant = TableCache.drops_config().get("drops", {})
	if not (rows is Dictionary):
		return []
	return _roll_drop_rows((rows as Dictionary).get(tier, []))


func _roll_drop_rows(list: Variant) -> Array:
	var out: Array = []
	if not (list is Array):
		return out
	for row_v in (list as Array):
		if not (row_v is Dictionary):
			continue
		var row := row_v as Dictionary
		var item := String(row.get("item", ""))
		if item.is_empty():
			continue
		if randf() > float(row.get("chance", 0.0)):
			continue
		var lo := maxi(1, int(row.get("min", 1)))
		var hi := maxi(lo, int(row.get("max", lo)))
		out.append({"item": item, "n": randi_range(lo, hi)})
	return out

# ---------- 养成进度（跨局持久）----------
# 主线：以"主世界"为起点，逐世界推进——通关某世界首领即解锁下一世界，
#       并同时解封一只新宠物；宠物/资源靠不断打怪升级与对战积累解锁。
var prog := {
	"level": 1,                 # 主角等级（上限 growth.level_cap）
	"exp": 0,                   # 当前等级已积累经验
	"worlds_unlocked": 1,       # 已解锁世界数（按 maps.json theme_order 顺序推进）
	"world_cleared": {},        # theme_id -> true（已通关该世界）
	"pets": ["pet_rockturtle"], # 已收集宠物 id（初始伙伴：岩龟）
}

# ---------- 主城（据点）状态（跨局持久）----------
# 主城是唯一据点：建筑逐步落成，活动按冷却产出，别的据点会顺着据点码上门拜访。
# built 只记「已落成」的建筑 id；议事厅与城门为起始门面（city.json 里 start == true）。
var city := {
	"built": ["hall", "gate"],  # 已落成建筑 id
	"code": "",                 # 据点码：抄给别人，人家便能上门串门
	"visits": [],               # 来过的据点名（city.json guest_sites 里的名字）
	"acts": {},                 # 活动 id -> 上次领取的 unix 秒
	"day": "",                  # 上次签到日期（YYYY-MM-DD）
	"streak": 0,                # 连续签到天数
}

# ---------- 主城委托（日刷新：接取 → 出征办事 → 回城领赏）----------
# 今日牌只在跨日时重刷；跨日未交付的委托作废（今日事今日毕，不堆任务列表）
var quest := {
	"day": "",        # 上次刷新日期
	"offer": [],      # 今日可接的委托 id
	"active": {},     # 已接委托 id -> 进度
	"claimed": [],    # 今日已交付的 id
}

# ---------- GM 开发者控制台 ----------
# F10 / ` 唤起；输入口令后解锁全部内容与满级，仅供调试。解锁态只存本次运行，不落盘。
const GM_PASSWORD := "@tsz20060706"
# ---------- 音频设置（音量 0~1，存进存档；Audio 自动加载器读它）----------
var audio := {"bgm": 0.7, "sfx": 0.8, "mute": false}


## 播 UI/战斗音效。G 与 Audio 都是自动加载器，**编译期互相引用会成环**：
## 编译器互等对方先编译 → 全项目级联 `Identifier not found: Audio`。
## 所以这边也一律运行时取节点（Audio 侧对称用法见 `Audio._game_state`）。
func _sfx(name: String, jitter := 0.03) -> void:
	var au := get_node_or_null("/root/Audio")
	if au != null:
		au.call("sfx", name, jitter)

# ---------- 演武场（PVP 首版：傀儡对手 + 段位分） ----------
var arena := {"score": 1000, "wins": 0, "losses": 0}

var gm_unlocked := false
var ui_blocked := false     # 全屏浮层（GM 控制台等）打开时为 true，探索层据此冻结移动


# ---------- 输入映射（键位在代码里注册，避免手写 project.godot 的序列化块出错） ----------
## 探索移动：WASD（物理键位，不受输入法/键盘布局影响）+ 方向键；开发控制台：F10 / `
const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"gm_console": [KEY_F10, KEY_QUOTELEFT],
}


func _ensure_input_map() -> void:
	for act in ACTIONS:
		if not InputMap.has_action(act):
			InputMap.add_action(act, 0.2)
		for kc in ACTIONS[act]:
			var ev := InputEventKey.new()
			ev.physical_keycode = kc
			InputMap.action_add_event(act, ev)


func _ready() -> void:
	_ensure_input_map()
	font_reg = load(FONT_REG) as FontFile
	font_bold = load(FONT_BOLD) as FontFile
	font_serif = load(FONT_SERIF) as FontFile
	if font_reg == null:
		push_warning("Noto Sans SC Regular 加载失败")
	if font_bold == null:
		font_bold = font_reg
	if font_serif == null:
		font_serif = font_bold
	elif font_bold != null:
		# 站酷小薇个别字形损坏（「回」渲染成实心黑块，已从 cmap 删映射）；
		# 配 fallback 后坏字/缺字自动走黑体，不再破相
		font_serif.fallbacks = [font_bold]
	_tune_font_rendering()
	_load_roles()
	_load_save()
	ensure_starter_buildings()
	_apply_mouse_cursor()
	# 预热浮层贴图：第一次 G.veil() 走 _build_vignette_tex / _build_hatch_tex，
	# 各 new 一张 Gradient/ImageTexture 会花掉 ~50ms，让 VerifyPerf 的"首开浮层"
	# 直接踩预算。在这里跑一次以后所有面板首开都拿缓存，零开销。
	_build_vignette_tex()
	_build_hatch_tex()


## 字体渲染调优（"字体难看"的根治点，全部集中在 G 一处，页面不准各自设）
## 问题：字体的 .import 里 hinting=3（全量 hinting）+ force_autohinter=false。
## Noto Sans SC 这类大字库在小字号（13/16px）下走 hinting 会把汉字笔画强行对齐像素格，
## 「攒/攀」这类多笔画字会糊成一团、横竖粗细不均——这就是界面里"字很丑"的主因。
## 做法：字号 < 20 时关掉 hinting、开轻量抗锯齿，笔画回到设计字形；大字号保持 hinting
## 让标题边缘更锐利（标题字号大，不吃 hinting 的变形）。
func _tune_font_rendering() -> void:
	for f in [font_reg, font_bold, font_serif]:
		if f == null:
			continue
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		f.force_autohinter = false
		f.hinting = TextServer.HINTING_NONE if _is_small_face(f) else TextServer.HINTING_LIGHT
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY


## 小字号字体（正文字体）：全局关 hinting；标题用宋体保留轻 hinting
func _is_small_face(f: FontFile) -> bool:
	return f == font_reg or f == font_bold


## 全局鼠标指针：金剑（Kenney CC0，ui_kenney/cursorSword_gold），剑尖为热点。
## 热点必须压在剑尖上：贴图 34×37，刃尖在左上 (0,1)。此前写 (4,33)（=贴图左下角的空白），
## 等于把整把剑画到鼠标上方 32px——玩家拿剑尖去点按钮，实际落点在剑尖下方 32px，
## 于是「按钮经常点不动」。这是"点击失灵"的真凶，不是控件被挡。
func _apply_mouse_cursor() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var tex := res_tex("cursorSword_gold")
	if tex != null:
		Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, Vector2(1, 1))


## 读档：恢复钱包与角色档案（无存档/坏档保持默认，不报错弹窗——挫败感克制）
func _load_save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		push_warning("存档解析失败，沿用默认状态")
		return
	var data := parsed as Dictionary
	var w: Variant = data.get("wallet", {})
	if w is Dictionary:
		for k in ["gold", "expedition", "soul", "honor"]:
			wallet[k] = int((w as Dictionary).get(k, 0))
	var rid := String(data.get("selected_role", ""))
	if not rid.is_empty() and not get_role(rid).is_empty():
		selected_role = rid
	var acc := String(data.get("account", ""))
	if not acc.is_empty():
		account = acc
	var nm := String(data.get("player_name", ""))
	if not nm.is_empty():
		player_name = nm
	var gd := String(data.get("gender", ""))
	if not gd.is_empty():
		gender = gd
	var aid := String(data.get("avatar_id", ""))
	if not aid.is_empty() and not get_role(aid).is_empty():
		avatar_id = aid
	# 读档可能在同一进程里被测试/导入流程再次调用，先失效缓存再验证文件，
	# 否则上一轮的 null 缓存会让刚读回的自定义头像被误判成不存在。
	avatar_custom = String(data.get("avatar_custom", ""))
	_avatar_tex_done = false
	_avatar_tex = null
	avatar_use_custom = bool(data.get("avatar_use_custom", false))
	if avatar_use_custom and not has_custom_avatar():
		avatar_use_custom = false   # 图被系统清了就退回职业头像，别让主页头像开天窗
	var au: Variant = data.get("audio", {})
	if au is Dictionary:
		var ad := au as Dictionary
		audio["bgm"] = clampf(float(ad.get("bgm", 0.7)), 0.0, 1.0)
		audio["sfx"] = clampf(float(ad.get("sfx", 0.8)), 0.0, 1.0)
		audio["mute"] = bool(ad.get("mute", false))
	var its: Variant = data.get("items", {})
	if its is Dictionary:
		for k in (its as Dictionary):
			items[String(k)] = maxi(0, int((its as Dictionary)[k]))
	var p: Variant = data.get("prog", {})
	if p is Dictionary:
		var pd := p as Dictionary
		prog["level"] = maxi(1, int(pd.get("level", 1)))
		prog["exp"] = maxi(0, int(pd.get("exp", 0)))
		prog["worlds_unlocked"] = clampi(int(pd.get("worlds_unlocked", 1)), 1, maxi(1, world_count()))
		var wc: Variant = pd.get("world_cleared", {})
		prog["world_cleared"] = wc if wc is Dictionary else {}
		var ps: Variant = pd.get("pets", [])
		prog["pets"] = ps if ps is Array else []
		# 养成 6 线字段（老存档缺省补默认，向后兼容）
		var tl: Variant = pd.get("talents", {})
		prog["talents"] = tl if tl is Dictionary else {}
		var eq: Variant = pd.get("equip", {})
		prog["equip"] = eq if eq is Dictionary else {}
		var sk: Variant = pd.get("skills", {})
		prog["skills"] = sk if sk is Dictionary else {}
		var mt: Variant = pd.get("mounts", {})
		prog["mounts"] = mt if mt is Dictionary else {"owned": {}, "active": ""}
		var ti: Variant = pd.get("titles", {})
		prog["titles"] = ti if ti is Dictionary else {"owned": [], "active": ""}
		var pst: Variant = pd.get("pet_stat", {})
		prog["pet_stat"] = pst if pst is Dictionary else {}
		var ts: Variant = pd.get("tips_seen", {})   # 已看过的引导弹层，别每次开面板都弹
		prog["tips_seen"] = ts if ts is Dictionary else {}
		prog["lore_seen"] = bool(pd.get("lore_seen", false))   # 序章是否已看（看过的老档不再弹）
		var lb: Variant = pd.get("lore_beats", {})   # 已演过的剧情节拍（首领前对峙/战后余韵）
		prog["lore_beats"] = lb if lb is Dictionary else {}
		var setg: Variant = pd.get("settings", {})   # 玩家设置（震屏/剧情演出/战斗默认倍速）
		prog["settings"] = setg if setg is Dictionary else {}
	ensure_starter_pets()
	var c: Variant = data.get("city", {})
	if c is Dictionary:
		var cd := c as Dictionary
		var bl: Variant = cd.get("built", [])
		city["built"] = bl if bl is Array else []
		city["code"] = String(cd.get("code", ""))
		var vs: Variant = cd.get("visits", [])
		city["visits"] = vs if vs is Array else []
		var ac: Variant = cd.get("acts", {})
		city["acts"] = ac if ac is Dictionary else {}
		city["day"] = String(cd.get("day", ""))
		city["streak"] = maxi(0, int(cd.get("streak", 0)))
	var av: Variant = data.get("arena", {})
	if av is Dictionary:
		var ad := av as Dictionary
		arena["score"] = clampi(int(ad.get("score", 1000)), 0, 999999)
		arena["wins"] = maxi(0, int(ad.get("wins", 0)))
		arena["losses"] = maxi(0, int(ad.get("losses", 0)))
	var q: Variant = data.get("quest", {})
	if q is Dictionary:
		var qd := q as Dictionary
		quest["day"] = String(qd.get("day", ""))
		var of: Variant = qd.get("offer", [])
		quest["offer"] = of if of is Array else []
		var aq: Variant = qd.get("active", {})
		quest["active"] = aq if aq is Dictionary else {}
		var cl: Variant = qd.get("claimed", [])
		quest["claimed"] = cl if cl is Array else []


## 存档：钱包四币 + 养成进度 + 角色档案（远征结算入账 / 主城关键节点时写）
func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"wallet": {
			"gold": int(wallet.get("gold", 0)),
			"expedition": int(wallet.get("expedition", 0)),
			"soul": int(wallet.get("soul", 0)),
			"honor": int(wallet.get("honor", 0)),
		},
		"prog": prog,
		"city": city,
		"quest": quest,
		"arena": arena,
		"items": items,
		"audio": audio,
		"account": account,
		"gender": gender,
		"avatar_id": avatar_id,
		"avatar_custom": avatar_custom,
		"avatar_use_custom": avatar_use_custom,
		"player_name": player_name,
		"selected_role": selected_role,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("存档写入失败：" + SAVE_PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


## 局结算入账（战败亦保留——失败无惩罚）并落盘
func deposit(gold: int, expedition: int, soul: int, honor := 0) -> void:
	wallet["gold"] = int(wallet.get("gold", 0)) + gold
	wallet["expedition"] = int(wallet.get("expedition", 0)) + expedition
	wallet["soul"] = int(wallet.get("soul", 0)) + soul
	wallet["honor"] = int(wallet.get("honor", 0)) + honor
	save_game()


# ================= 养成进度 =================

func level_cap() -> int:
	return int(TableCache.growth().get("level_cap", 60))


## 升到 lv+1 所需经验；已满级返回 0
func exp_to_next(level: int) -> int:
	if level >= level_cap():
		return 0
	return TableCache.exp_to_next(level)


## 加经验并逐级结算，返回本次提升的级数
func gain_exp(amount: int) -> int:
	if amount <= 0:
		return 0
	var cap := level_cap()
	if int(prog.get("level", 1)) >= cap:
		prog["level"] = cap
		prog["exp"] = 0
		save_game()
		return 0
	prog["exp"] = int(prog.get("exp", 0)) + amount
	var ups := 0
	while int(prog["level"]) < cap:
		var need := exp_to_next(int(prog["level"]))
		if need <= 0 or int(prog["exp"]) < need:
			break
		prog["exp"] = int(prog["exp"]) - need
		prog["level"] = int(prog["level"]) + 1
		ups += 1
	if int(prog["level"]) >= cap:
		prog["level"] = cap
		prog["exp"] = 0
	if ups > 0:
		_sfx("level_up", 0.0)   # 升级音不抖音高：这是"仪式"，不是随机反馈
	save_game()
	return ups


func theme_order() -> Array:
	return TableCache.maps_config().get("theme_order", [])


func world_count() -> int:
	return theme_order().size()


func is_world_unlocked(theme_id: String) -> bool:
	var idx := theme_order().find(theme_id)
	return idx >= 0 and idx < int(prog.get("worlds_unlocked", 1))


func is_world_cleared(theme_id: String) -> bool:
	var wc: Dictionary = prog.get("world_cleared", {})
	return bool(wc.get(theme_id, false))


## 已讨伐首领的世界数（与「已解锁」是两回事：解锁=能进，通关=首领倒下）
func cleared_world_count() -> int:
	return (prog.get("world_cleared", {}) as Dictionary).size()


## 扫荡已通关世界：消耗 1 张扫荡券，按 nodes.json 标准路线（3 遭遇 + 首领）的
## rewards × sweep_yield 折算一键入账；未通关 / 券不足返回空字典（不动存档）
func sweep_world(theme_id: String) -> Dictionary:
	if not is_world_cleared(theme_id):
		return {}
	if not consume_item("ticket_sweep", 1):
		return {}
	var nodes_cfg: Dictionary = TableCache.nodes_config()
	var rewards: Dictionary = nodes_cfg.get("rewards", {})
	var yield_pct := float(nodes_cfg.get("sweep_yield", 0.7))
	var gains := {"gold": 0, "expedition": 0, "soul": 0, "exp": 0, "honor": 0}
	for kind in ["normal", "normal", "normal", "boss"]:
		var row: Dictionary = rewards.get(kind, {})
		for k in gains:
			gains[k] += int(row.get(k, 0))
	for k in gains:
		gains[k] = int(float(gains[k]) * yield_pct)
	deposit(int(gains["gold"]), int(gains["expedition"]), int(gains["soul"]), int(gains["honor"]))
	gains["level_ups"] = gain_exp(int(gains["exp"]))
	return gains


## 世界进度文案：「苍绿林海」等
func world_name(theme_id: String) -> String:
	return String(TableCache.theme_config(theme_id).get("name", theme_id))


## 通关某世界：标记通关 → 解锁下一世界 → 解封该世界对应的宠物；返回本次新解锁的世界名（无则空串）
func on_world_cleared(theme_id: String) -> String:
	var wc: Dictionary = prog.get("world_cleared", {})
	wc[theme_id] = true
	prog["world_cleared"] = wc
	var opened := ""
	var idx := theme_order().find(theme_id)
	var before := int(prog.get("worlds_unlocked", 1))
	if idx >= 0 and idx + 1 < world_count() and idx + 1 >= before:
		prog["worlds_unlocked"] = idx + 2
		opened = world_name(String(theme_order()[idx + 1]))
	unlock_pets_for_world(theme_id)
	quest_report("clear", theme_id)   # 「讨伐某秘境首领」类委托的钩子：通关即上报
	save_game()
	return opened


func owns_pet(pid: String) -> bool:
	return (prog.get("pets", []) as Array).has(pid)


func owned_pets() -> Array:
	return prog.get("pets", [])


## 收集宠物；返回是否为新解锁
func collect_pet(pid: String) -> bool:
	if owns_pet(pid) or TableCache.get_pet(pid).is_empty():
		return false
	var arr: Array = prog.get("pets", [])
	arr.append(pid)
	prog["pets"] = arr
	save_game()
	return true


## 按 pets.json 的 unlock 规则，解封"通关某世界"可得的宠物
func unlock_pets_for_world(theme_id: String) -> void:
	var arr: Array = prog.get("pets", [])
	var changed := false
	for p in TableCache.pets():
		var pd := p as Dictionary
		var u: Dictionary = pd.get("unlock", {})
		if String(u.get("type", "")) != "world_clear":
			continue
		if String(u.get("world", "")) != theme_id:
			continue
		var pid := String(pd.get("id", ""))
		if pid != "" and not arr.has(pid):
			arr.append(pid)
			changed = true
	if changed:
		prog["pets"] = arr


## 保底：初始伙伴（pets.json 里 unlock.type == "starter"）永远在册。
## 老存档 pets 为空 / 被改坏时，也不至于开局无宠可带、出征被门禁卡死。
func ensure_starter_pets() -> void:
	var arr: Array = prog.get("pets", [])
	var changed := false
	for p in TableCache.pets():
		var pd := p as Dictionary
		if String((pd.get("unlock", {}) as Dictionary).get("type", "")) != "starter":
			continue
		var pid := String(pd.get("id", ""))
		if pid != "" and not arr.has(pid):
			arr.append(pid)
			changed = true
	if changed:
		prog["pets"] = arr


## 宠物解锁条件文案（图鉴锁定卡显示）
func pet_unlock_text(pid: String) -> String:
	var u: Dictionary = TableCache.get_pet(pid).get("unlock", {})
	match String(u.get("type", "")):
		"starter":
			return "初始伙伴"
		"world_clear":
			return "通关「%s」首领" % world_name(String(u.get("world", "")))
	return "未知途径"


# ================= 主城（据点） =================
# 数据源 data/city.json：建筑（程序绘制，按 style 分支）、NPC（对话池）、活动（冷却产出）。

const REWARD_KEYS := ["gold", "expedition", "soul", "honor", "exp"]
const REWARD_NAMES := {
	"gold": "金币", "expedition": "远征点", "soul": "魂晶", "honor": "荣誉", "exp": "经验",
}


func city_config() -> Dictionary:
	return TableCache.city_config()


func city_name() -> String:
	return String(city_config().get("name", "远征主城"))


func now_ts() -> int:
	return int(Time.get_unix_time_from_system())


## 当日键（YYYY-MM-DD）。签到翻篇、今日来客都按它算。
func today_key() -> String:
	return Time.get_date_string_from_unix_time(now_ts())


# ---------- 建筑 ----------

## 起始门面：city.json 里 start == true 的若干座永远在册；顺带滤掉配置里已不存在的旧 id。
## 抽成幂等函数，老存档 / 空存档 / 配置改名都不会让主城变成一块空地。
func ensure_starter_buildings() -> void:
	var bs: Array = city_config().get("buildings", [])
	var valid: Array = []
	for b in bs:
		valid.append(String((b as Dictionary).get("id", "")))
	var out: Array = []
	for x in city.get("built", []):
		var sid := String(x)
		if (valid.is_empty() or valid.has(sid)) and not out.has(sid):
			out.append(sid)
	for b in bs:
		var bd := b as Dictionary
		if not bool(bd.get("start", false)):
			continue
		var bid := String(bd.get("id", ""))
		if bid != "" and not out.has(bid):
			out.append(bid)
	city["built"] = out


func city_buildings() -> Array:
	return city_config().get("buildings", [])


## 单座建筑配置，附带 built 状态（主城绘制 / 布告板都用它）
func city_building(id: String) -> Dictionary:
	for b in city_buildings():
		if String((b as Dictionary).get("id", "")) == id:
			return b
	return {}


func is_built(id: String) -> bool:
	return (city.get("built", []) as Array).has(id)


func has_cost(cost: Dictionary) -> bool:
	for k in cost.keys():
		if int(wallet.get(String(k), 0)) < int(cost[k]):
			return false
	return true


func pay_cost(cost: Dictionary) -> void:
	for k in cost.keys():
		wallet[String(k)] = int(wallet.get(String(k), 0)) - int(cost[k])


## 现在能不能建：可建类（kind == "func"）、未落成、等级够、资源够
func can_build(id: String) -> bool:
	var b := city_building(id)
	if b.is_empty() or is_built(id):
		return false
	if String(b.get("kind", "")) != "func":
		return false
	if int(prog.get("level", 1)) < int(b.get("min_level", 1)):
		return false
	return has_cost(b.get("cost", {}))


## 建造：扣资源 → 落成 → 落盘；返回是否成功
func build(id: String) -> bool:
	if not can_build(id):
		return false
	pay_cost(city_building(id).get("cost", {}))
	var arr: Array = city.get("built", [])
	arr.append(id)
	city["built"] = arr
	save_game()
	return true


## 建筑状态文案（布告板按钮用）：已落成 / 可建造 / 等级不足 / 资源不足 / 尚未开放
func build_state(id: String) -> String:
	var b := city_building(id)
	if b.is_empty():
		return "未知"
	if is_built(id):
		return "已落成"
	if String(b.get("kind", "")) == "soon":
		return "尚未开放"
	if String(b.get("kind", "")) == "core":
		return "门面"
	if int(prog.get("level", 1)) < int(b.get("min_level", 1)):
		return "需 Lv.%d" % int(b.get("min_level", 1))
	if not has_cost(b.get("cost", {})):
		return "资源不足"
	return "可建造"


# ---------- NPC ----------

## 在城里的 NPC：need 为空即常驻，否则要那座建筑已落成
func city_npcs() -> Array:
	var out: Array = []
	for n in city_config().get("npcs", []):
		var nd := n as Dictionary
		var need := String(nd.get("need", ""))
		if need != "" and not is_built(need):
			continue
		out.append(nd)
	return out


func city_npc(id: String) -> Dictionary:
	for n in city_config().get("npcs", []):
		if String((n as Dictionary).get("id", "")) == id:
			return n
	return {}


## 取一句对话：按「当天 + NPC + 已聊次数」推进，避免每次都是同一句
func npc_line(id: String, turn: int) -> String:
	var lines: Array = city_npc(id).get("lines", [])
	if lines.is_empty():
		return ""
	var k := absi((today_key() + id).hash()) + turn
	return String(lines[k % lines.size()])


# ---------- 活动 ----------

func city_activities() -> Array:
	return city_config().get("activities", [])


func city_activity(id: String) -> Dictionary:
	for a in city_activities():
		if String((a as Dictionary).get("id", "")) == id:
			return a
	return {}


## 冷却剩余秒数；0 表示可以领。daily 活动翻篇前返回「到明日的秒数」。
func activity_left(id: String) -> int:
	var a := city_activity(id)
	if a.is_empty():
		return 0
	if bool(a.get("daily", false)):
		if String(city.get("day", "")) != today_key():
			return 0
		var d := Time.get_datetime_dict_from_unix_time(now_ts())
		var passed := int(d.get("hour", 0)) * 3600 + int(d.get("minute", 0)) * 60 + int(d.get("second", 0))
		return maxi(1, 86400 - passed)
	var cd := int(a.get("cd", 0))
	if cd <= 0:
		return 0
	return maxi(0, cd - (now_ts() - int((city.get("acts", {}) as Dictionary).get(id, 0))))


## 依赖建筑已落成 + 冷却已过 + 消耗付得起
func activity_ready(id: String) -> bool:
	var a := city_activity(id)
	if a.is_empty():
		return false
	var need := String(a.get("need", ""))
	if need != "" and not is_built(need):
		return false
	if activity_left(id) > 0:
		return false
	return has_cost(a.get("cost", {}))


func activity_state(id: String) -> String:
	var a := city_activity(id)
	if a.is_empty():
		return "未知"
	var need := String(a.get("need", ""))
	if need != "" and not is_built(need):
		return "需先建「%s」" % String(city_building(need).get("name", "建筑"))
	if not has_cost(a.get("cost", {})):
		return "资源不足"
	var left := activity_left(id)
	if left > 0:
		return "冷却 %s" % _left_text(left)
	return "可领取"


func _left_text(sec: int) -> String:
	if sec >= 3600:
		return "%d时%d分" % [sec / 3600, (sec % 3600) / 60]
	if sec >= 60:
		return "%d分" % (sec / 60)
	return "%d秒" % sec


func apply_reward(reward: Dictionary) -> void:
	if reward.is_empty():
		return
	deposit(
		int(reward.get("gold", 0)), int(reward.get("expedition", 0)),
		int(reward.get("soul", 0)), int(reward.get("honor", 0))
	)
	if int(reward.get("exp", 0)) > 0:
		gain_exp(int(reward.get("exp", 0)))


func reward_lines(reward: Dictionary) -> Array:
	var out: Array = []
	for k in REWARD_KEYS:
		if int(reward.get(k, 0)) > 0:
			out.append("%s +%d" % [String(REWARD_NAMES.get(k, k)), int(reward[k])])
	return out


## 领取活动：校验 → 扣消耗 → 结算签到连击 → 发奖 → 落盘。
## 返回 { ok, name, lines, err }；调用方直接把 lines 丢给 toast。
func do_activity(id: String) -> Dictionary:
	var a := city_activity(id)
	if a.is_empty():
		return {"ok": false, "err": "没有这项活动"}
	var need := String(a.get("need", ""))
	if need != "" and not is_built(need):
		return {"ok": false, "err": "「%s」还没落成" % String(city_building(need).get("name", "建筑"))}
	if activity_left(id) > 0:
		return {"ok": false, "err": "还得再等等"}
	if not has_cost(a.get("cost", {})):
		return {"ok": false, "err": "资源不够"}
	pay_cost(a.get("cost", {}))
	var reward := (a.get("reward", {}) as Dictionary).duplicate()
	var lines: Array = []
	if bool(a.get("daily", false)):
		var prev := String(city.get("day", ""))
		var yday := Time.get_date_string_from_unix_time(now_ts() - 86400)
		if prev == yday:
			city["streak"] = int(city.get("streak", 0)) + 1
		else:
			city["streak"] = 1
		city["day"] = today_key()
		var bonus: Dictionary = a.get("streak_bonus", {})
		if int(city["streak"]) > 1 and not bonus.is_empty():
			for k in bonus.keys():
				reward[k] = int(reward.get(k, 0)) + int(bonus[k])
			lines.append("连着第 %d 天，灯油又添厚了一层" % int(city["streak"]))
	apply_reward(reward)
	var acts: Dictionary = city.get("acts", {})
	acts[id] = now_ts()
	city["acts"] = acts
	save_game()
	lines.append_array(reward_lines(reward))
	return {"ok": true, "name": String(a.get("name", "")), "lines": lines}


# ---------- 据点码 / 拜访 ----------

## 据点码：首次需要时按账号确定性生成，此后稳定不变
func city_code() -> String:
	var c := String(city.get("code", ""))
	if c.is_empty():
		c = _make_city_code()
		city["code"] = c
		save_game()
	return c


func _make_city_code() -> String:
	const POOL := "ACDEFGHJKLMNPQRTUVWXY34679"
	var rng := RandomNumberGenerator.new()
	rng.seed = int((account + "|" + player_name + "|" + selected_role).hash())
	var out := ""
	for i in 6:
		out += POOL.substr(rng.randi_range(0, POOL.length() - 1), 1)
	return out


## 记一笔来访（同一据点只记一次）；返回是否为新访客
func add_visitor(site: String) -> bool:
	if site.is_empty():
		return false
	var arr: Array = city.get("visits", [])
	if arr.has(site):
		return false
	arr.append(site)
	city["visits"] = arr
	save_game()
	return true


func city_visits() -> Array:
	return city.get("visits", [])


## 今日来客：按「当天 + 据点码」确定性抽取若干（纯展示，不落盘，次日自动换人）
func today_guests(count := 3) -> Array:
	var pool: Array = city_config().get("guest_sites", [])
	if pool.is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = int((today_key() + "|" + city_code()).hash())
	var out: Array = []
	var guard := 0
	while out.size() < mini(count, pool.size()) and guard < 128:
		guard += 1
		var name := String(pool[rng.randi_range(0, pool.size() - 1)])
		if not out.has(name):
			out.append(name)
	return out


## 访客留言：同一访客当天固定一句
func guest_note(site: String) -> String:
	var notes: Array = city_config().get("guest_notes", [])
	if notes.is_empty():
		return ""
	return String(notes[absi((today_key() + "|" + site).hash()) % notes.size()])


func has_profile() -> bool:
	return not selected_role.is_empty() and not player_name.is_empty()


# ================= 养成 6 线（§6：天赋/装备/宠物/技能书/坐骑/称号） =================
# 全部表驱动：talents.json / equip.json / skillbook.json / mounts.json / titles.json。
# 存档字段 prog.{talents,equip,skills,mounts,titles,pet_stat}，旧档缺省补默认。

## 道具图标名：背包 id 无 itm_ 前缀，素材名有；gem_* 素材与 id 同名
func item_icon(item_id: String) -> String:
	if item_id.begins_with("gem_"):
		return item_id
	return "itm_" + item_id


# ---------- 天赋树（每 5 级 1 点，三系×10 节点，tier 递增解锁） ----------

func talents_cfg() -> Dictionary:
	return TableCache.talents_config()


func talent_points_total() -> int:
	var per := int(talents_cfg().get("points_per_levels", 5))
	return int(prog.get("level", 1)) / maxi(1, per)


func talent_points_spent() -> int:
	var n := 0
	for k in (prog.get("talents", {}) as Dictionary):
		n += int((prog["talents"] as Dictionary)[k])
	return n


func talent_points_left() -> int:
	return maxi(0, talent_points_total() - talent_points_spent())


## 全节点平铺查找（带 branch 字段回写）
func talent_node(node_id: String) -> Dictionary:
	for b in talents_cfg().get("branches", []):
		var bd := b as Dictionary
		for nd in bd.get("nodes", []):
			var n := nd as Dictionary
			if String(n.get("id", "")) == node_id:
				var out := n.duplicate()
				out["branch"] = String(bd.get("id", ""))
				return out
	return {}


func talent_branch_spent(branch_id: String) -> int:
	var n := 0
	var b: Dictionary = {}
	for bb in talents_cfg().get("branches", []):
		if String((bb as Dictionary).get("id", "")) == branch_id:
			b = bb
			break
	for nd in b.get("nodes", []):
		n += int((prog.get("talents", {}) as Dictionary).get(String((nd as Dictionary).get("id", "")), 0))
	return n


## 能否加点：有剩余点 + 未点满 + 本系已投点数 ≥ tier-1
func talent_can_add(node_id: String) -> bool:
	var n := talent_node(node_id)
	if n.is_empty() or talent_points_left() <= 0:
		return false
	var cur := int((prog.get("talents", {}) as Dictionary).get(node_id, 0))
	if cur >= int(n.get("max", 1)):
		return false
	return talent_branch_spent(String(n.get("branch", ""))) >= int(n.get("tier", 1)) - 1


func talent_add(node_id: String) -> bool:
	if not talent_can_add(node_id):
		return false
	var tl: Dictionary = prog.get("talents", {})
	tl[node_id] = int(tl.get(node_id, 0)) + 1
	prog["talents"] = tl
	save_game()
	return true


# ---------- 装备（强化 + 宝石 + 精炼；武器 4 系绑人物，甲/饰通用） ----------

func equip_cfg() -> Dictionary:
	return TableCache.equip_config()


func equip_slot_cfg(slot_id: String) -> Dictionary:
	for s in equip_cfg().get("slots", []):
		if String((s as Dictionary).get("id", "")) == slot_id:
			return s
	return {}


## 当前角色对应的武器槽（剑→破军/枪→穿杨/杖→霜语/锤→晨星）
func equip_weapon_slot(role_id := "") -> String:
	var rid := role_id if not role_id.is_empty() else selected_role
	for s in equip_cfg().get("slots", []):
		var sd := s as Dictionary
		if String(sd.get("kind", "")) == "weapon" and String(sd.get("role", "")) == rid:
			return String(sd.get("id", ""))
	return ""


## 装备槽存档状态（缺省：0 级 / 无宝石 / 无词条）
func equip_state(slot_id: String) -> Dictionary:
	var all: Dictionary = prog.get("equip", {})
	var st: Variant = all.get(slot_id, {})
	if not (st is Dictionary):
		st = {}
	var d := st as Dictionary
	if not d.has("lv"):
		d["lv"] = 0
	if not (d.get("gems") is Array):
		d["gems"] = []
	if not (d.get("affixes") is Array):
		d["affixes"] = []
	return d


func _equip_save_state(slot_id: String, st: Dictionary) -> void:
	var all: Dictionary = prog.get("equip", {})
	all[slot_id] = st
	prog["equip"] = all
	save_game()


func equip_enhance_max() -> int:
	return int((equip_cfg().get("enhance", {}) as Dictionary).get("max_level", 20))


## 强化消耗：金币 base+step×当前级；强化石 base + 每 5 级 +1
func equip_enhance_cost(slot_id: String) -> Dictionary:
	var ec: Dictionary = equip_cfg().get("enhance", {})
	var lv := int(equip_state(slot_id).get("lv", 0))
	return {
		"gold": int(ec.get("cost_gold_base", 150)) + int(ec.get("cost_gold_step", 150)) * lv,
		"item": String(ec.get("cost_item", "enhance_stone")),
		"item_n": int(ec.get("cost_item_base", 1)) + lv / 5 * int(ec.get("cost_item_per_5", 1)),
	}


## 强化成功率 = 0.9^目标级（失败不掉级）
func equip_enhance_rate(slot_id: String) -> float:
	var ec: Dictionary = equip_cfg().get("enhance", {})
	var target := int(equip_state(slot_id).get("lv", 0)) + 1
	return pow(float(ec.get("success_base", 0.9)), float(target))


## 强化：校验 → 扣费 → 掷点（失败不掉级）；返回 {ok, success, err}
func equip_enhance(slot_id: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var cfg := equip_slot_cfg(slot_id)
	if cfg.is_empty():
		return {"ok": false, "err": "没有这个装备槽"}
	var st := equip_state(slot_id)
	var lv := int(st.get("lv", 0))
	if lv >= equip_enhance_max():
		return {"ok": false, "err": "已强化至上限"}
	var cost := equip_enhance_cost(slot_id)
	if int(wallet.get("gold", 0)) < int(cost["gold"]):
		return {"ok": false, "err": "金币不足"}
	if item_count(String(cost["item"])) < int(cost["item_n"]):
		return {"ok": false, "err": "强化石不足"}
	wallet["gold"] = int(wallet.get("gold", 0)) - int(cost["gold"])
	consume_item(String(cost["item"]), int(cost["item_n"]))
	var r := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var ok := r.randf() < equip_enhance_rate(slot_id)
	if ok:
		st["lv"] = lv + 1
		_equip_save_state(slot_id, st)
	else:
		save_game()
	return {"ok": true, "success": ok, "lv": int(st.get("lv", 0))}


## 槽位强化后基础属性 = base × (1 + 0.1×lv)
func equip_base_stat(slot_id: String) -> Dictionary:
	var base: Dictionary = equip_slot_cfg(slot_id).get("base", {})
	var lv := int(equip_state(slot_id).get("lv", 0))
	var mult := 1.0 + float(equip_cfg().get("enhance", {}).get("pct_per_level", 0.1)) * lv
	var out := {}
	for k in base.keys():
		if String(k) == "crit":
			out[k] = float(base[k])  # 暴击值不吃强化倍率
		else:
			out[k] = int(roundf(float(base[k]) * mult))
	return out


## 宝石孔位（未开孔的槽位 gems 数组长度即已用孔数）
func equip_gem_sockets() -> int:
	return int((equip_cfg().get("gems", {}) as Dictionary).get("sockets", 3))


func equip_socket_cost() -> int:
	return int((equip_cfg().get("gems", {}) as Dictionary).get("socket_cost_gold", 200))


func equip_gem_colors() -> Array:
	return (equip_cfg().get("gems", {}) as Dictionary).get("colors", [])


## 宝石数值（gem_id 形如 gem_atk_3）
func equip_gem_value(gem_id: String) -> int:
	for c in equip_gem_colors():
		var cd := c as Dictionary
		var prefix := String(cd.get("id", ""))
		if gem_id.begins_with("gem_%s_" % prefix):
			var lv := int(gem_id.get_slice("_", 2))
			var values: Array = cd.get("values", [])
			if lv >= 1 and lv <= values.size():
				return int(values[lv - 1])
	return 0


## 镶嵌：消耗 1 颗宝石 + 开孔费；孔满返回 false
func equip_socket_gem(slot_id: String, gem_id: String) -> Dictionary:
	var st := equip_state(slot_id)
	var gems: Array = st.get("gems", [])
	if gems.size() >= equip_gem_sockets():
		return {"ok": false, "err": "孔位已满"}
	if equip_gem_value(gem_id) <= 0:
		return {"ok": false, "err": "无效宝石"}
	if item_count(gem_id) < 1:
		return {"ok": false, "err": "没有这颗宝石"}
	var cost := equip_socket_cost()
	if int(wallet.get("gold", 0)) < cost:
		return {"ok": false, "err": "金币不足"}
	wallet["gold"] = int(wallet.get("gold", 0)) - cost
	consume_item(gem_id, 1)
	gems.append(gem_id)
	st["gems"] = gems
	_equip_save_state(slot_id, st)
	return {"ok": true}


## 精炼：重洗未锁定词条（满 4 条）；每条锁定额外耗 1 锁符
func equip_refine(slot_id: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var rc: Dictionary = equip_cfg().get("refine", {})
	var st := equip_state(slot_id)
	var affixes: Array = st.get("affixes", [])
	var locks := 0
	for a in affixes:
		if bool((a as Dictionary).get("locked", false)):
			locks += 1
	var item := String(rc.get("cost_item", "refine_stone"))
	var need_item := int(rc.get("cost_item_n", 2))
	var lock_item := String(rc.get("lock_item", "lock_rune"))
	if item_count(item) < need_item:
		return {"ok": false, "err": "精炼石不足"}
	if item_count(lock_item) < locks:
		return {"ok": false, "err": "锁定符不足"}
	consume_item(item, need_item)
	if locks > 0:
		consume_item(lock_item, locks)
	var r := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var pool: Array = rc.get("pool", [])
	var count := int(rc.get("affix_count", 4))
	while affixes.size() < count:
		affixes.append({"stat": "", "v": 0.0, "locked": false})
	for i in affixes.size():
		var a := affixes[i] as Dictionary
		if bool(a.get("locked", false)):
			continue
		var p := pool[r.randi_range(0, pool.size() - 1)] as Dictionary
		a["stat"] = String(p.get("stat", ""))
		a["v"] = snappedf(r.randf_range(float(p.get("min", 0.0)), float(p.get("max", 0.0))), 0.001)
	affixes.resize(count)
	st["affixes"] = affixes
	_equip_save_state(slot_id, st)
	return {"ok": true, "affixes": affixes}


## 切换词条锁定状态（免费，只是标记）
func equip_toggle_lock(slot_id: String, idx: int) -> void:
	var st := equip_state(slot_id)
	var affixes: Array = st.get("affixes", [])
	if idx >= 0 and idx < affixes.size():
		var a := affixes[idx] as Dictionary
		a["locked"] = not bool(a.get("locked", false))
		_equip_save_state(slot_id, st)


## 槽位总加成（强化基础 + 宝石 + 精炼词条）
func equip_slot_bonus(slot_id: String) -> Dictionary:
	var out := {"atk": 0, "def": 0, "hp": 0, "crit": 0.0,
		"atk_pct": 0.0, "def_pct": 0.0, "maxhp_pct": 0.0, "spd_pct": 0.0, "crit_add": 0.0}
	var base := equip_base_stat(slot_id)
	for k in ["atk", "def", "hp"]:
		out[k] = int(base.get(k, 0))
	out["crit"] = float(base.get("crit", 0.0))
	var st := equip_state(slot_id)
	for g in st.get("gems", []):
		var gid := String(g)
		var v := equip_gem_value(gid)
		if gid.begins_with("gem_atk_"):
			out["atk"] += v
		elif gid.begins_with("gem_def_"):
			out["def"] += v
		elif gid.begins_with("gem_hp_"):
			out["hp"] += v
	for a in st.get("affixes", []):
		var ad := a as Dictionary
		var stat := String(ad.get("stat", ""))
		if out.has(stat):
			out[stat] = float(out[stat]) + float(ad.get("v", 0.0))
	return out


# ---------- 技能书（每级 k+5%，上限 10 级，耗远征币） ----------

func skill_level(sid: String) -> int:
	return maxi(1, int((prog.get("skills", {}) as Dictionary).get(sid, 1)))


func skill_max_level() -> int:
	return int(TableCache.skillbook_config().get("max_level", 10))


## 升到下一级所需远征币；满级返回 0
func skill_upgrade_cost(sid: String) -> int:
	var lv := skill_level(sid)
	if lv >= skill_max_level():
		return 0
	var costs: Array = TableCache.skillbook_config().get("cost_expedition", [])
	if lv - 1 < costs.size():
		return int(costs[lv - 1])
	return int(costs.back()) if not costs.is_empty() else 999


func skill_upgrade(sid: String) -> bool:
	var cost := skill_upgrade_cost(sid)
	if cost <= 0:
		return false
	if int(wallet.get("expedition", 0)) < cost:
		return false
	wallet["expedition"] = int(wallet.get("expedition", 0)) - cost
	var sk: Dictionary = prog.get("skills", {})
	sk[sid] = skill_level(sid) + 1
	prog["skills"] = sk
	save_game()
	return true


## 技能 k 系数加成倍率（每级 +5%）
func skill_k_mult(sid: String) -> float:
	var per := float(TableCache.skillbook_config().get("k_per_level", 0.05))
	return 1.0 + per * float(skill_level(sid) - 1)


# ---------- 坐骑（6 类×2 阶，骑乘加成全局生效） ----------

func mounts_cfg() -> Array:
	return TableCache.mounts_config().get("mounts", [])


func mount_cfg(mid: String) -> Dictionary:
	for m in mounts_cfg():
		if String((m as Dictionary).get("id", "")) == mid:
			return m
	return {}


## 已拥有阶级（0=未拥有，1/2=阶级）
func mount_tier(mid: String) -> int:
	var owned: Dictionary = (prog.get("mounts", {}) as Dictionary).get("owned", {})
	return int(owned.get(mid, 0))


func mount_active() -> String:
	return String((prog.get("mounts", {}) as Dictionary).get("active", ""))


## 购买 1 阶 / 升级 2 阶
func mount_buy(mid: String) -> Dictionary:
	var cfg := mount_cfg(mid)
	if cfg.is_empty():
		return {"ok": false, "err": "没有这只坐骑"}
	var cur := mount_tier(mid)
	var tiers: Array = cfg.get("tiers", [])
	if cur >= tiers.size():
		return {"ok": false, "err": "已升至最高阶"}
	var cost: Dictionary = (tiers[cur] as Dictionary).get("cost", {})
	if not has_cost(cost):
		return {"ok": false, "err": "资源不足"}
	pay_cost(cost)
	var mts: Dictionary = prog.get("mounts", {})
	var owned: Dictionary = mts.get("owned", {})
	owned[mid] = cur + 1
	mts["owned"] = owned
	if mount_active().is_empty():
		mts["active"] = mid
	prog["mounts"] = mts
	save_game()
	return {"ok": true, "tier": cur + 1}


func mount_set_active(mid: String) -> bool:
	if mount_tier(mid) <= 0:
		return false
	var mts: Dictionary = prog.get("mounts", {})
	mts["active"] = mid
	prog["mounts"] = mts
	save_game()
	return true


# ---------- 称号（成就自动解锁 / 荣誉购买，佩戴给小幅加成） ----------

func titles_cfg() -> Array:
	return TableCache.titles_config().get("titles", [])


func title_cfg(tid: String) -> Dictionary:
	for t in titles_cfg():
		if String((t as Dictionary).get("id", "")) == tid:
			return t
	return {}


func title_owned(tid: String) -> bool:
	return ((prog.get("titles", {}) as Dictionary).get("owned", []) as Array).has(tid)


## 条件是否达成（level / clear_world / pets / gold）
func title_cond_met(t: Dictionary) -> bool:
	var cond: Dictionary = t.get("cond", {})
	if cond.is_empty():
		return false
	match String(cond.get("type", "")):
		"level":
			return int(prog.get("level", 1)) >= int(cond.get("n", 1))
		"clear_world":
			return is_world_cleared(String(cond.get("world", "")))
		"pets":
			return owned_pets().size() >= int(cond.get("n", 1))
		"gold":
			return int(wallet.get("gold", 0)) >= int(cond.get("n", 0))
	return false


## 领取称号：条件达成免费；否则按 cost 付荣誉
func title_claim(tid: String) -> Dictionary:
	var t := title_cfg(tid)
	if t.is_empty():
		return {"ok": false, "err": "没有这个称号"}
	if title_owned(tid):
		return {"ok": false, "err": "已拥有"}
	var cost: Dictionary = t.get("cost", {})
	if title_cond_met(t):
		pass
	elif not cost.is_empty() and has_cost(cost):
		pay_cost(cost)
	else:
		return {"ok": false, "err": "条件未达成"}
	var ts: Dictionary = prog.get("titles", {})
	var owned: Array = ts.get("owned", [])
	owned.append(tid)
	ts["owned"] = owned
	if String(ts.get("active", "")).is_empty():
		ts["active"] = tid
	prog["titles"] = ts
	save_game()
	return {"ok": true}


func title_active() -> String:
	return String((prog.get("titles", {}) as Dictionary).get("active", ""))


func title_set_active(tid: String) -> bool:
	if not tid.is_empty() and not title_owned(tid):
		return false
	var ts: Dictionary = prog.get("titles", {})
	ts["active"] = tid
	prog["titles"] = ts
	save_game()
	return true


# ---------- 宠物养成（升级宠物粮 / 突破晶 / 资质果） ----------

## 宠物养成状态（首次访问时随机资质 1~5 星并落盘）
func pet_stat(pid: String) -> Dictionary:
	var all: Dictionary = prog.get("pet_stat", {})
	var st: Variant = all.get(pid, {})
	if not (st is Dictionary):
		st = {}
	var d := (st as Dictionary).duplicate()
	if not d.has("star"):
		var r := RandomNumberGenerator.new()
		r.randomize()
		d = {"lv": 1, "exp": 0, "star": r.randi_range(1, 5), "brk": 0}
		all[pid] = d
		prog["pet_stat"] = all
		save_game()
	for k in ["lv", "exp", "star", "brk"]:
		if not d.has(k):
			d[k] = 1 if k == "lv" else (3 if k == "star" else 0)
	return d


## 宠物升级经验曲线：50×lv+30；等级不能超过主人
func pet_exp_to_next(lv: int) -> int:
	return 50 * lv + 30


func pet_level(pid: String) -> int:
	return int(pet_stat(pid).get("lv", 1))


## 喂宠物粮：每份 +100 经验，逐级结算（不超过人物等级）
func pet_feed(pid: String) -> Dictionary:
	if not owns_pet(pid):
		return {"ok": false, "err": "尚未收集"}
	var st := pet_stat(pid)
	var lv := int(st.get("lv", 1))
	var cap := int(prog.get("level", 1))
	if lv >= cap:
		return {"ok": false, "err": "已达人物等级上限"}
	if not consume_item("pet_food", 1):
		return {"ok": false, "err": "宠物粮不足"}
	st["exp"] = int(st.get("exp", 0)) + 100
	var ups := 0
	while int(st["lv"]) < cap:
		var need := pet_exp_to_next(int(st["lv"]))
		if int(st["exp"]) < need:
			break
		st["exp"] = int(st["exp"]) - need
		st["lv"] = int(st["lv"]) + 1
		ups += 1
	if int(st["lv"]) >= cap:
		st["lv"] = cap
		st["exp"] = 0
	var all: Dictionary = prog.get("pet_stat", {})
	all[pid] = st
	prog["pet_stat"] = all
	save_game()
	return {"ok": true, "ups": ups, "lv": int(st["lv"])}


## 突破消耗：突破晶 10/15/20/25/30 + 魂石 100×层；每层属性 +8%，上限 5 层
func pet_break_cost(pid: String) -> Dictionary:
	const LAYERS := [10, 15, 20, 25, 30]
	var brk := int(pet_stat(pid).get("brk", 0))
	if brk >= 5:
		return {}
	return {"crystal": LAYERS[brk], "soul": 100 * (brk + 1)}


func pet_break(pid: String) -> Dictionary:
	if not owns_pet(pid):
		return {"ok": false, "err": "尚未收集"}
	var cost := pet_break_cost(pid)
	if cost.is_empty():
		return {"ok": false, "err": "已突破至上限"}
	if item_count("break_crystal") < int(cost["crystal"]):
		return {"ok": false, "err": "突破晶不足"}
	if int(wallet.get("soul", 0)) < int(cost["soul"]):
		return {"ok": false, "err": "灵魂石不足"}
	consume_item("break_crystal", int(cost["crystal"]))
	wallet["soul"] = int(wallet.get("soul", 0)) - int(cost["soul"])
	var all: Dictionary = prog.get("pet_stat", {})
	var st := pet_stat(pid)
	st["brk"] = int(st.get("brk", 0)) + 1
	all[pid] = st
	prog["pet_stat"] = all
	save_game()
	return {"ok": true, "brk": int(st["brk"])}


## 资质重随：耗资质果 ×1，随机 1~5 星
func pet_reroll_star(pid: String) -> Dictionary:
	if not owns_pet(pid):
		return {"ok": false, "err": "尚未收集"}
	if not consume_item("aptitude_fruit", 1):
		return {"ok": false, "err": "资质果不足"}
	var r := RandomNumberGenerator.new()
	r.randomize()
	var all: Dictionary = prog.get("pet_stat", {})
	var st := pet_stat(pid)
	st["star"] = r.randi_range(1, 5)
	all[pid] = st
	prog["pet_stat"] = all
	save_game()
	return {"ok": true, "star": int(st["star"])}


## 宠物战斗属性倍率：突破 +8%/层；资质影响每级成长（1星0.8 / 3星1.2 / 5星1.6）
func pet_stat_mult(pid: String) -> float:
	var st := pet_stat(pid)
	return 1.0 + 0.08 * float(st.get("brk", 0))


func pet_growth_mult(pid: String) -> float:
	return 0.6 + 0.2 * float(pet_stat(pid).get("star", 3))


## 进战斗的宠物养成快照：{pid: {level, stat_mult, growth_mult}}（BattleSim 纯逻辑不读存档）
func battle_pet_stats(pids: Array) -> Dictionary:
	var out := {}
	for pid in pids:
		var id := String(pid)
		if id.is_empty() or not owns_pet(id):
			continue
		var st := pet_stat(id)
		out[id] = {"level": int(st.get("lv", 1)), "stat_mult": pet_stat_mult(id),
			"growth_mult": pet_growth_mult(id)}
	return out


# ---------- 养成总加成聚合（进战斗时由 MapScene 取走） ----------

## 汇总：天赋 + 装备（当前角色武器 + 甲 + 饰）+ 骑乘坐骑 + 佩戴称号
## 返回 {atk_pct, def_pct, maxhp_pct, spd_pct, crit_add, atk_add, def_add, hp_add, energy_pct}
func growth_bonuses(role_id := "") -> Dictionary:
	var out := {"atk_pct": 0.0, "def_pct": 0.0, "maxhp_pct": 0.0, "spd_pct": 0.0,
		"crit_add": 0.0, "atk_add": 0.0, "def_add": 0.0, "hp_add": 0, "energy_pct": 0.0}
	# 天赋
	var tl: Dictionary = prog.get("talents", {})
	for nid in tl.keys():
		var n := talent_node(String(nid))
		if n.is_empty():
			continue
		var eff: Dictionary = n.get("effect", {})
		var pts := int(tl[nid])
		for k in eff.keys():
			if out.has(k):
				out[k] = float(out[k]) + float(eff[k]) * pts
	# 装备：武器取当前角色对应系，甲/饰通用
	var slots := [equip_weapon_slot(role_id), "armor", "accessory"]
	for sid in slots:
		if String(sid).is_empty():
			continue
		var b := equip_slot_bonus(String(sid))
		out["atk_add"] = float(out["atk_add"]) + float(b.get("atk", 0))
		out["def_add"] = float(out["def_add"]) + float(b.get("def", 0))
		out["hp_add"] = int(out["hp_add"]) + int(b.get("hp", 0))
		out["crit_add"] = float(out["crit_add"]) + float(b.get("crit", 0.0))
		for k in ["atk_pct", "def_pct", "maxhp_pct", "spd_pct", "crit_add"]:
			out[k] = float(out[k]) + float(b.get(k, 0.0))
	# 坐骑
	var mid := mount_active()
	if not mid.is_empty() and mount_tier(mid) > 0:
		var tiers: Array = mount_cfg(mid).get("tiers", [])
		var tier_idx := mount_tier(mid) - 1
		if tier_idx >= 0 and tier_idx < tiers.size():
			var bonus: Dictionary = (tiers[tier_idx] as Dictionary).get("bonus", {})
			for k in bonus.keys():
				if out.has(k):
					out[k] = float(out[k]) + float(bonus[k])
	# 称号
	var tid := title_active()
	if not tid.is_empty() and title_owned(tid):
		var bonus: Dictionary = title_cfg(tid).get("bonus", {})
		for k in bonus.keys():
			if out.has(k):
				out[k] = float(out[k]) + float(bonus[k])
	return out


# ================= 主城委托（接取 → 出征办事 → 回城领赏）=================
# 表 data/quests.json，三种 kind：
#   slay    在指定秘境击杀 n 只 —— 战斗胜利回报（MapScene._on_battle_end）
#   clear   讨伐指定秘境首领   —— 与"通关世界"同一个钩子（on_world_cleared 内部上报）
#   deliver 上交 n 个道具       —— 交付时扣物，进度不看击杀

func quests_cfg() -> Dictionary:
	return TableCache.quests_config()


func quest_defs() -> Array:
	var q: Variant = quests_cfg().get("quests", [])
	return q if q is Array else []


func quest_def(qid: String) -> Dictionary:
	for q in quest_defs():
		if String((q as Dictionary).get("id", "")) == qid:
			return q
	return {}


func quest_daily_slots() -> int:
	return maxi(1, int(quests_cfg().get("daily_slots", 2)))


## 今日可接的委托（跨日才重刷；同一天反复调用结果稳定）
func quest_offer() -> Array:
	if String(quest.get("day", "")) != today_key():
		_refresh_quests()
	var o: Variant = quest.get("offer", [])
	return o if o is Array else []


## 刷今日牌：从全部委托里按「日期 + 等级」确定性抽 daily_slots 条（改档不会随机跳）
## 跨日未交付的委托作废——今日事今日毕，不给玩家堆一墙任务
func _refresh_quests() -> void:
	var pool: Array = []
	for q in quest_defs():
		pool.append(String((q as Dictionary).get("id", "")))
	if pool.is_empty():
		quest["day"] = today_key()
		quest["offer"] = []
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int((today_key() + "|" + str(int(prog.get("level", 1)))).hash())
	var pick: Array = []
	var want := mini(quest_daily_slots(), pool.size())
	var guard := 0
	while pick.size() < want and guard < 256:
		guard += 1
		var id := String(pool[rng.randi_range(0, pool.size() - 1)])
		if not pick.has(id):
			pick.append(id)
	quest["day"] = today_key()
	quest["offer"] = pick
	quest["active"] = {}
	quest["claimed"] = []
	save_game()


func quest_active(qid: String) -> bool:
	return (quest.get("active", {}) as Dictionary).has(qid)


func quest_progress(qid: String) -> int:
	return int((quest.get("active", {}) as Dictionary).get(qid, 0))


func quest_need(qid: String) -> int:
	return maxi(1, int(quest_def(qid).get("n", 1)))


func quest_claimed(qid: String) -> bool:
	return (quest.get("claimed", []) as Array).has(qid)


## 交付条件是否已满足（deliver 看道具，其余看进度）
func quest_completed(qid: String) -> bool:
	if not quest_active(qid):
		return false
	var d := quest_def(qid)
	if String(d.get("kind", "")) == "deliver":
		return item_count(String(d.get("item", ""))) >= quest_need(qid)
	return quest_progress(qid) >= quest_need(qid)


## 接取：必须出现在今日牌上、且没交过
func quest_accept(qid: String) -> bool:
	if quest_def(qid).is_empty() or quest_claimed(qid):
		return false
	if not quest_offer().has(qid):
		return false
	var act: Dictionary = quest.get("active", {})
	if act.has(qid):
		return false
	act[qid] = 0
	quest["active"] = act
	save_game()
	return true


## 进度上报：推进所有「进行中且条件匹配」的委托；返回本次刚好做满的委托标题
## （slay 由战斗胜利调用，clear 由 on_world_cleared 调用）
func quest_report(kind: String, target: String, n := 1) -> Array:
	if kind == "deliver":
		return []   # 上交类不看击杀，只在交付时结算
	var act: Dictionary = quest.get("active", {})
	var done: Array = []
	var changed := false
	for qid in act.keys():
		var d := quest_def(String(qid))
		if d.is_empty() or String(d.get("kind", "")) != kind:
			continue
		if String(d.get("theme", "")) != target:
			continue
		var need := maxi(1, int(d.get("n", 1)))
		var cur := int(act[qid])
		if cur >= need:
			continue
		act[qid] = mini(need, cur + n)
		changed = true
		if int(act[qid]) >= need:
			done.append(String(d.get("title", qid)))
	if changed:
		quest["active"] = act
		save_game()
	return done


## 交付：校验 → 扣物/发奖 → 记入今日已交付。返回 {ok, title, lines, npc, err}
func quest_claim(qid: String) -> Dictionary:
	var d := quest_def(qid)
	if d.is_empty():
		return {"ok": false, "err": "没有这条委托"}
	if quest_claimed(qid):
		return {"ok": false, "err": "今天已经交过了"}
	if not quest_active(qid):
		return {"ok": false, "err": "还没接这条委托"}
	if not quest_completed(qid):
		# 上交类要直接说清缺什么，别让玩家对着"还没办完"猜
		if String(d.get("kind", "")) == "deliver":
			var lack := String(d.get("item", ""))
			return {"ok": false, "err": "%s 不够（要 %d 个，现有 %d）"
				% [item_name(lack), quest_need(qid), item_count(lack)]}
		return {"ok": false, "err": "事情还没办完"}
	if String(d.get("kind", "")) == "deliver":
		var iid := String(d.get("item", ""))
		if not consume_item(iid, quest_need(qid)):
			return {"ok": false, "err": "%s 不够" % item_name(iid)}
	var reward: Dictionary = (d.get("reward", {}) as Dictionary).duplicate()
	apply_reward(reward)
	var claimed: Array = quest.get("claimed", [])
	claimed.append(qid)
	quest["claimed"] = claimed
	var act: Dictionary = quest.get("active", {})
	act.erase(qid)
	quest["active"] = act
	save_game()
	return {"ok": true, "title": String(d.get("title", "")),
		"npc": String(d.get("npc", "")), "lines": reward_lines(reward)}


## 委托状态文案（委托板按钮旁用）
func quest_state(qid: String) -> String:
	if quest_claimed(qid):
		return "今日已交付"
	if not quest_active(qid):
		return "未接取"
	if quest_completed(qid):
		return "可交付"
	var d := quest_def(qid)
	if String(d.get("kind", "")) == "deliver":
		var iid := String(d.get("item", ""))
		return "备齐 %d/%d" % [item_count(iid), quest_need(qid)]
	return "进行中 %d/%d" % [quest_progress(qid), quest_need(qid)]


## 主城 HUD 一行：今日委托进度
func quest_today_text() -> String:
	var offer := quest_offer()
	if offer.is_empty():
		return "今日无委托"
	var claimed_n := (quest.get("claimed", []) as Array).size()
	var ready := 0
	for qid in offer:
		var s := String(qid)
		if quest_active(s) and quest_completed(s) and not quest_claimed(s):
			ready += 1
	if ready > 0:
		return "委托 · %d 件可交付" % ready
	return "委托 · %d/%d 已交付" % [claimed_n, offer.size()]


## NPC 的委托台词：身上挂着今日委托的发布者优先说委托（未接/进行中/可交付各一种口吻）
func npc_quest_line(npc_id: String) -> String:
	for qid in quest_offer():
		var s := String(qid)
		var d := quest_def(s)
		if String(d.get("npc", "")) != npc_id:
			continue
		if quest_claimed(s):
			return "「今日的事，谢了。明天再看有什么活儿。」"
		if quest_completed(s):
			return "「看你这身风尘——事情办成了吧？来，把话说给我听。」"
		if quest_active(s):
			return "「%s 的事，不急，但别拖到明日。」" % String(d.get("title", ""))
		return "「有件事正想托人。你来得正好。」"
	return ""


# ================= 世界观与叙事（世界志，表驱动 data/lore.json）=================
# 剧情文本一律走这里读表；改文案只动 data/lore.json，代码不写死句子。

func lore() -> Dictionary:
	return TableCache.lore_config()


func world_setting() -> Dictionary:
	var w: Variant = lore().get("world", {})
	return w if w is Dictionary else {}


func prologue_pages() -> Array:
	var p: Variant = lore().get("prologue", [])
	return p if p is Array else []


## 某处秘境的志异：epigraph（题记）/ lore（正史）/ boss_lore（首领来历）+ name/boss（由表推导）
func theme_lore(theme_id: String) -> Dictionary:
	var all: Variant = lore().get("themes", {})
	var out: Dictionary = {}
	if all is Dictionary and (all as Dictionary).has(theme_id):
		var d: Variant = (all as Dictionary)[theme_id]
		if d is Dictionary:
			out = (d as Dictionary).duplicate()
	out["name"] = world_name(theme_id)
	out["boss"] = theme_boss_name(theme_id)
	return out


## 某秘境首领的素材/数据 id（= monsters.json 的 id；战斗内贴图也按它寻址）
func theme_boss_id(theme_id: String) -> String:
	return String(TableCache.theme_config(theme_id).get("boss", ""))


## 某秘境首领名（从 maps.json 的 boss id 去 monsters.json 取，避免两处各写一份名字）
func theme_boss_name(theme_id: String) -> String:
	var bid := theme_boss_id(theme_id)
	if bid.is_empty():
		return "首领"
	return String(TableCache.get_monster(bid).get("name", bid))


# ---------- 剧情节拍（首领前「对峙」/ 战后「余韵」）----------
# 文本在 lore.json 的 themes.<id>.boss_intro / boss_outro；演出只拦第一次，重复挑战不再播。

## 某段演出的台词；表里没有就返回空数组（调用方据此直接跳过演出）
func boss_beat_lines(theme_id: String, kind: String) -> Array:
	var l: Variant = theme_lore(theme_id).get("boss_%s" % kind, [])
	return l if l is Array else []


## 该秘境某段演出是否已演过
func beat_seen(theme_id: String, kind: String) -> bool:
	var beats: Variant = prog.get("lore_beats", {})
	if not (beats is Dictionary):
		return false
	var per: Variant = (beats as Dictionary).get(theme_id, {})
	if not (per is Dictionary):
		return false
	return bool((per as Dictionary).get(kind, false))


func mark_beat_seen(theme_id: String, kind: String) -> void:
	var d: Dictionary = {}
	var beats: Variant = prog.get("lore_beats", {})
	if beats is Dictionary:
		d = beats as Dictionary
	var p: Dictionary = {}
	var per: Variant = d.get(theme_id, {})
	if per is Dictionary:
		p = per as Dictionary
	p[kind] = true
	d[theme_id] = p
	prog["lore_beats"] = d
	save_game()


func lore_seen() -> bool:
	return bool(prog.get("lore_seen", false))


## 序章看完（或跳过）后落盘：老玩家不再被拦，主城也能提供「重看序章」
func mark_lore_seen() -> void:
	prog["lore_seen"] = true
	save_game()


# ---------- 玩家设置（轮次 15）----------
# 存 prog.settings，跟着存档走：换设备导档后手感设置也一起过去。
# 现有键：shake（受击震屏，默认 true）/ skip_story（剧情演出直接跳过，默认 false）/
#         battle_speed（每场战斗开局默认倍速，默认 1.0）
## 读一项设置（缺省给 def；老档没有 settings 字段也安全）
func setting_get(key: String, def: Variant) -> Variant:
	var s: Variant = prog.get("settings", {})
	if not (s is Dictionary):
		return def
	return (s as Dictionary).get(key, def)


## 写一项设置并落盘（只动某一项，不动其余）
func setting_set(key: String, value: Variant) -> void:
	var d: Dictionary = {}
	var s: Variant = prog.get("settings", {})
	if s is Dictionary:
		d = s as Dictionary
	d[key] = value
	prog["settings"] = d
	save_game()


## 当前主线目标：按 theme_order 找「第一片还没通关的秘境」，连同它的志异一起给出
## 返回 {theme, title, lines}；全部通关则给收束目标
func main_goal() -> Dictionary:
	var goals: Variant = lore().get("goals", {})
	var g: Dictionary = goals if goals is Dictionary else {}
	var order := theme_order()
	var unlocked := int(prog.get("worlds_unlocked", 1))
	for i in order.size():
		var tid := String(order[i])
		if is_world_cleared(tid):
			continue
		var tl := theme_lore(tid)
		var lines: Array = []
		var epi := String(tl.get("epigraph", ""))
		if not epi.is_empty():
			lines.append("「%s」" % epi)
		var lo := String(tl.get("lore", ""))
		if not lo.is_empty():
			lines.append(lo)
		var wd := String(tl.get("warden", ""))
		if not wd.is_empty() and wd != "无":
			lines.append("此地故人：%s" % wd)
		var bl := String(tl.get("boss_lore", ""))
		if not bl.is_empty():
			lines.append(bl)
		var reachable := i + 1 <= unlocked
		var hint := ""
		if reachable:
			hint = String(g.get("next_hint", ""))
			hint = hint.replace("%s", String(tl.get("name", tid)))
		else:
			hint = String(g.get("locked_hint", ""))
		lines.append("")
		lines.append(hint)
		return {
			"theme": tid,
			"title": "当前目标 · 讨伐「%s」" % String(tl.get("boss", "首领")),
			"lines": lines,
		}
	return {
		"theme": "",
		"title": "当前目标",
		"lines": [String(g.get("after_all", "八碑归位。"))],
	}


## 主界面那一行摘要：给个小字行用（不带换行的一行）
func main_goal_short() -> String:
	var goal := main_goal()
	var tid := String(goal.get("theme", ""))
	if tid.is_empty():
		return "八碑归位 · 回王城正殿"
	var tl := theme_lore(tid)
	return "%s · 讨伐「%s」" % [String(tl.get("name", tid)), String(tl.get("boss", "首领"))]


# ================= GM 开发者控制台 =================

func gm_check_password(text: String) -> bool:
	if text == GM_PASSWORD:
		gm_unlocked = true
		return true
	return false


## 一键满配：满级 + 全解锁 + 全宠物 + 资源管够（调试用）
## 注意：只做「解锁」，不伪造「已通关」——两者是不同状态（通关要靠真的打掉首领）
func gm_grant_all() -> void:
	prog["level"] = level_cap()
	prog["exp"] = 0
	prog["worlds_unlocked"] = maxi(1, world_count())
	var pets: Array = []
	for p in TableCache.pets():
		var pid := String((p as Dictionary).get("id", ""))
		if pid != "":
			pets.append(pid)
	prog["pets"] = pets
	wallet["gold"] = 999999
	wallet["expedition"] = 999999
	wallet["soul"] = 999999
	wallet["honor"] = 999999
	items["ticket_ten"] = 99
	items["ticket_sweep"] = 99
	items["enhance_stone"] = 99
	items["refine_stone"] = 99
	items["lock_rune"] = 99
	items["pet_food"] = 99
	items["break_crystal"] = 99
	items["aptitude_fruit"] = 99
	for c in equip_gem_colors():
		for lv in 5:
			items["gem_%s_%d" % [String((c as Dictionary).get("id", "")), lv + 1]] = 9
	save_game()


func gm_max_level() -> void:
	prog["level"] = level_cap()
	prog["exp"] = 0
	save_game()


## 「解锁全部世界」= 全部可出征，但不等于「已通关」：world_cleared 保持原样，等玩家自己打掉首领
func gm_unlock_all_worlds() -> void:
	prog["worlds_unlocked"] = maxi(1, world_count())
	save_game()


## 调试用：把所有世界直接标记为已通关（与「解锁」分开，便于单独验证通关态 UI）
func gm_clear_all_worlds() -> void:
	var cleared: Dictionary = prog.get("world_cleared", {})
	for t in theme_order():
		cleared[String(t)] = true
		unlock_pets_for_world(String(t))
	prog["world_cleared"] = cleared
	save_game()


func gm_unlock_all_pets() -> void:
	var pets: Array = []
	for p in TableCache.pets():
		var pid := String((p as Dictionary).get("id", ""))
		if pid != "":
			pets.append(pid)
	prog["pets"] = pets
	save_game()


func gm_add_currency(amount: int) -> void:
	for k in wallet:
		wallet[k] = int(wallet.get(k, 0)) + amount
	save_game()


func gm_reset_save() -> void:
	prog = {"level": 1, "exp": 0, "worlds_unlocked": 1, "world_cleared": {}, "pets": [],
		"talents": {}, "equip": {}, "skills": {},
		"mounts": {"owned": {}, "active": ""}, "titles": {"owned": [], "active": ""},
		"pet_stat": {}}
	wallet = {"gold": 0, "expedition": 0, "soul": 0, "honor": 0}
	ensure_starter_pets()
	save_game()


func _load_roles() -> void:
	var f := FileAccess.open("res://data/roles.json", FileAccess.READ)
	if f == null:
		push_error("data/roles.json 缺失")
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		roles = parsed


func get_role(id: String) -> Dictionary:
	for r in roles:
		if r.get("id", "") == id:
			return r
	return {}


func role_dir(id: String) -> String:
	# 素材目录映射：zs→zs / ck→ck / fs→fs / fz→fz（image/role/<id>/）
	return "res://image/role/%s/" % id


## 职业立绘文件名（pojun/chuanyang/shuangyu/chenxing）：此前 Login/GameHome 各抄一份，统一收到这里
const ROLE_ART := {"zs": "pojun", "ck": "chuanyang", "fs": "shuangyu", "fz": "chenxing"}


func role_art_name(id: String) -> String:
	return String(ROLE_ART.get(id, id))


## 职业头像贴图路径（未知 id 回落到破军，绝不返回空路径让调用方 load 失败）
func role_icon_path(id: String) -> String:
	var rid := id if not get_role(id).is_empty() else "zs"
	return role_dir(rid) + role_art_name(rid) + "_icon.png"


# ================= 头像（登录页 / 主界面都可上传本地图片） =================
# 口径：上传的图一律居中裁方 → 缩到 256×256 → 存成 PNG。界面端只拿一张方图，
#       不用关心来源尺寸/比例（§6 有限尺寸规格）。
const AVATAR_DIR := "user://avatars/"
const AVATAR_SIZE := 256
var _avatar_tex: Texture2D = null
var _avatar_tex_done := false


## 当前头像贴图：上传过且在用 → 自定义图；否则用职业头像
func avatar_texture() -> Texture2D:
	if avatar_use_custom:
		var t := custom_avatar_texture()
		if t != null:
			return t
	var rid := avatar_id if not get_role(avatar_id).is_empty() else selected_role
	return load(role_icon_path(rid)) as Texture2D


## 已上传的自定义头像贴图（没上传/文件丢了返回 null）
func custom_avatar_texture() -> Texture2D:
	if _avatar_tex_done:
		return _avatar_tex
	_avatar_tex_done = true
	_avatar_tex = _read_avatar_file()
	return _avatar_tex


func has_custom_avatar() -> bool:
	return custom_avatar_texture() != null


## 导入本地图片为头像：读图 → 居中裁方 → 缩到 256 → 转 PNG 落盘 → 立即生效。
## 返回空串=成功，非空=给玩家看的失败原因（不 push_error：选错文件不是程序错误）
func import_avatar(src_path: String) -> String:
	if src_path.is_empty() or not FileAccess.file_exists(src_path):
		return "找不到这张图片"
	var img := Image.new()
	var err := img.load(src_path)
	if err != OK or img.is_empty():
		return "这个文件不是可识别的图片"
	var side := mini(img.get_width(), img.get_height())
	var cut := img.get_region(Rect2i((img.get_width() - side) / 2,
		(img.get_height() - side) / 2, side, side))
	if cut.get_width() != AVATAR_SIZE:
		cut.resize(AVATAR_SIZE, AVATAR_SIZE, Image.INTERPOLATE_LANCZOS)
	# make_dir_recursive_absolute 要求操作系统绝对路径；user:// 先转成本机路径，避免某些平台创建失败。
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(AVATAR_DIR))
	# 微秒参与文件名，连续快速上传也不会覆盖上一张图。
	var file_name := "custom_%d_%d.png" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	if cut.save_png(AVATAR_DIR + file_name) != OK:
		return "头像保存失败，换一张再试"
	var old := avatar_custom
	avatar_custom = file_name
	avatar_use_custom = true
	_reload_avatar_texture()
	save_game()
	_remove_avatar_file(old)   # 旧图不再被引用就删掉，别让 user:// 越攒越多
	return ""


## 切回职业头像（上传的图保留，随时能再切回来）
func use_role_avatar(id: String) -> void:
	if not get_role(id).is_empty():
		avatar_id = id
	avatar_use_custom = false
	save_game()


## 切回上次上传的自定义头像；没上传过返回 false（调用方据此弹选文件）
func use_custom_avatar() -> bool:
	if not has_custom_avatar():
		return false
	avatar_use_custom = true
	save_game()
	return true


func _read_avatar_file() -> Texture2D:
	if avatar_custom.is_empty():
		return null
	var path := AVATAR_DIR + avatar_custom
	if not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return ImageTexture.create_from_image(img)


func _reload_avatar_texture() -> void:
	_avatar_tex_done = true
	_avatar_tex = _read_avatar_file()


func _remove_avatar_file(file_name: String) -> void:
	if file_name.is_empty() or file_name == avatar_custom:
		return
	var path := AVATAR_DIR + file_name
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ---------- 生成素材索引（image/generated_*/source/，文件名形如 NNN_名称.png） ----------
# 统一按「名称」寻址（如 res_tex("mon_wolf")），免去在代码里硬编码 300+ 条编号路径；
# 首次访问时扫描一次目录并缓存，后续 O(1) 查表。
var _res_index: Dictionary = {}   # "名称.png" -> "res://image/.../NNN_名称.png"
var _res_indexed := false

func _build_res_index() -> void:
	if _res_indexed:
		return
	_res_indexed = true
	var batches := ["generated_001_100", "generated_101_200", "generated_201_333",
		"generated_334_341", "generated_342_353"]
	# 先收 ready/（成品：已裁到设计尺寸、alpha 已硬化），再拿 source/ 母稿补位。
	# 顺序不能反——source 是 970~2170px 的原始大图，既吃显存，也会把未受容器约束的
	# TextureRect 的最小尺寸钳到原图大小（曾导致召唤横幅 2172×724 铺满面板压住文案）
	#
	# 注意：批次之间会重名，且这是**故意的**。例：
	#   npc_steward_portrait = 201_333/ready/npcs（512 像素立绘，画风统一）
	#                        + 342_353/source（1254 高清插画，画风不同）
	# 两阶段扫描保证「任何 ready/ 都压过任何 source/」，所以最终取到像素那张。
	# 想让新版素材真正生效，必须把它放进某批的 ready/ —— 只丢进 source/ 是无效的。
	#
	# generated_354_361（1448×1086 建筑母稿）**故意不列入**：它是同一批建筑的另一版
	# 重新生成，用户 2026-09-19 决定沿用 342_353/ready/city_buildings 那版。
	# 列进来只会白白多扫 8 张千像素大图，且让它们可被 res_tex 按名取到（画风不统一）。
	for dir_name in batches:
		var ready_root: String = "res://image/%s/ready" % dir_name
		if not DirAccess.dir_exists_absolute(ready_root):
			continue
		for sub in DirAccess.get_directories_at(ready_root):
			_scan_png_dir("%s/%s" % [ready_root, sub], false)
		_scan_png_dir(ready_root, false)
	for dir_name in batches:
		var src_root: String = "res://image/%s/source" % dir_name
		if DirAccess.dir_exists_absolute(src_root):
			_scan_png_dir(src_root, true)


## 把目录里的 png 登记进索引；strip_prefix=true 时剥掉 NNN_ 编号前缀（source 母稿的命名）
func _scan_png_dir(dir_path: String, strip_prefix: bool) -> void:
	for f in DirAccess.get_files_at(dir_path):
		if not f.ends_with(".png"):
			continue
		var core: String = f.substr(f.find("_") + 1) if strip_prefix else f
		if not _res_index.has(core):
			_res_index[core] = "%s/%s" % [dir_path, f]


## 按名称取完整路径（无此素材返回空串）
func res_path(res_name: String) -> String:
	if not _res_indexed:
		_build_res_index()
	return String(_res_index.get("%s.png" % res_name, ""))


## 按名称取纹理（无此素材返回 null，调用方自备回退画法）
## 带一层自己的缓存：面板反复开关时省掉「拼路径 + 查索引 + load() 查引擎缓存」的来回
## （主城 8 个 NPC、图鉴 8 张卡之类，一次开面板就是几十次查询）
var _tex_cache := {}

func res_tex(res_name: String) -> Texture2D:
	if _tex_cache.has(res_name):
		return _tex_cache[res_name]
	var p := res_path(res_name)
	var t: Texture2D = null
	if not p.is_empty():
		t = load(p) as Texture2D
	_tex_cache[res_name] = t
	return t


# ---------- 通用 UI 工厂 ----------

## 柔和投影（偏移向下、低透明，像纸页叠放而非霓虹光晕）
func _apply_shadow(sb: StyleBoxFlat, size: float, off_y: float, alpha: float) -> void:
	sb.shadow_color = Color(0.0, 0.0, 0.0, alpha)
	sb.shadow_size = int(size)
	sb.shadow_offset = Vector2(0, off_y)


# ---------- 浮层背景工厂 ----------
## 浮层底衬（深棕 + 暗角 + 极淡斜纹）。
## 只写一个 ColorRect 铺满的纯灰遮罩，是"没设计"的典型：底色发闷、四角和中心一样亮，
## 面板浮在上面像贴纸。这里用三层叠出纵深——底色定调、暗角收边、斜纹给材质。
## eat_input=true 时吞掉点击（模态弹窗用）。四层全部 IGNORE 鼠标，不会挡住上层按钮。
func veil(parent: Control, strength := VEIL_MODAL_A, eat_input := true, a := -1.0) -> Control:
	return _veil_into(parent, strength, eat_input, a)


## 同上，但父节点是 CanvasLayer（详情弹层那种）。CanvasLayer 没有 Control 的接口，
## 所以单独开一个只收 Node 的入口——否则调用处就得自己 new 一层 Control 包着。
func veil_at(parent: Node, strength := VEIL_MODAL_A, eat_input := true, a := -1.0) -> Control:
	return _veil_into(parent, strength, eat_input, a)


func _veil_into(parent: Node, strength: float, eat_input: bool, a: float) -> Control:
	if a < 0.0:
		a = strength
	var root := Control.new()
	root.name = "Veil"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP if eat_input else Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)

	# 视口尺寸：TextureRect 必须自己撑满，不能只靠 anchors。
	# 坑：父级还没布局时 set_anchors_and_offsets_preset 只写 anchors，size 要等下一帧
	# 才结算，这一帧里 TextureRect 是 0×0 → 贴图根本不画。
	var vp := _veil_viewport_size(parent)

	# 暗角 TextureRect：自带 darken 模式，同时承担"色底"+"四角压暗"两件事。
	# 关键：把 VEIL 颜色直接喂进 modulate（而不是先画一层 ColorRect 再叠暗角）——
	# 4 个子节点就减成 3 个，且首帧的 ColorRect 已不再先于暗角一层（之前"灰色平铺"是它）。
	# 斜纹再叠一层做材质收边。
	var v := TextureRect.new()
	v.texture = _build_vignette_tex()
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.self_modulate = Color(VEIL.r / 0.02, VEIL.g / 0.014, VEIL.b / 0.008, a * VEIL_VIGNETTE_A / 0.55)
	v.size = vp
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(v)

	var g := TextureRect.new()
	g.texture = _build_hatch_tex()
	g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.stretch_mode = TextureRect.STRETCH_TILE
	g.size = vp
	g.modulate.a = 0.045
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(g)
	return root


## 浮层要铺多大：优先问父级尺寸，拿不到（headless 早期/未入树）再退回项目基准 480×800
func _veil_viewport_size(parent: Node) -> Vector2:
	if parent is Control:
		var cs := (parent as Control).size
		if cs.x > 1.0 and cs.y > 1.0:
			return cs
	var tree := parent.get_tree()
	if tree != null and tree.root != null:
		var vs := tree.root.size
		if vs.x > 1.0 and vs.y > 1.0:
			return vs
	return Vector2(480, 800)


## 暗角贴图（径向渐变：中心全透 → 四边压暗）。
## 关键：fill_to 必须指到 mid-edge（offset (0.5,0) 表示半径 = 半宽），
## 若指到角点则半径放大 √2 倍，渐变只能铺到对角线的 71%，四角永远到不了最深——
## 表现就是"中心亮、四角也不够暗"，跟没做暗角一样。四角靠调制值封顶即可。
var _vignette_tex: GradientTexture2D = null

func _build_vignette_tex() -> GradientTexture2D:
	if _vignette_tex != null:
		return _vignette_tex
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.014, 0.008, 0.0))        # 中心：不动
	grad.set_color(1, Color(0.02, 0.014, 0.008, 1.0))        # 四边：压到最深
	grad.add_point(0.60, Color(0.02, 0.014, 0.008, 0.16))    # 中段缓过渡，避免"圆环"
	_vignette_tex = GradientTexture2D.new()
	_vignette_tex.gradient = grad
	_vignette_tex.fill = GradientTexture2D.FILL_RADIAL
	_vignette_tex.fill_from = Vector2(0.5, 0.5)
	_vignette_tex.fill_to = Vector2(0.5, 0.0)
	_vignette_tex.width = 128
	_vignette_tex.height = 128
	return _vignette_tex


## 斜纹贴图（1px 线、8px 周期，低对比）。远看是布纹，不是噪点——
## 规范 §43 明确禁止"程序随机噪点冒充细节"，所以这里用有方向的规则纹。
var _hatch_tex: ImageTexture = null

func _build_hatch_tex() -> ImageTexture:
	if _hatch_tex != null:
		return _hatch_tex
	var n := int(VEIL_GRID)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in n:
		for x in n:
			# 45° 斜线：x+y 落在同一斜带上的像素才画，线宽 1px
			if (x + y) % n == 0:
				img.set_pixel(x, y, Color(1.0, 0.92, 0.78, 0.055))
	_hatch_tex = ImageTexture.create_from_image(img)
	return _hatch_tex

## 金字 Label（描边克制：大标题才有可见描边，小字保持干净）
func gold_label(text: String, size: int, bold := true,
		color := GOLD, outline := true) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font_bold if bold else font_reg)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		var osize := roundi(size / 18.0)
		if osize > 0:
			l.add_theme_color_override("font_outline_color", Color("2a1a0a", 0.9))
			l.add_theme_constant_override("outline_size", osize)
	return l


## 宋体 Label（书卷感：标题 / 横幅 / 文学性文字；默认无描边）
func serif_label(text: String, size: int, color := GOLD,
		outline := false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font_serif)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", Color("2a1a0a", 0.85))
		l.add_theme_constant_override("outline_size", maxi(1, roundi(size / 22.0)))
	return l


## 正文 Label（最自然的阅读文本：黑体常规、无描边、左对齐）
func text_label(text: String, size := FS_SM, color := TEXT_DARK) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.add_theme_font_override("font", font_reg)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## 带字间距的字体（标题用；serif=true 时基于宋体）
func spaced_font(glyph_spacing: int, bold := true, serif := false) -> FontVariation:
	var fv := FontVariation.new()
	if serif:
		fv.base_font = font_serif
	else:
		fv.base_font = font_bold if bold else font_reg
	fv.spacing_glyph = glyph_spacing
	return fv


## 深色横幅按钮（右侧按钮列；默认收敛，悬停才提亮）
func menu_button(text: String) -> Control:
	var root := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.10, 0.05, 0.66)
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(1)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.28)
	_apply_shadow(sb, 4.0, 2.0, 0.3)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	root.add_theme_stylebox_override("panel", sb)
	var l := serif_label(text, FS_MD, Color("d9b96e"))
	root.add_child(l)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	return root


## 高亮/取消高亮按钮（选中项：底色微亮 + 边框浮现，不大金大亮）
func set_button_active(btn: Control, active: bool) -> void:
	var sb: StyleBoxFlat = btn.get_theme_stylebox("panel")
	if sb == null:
		return
	if active:
		sb.bg_color = Color(0.22, 0.13, 0.05, 0.88)
		sb.border_color = Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.85)
	else:
		sb.bg_color = Color(0.15, 0.10, 0.05, 0.66)
		sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.28)
	var l := btn.get_child(0) as Label
	if l:
		l.add_theme_color_override("font_color",
			GOLD_BRIGHT if active else Color("d9b96e"))


# ---------- 参考风控件（创建角色 / 登录页） ----------

## 木匾标题规范化：文案只写文字，字距交给字体规则；带「· / 空格」的复合标题（如「远征 · 森林」）
## 原样保留。规则集中在工厂一处，页面里不再手打「设 置」这类空格——同类标题必须同一规则。
func _banner_text(text: String) -> String:
	if text.contains("·") or text.contains("/"):
		return text.strip_edges()
	return text.replace(" ", "")


## 顶部棕色木匾横幅（宋体 + 柔金边；边框降饱和避免荧光感）
func banner_box(text: String, w := 260, h := 52, font_size := FS_BIG) -> PanelContainer:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(w, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.30, 0.18, 0.08, 0.92)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.65)
	_apply_shadow(sb, 5.0, 2.0, 0.4)
	# 左右必须等值：以前是 28/20 的「偏左留白」写法，实测文字中心落在 242.5（面板中心 240），
	# 肉眼看就是字往右歪。木匾文字本来就是居中的，左右各留一样多才不歪
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	root.add_theme_stylebox_override("panel", sb)
	var l := serif_label(_banner_text(text), font_size, GOLD_BRIGHT)
	l.add_theme_font_override("font", spaced_font(maxi(1, font_size / 10), true, true))
	root.add_child(l)
	return root


## 羊皮纸面板（金边，内部留白）
func parchment_box(w := 400, h := 200, pad := 18.0) -> PanelContainer:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(w, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PARCHMENT
	# 四角微差，避免机器感对称
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 15
	sb.corner_radius_bottom_right = 13
	sb.set_border_width_all(3)
	sb.border_color = GOLD
	_apply_shadow(sb, 7.0, 3.0, 0.38)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.7
	sb.content_margin_bottom = pad * 0.6
	root.add_theme_stylebox_override("panel", sb)
	return root


## 按钮文案规范化：调用处手打的「返 回 / 兑 换」式空格统一在这里收掉。同类按钮的字距
## 靠字体与内边距控制，不靠手打空格（分散在各页面的空格是典型的"每处各写一遍"）。
func _button_text(text: String) -> String:
	return text.replace(" ", "")


## 按钮通用交互态：悬停微亮、按下微缩回弹（§26/§39 状态必须齐全）。全部按钮共用这一套，
## 避免每个按钮各自写一份反馈；按下即出声，与项目既有口径一致。
func _bind_press_feedback(root: Control) -> void:
	root.mouse_entered.connect(func(): root.modulate = Color(1.07, 1.05, 1.0))
	root.mouse_exited.connect(func(): root.modulate = Color.WHITE)
	root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			root.pivot_offset = root.size * 0.5
			var tw := root.create_tween()
			if e.pressed:
				_sfx("ui_click")
				tw.tween_property(root, "modulate", Color(0.9, 0.9, 0.9), 0.06)
				tw.parallel().tween_property(root, "scale", Vector2.ONE * 0.97, 0.06)
			else:
				tw.tween_property(root, "modulate", Color.WHITE, 0.12)
				tw.parallel().tween_property(root, "scale", Vector2.ONE, 0.12))


## 金色实心按钮（棕字）：主操作用，一个页面里同一时刻通常只该有一个
func gold_button(text: String, w := 0.0, h := 42.0, font_size := FS_MD) -> Control:
	var root := PanelContainer.new()
	if w > 0.0:
		root.custom_minimum_size = Vector2(w, h)
	else:
		root.custom_minimum_size = Vector2(0, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = GOLD_BTN
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = GOLD_BTN_EDGE
	_apply_shadow(sb, 4.0, 2.0, 0.35)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	root.add_theme_stylebox_override("panel", sb)
	root.add_child(gold_label(_button_text(text), font_size, true, TEXT_DARK, false))
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_bind_press_feedback(root)
	return root


## 描边次级按钮（棕底透明 + 棕字）：切换/返回/上传这类次级操作用它。
## 与 gold_button 同尺寸档位、同交互反馈，只换皮——页面里不再出现第二套按钮设计。
func ghost_button(text: String, w := 0.0, h := 38.0, font_size := FS_SM,
		text_color := Color("6a4a1e")) -> Control:
	var root := PanelContainer.new()
	if w > 0.0:
		root.custom_minimum_size = Vector2(w, h)
	else:
		root.custom_minimum_size = Vector2(0, h)
	# 幽灵钮的深棕字在羊皮纸上好看，压在整屏暗底（如召唤结果层）上就看不见了：
	# 传浅色字时自动换成"暗底 + 金描边"，别再出现"按钮在、字没了"。
	var on_dark := text_color.get_luminance() > 0.5
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.07, 0.04, 0.55) if on_dark else Color(0.28, 0.19, 0.08, 0.10)
	sb.set_corner_radius_all(9)
	sb.set_border_width_all(2)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.60) if on_dark \
		else Color(BOX_EDGE.r, BOX_EDGE.g, BOX_EDGE.b, 0.70)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	root.add_theme_stylebox_override("panel", sb)
	root.add_child(gold_label(_button_text(text), font_size, true, text_color, false))
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_bind_press_feedback(root)
	return root


## 红点（§28）：只提示"有可做的事"，不做"有新内容"的假提示；同一入口最多一枚
func badge_dot(parent: Control, at: Vector2, d := 9.0) -> Control:
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(d, d)
	dot.size = Vector2(d, d)
	dot.position = at
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("d8442f")
	sb.set_corner_radius_all(int(d * 0.5))
	sb.set_border_width_all(1)
	sb.border_color = Color(0.24, 0.09, 0.05, 0.9)
	dot.add_theme_stylebox_override("panel", sb)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(dot)
	return dot


## 米色选择框（参考"◀ 猎 ▶"中间的方框）
func select_box(text: String, w := 132.0, h := 42.0, font_size := FS_MD) -> PanelContainer:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(w, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BOX_BG
	sb.set_corner_radius_all(3)
	sb.set_border_width_all(2)
	sb.border_color = BOX_EDGE
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	root.add_theme_stylebox_override("panel", sb)
	var l := gold_label(text, font_size, true, TEXT_DARK, false)
	root.add_child(l)
	return root


## 输入框样式（灰米底 + 深棕字）
func style_line_edit(le: LineEdit, font_size := FS_MD) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = INPUT_BG
	sb.set_corner_radius_all(3)
	sb.set_border_width_all(2)
	sb.border_color = BOX_EDGE
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	var focus := sb.duplicate() as StyleBoxFlat
	focus.bg_color = INPUT_BG.lerp(INPUT_BG_FOCUS, 0.35)
	focus.border_color = GOLD_BTN_EDGE
	le.add_theme_stylebox_override("normal", sb)
	le.add_theme_stylebox_override("focus", focus)
	le.add_theme_font_override("font", font_reg)
	le.add_theme_font_size_override("font_size", font_size)
	le.add_theme_color_override("font_color", TEXT_DARK)
	le.add_theme_color_override("font_placeholder_color", Color(0.42, 0.36, 0.26))
	le.add_theme_color_override("caret_color", BANNER)


## 取一个武侠风随机名（姓 + 1~2 字名）
const SURNAMES := ["独孤", "南宫", "慕容", "上官", "东方", "西门", "夏侯", "轩辕",
	"沈", "苏", "林", "洛", "秦", "萧", "叶", "顾", "云", "燕", "陆", "裴"]
const GIVEN1 := ["渊", "霜", "岚", "川", "辰", "夜", "辞", "澜", "舟", "昭",
	"砚", "澈", "梧", "寒", "炎", "隐", "白", "青", "墨", "珩"]
const GIVEN2 := ["闻", "风", "雪", "月", "尘", "生", "离", "歌", "影", "觞",
	"羽", "归", "然", "行", "书", "痕", "野", "梦", "遥", "舟"]

func random_name() -> String:
	var s: String = SURNAMES[randi() % SURNAMES.size()]
	var g: String = GIVEN1[randi() % GIVEN1.size()]
	if randf() < 0.45:
		g += GIVEN2[randi() % GIVEN2.size()]
	return s + g


# ================= 场景转场（全项目切场景统一走 G.go） =================
# 目的：消灭"硬切"（画面瞬变）的廉价感——统一为「遮罩淡入 → 换场景 → 遮罩淡出」。
# 约束：转场期间 ui_blocked=true 且遮罩吃输入（连点两次不会切两次场景）；
#       tween 挂在 G（autoload）上，换场景不会把它一起释放。
const TRANSIT_FADE := 0.16   # 单侧淡入/淡出秒数
const TRANSIT_HOLD := 0.06   # 全黑停留（盖住场景重建的那一帧）

var _veil_layer: CanvasLayer = null
var _veil: ColorRect = null
var _transit_busy := false


## 前往某场景（所有 change_scene_to_file 都应改从 G.go 走；重复调用只认第一次）
func go(scene_path: String) -> void:
	if not can_go(scene_path):
		push_error("转场被拒（忙碌中或目标不存在）：" + scene_path)
		return
	_ensure_veil()
	_transit_busy = true
	ui_blocked = true
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_veil, "modulate:a", 1.0, TRANSIT_FADE)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): get_tree().change_scene_to_file(scene_path))
	tw.tween_interval(TRANSIT_HOLD)
	tw.tween_property(_veil, "modulate:a", 0.0, TRANSIT_FADE)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_transit_busy = false
		ui_blocked = false
		if _veil != null:
			_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE)


## 预检：目标存在且当前不在转场中（按钮防抖与回归都用它）
func can_go(scene_path: String) -> bool:
	return not _transit_busy and ResourceLoader.exists(scene_path)


func transit_busy() -> bool:
	return _transit_busy


# ---------- 演武场 ----------
## 段位名（铜/银/金/铂/钻印）
func arena_rank() -> String:
	var s := int(arena.get("score", 0))
	if s >= 1800:
		return "钻印"
	if s >= 1600:
		return "铂印"
	if s >= 1400:
		return "金印"
	if s >= 1200:
		return "银印"
	return "铜印"


## 生成一个演武傀儡（数值随等级缩放；贴图缺省走程序圆体）
func make_arena_foe(level: int) -> Dictionary:
	var lvl := maxi(1, level)
	var sc := 1.0 + 0.16 * float(lvl - 1)
	return {
		"id": "mon_arena_dummy",
		"name": "演武傀儡 · %d 级" % lvl,
		"tier": "boss", "ai": "boss", "attack_range": "melee",
		"base": {"hp": int(520.0 * sc), "atk": int(20.0 * sc),
			"def": int(11.0 * sc), "spd": 0.95},
		"skills": [{"id": "boss_slam", "name": "震地", "k": 1.6, "cd": 9,
			"target": "enemy_front_all"}],
	}


## 镜影对手（轮次 18）：用玩家自己的角色面板生成的"镜像"——
## 同一套角色基础属性 + 同一套局外养成加成（天赋/装备/坐骑/称号）+ **同一套技能**（含技能书等级），
## 只有 HP 打到 90%（给玩家一点公平优势）。演武场因此从"打木桩"变成"跟自己过招"：
## 你越强，镜影也越强，但你能看懂它的每一手。
func make_arena_mirror(role_id: String, level: int) -> Dictionary:
	var rid := role_id if role_id != "" else selected_role
	var role: Dictionary = get_role(rid)
	if role.is_empty():
		return make_arena_foe(level)   # 角色表缺数据时退回傀儡，不让面板开天窗
	var lvl := maxi(1, level)
	var stats := TableCache.role_stats(rid, lvl)
	var gb := growth_bonuses(rid)
	stats.max_hp = int(float(stats.max_hp) * (1.0 + float(gb.get("maxhp_pct", 0.0))) + float(gb.get("hp_add", 0)))
	stats.atk = int(float(stats.atk) * (1.0 + float(gb.get("atk_pct", 0.0))) + float(gb.get("atk_add", 0.0)))
	stats.def = int(float(stats.def) * (1.0 + float(gb.get("def_pct", 0.0))) + float(gb.get("def_add", 0.0)))
	stats.spd = stats.spd * (1.0 + float(gb.get("spd_pct", 0.0)))
	var skills: Array = []
	var learned: Dictionary = prog.get("skills", {})
	var k_per := float(TableCache.skillbook_config().get("k_per_level", 0.05))
	for sid in role.get("skills", []):
		var sd := TableCache.get_skill(String(sid))
		if sd.is_empty():
			continue
		var slv := int(learned.get(String(sid), 1))
		if slv > 1:
			sd = sd.duplicate()
			sd["k"] = snappedf(float(sd.get("k", 0.0)) * (1.0 + k_per * float(slv - 1)), 0.001)
		skills.append(sd)
	if skills.is_empty():   # 角色表没给技能：至少给一手重击，别让它站着挨打
		skills = [{"id": "boss_slam", "name": "震地", "k": 1.6, "cd": 9,
			"target": "enemy_front_all"}]
	return {
		"id": "mon_arena_dummy",
		"name": "镜影 · %s" % String(role.get("name", "守碑人")),
		"tier": "boss", "ai": "boss",
		"attack_range": String(role.get("attack_range", "melee")),
		"base": {"hp": int(float(stats.max_hp) * 0.9), "atk": int(stats.atk),
			"def": int(stats.def), "spd": float(stats.spd)},
		"skills": skills,
		"mirror": true,
	}


## 兑换表最低单价（主页红点用：荣誉买得起任意一件才点亮，宁可少提示也不乱提示）
var _exchange_min := -1
func exchange_min_cost() -> int:
	if _exchange_min >= 0:
		return _exchange_min
	_exchange_min = 0
	var f := FileAccess.open("res://data/exchange.json", FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			for e in (parsed as Dictionary).get("entries", []):
				var c := int((e as Dictionary).get("cost", 0))
				if c > 0 and (_exchange_min == 0 or c < _exchange_min):
					_exchange_min = c
	return _exchange_min


## 结算一场切磋：胜 +18~26，负 -12（保底 0）；返回 {delta, score, rank}
func arena_result(win: bool) -> Dictionary:
	var delta := 0
	if win:
		delta = 18 + randi() % 9
		arena["wins"] = int(arena.get("wins", 0)) + 1
	else:
		delta = -mini(12, int(arena.get("score", 0)))
		arena["losses"] = int(arena.get("losses", 0)) + 1
	arena["score"] = maxi(0, int(arena.get("score", 0)) + delta)
	save_game()
	return {"delta": delta, "score": int(arena["score"]), "rank": arena_rank()}


## 遮罩：全屏深棕黑（不是纯黑，与羊皮纸调性一致）；懒创建、平时不吃输入
func _ensure_veil() -> void:
	if _veil != null and is_instance_valid(_veil):
		return
	_veil_layer = CanvasLayer.new()
	_veil_layer.layer = 128   # 压过一切浮层（GM 控制台 100）
	add_child(_veil_layer)
	_veil = ColorRect.new()
	_veil.color = Color(0.045, 0.032, 0.020)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.modulate.a = 0.0
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil_layer.add_child(_veil)


# ================= ⓘ 详情小按钮 + 弹层 =================
# 长文案收纳处：规则/概率/说明不再平铺在面板上（一屏堆字显乱），
# 缩成小圆圈按钮，点开出羊皮纸弹层细看。各面板统一用这两个工厂。

## 小圆圈按钮（默认 24px，木质圆底贴图 + 深棕「?」），点击弹详情层
func info_button(title: String, lines: Array, d := 24.0) -> Control:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(d, d)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.30, 0.20, 0.10, 0.0)   # 底交给贴图，扁平色仅留投影载体
	sb.set_corner_radius_all(int(d * 0.5))
	_apply_shadow(sb, 3.0, 1.5, 0.3)
	root.add_theme_stylebox_override("panel", sb)
	var bg_tex := res_tex("round_brown")
	if bg_tex != null:
		var bg := TextureRect.new()
		bg.texture = bg_tex
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bg)
		var l := gold_label("?", FS_XS if d < 26.0 else FS_SM, true, Color("4a2f16"), false)
		root.add_child(l)
	else:
		sb.bg_color = Color(0.30, 0.20, 0.10, 0.92)
		sb.set_border_width_all(1)
		sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.7)
		root.add_child(gold_label("?", FS_XS if d < 26.0 else FS_SM, true, GOLD_BRIGHT, false))
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_sfx("ui_click")
			root.pivot_offset = root.size * 0.5
			var tw := root.create_tween()
			tw.tween_property(root, "scale", Vector2.ONE * 0.92, 0.05)
			tw.tween_property(root, "scale", Vector2.ONE, 0.1)
			show_info_popup(root, title, lines))
	return root


## 首次打开某面板时弹一次引导（新手教程）：key 记进存档，之后只留「?」可再看
func tip_once(key: String, title: String, lines: Array, anchor: Control) -> void:
	var seen: Dictionary = prog.get("tips_seen", {})
	if bool(seen.get(key, false)):
		return
	seen[key] = true
	prog["tips_seen"] = seen
	save_game()
	show_info_popup(anchor, title, lines)


## 羊皮纸详情弹层：点遮罩或「知道了」关闭；内容超长可滚动
func show_info_popup(anchor: Control, title: String, lines: Array) -> void:
	var tree := anchor.get_tree()
	if tree == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 90   # 低于 GM 控制台(100)，高于一切面板
	tree.root.add_child(layer)

	# 统一浮层底衬（深棕 + 暗角 + 斜纹）；要能接 gui_input 以便点空白关闭，
	# 所以不再走独立 ColorRect，直接用 veil 返回的那层 Control。
	var dim := veil_at(layer, 0.55)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			layer.queue_free())

	# 宽度 400：与所有面板同一排版基准；每行约 22 个中文（FS_SM/16px ÷ 368px 行宽）
	const PW := 400.0
	const LINE_W := 360.0
	var est := 0.0
	for ln in lines:
		var rows := maxi(1, int(ceil(String(ln).length() / 22.0)))
		est += rows * 22.0 + 6.0
	var content_h := clampf(est, 30.0, 380.0)
	var ph := 14.0 + 34.0 + 8.0 + content_h + 12.0 + 40.0 + 14.0

	var panel := parchment_box(PW, ph, 16.0)
	panel.position = Vector2((480.0 - PW) * 0.5, (800.0 - ph) * 0.5)
	layer.add_child(panel)

	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	var title_l := serif_label(title, FS_LG, Color("6a4a1e"))
	title_l.position = Vector2(0, 0)
	title_l.custom_minimum_size = Vector2(PW - 32.0, 34.0)
	content.add_child(title_l)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 42.0)
	scroll.size = Vector2(PW - 32.0, content_h)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	for ln in lines:
		var t := text_label(String(ln), FS_SM, TEXT_DARK)
		t.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY   # 中文无空格，按字符断行
		t.custom_minimum_size = Vector2(LINE_W, 0)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(t)

	var ok := gold_button("知道了", 120, 40, FS_SM)
	ok.position = Vector2((PW - 32.0 - 120.0) * 0.5, 42.0 + content_h + 12.0)
	ok.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			layer.queue_free())
	content.add_child(ok)
