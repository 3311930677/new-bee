# G.gd —— 全局单例：主题、字体、共享状态
extends Node

# ---------- 配色（模仿参考游戏：暖棕 + 羊皮纸 + 金） ----------
const BG_DEEP := Color("2a1f14")        # 深棕黑（选人底）
const BANNER := Color("5a3a1e")          # 棕色横幅
const PARCHMENT := Color("eedbaa")       # 参考风纸色底，安静的大色块
const GOLD := Color("f0c060")            # 金字/金边
const GOLD_BRIGHT := Color("ffd97a")     # 选中亮金
const NAME_GREEN := Color("84c48c")      # 角色名（柔玉绿，非荧光绿）
const LV_ORANGE := Color("f0a030")      # 等级橙
const TEXT_DARK := Color("3a2a14")      # 羊皮纸上的深字
const TEXT_LIGHT := Color("f5ead0")      # 深底上的浅字

# ---------- 语义色（按「含义」取色，不按「好看」取色） ----------
# 凡是表达「获得/代价/提示/稀有」语义的地方一律引用这里，禁止再写散落的字面色值。
const C_GAIN := Color("7ddb6a")          # 获得 / 治疗 / 增益（绿）
const C_COST := Color("c04030")          # 代价 / 不足 / 扣除（红）
const C_HINT := Color("a89e88")          # 次要提示 / 未解锁 / 中性（灰米，与稀有度「普通」同调）
const C_RARE := Color("d8ab48")          # 稀有 / 传说强调（金）
const C_COMPANION := Color("83cfd1")     # 伙伴协战 / 元素响应
const C_COMPANION_GUARD := Color("6f9fd0") # 伙伴护卫

# ---------- 稀有度四档（全项目唯一定义，各面板只引用，禁止再各自复制一份） ----------
const RARITY_HUE := {
	"white": C_HINT, "blue": Color("6f9fd0"),
	"purple": Color("a273c9"), "gold": C_RARE,
}
const RARITY_NAME := {"white": "普通", "blue": "稀有", "purple": "史诗", "gold": "传说"}

# ---------- 参考风（创建角色页）配色 ----------
const WOOD := Color("6b4a28")            # 木框/顶栏棕
const WOOD_DARK := Color("4a3018")       # 木框暗部
const GOLD_BTN := Color("d7b668")        # 低饱和金色选中/操作底
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
const BTN_S := Vector2(120, 44)   # 返回 / 关闭（P01 样板 §4：次级按钮高度不低于 44 触控下限）
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


## 人物名始终取创角昵称；登录账号只用于本地存档识别。
func display_name() -> String:
	if not player_name.strip_edges().is_empty():
		return player_name.strip_edges()
	return "旅人"

# ---------- 存档与钱包（user://save.json；四币 + 角色档案 + 养成进度） ----------
# 用 var 而非 const：自动化测试会把 SAVE_PATH 指向临时文件，避免污染真实存档
var SAVE_PATH := "user://save.json"
const SAVE_VERSION := SaveData.CURRENT_VERSION
## 最近一次读档的报告（SaveData.load_payload 的返回值）：mode/err/steps 都在里面，
## 设置面板与回归用例据此判断"这次是正常读、迁移读、还是遇到未来版本的档"。
var last_load_report: Dictionary = {}
## 未来版本的档被读取时，原档备份的位置（没发生就是空串）
var save_backup_path := ""
## 读档被判非法后锁写：此时内存是「干净默认态」，一旦写盘就会用默认态覆盖玩家的真档（A7）。
## 解锁只发生在玩家显式做出选择后（继续 = 放弃原档 / 导入旧档 = 走了导入路径）。
var save_locked := false
## 锁写原因（给玩家看的那一句）
var save_lock_reason := ""
var wallet := {"gold": 0, "expedition": 0, "soul": 0, "honor": 0}

# ---------- 道具库存（最小实现：id -> 数量；券类先行，后续道具沿用） ----------
var items := {"ticket_ten": 0, "ticket_sweep": 1}

## 道具显示名（委托/兑换/提示共用；没有登记的一律回落到 id，不静默编名字）
const ITEM_NAMES := {
	"ticket_ten": "十连券", "ticket_sweep": "扫荡券",
	"enhance_stone": "强化石", "refine_stone": "精炼石", "lock_rune": "锁定符",
	"pet_food": "宠物粮", "break_crystal": "突破晶", "aptitude_fruit": "资质果",
	"evolve_crystal": "进化晶石",
	"stele_fragment": "失声碑文",
	"salt_ledger": "盐车账页",
	"gate_clue": "闸门线索", "tide_core": "潮蚀闸芯",
	"frost_letter": "霜关来信", "mine_record": "矿道记录",
	"gate_stamp": "关闸铁印", "frost_reply": "双关回讯", "veil_seal": "雪幕印",
	"frost_nameplate": "裂纹名牌", "frost_parcel": "寒路药包",
	"tide_egg": "潮纹蛋",
	"fish_salt": "盐泉鲫", "fish_port": "港湾银鳞", "fish_tide": "潮纹鳞",
	"wind_chime": "旧风铃", "salt_pack": "封好的盐包",
	"trade_grain": "谷物", "trade_salt": "盐", "trade_herb": "药草", "trade_iron": "铁料",
}


func item_name(id: String) -> String:
	if id.begins_with("gem_"):
		return gem_label(id)
	return String(ITEM_NAMES.get(id, id))


func item_count(id: String) -> int:
	return int(items.get(id, 0))


## 发放道具（数量下限 0）
func grant_item(id: String, n: int, persist := true) -> void:
	items[id] = maxi(0, item_count(id) + n)
	if persist:
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
var _pending_campaign_note := ""
var _campaign_exp_batch := false
var prog := {
	"level": 1,                 # 主角等级（上限 growth.level_cap）
	"exp": 0,                   # 当前等级已积累经验
	"worlds_unlocked": 1,       # 已解锁世界数（按 maps.json theme_order 顺序推进）
	"world_cleared": {},        # theme_id -> true（已通关该世界）
	"pets": [],                 # 已收集宠物 id；岩龟在第一幕 s04 后于兽栏领取
	"main_world": {"map_id": "lorin_wilds"},
	"story": {"step": "s01", "done": [], "goals": {}},
	"ledger": {"applied": []},  # P02：已结算事务 ID（同一事务只落地一次）
	"flags": {},                # P02：世界旗标（事务副作用）
	"inventory": {"instances": [], "pending": [], "next_uid": 1},  # P04：装备实例拥有池 + 待领取箱
	"economy": {},            # P06：游戏日、现货余量、价格历史与订单
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
	if not is_inside_tree(): return
	var au := get_node_or_null("/root/Audio")
	if au != null:
		au.call("sfx", name, jitter)

# ---------- 演武场（PVP 首版：傀儡对手 + 段位分） ----------
var arena := {"score": 1000, "wins": 0, "losses": 0, "streak": 0, "best_streak": 0}

var gm_unlocked := false
## 全屏浮层（GM 控制台/转场）或详情弹层打开时为 true，探索层据此冻结移动。
## 写成属性而非裸变量（问题 #6）：详情弹层现在也是"阻塞源"，但阻塞不能靠简单布尔覆盖——
## 否则关掉弹层时会把别人的锁一起放掉。内部锁 + 模态栈取并集，读法对 30 处调用点保持不变。
var _ui_blocked_locked := false
var ui_blocked: bool:
	get:
		return _ui_blocked_locked or not _modals.is_empty()
	set(v):
		_ui_blocked_locked = v


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


## 静默解析 JSON：失败返回 null，不打印引擎错误。
## JSON.parse_string 解析失败时会自己 push 一条 "Parse JSON failed"，
## 玩家粘贴一段乱码存档码就刷红字——那是我们自己的输入校验该说话，不是引擎。
func json_parse_silent(text: String) -> Variant:
	var j := JSON.new()
	if j.parse(text) != OK:
		return null
	return j.data


## 读档：恢复钱包与角色档案（无存档/坏档保持默认，不报错弹窗——挫败感克制）
##
## 版本闸门 / 逐版迁移 / 语义校验都收在 SaveData（问题 #39）；未来时间水位也在那里判（#24）。
## 未来版本的档不能"只用默认值顶着"——那等于静默覆盖玩家进度，所以先备份原档再按兼容方式读。
func _load_save() -> void:
	var now := int(Time.get_unix_time_from_system())
	# R-04：启动恢复不只认主档 —— 上次写盘若在替换中途被打断（留下 .tmp/.prev）或主档丢失，
	# 就从这些残档 / 最近备份里挑一份有效档读回来。**主档缺失不等于新档**：
	# 只有主档与所有恢复源都不可用时才算新档，否则玩家会在一次崩溃后被静默清空进度。
	var pick := SaveData.pick_readable(SAVE_PATH, now)
	var source := String(pick.get("source", "none"))
	if source == "none":
		return
	if source == "unreadable":
		# 主档在，但连 JSON 都解析不了：不改写内存、不锁写（保持"坏档不静默覆盖玩家真档"的既有语义），
		# 把判断权交回玩家 / 工具。
		push_warning("存档解析失败，沿用默认状态（原档保持不动）")
		return
	if source != "main":
		# 从残档 / 备份恢复：把内容写回主档，让"主档缺失"被真正修好，而不是每次启动都从备份捞。
		# 写不回也不阻断本次读取（内存里仍用恢复出来的那份）。
		var rp := String(pick.get("path", ""))
		var rf := FileAccess.open(rp, FileAccess.READ)
		if rf != null:
			var rtext := rf.get_as_text()
			rf.close()
			var wres := SaveData.save_text(SAVE_PATH, rtext, now, false)
			if bool(wres.get("ok", false)):
				push_warning("存档主档缺失/损坏，已从 %s 恢复（%s）" % [source, rp])
			else:
				push_warning("从 %s 恢复存档失败：%s" % [source, String(wres.get("err", ""))])
	var res: Dictionary = pick.get("res", {})
	last_load_report = res
	if not bool(res.get("ok", false)):
		# 非法档同样要留备份（A7）：以前只有 future 档备份，钱包为负 / 时间水位超前被判非法时
		# 原档无人看管，玩家一捡道具就被默认态覆盖
		save_backup_path = SaveData.backup_file(SAVE_PATH, now)
		save_locked = true
		save_lock_reason = String(res.get("err", ""))
		push_warning("存档校验失败：%s（沿用默认状态，原档已备份到 %s 并锁定写盘）"
			% [save_lock_reason, save_backup_path])
		return
	if String(res.get("mode", "")) == "future":
		save_backup_path = SaveData.backup_file(SAVE_PATH, now)
		push_warning("%s；原档已备份到 %s" % [String(res.get("err", "")), save_backup_path])
	save_locked = false
	save_lock_reason = ""
	var data: Dictionary = res.get("data", {})
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
		var mw: Variant = pd.get("main_world", {})
		prog["main_world"] = WorldSession.normalize_state(
			mw if mw is Dictionary else {"map_id": "lorin_wilds"})
		var story: Variant = pd.get("story", {})
		prog["story"] = QuestService.normalize_state(
			story if story is Dictionary else {"step": "s01", "done": [], "goals": {}})
		var lg: Variant = pd.get("ledger", {})
		prog["ledger"] = RewardLedger.ensure(lg if lg is Dictionary else {"applied": []})
		var flg: Variant = pd.get("flags", {})
		prog["flags"] = flg if flg is Dictionary else {}
		# P05：第一幕状态（repair_method / side_quests / tracked / discoveries / first_kills）。
		# 读档白名单此前漏了 act1，会让修碑选择与支线进度在读档后静默丢失——这里补上，
		# 缺键由 act1_state() 懒归一兜底（不预写默认，避免把"没做过"写成"做过了"）。
		var a1: Variant = pd.get("act1", {})
		prog["act1"] = a1 if a1 is Dictionary else {}
		var ec: Variant = pd.get("economy", {})
		prog["economy"] = EconomyService.ensure(ec if ec is Dictionary else {},
			TableCache.economy_config())
		var fishing: Variant = pd.get("fishing", {})
		prog["fishing"] = fishing if fishing is Dictionary else {}
		# P04：装备实例拥有池（SaveData 的 v5 迁移已补齐，这里再兜一层）
		var invv: Variant = pd.get("inventory", {})
		prog["inventory"] = Inventory.ensure(invv if invv is Dictionary else {})
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
		if pd.has("companions"): prog["companions"] = (pd.companions as Dictionary).duplicate(true)
		if pd.has("campaign_growth"): prog["campaign_growth"] = (pd.campaign_growth as Dictionary).duplicate(true)
		var ts: Variant = pd.get("tips_seen", {})   # 已看过的引导弹层，别每次开面板都弹
		prog["tips_seen"] = ts if ts is Dictionary else {}
		prog["lore_seen"] = bool(pd.get("lore_seen", false))   # 序章是否已看（看过的老档不再弹）
		var lb: Variant = pd.get("lore_beats", {})   # 已演过的剧情节拍（首领前对峙/战后余韵）
		prog["lore_beats"] = lb if lb is Dictionary else {}
		var setg: Variant = pd.get("settings", {})   # 玩家设置（震屏/剧情演出/战斗默认倍速）
		prog["settings"] = setg if setg is Dictionary else {}
		prog["last_ts"] = maxi(0, int(pd.get("last_ts", 0)))   # 单调时间水位（P1-13）
		var gg: Variant = pd.get("gacha", {})   # 抽奖状态（保底 / 每日免费；P1-1）
		var ggd: Dictionary = gg if gg is Dictionary else {}
		prog["gacha"] = {"pity": maxi(0, int(ggd.get("pity", 0))),
			"free_day": String(ggd.get("free_day", "")),
			"free_streak": maxi(0, int(ggd.get("free_streak", 0))),
			"free_last": String(ggd.get("free_last", ""))}
		var cc: Variant = pd.get("codex_claimed", [])   # 已领取的图鉴收集里程
		prog["codex_claimed"] = cc if cc is Array else []
		# 保底迁移（items.gacha_pity → prog.gacha.pity）已收进 SaveData 的 v2→v3 步骤与归一化，
		# 不再散落在读档赋值之间（问题 #39：迁移要有版本边界、要幂等）。
		ensure_starter_pets()
		ensure_starter_equip()
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
		arena["streak"] = maxi(0, int(ad.get("streak", 0)))
		arena["best_streak"] = maxi(0, int(ad.get("best_streak", 0)))
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


## 把「进度类」内存态重置为初始默认值（导入重读 / 重置存档共用，P0-3/P0-4）。
## 保留项：音频偏好（设置而非进度）与已上传头像文件（avatar_custom 串保留、不启用）。
func _init_state_defaults() -> void:
	_pending_campaign_note = ""
	_campaign_exp_batch = false
	wallet = {"gold": 0, "expedition": 0, "soul": 0, "honor": 0}
	items = {"ticket_ten": 0, "ticket_sweep": 1}
	prog = {"level": 1, "exp": 0, "worlds_unlocked": 1, "world_cleared": {}, "pets": [],
		"main_world": {"map_id": "lorin_wilds"},
		"story": {"step": "s01", "done": [], "goals": {}},
		"ledger": {"applied": []}, "flags": {},
		"inventory": {"instances": [], "pending": [], "next_uid": 1},
		"economy": {},
		"talents": {}, "equip": {}, "skills": {}, "mounts": {"owned": {}, "active": ""},
		"titles": {"owned": [], "active": ""}, "pet_stat": {}, "tips_seen": {},
		"lore_seen": false, "lore_beats": {}, "settings": {}, "last_ts": 0,
		"gacha": {"pity": 0, "free_day": "", "free_streak": 0, "free_last": ""},
		"codex_claimed": []}
	city = {"built": ["hall", "gate"], "code": "", "visits": [], "acts": {}, "day": "", "streak": 0}
	quest = {"day": "", "offer": [], "active": {}, "claimed": []}
	arena = {"score": 1000, "wins": 0, "losses": 0, "streak": 0, "best_streak": 0}
	account = ""
	gender = "男"
	selected_role = ""
	avatar_id = ""
	avatar_use_custom = false
	player_name = ""
	_avatar_tex_done = false
	_avatar_tex = null


## 导入存档 / 外部写入后：重置内存态并重读文件。此前只写盘不重读，
## 旧内存会在下一次 save_game 把刚导入的档覆盖掉（P0-3）
func reload_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	_init_state_defaults()
	_load_save()
	return true


## 存档：钱包四币 + 养成进度 + 角色档案（远征结算入账 / 主城关键节点时写）
##
## R-04：写入统一走 SaveData.save_text（临时文件 + 回读校验 + 滚动备份 + 就地替换 + 失败回滚），
## 不再直接 FileAccess.open(WRITE) 覆盖唯一档。返回是否真的落到盘上 ——
## 调用方（结算 / 领取等）据此决定要不要向玩家显示"已入袋 / 已领取"。
func save_game() -> bool:
	# 读档被判非法期间禁止写盘：内存是默认态，写下去就是覆盖玩家真档（A7）。
	# 不静默跳过——必须 push_warning，否则坏档这件事没人知道。
	if save_locked:
		push_warning("存档处于锁定状态，本次写盘已跳过（原因：%s；备份：%s）"
			% [save_lock_reason, save_backup_path])
		return false
	# v6 新档在尚未进入市集时也必须写出完整经济结构。
	economy_state()
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
	var res := SaveData.save_text(SAVE_PATH, JSON.stringify(data, "\t"),
		int(Time.get_unix_time_from_system()))
	if not bool(res.get("ok", false)):
		push_error("存档写入失败：%s（%s）" % [SAVE_PATH, String(res.get("err", ""))])
		return false
	return true


# ---------- 出征补给（轮次 21）：出征前花金币加带药剂 ----------
# 药剂本来是固定 2 瓶（开局给），玩家没有任何"为这趟远征投资"的决策；
# 加带补给把金币变成一次可选的战前取舍：多带一瓶 = 多一次容错，但要花钱。

func run_cfg() -> Dictionary:
	var c: Variant = TableCache.nodes_config().get("run", {})
	return c if c is Dictionary else {}


## 苦行（轮次 22）：出征前可选的难度/收益开关，参数在 data/nodes.json 的 ascetic 段
func ascetic_cfg() -> Dictionary:
	var c: Variant = TableCache.nodes_config().get("ascetic", {})
	return c if c is Dictionary else {}


func run_potions_base() -> int:
	return maxi(0, int(run_cfg().get("potions_base", 2)))


func run_potions_max() -> int:
	return maxi(run_potions_base(), int(run_cfg().get("potions_max", 4)))


## 第 bought 瓶加带药剂的单价（bought 从 0 起，单价随已购数量递增）
func run_supply_price(bought: int) -> int:
	var c := run_cfg()
	var base := int(c.get("supply_price", 0))
	if base <= 0:
		return 0
	return base + maxi(0, bought) * maxi(0, int(c.get("supply_price_step", 0)))


## 出征前补给打包结算：买 extra 瓶。
## 超上限 / 单价未配置 / 余额不足 → 整单拒绝（不做部分发放），成功才扣款落盘。
## 返回 { ok, err, total }
func buy_run_supply_pack(extra: int) -> Dictionary:
	if extra <= 0:
		return {"ok": true, "err": "", "total": 0}
	var room := run_potions_max() - run_potions_base()
	if extra > room:
		return {"ok": false, "err": "补给最多再带 %d 瓶" % maxi(0, room)}
	var total := 0
	for i in extra:
		var p := run_supply_price(i)
		if p <= 0:
			return {"ok": false, "err": "补给价格未配置"}
		total += p
	if int(wallet.get("gold", 0)) < total:
		return {"ok": false, "err": "金币不足（加带 %d 瓶需 %d）" % [extra, total]}
	wallet["gold"] = int(wallet.get("gold", 0)) - total
	save_game()
	_sfx("coin", 0.0)
	return {"ok": true, "err": "", "total": total}


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
func gain_exp(amount: int, persist := true) -> int:
	if amount <= 0:
		return 0
	var cap := level_cap()
	if int(prog.get("level", 1)) >= cap:
		prog["level"] = cap
		prog["exp"] = 0
		if persist:
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
	if ups > 0 and not _campaign_exp_batch:
		_sfx("level_up", 0.0)   # 升级音不抖音高：这是"仪式"，不是随机反馈
	if persist:
		save_game()
	return ups


## 旧主线首通经验差额：按任务版本补记，与去重账本和等级同一次保存。
func campaign_growth_catchup(persist := true) -> Dictionary:
	if save_locked: return {"ok": false, "exp": 0}
	var plan := CampaignGrowth.catchup_plan(prog)
	if plan.is_empty(): return {"ok": true, "exp": 0}
	var before := prog.duplicate(true)
	var old_level := int(prog.get("level", 1))
	var total := 0
	var previous_batch := _campaign_exp_batch
	_campaign_exp_batch = true
	for entry in plan:
		var tx := RewardLedger.make(String(entry.transaction_id), {}, {"exp": int(entry.exp)})
		var result := RewardLedger.apply(tx, ledger(), self)
		if not bool(result.get("ok", false)):
			prog = before
			_campaign_exp_batch = previous_batch
			return {"ok": false, "exp": 0}
		if bool(result.get("applied", false)): total += int(entry.exp)
		CampaignGrowth.mark(prog, String(entry.id))
	_campaign_exp_batch = previous_batch
	if persist and not save_game():
		prog = before
		return {"ok": false, "exp": 0}
	if int(prog.get("level", 1)) > old_level and not previous_batch: _sfx("level_up", 0.0)
	return {"ok": true, "exp": total, "levels": int(prog.get("level", 1)) - old_level}


func take_campaign_note() -> String:
	var result := _pending_campaign_note
	_pending_campaign_note = ""
	return result


func campaign_gear_claim(persist := true) -> Dictionary:
	if save_locked: return {"ok": false, "count": 0, "err": "存档暂不可写"}
	var role := selected_role if not selected_role.is_empty() else "zs"
	var plan := CampaignGear.claim_plan(prog, role)
	if plan.is_empty(): return {"ok": true, "count": 0, "names": []}
	var before_prog := prog.duplicate(true)
	var before_items := items.duplicate(true)
	var before_wallet := wallet.duplicate(true)
	var names: Array = []
	for entry in plan:
		var tpl := equip_tpl(String(entry.tpl))
		var grants := {"equip:%s:%d" % [String(entry.tpl), int(tpl.get("rarity", 3))]: 1}
		for id in entry.materials: grants["item:%s" % String(id)] = int(entry.materials[id])
		var result := RewardLedger.apply(RewardLedger.make(String(entry.transaction_id), {}, grants), ledger(), self)
		if not bool(result.get("ok", false)):
			prog = before_prog
			items = before_items
			wallet = before_wallet
			return {"ok": false, "count": 0, "err": String(result.get("err", "保底未保存"))}
		if bool(result.get("applied", false)): names.append(String(tpl.get("name", "装备")))
	if persist and not save_game():
		prog = before_prog
		items = before_items
		wallet = before_wallet
		return {"ok": false, "count": 0, "err": "保底未保存，已回滚"}
	return {"ok": true, "count": names.size(), "names": names}


## 主线目标由事件驱动，任务 ID 固定写档，查询展示新版首通经验。
func story_current() -> Dictionary:
	var state := normalize_story_state()
	var step := String(state.get("step", "s01"))
	if step.is_empty():
		return {}
	var rows: Variant = CampaignGrowth.story_rows()
	if rows is Array:
		for row_v in rows:
			if row_v is Dictionary and String((row_v as Dictionary).get("id", "")) == step:
				var row := (row_v as Dictionary).duplicate(true)
				var floor_reward := CampaignGear.reward(step, selected_role if not selected_role.is_empty() else "zs")
				if not floor_reward.is_empty(): row["reward"]["campaign_gear"] = floor_reward
				return row
	return {}


func story_goal_short() -> String:
	var row := story_current()
	if row.is_empty():
		if story_step_done("s28"):
			return "双关已互通 · 自由探索"
		if story_step_done("s20"):
			return "第二幕潮闸已开 · 自由探索"
		return "边城失声已平息 · 自由探索"
	return "主线 · %s" % String(row.get("goal", ""))


func story_step_done(step_id: String) -> bool:
	var state: Variant = prog.get("story", {})
	return state is Dictionary and step_id in (state as Dictionary).get("done", [])


## 奖励账本（P02）：prog.ledger.applied 记录已落地的事务 ID，同一事务只发一次。
func ledger() -> Dictionary:
	# 注意用 .get 不带缺省值：拿临时容器再写，记录会落进临时对象里丢掉
	var l: Variant = prog.get("ledger")
	if not (l is Dictionary):
		l = {"applied": []}
		prog["ledger"] = l
	return RewardLedger.ensure(l as Dictionary)


## 主线状态归一（P02）：保证 step/done/goals 三件套存在，旧档 done[] 补成 goals。
func normalize_story_state() -> Dictionary:
	var s: Variant = prog.get("story")
	if not (s is Dictionary):
		s = {"step": "s01", "done": [], "goals": {}}
		prog["story"] = s
	var state := QuestService.normalize_state(s as Dictionary)
	# 第一幕完结时旧版本把 step 写成空串。只迁移已完成 s12 的档，
	# 不重放复命事件，也不碰奖励账本、位置或其他养成状态。
	if String(state.get("step", "")) == "":
		var done: Array = state.get("done", [])
		if done.has("s24") and not done.has("s25"):
			state["step"] = "s25"
		elif done.has("s20") and not done.has("s21"):
			state["step"] = "s21"
		elif done.has("s16") and not done.has("s17"):
			state["step"] = "s17"
		elif done.has("s12") and not done.has("s13"):
			state["step"] = "s13"
	return state


func story_event(kind: String, target: String, map_id: String, persist := true,
		payload := {}) -> Dictionary:
	if save_locked:
		return {}
	var before_prog := prog.duplicate(true)
	var before_wallet := wallet.duplicate(true)
	var before_items := items.duplicate(true)
	var event := QuestService.world_event(kind, target, map_id,
		selected_role if not selected_role.is_empty() else "player", payload)
	var rows: Variant = CampaignGrowth.story_rows()
	var plan := QuestService.plan(normalize_story_state(),
		rows if rows is Array else [], event, items)
	if not bool(plan.get("ok", false)):
		return {}
	var step_id := String(plan.get("step_id", ""))
	var row: Dictionary = plan.get("step", {})
	var reward: Dictionary = plan.get("reward", {})
	# 一次事务：需要就扣任务物，奖励走账本去重；状态推进与发放同一次写盘
	var costs := {}
	var consume := String(plan.get("consume_item", ""))
	if not consume.is_empty():
		costs["item:%s" % consume] = 1
	var extra_costs: Dictionary = plan.get("extra_costs", {})
	for key in extra_costs:
		costs[String(key)] = int(costs.get(String(key), 0)) + int(extra_costs[key])
	var grants := {
		"gold": maxi(0, int(reward.get("gold", 0))),
		"exp": maxi(0, int(reward.get("exp", 0))),
	}
	var reward_item := String(reward.get("item", ""))
	if not reward_item.is_empty():
		grants["item:%s" % reward_item] = maxi(1, int(reward.get("count", 1)))
	var choice := String(plan.get("choice", ""))
	var flags := {}
	if step_id == "s11" and not choice.is_empty():
		flags = {"act1_stele_repaired": true, "act1_route_open": true,
			"act1_repair_method": choice}
	elif step_id == "s20" and not choice.is_empty():
		flags = {"act2_tide_gate_open": true, "act2_port_choice": choice}
	elif step_id == "s28" and not choice.is_empty():
		flags = {"act3_supply_choice": choice, "act3_pass_open": true}
	var tx := RewardLedger.make(RewardLedger.tx_id("story", step_id,
		String(event.get("event_id", ""))), costs, grants, flags)
	var res := RewardLedger.apply(tx, ledger(), self)
	if not bool(res.get("ok", false)):
		push_warning("主线结算未落地：%s" % String(res.get("err", "")))
		return {}
	prog["story"] = plan.get("next_state", {})
	if bool(res.get("applied", false)):
		CampaignGrowth.mark(prog, step_id)
	if not bool(campaign_growth_catchup(false).get("ok", false)):
		prog = before_prog
		wallet = before_wallet
		items = before_items
		return {}
	var gear := campaign_gear_claim(false)
	if not bool(gear.get("ok", false)):
		prog = before_prog
		wallet = before_wallet
		items = before_items
		return {}
	if step_id == "s20" and not choice.is_empty():
		economy_state()["port_event"] = choice
	if step_id == "s28" and not choice.is_empty():
		economy_state()["frost_event"] = choice
	if step_id == "s11" and not choice.is_empty():
		var act1: Dictionary = prog.get("act1", {})
		act1["repair_method"] = choice
		prog["act1"] = act1
	if persist:
		if not save_game():
			prog = before_prog
			wallet = before_wallet
			items = before_items
			return {}
	return {"id": step_id, "title": String(row.get("title", "")), "reward": reward,
		"next_goal": story_goal_short(), "gear": gear}


# ---------- 第一幕支线（P05-B） ----------
#
# 状态在 prog.act1（side_quests / tracked / discoveries / first_kills），规则与纯逻辑在
# QuestService.side_*，这里只做胶水：存档（含写盘失败回滚）、物品发放/消耗与 UI 文案。
# 奖励一律走 RewardLedger（tx = side|<qid>|complete）——重复交付不会再发第二次。
# 共同规则（P05 设计 §4）：目标发生在接取前不计数；同一时间只追踪 1 条；完成后可补做。

## 支线全表（data/side_quests.json）。
func side_quest_rows() -> Array:
	var rows: Variant = TableCache.side_quests_config().get("quests", [])
	return rows if rows is Array else []


## 当前可玩（live）的支线行：a1_elite_beast 要等 P05-C 失路兽落地后才开门，
## 所有入口（接取／NPC 交互／实体生成）统一走这里，避免开出做不了的任务。
func _side_live_rows() -> Array:
	var out: Array = []
	for row_v in side_quest_rows():
		if row_v is Dictionary and bool((row_v as Dictionary).get("live", true)):
			var prerequisite := String((row_v as Dictionary).get("requires_story", ""))
			if not prerequisite.is_empty() and not story_step_done(prerequisite):
				continue
			out.append(row_v)
	return out


## prog.act1 归一（幂等，只补缺键）：side_quests / tracked / discoveries / first_kills。
## 旧档没有这些键时补空结构；不重写 repair_method 等既有内容。
func act1_state() -> Dictionary:
	var a: Variant = prog.get("act1")
	if not (a is Dictionary):
		a = {}
		prog["act1"] = a
	var act1 := a as Dictionary
	if not (act1.get("side_quests") is Dictionary):
		act1["side_quests"] = {}
	if not (act1.get("discoveries") is Array):
		act1["discoveries"] = []
	if not (act1.get("first_kills") is Array):
		act1["first_kills"] = []
	if not act1.has("tracked"):
		act1["tracked"] = ""
	return act1


# ---------- P05-D：导师第二技能与第一专精 ----------

func mentor_cfg() -> Dictionary:
	var v: Variant = TableCache.act1_growth_config().get("mentor", {})
	return v if v is Dictionary else {}


func mentor_role_cfg(role_id := "") -> Dictionary:
	var rid := role_id if not role_id.is_empty() else selected_role
	var roles_v: Variant = mentor_cfg().get("roles", {})
	if not (roles_v is Dictionary):
		return {}
	var row: Variant = (roles_v as Dictionary).get(rid, {})
	return row if row is Dictionary else {}


func mentor_second_skill(role_id := "") -> String:
	return String(mentor_role_cfg(role_id).get("skill", ""))


func mentor_state() -> Dictionary:
	var a := act1_state()
	var v: Variant = a.get("mentor")
	if not (v is Dictionary):
		v = {"unlocked": [], "mastery": {}, "variants": {}}
		a["mentor"] = v
	var m := v as Dictionary
	if not (m.get("unlocked") is Array):
		m["unlocked"] = []
	if not (m.get("mastery") is Dictionary):
		m["mastery"] = {}
	if not (m.get("variants") is Dictionary):
		m["variants"] = {}
	return m


func mentor_status(role_id := "") -> String:
	var rid := role_id if not role_id.is_empty() else selected_role
	var sid := mentor_second_skill(rid)
	if sid.is_empty():
		return "unavailable"
	var unlock_after := String(mentor_cfg().get("unlock_after", "s03"))
	if not story_step_done(unlock_after):
		return "locked"
	var m := mentor_state()
	if not (m["unlocked"] as Array).has(sid):
		return "ready"
	var need := maxi(1, int(mentor_cfg().get("mastery_target", 1)))
	if int((m["mastery"] as Dictionary).get(sid, 0)) < need:
		return "practice"
	if String((m["variants"] as Dictionary).get(sid, "")).is_empty():
		return "choose"
	return "chosen"


## 主世界技能槽：第一式默认可用；导师领取后加入第二式。未传该字段的历练／演武仍保留五技。
func act1_unlocked_skills(role_id := "") -> Array:
	var rid := role_id if not role_id.is_empty() else selected_role
	var role := get_role(rid)
	var all: Array = role.get("skills", [])
	if all.is_empty():
		return []
	var out: Array = [String(all[0])]
	var sid := mentor_second_skill(rid)
	if not sid.is_empty() and (mentor_state()["unlocked"] as Array).has(sid):
		out.append(sid)
	return out


func act1_skill_variants(role_id := "") -> Dictionary:
	var sid := mentor_second_skill(role_id)
	if sid.is_empty():
		return {}
	var choice := String((mentor_state()["variants"] as Dictionary).get(sid, ""))
	if choice.is_empty():
		return {}
	var variants_v: Variant = mentor_role_cfg(role_id).get("variants", {})
	if not (variants_v is Dictionary):
		return {}
	var mod_v: Variant = (variants_v as Dictionary).get(choice, {})
	return {sid: (mod_v as Dictionary).duplicate(true)} if mod_v is Dictionary else {}


func mentor_unlock_second(persist := true) -> Dictionary:
	if save_locked or mentor_status() != "ready":
		return {"ok": false, "reason": mentor_status()}
	var sid := mentor_second_skill()
	var before := prog.duplicate(true)
	(mentor_state()["unlocked"] as Array).append(sid)
	if persist and not save_game():
		prog = before
		return {"ok": false, "reason": "save_failed"}
	return {"ok": true, "skill": sid, "name": String(TableCache.get_skill(sid).get("name", sid))}


## 一场战斗同一技能只上报一次；只有 SkillSystem 发出的 skill_effective 才会进入这里，空放不刷。
func mentor_report_effective(skill_ids: Array, persist := true) -> Array:
	var messages: Array = []
	var sid := mentor_second_skill()
	if sid.is_empty() or not skill_ids.has(sid):
		return messages
	var m := mentor_state()
	if not (m["unlocked"] as Array).has(sid):
		return messages
	var mastery := m["mastery"] as Dictionary
	var need := maxi(1, int(mentor_cfg().get("mastery_target", 1)))
	var old := int(mastery.get(sid, 0))
	if old >= need:
		return messages
	var before := prog.duplicate(true)
	var now := mini(need, old + 1)
	mastery[sid] = now
	if persist and not save_game():
		prog = before
		return []
	messages.append("熟练 · %s %d/%d" % [String(TableCache.get_skill(sid).get("name", sid)), now, need])
	if now >= need:
		messages.append("可回城找岳教头选择招式分支")
	return messages


func mentor_choose_variant(choice: String, persist := true) -> Dictionary:
	if save_locked or mentor_status() != "choose":
		return {"ok": false, "reason": mentor_status()}
	var sid := mentor_second_skill()
	var variants_v: Variant = mentor_role_cfg().get("variants", {})
	if not (variants_v is Dictionary) or not (variants_v as Dictionary).has(choice):
		return {"ok": false, "reason": "invalid_choice"}
	var before := prog.duplicate(true)
	(mentor_state()["variants"] as Dictionary)[sid] = choice
	if persist and not save_game():
		prog = before
		return {"ok": false, "reason": "save_failed"}
	var row := (variants_v as Dictionary)[choice] as Dictionary
	return {"ok": true, "skill": sid, "choice": choice,
		"name": String(row.get("name", choice)), "desc": String(row.get("desc", ""))}


func mentor_reset_variant(persist := true) -> Dictionary:
	if save_locked or mentor_status() != "chosen":
		return {"ok": false, "reason": mentor_status()}
	var cost := maxi(0, int(mentor_cfg().get("reset_cost_gold", 120)))
	if int(wallet.get("gold", 0)) < cost:
		return {"ok": false, "reason": "gold"}
	var before_prog := prog.duplicate(true)
	var before_wallet := wallet.duplicate(true)
	wallet["gold"] = int(wallet.get("gold", 0)) - cost
	(mentor_state()["variants"] as Dictionary).erase(mentor_second_skill())
	if persist and not save_game():
		prog = before_prog
		wallet = before_wallet
		return {"ok": false, "reason": "save_failed"}
	return {"ok": true, "cost": cost}


func side_status_of(qid: String) -> String:
	return QuestService.side_status(act1_state(), qid)


## 第一幕商路报价是只读预览：由已交付的送盐支线与修碑方式派生，
## 不另存一份价格状态，读档后始终与实际世界旗一致。
func first_order_preview() -> Dictionary:
	var cfg: Dictionary = TableCache.act1_orders_config().get("first_route", {})
	if cfg.is_empty():
		return {}
	var out := cfg.duplicate(true)
	var qid := String(cfg.get("unlock_side_quest", ""))
	var unlocked := side_status_of(qid) == QuestService.SIDE_DONE
	out["unlocked"] = unlocked
	var method := String(act1_state().get("repair_method", ""))
	var quotes: Dictionary = cfg.get("repair_quotes", {})
	out["quote_gold"] = int(quotes.get(method, cfg.get("base_quote_gold", 0)))
	out["route_state"] = "blocked" if not unlocked else ("repaired" if quotes.has(method) else "open")
	out["note"] = String(cfg.get("blocked_note", "")) if not unlocked else \
		String(cfg.get("%s_note" % method, cfg.get("open_note", "")))
	return out


## P06 单机现货：每笔交易只修改本地档。游戏日与价格从存档状态重现，不看现实零点。
func economy_state() -> Dictionary:
	var current: Variant = prog.get("economy", {})
	if current is Dictionary:
		var existing := current as Dictionary
		if existing.has("seed") and existing.has("day") and existing.has("next_tx") \
				and existing.has("bought") and existing.has("sold") and existing.has("history") \
			and existing.has("orders") and existing.has("work"):
			return existing
	var state := EconomyService.ensure(current if current is Dictionary else {},
		TableCache.economy_config())
	prog["economy"] = state
	return state


func economy_quote(site_id: String, good_id: String) -> Dictionary:
	var cfg := TableCache.economy_config()
	var state := economy_state()
	var repair := String(act1_state().get("repair_method", ""))
	var out := EconomyService.quote(cfg, state, site_id, good_id, repair)
	if not out.is_empty():
		out["held"] = item_count(good_id)
		out["carried_weight"] = EconomyService.carried_weight(cfg, items)
		out["carry_limit"] = int(cfg.get("carry_limit", 28))
	return out


## {ok, err, action, quantity, total_gold, transaction_id}；失败内存/存档零副作用。
func economy_trade(site_id: String, good_id: String, action: String, quantity: int) -> Dictionary:
	if save_locked:
		return {"ok": false, "err": "存档暂不可写"}
	if action not in ["buy", "sell"] or quantity < 1 or quantity > 20:
		return {"ok": false, "err": "交易数量须为 1–20"}
	var cfg := TableCache.economy_config()
	var quote := economy_quote(site_id, good_id)
	if quote.is_empty():
		return {"ok": false, "err": "没有这个交易点或货品"}
	if action == "buy" and quantity > int(quote["stock_left"]):
		return {"ok": false, "err": "今日库存不足"}
	if action == "sell" and quantity > int(quote["demand_left"]):
		return {"ok": false, "err": "今日收购额度已满"}
	if action == "buy" and int(quote["carried_weight"]) + quantity * int(quote["weight"]) \
			> int(quote["carry_limit"]):
		return {"ok": false, "err": "携带负担已满"}
	var unit := int(quote["buy_gold"] if action == "buy" else quote["sell_gold"])
	var total := unit * quantity
	var costs := {"gold": total} if action == "buy" else {"item:%s" % good_id: quantity}
	var grants := {"item:%s" % good_id: quantity} if action == "buy" else {"gold": total}
	var before_prog := prog.duplicate(true)
	var before_wallet := wallet.duplicate(true)
	var before_items := items.duplicate(true)
	var state := economy_state()
	var tid := RewardLedger.tx_id("spot", site_id, "%s:%s" % [action, good_id],
		str(int(state.get("next_tx", 1))))
	var applied := RewardLedger.apply(RewardLedger.make(tid, costs, grants, {}), ledger(), self)
	if not bool(applied.get("applied", false)):
		prog = before_prog
		wallet = before_wallet
		items = before_items
		return {"ok": false, "err": String(applied.get("err", "交易未结算"))}
	state["next_tx"] = int(state.get("next_tx", 1)) + 1
	var bucket := "bought" if action == "buy" else "sold"
	var counts: Dictionary = state[bucket]
	var stock_key := EconomyService.key(site_id, good_id)
	counts[stock_key] = int(counts.get(stock_key, 0)) + quantity
	EconomyService.record_history(cfg, state,
		String(act1_state().get("repair_method", "")))
	if not save_game():
		prog = before_prog
		wallet = before_wallet
		items = before_items
		return {"ok": false, "err": "交易写盘失败，已回滚"}
	return {"ok": true, "err": "", "action": action, "quantity": quantity,
		"total_gold": total, "transaction_id": tid}


## 在可走到的驿点歇脚推进游戏日；付费让行情轮换有真实成本。
func economy_rest(site_id: String) -> Dictionary:
	if save_locked or EconomyService.site(TableCache.economy_config(), site_id).is_empty():
		return {"ok": false, "err": "当前不能歇脚"}
	var cfg := TableCache.economy_config()
	var fee := maxi(0, int(cfg.get("rest_gold", 22)))
	var before_prog := prog.duplicate(true)
	var before_wallet := wallet.duplicate(true)
	var before_items := items.duplicate(true)
	var state := economy_state()
	var tid := RewardLedger.tx_id("economy", "rest", site_id,
		str(int(state.get("next_tx", 1))))
	var applied := RewardLedger.apply(RewardLedger.make(tid, {"gold": fee}, {}, {}), ledger(), self)
	if not bool(applied.get("applied", false)):
		prog = before_prog
		wallet = before_wallet
		items = before_items
		return {"ok": false, "err": String(applied.get("err", "歇脚未结算"))}
	state["next_tx"] = int(state.get("next_tx", 1)) + 1
	var day := EconomyService.advance_day(cfg, state,
		String(act1_state().get("repair_method", "")))
	if not save_game():
		prog = before_prog
		wallet = before_wallet
		items = before_items
		return {"ok": false, "err": "歇脚写盘失败，已回滚"}
	return {"ok": true, "day": day, "fee_gold": fee}


## 工作每日每种只完成一次，收益低且稳定；事务 ID 含游戏日，读档不能重复领。
func economy_work(site_id: String, job_id: String) -> Dictionary:
	if save_locked:
		return {"ok": false, "err": "存档暂不可写"}
	var job := {}
	for row_v in (TableCache.economy_config().get("jobs", []) as Array):
		var row := row_v as Dictionary
		if String(row.get("id", "")) == job_id and String(row.get("site_id", "")) == site_id:
			job = row
			break
	if job.is_empty():
		return {"ok": false, "err": "这里没有这份工作"}
	var state := economy_state()
	var day := int(state.get("day", 1))
	var work: Dictionary = state.get("work", {})
	if int(work.get(job_id, 0)) >= day:
		return {"ok": false, "err": "今天这份工作已经做过"}
	var before_prog := prog.duplicate(true)
	var before_wallet := wallet.duplicate(true)
	var tid := RewardLedger.tx_id("work", site_id, job_id, str(day))
	var grant := {"gold": int(job.get("gold", 0)), "exp": int(job.get("exp", 0))}
	var applied := RewardLedger.apply(RewardLedger.make(tid, {}, grant, {}), ledger(), self)
	if not bool(applied.get("applied", false)):
		prog = before_prog
		wallet = before_wallet
		return {"ok": false, "err": String(applied.get("err", "工作未结算"))}
	work[job_id] = day
	if not save_game():
		prog = before_prog
		wallet = before_wallet
		return {"ok": false, "err": "工作写盘失败，已回滚"}
	return {"ok": true, "gold": int(job.get("gold", 0)), "exp": int(job.get("exp", 0))}


## 第一幕运路：货物由现货买入或其它玩法取得；订单只认实际携带数量。
func economy_first_order() -> Dictionary:
	var route := first_order_preview()
	var config: Dictionary = TableCache.economy_config().get("first_order", {})
	if route.is_empty() or config.is_empty():
		return {}
	var id := String(config.get("id", ""))
	var state := economy_state()
	var saved: Variant = (state.get("orders", {}) as Dictionary).get(id, {})
	var record: Dictionary = saved if saved is Dictionary else {}
	var status := String(record.get("status", "available"))
	if not bool(route.get("unlocked", false)):
		status = "locked"
	elif status == "active" and int(state.get("day", 1)) > int(record.get("deadline_day", 0)):
		status = "expired"
	var cargo: Dictionary = config.get("cargo", {})
	var purchase := 0
	for gid in cargo:
		var q := economy_quote(String(config.get("origin_site", "")), String(gid))
		purchase += int(q.get("buy_gold", 0)) * int(cargo[gid])
	# 接单瞬间锁定净报酬。修碑与行情随后变化时不追溯修改合同。
	var freight := int(record.get("freight_gold", route.get("quote_gold", 0)))
	var payout := int(record.get("payout_gold", maxi(0,
		int(config.get("gross_reward_gold", 0)) - freight)))
	return {"id": id, "name": String(route.get("name", "")), "status": status,
		"origin_site": String(config.get("origin_site", "")),
		"destination_site": String(config.get("destination_site", "")),
		"cargo": cargo, "freight_gold": freight, "payout_gold": payout,
		"purchase_gold": purchase, "expected_profit_gold": payout - purchase,
		"reward_exp": int(config.get("reward_exp", 0)),
		"day": int(state.get("day", 1)), "deadline_day": int(record.get("deadline_day", 0)),
		"attempt": int(record.get("attempt", 0))}


func economy_first_order_accept() -> Dictionary:
	if save_locked:
		return {"ok": false, "err": "存档暂不可写"}
	var info := economy_first_order()
	if String(info.get("status", "locked")) not in ["available", "expired"]:
		return {"ok": false, "err": "这份订单目前不可接取"}
	var before := prog.duplicate(true)
	var state := economy_state()
	var orders: Dictionary = state["orders"]
	var id := String(info["id"])
	var prior: Variant = orders.get(id, {})
	var old: Dictionary = prior if prior is Dictionary else {}
	var day := int(state["day"])
	var deadline := day + int(TableCache.economy_config().get("first_order", {}).get("deadline_days", 3))
	orders[id] = {"status": "active", "attempt": int(old.get("attempt", 0)) + 1,
		"accepted_day": day, "deadline_day": deadline,
		"freight_gold": int(info["freight_gold"]), "payout_gold": int(info["payout_gold"])}
	if not save_game():
		prog = before
		return {"ok": false, "err": "接单写盘失败，已回滚"}
	return {"ok": true, "deadline_day": deadline, "attempt": int((orders[id] as Dictionary)["attempt"])}


func economy_first_order_deliver(site_id: String) -> Dictionary:
	if save_locked:
		return {"ok": false, "err": "存档暂不可写"}
	var info := economy_first_order()
	if site_id != String(info.get("destination_site", "")):
		return {"ok": false, "err": "请到订单目的地交货"}
	if String(info.get("status", "")) != "active":
		return {"ok": false, "err": "订单未接取、已过期或已经完成"}
	var costs := {}
	for gid in (info.get("cargo", {}) as Dictionary):
		costs["item:%s" % String(gid)] = int((info["cargo"] as Dictionary)[gid])
	var grants := {"gold": int(info["payout_gold"]), "exp": int(info["reward_exp"])}
	var before_prog := prog.duplicate(true)
	var before_wallet := wallet.duplicate(true)
	var before_items := items.duplicate(true)
	var tid := RewardLedger.tx_id("order", String(info["id"]), "complete",
		str(int(info["attempt"])))
	var applied := RewardLedger.apply(RewardLedger.make(tid, costs, grants,
		{"act1_first_order_done": true}), ledger(), self)
	if not bool(applied.get("applied", false)):
		prog = before_prog
		wallet = before_wallet
		items = before_items
		return {"ok": false, "err": String(applied.get("err", "订单未结算"))}
	var state := economy_state()
	var orders: Dictionary = state["orders"]
	var record: Dictionary = orders[String(info["id"])]
	record["status"] = "done"
	record["completed_day"] = int(state.get("day", 1))
	if not save_game():
		prog = before_prog
		wallet = before_wallet
		items = before_items
		return {"ok": false, "err": "交单写盘失败，已回滚"}
	return {"ok": true, "gold": int(info["payout_gold"]), "exp": int(info["reward_exp"]),
		"transaction_id": tid}


## P07-D：现货备货 → 港口装船 → 下一游戏日领取。与 P06 共用实物和订单账本。
func shipping_config(id: String) -> Dictionary:
	for row in (TableCache.economy_config().get("shipping_orders", []) as Array):
		if String((row as Dictionary).get("id", "")) == id:
			return row as Dictionary
	return {}


func shipping_order(id: String) -> Dictionary:
	var cfg := shipping_config(id)
	if cfg.is_empty():
		return {}
	var state := economy_state()
	var record: Dictionary = (state["orders"] as Dictionary).get(id, {})
	var day := int(state["day"])
	var status := String(record.get("status", "available"))
	if not story_step_done(String(cfg.get("unlock_step", "s16"))):
		status = "locked"
	elif status == "active" and day > int(record.get("deadline_day", 0)):
		status = "expired"
	elif status == "transit" and day >= int(record.get("arrival_day", 0)):
		status = "ready"
	elif status == "done" and day > int(record.get("completed_day", 0)):
		status = "available"
	var event := String(state.get("port_event", ""))
	var freight := maxi(0, int(cfg.get("freight_gold", 0))
		+ int((cfg.get("event_freight", {}) as Dictionary).get(event, 0)))
	var payout := maxi(0, int(cfg.get("gross_reward_gold", 0)) - freight)
	if status in ["active", "transit", "ready", "done"]:
		freight = int(record.get("freight_gold", freight))
		payout = int(record.get("payout_gold", payout))
	var purchase := 0
	for gid in (cfg["cargo"] as Dictionary):
		purchase += int(economy_quote(String(cfg["purchase_site"]), String(gid)).get("buy_gold", 0)) \
			* int((cfg["cargo"] as Dictionary)[gid])
	var out := cfg.duplicate(true)
	out.merge({"status": status, "day": day, "freight_gold": freight, "payout_gold": payout,
		"purchase_gold": purchase, "expected_profit_gold": payout - purchase,
		"attempt": int(record.get("attempt", 0)), "deadline_day": int(record.get("deadline_day", 0)),
		"arrival_day": int(record.get("arrival_day", 0))}, true)
	return out


func shipping_accept(id: String, site_id: String) -> Dictionary:
	var info := shipping_order(id)
	if save_locked or info.is_empty() or site_id != String(info.get("dispatch_site", "")):
		return {"ok": false, "err": "请在沉渊港港务厅接单"}
	if String(info.get("status", "")) not in ["available", "expired"]:
		return {"ok": false, "err": "此船单未开放或正在执行，本日完成的单明日可再接"}
	var before := prog.duplicate(true)
	var state := economy_state()
	var orders: Dictionary = state["orders"]
	var attempt := int(info["attempt"]) + 1
	var deadline := int(state["day"]) + int(info["deadline_days"])
	orders[id] = {"status": "active", "attempt": attempt, "accepted_day": int(state["day"]),
		"deadline_day": deadline, "freight_gold": int(info["freight_gold"]),
		"payout_gold": int(info["payout_gold"])}
	if not save_game():
		prog = before
		return {"ok": false, "err": "接单未保存，已回滚"}
	return {"ok": true, "deadline_day": deadline}


func shipping_dispatch(id: String, site_id: String) -> Dictionary:
	var info := shipping_order(id)
	if save_locked or info.is_empty() or site_id != String(info.get("dispatch_site", "")):
		return {"ok": false, "err": "请在沉渊港装船"}
	if String(info.get("status", "")) != "active":
		return {"ok": false, "err": "此船单尚未接取、已过期或已装船"}
	var costs := {}
	for gid in (info["cargo"] as Dictionary):
		costs["item:%s" % String(gid)] = int((info["cargo"] as Dictionary)[gid])
	var before_prog := prog.duplicate(true)
	var before_items := items.duplicate(true)
	var tid := RewardLedger.tx_id("shipping", id, "dispatch", str(int(info["attempt"])))
	var res := RewardLedger.apply(RewardLedger.make(tid, costs, {}, {}), ledger(), self)
	if not bool(res.get("applied", false)):
		prog = before_prog
		items = before_items
		return {"ok": false, "err": "所需货物不足或此批已经装船"}
	var state := economy_state()
	var record: Dictionary = (state["orders"] as Dictionary)[id]
	record["status"] = "transit"
	record["arrival_day"] = int(state["day"]) + maxi(1, int(info.get("travel_days", 1)))
	if not save_game():
		prog = before_prog
		items = before_items
		return {"ok": false, "err": "装船未保存，货物已退回"}
	return {"ok": true, "arrival_day": int(record["arrival_day"])}


func shipping_claim(id: String, site_id: String) -> Dictionary:
	var info := shipping_order(id)
	if save_locked or info.is_empty() or site_id != String(info.get("dispatch_site", "")):
		return {"ok": false, "err": "请回沉渊港领取船单报酬"}
	if String(info.get("status", "")) != "ready":
		return {"ok": false, "err": "船尚未到港或这笔报酬已领取"}
	var before_prog := prog.duplicate(true)
	var before_wallet := wallet.duplicate(true)
	var tid := RewardLedger.tx_id("shipping", id, "arrive", str(int(info["attempt"])))
	var grants := {"gold": int(info["payout_gold"]), "exp": int(info["reward_exp"])}
	var res := RewardLedger.apply(RewardLedger.make(tid, {}, grants,
		{"act2_ship_first_done": true}), ledger(), self)
	if not bool(res.get("applied", false)):
		prog = before_prog
		wallet = before_wallet
		return {"ok": false, "err": "船单报酬已经结算"}
	var state := economy_state()
	var record: Dictionary = (state["orders"] as Dictionary)[id]
	record["status"] = "done"
	record["completed_day"] = int(state["day"])
	if not save_game():
		prog = before_prog
		wallet = before_wallet
		return {"ok": false, "err": "领取未保存，已回滚"}
	return {"ok": true, "gold": int(info["payout_gold"]), "exp": int(info["reward_exp"])}


## 港务关系第一段：叙事选择等值，宝石奖励整段只领取一次。
func port_relation_choice(choice: String) -> Dictionary:
	if save_locked or not story_step_done("s20") or choice not in ["remember", "promise"]:
		return {"ok": false, "err": "先处理潮闸与回港定路，再与沈澜谈谈"}
	if int((prog.get("flags", {}) as Dictionary).get("act2_shenlan_relation_stage", 0)) >= 1:
		return {"ok": false, "err": "这一段谈话已经完成"}
	var before_prog := prog.duplicate(true)
	var before_items := items.duplicate(true)
	var before_wallet := wallet.duplicate(true)
	var tx := RewardLedger.make(RewardLedger.tx_id("relation", "shenlan", "stage1"), {},
		{"item:gem_def_1": 1, "exp": 20}, {"act2_shenlan_relation_stage": 1, "act2_shenlan_relation_choice": choice})
	var result := RewardLedger.apply(tx, ledger(), self)
	if not bool(result.get("applied", false)) or not save_game():
		prog = before_prog
		items = before_items
		wallet = before_wallet
		return {"ok": false, "err": "谈话未保存，奖励已回滚"}
	return {"ok": true, "gem": "gem_def_1", "exp": 20}


func restored_stele_name() -> String:
	return String(TableCache.story_quests_config().get("restored_stele_name", "归路碑"))


func side_tracked() -> String:
	return String(act1_state().get("tracked", ""))


## 切换追踪（写盘）。只能追踪已接且未完的支线；同一时间只追踪一条。
func side_track(qid: String) -> bool:
	if save_locked:
		return false
	var before := prog.duplicate(true)
	if not QuestService.side_track(act1_state(), qid):
		return false
	if not save_game():
		prog = before
		return false
	return true


## 接取支线（写盘；含接取时发放的任务物，如驿商的盐包）。
func side_accept(qid: String) -> Dictionary:
	if save_locked:
		return {"ok": false, "reason": "locked"}
	var rows := _side_live_rows()
	var row := QuestService.side_row(rows, qid)
	if row.is_empty():
		return {"ok": false, "reason": "locked"}
	var before := prog.duplicate(true)
	var before_items := items.duplicate(true)
	var res := QuestService.side_accept(act1_state(), rows, qid)
	if not bool(res.get("ok", false)):
		return res
	var give := String(row.get("accept_item", ""))
	if not give.is_empty():
		items[give] = item_count(give) + 1
	if not save_game():
		prog = before
		items = before_items
		return {"ok": false, "reason": "save_failed"}
	return {"ok": true, "reason": "ok", "qid": qid,
		"title": String(row.get("title", "")),
		"line": String(row.get("accept_dialogue", ""))}


## 野外事件上报（战斗胜利／采集／观察）。persist=false 时由调用方与主线一起写盘。
## 返回发生变化的 qid 列表；dup 与无变化返回空（同一场战斗只结算一次，不会重复计数）。
func side_report(kind: String, source_id: String, map_id: String, persist := true) -> Array:
	if save_locked:
		return []
	var before := prog.duplicate(true)
	var event := QuestService.world_event(kind, source_id, map_id,
		selected_role if not selected_role.is_empty() else "player")
	var touched := QuestService.side_report(act1_state(), _side_live_rows(), event, items)
	if touched.is_empty():
		return []
	if persist and not save_game():
		prog = before
		return []
	return touched


## 野外实体是否该生成（MapScene 调）。规则：未接／可交付／已完成不生成；
## 已采过或看过的实体（seen）不再生成——跨读档、跨天一致，不靠每日刷新。
func side_entity_visible(eid: String, qid: String) -> bool:
	if qid.is_empty():
		return true   # 无任务归属的实体（P05-D 旧路石箱）由 WorldSession 实体态自己管
	var act1 := act1_state()
	var st := QuestService.side_status(act1, qid)
	if st.is_empty() or st == QuestService.SIDE_READY or st == QuestService.SIDE_DONE:
		return false
	var seen: Variant = QuestService.side_get(act1, qid).get("seen", [])
	return not (seen is Array and (seen as Array).has(eid))


## 野外实体交互（MapScene 调）。kind ∈ collect／observe／deliver。
## 返回 { ok, reason, toasts, hide }：hide=true 时实体从地图上消失（采集/观察/送达成功）。
func side_entity_interact(kind: String, eid: String, map_id: String, qid := "") -> Dictionary:
	if save_locked:
		return {"ok": false, "reason": "locked", "toasts": [], "hide": false}
	var before_prog := prog.duplicate(true)
	var before_wallet := wallet.duplicate(true)
	var before_items := items.duplicate(true)
	var act1 := act1_state()
	var rows := _side_live_rows()
	var event := QuestService.world_event(kind, eid, map_id,
		selected_role if not selected_role.is_empty() else "player")
	var touched := QuestService.side_report(act1, rows, event, items)
	if touched.is_empty():
		return {"ok": false, "reason": "no_progress", "toasts": [], "hide": false}
	var toasts: Array = []
	if kind == "collect":
		for qid_v in touched:
			var row := QuestService.side_row(rows, String(qid_v))
			var give := String(row.get("collect_item", ""))
			if not give.is_empty():
				items[give] = item_count(give) + 1
				toasts.append("获得 %s ×1" % item_name(give))
	if kind == "deliver":
		for qid_v2 in touched:
			var qid2 := String(qid_v2)
			var row2 := QuestService.side_row(rows, qid2)
			if String(row2.get("turn_in", "")) == eid:
				var done := _side_complete(qid2, false)   # 收件人是实体自己：当场成交
				for t in done.get("toasts", []):
					toasts.append(String(t))
	if not save_game():
		prog = before_prog
		wallet = before_wallet
		items = before_items
		return {"ok": false, "reason": "save_failed", "toasts": [], "hide": false}
	return {"ok": true, "reason": "", "toasts": toasts, "hide": true}


## 交付领取（persist=true 时自己写盘；false 时由调用方统一写盘）。
## 前置：该支线 ready。一个事务：扣交付物 + 发奖 + 记线索 + 清追踪，同次落盘；失败整体回滚。
func _side_complete(qid: String, persist := true, choice := "") -> Dictionary:
	if save_locked:
		return {}
	var rows := _side_live_rows()
	var row := QuestService.side_row(rows, qid)
	if row.is_empty():
		return {}
	var options: Dictionary = row.get("choices", {})
	if not options.is_empty() and not options.has(choice):
		return {}
	var before_prog := prog.duplicate(true)
	var before_wallet := wallet.duplicate(true)
	var before_items := items.duplicate(true)
	var res := QuestService.side_turn_in(act1_state(), rows, qid)
	if not bool(res.get("ok", false)):
		return {}
	var chosen: Dictionary = options.get(choice, {})
	if not chosen.is_empty():
		QuestService.side_get(act1_state(), qid)["choice"] = choice
	var reward: Dictionary = res.get("reward", {})
	var costs := {}
	var consume := String(res.get("consume_item", ""))
	if not consume.is_empty():
		costs["item:%s" % consume] = 1
	var grants := {
		"gold": maxi(0, int(reward.get("gold", 0))),
		"exp": maxi(0, int(reward.get("exp", 0))),
	}
	var ritems: Variant = reward.get("items", {})
	if ritems is Dictionary:
		for key in (ritems as Dictionary):
			grants["item:%s" % String(key)] = maxi(1, int((ritems as Dictionary)[key]))
	var completion_flags: Dictionary = chosen.get("flags", {})
	var tx := RewardLedger.make(RewardLedger.tx_id("side", qid, "complete"), costs, grants, completion_flags)
	var applied := RewardLedger.apply(tx, ledger(), self)
	if not bool(applied.get("ok", false)):
		prog = before_prog
		wallet = before_wallet
		items = before_items
		push_warning("支线交付未落地：%s" % String(applied.get("err", "")))
		return {}
	var discovery := String(res.get("discovery", ""))
	if not discovery.is_empty():
		var discs: Array = act1_state()["discoveries"]
		if not discs.has(discovery):
			discs.append(discovery)
	if persist and not save_game():
		prog = before_prog
		wallet = before_wallet
		items = before_items
		return {}
	return {"ok": true, "qid": qid, "reward": reward,
		"title": String(row.get("title", "")),
		"line": String(chosen.get("dialogue", row.get("completion_dialogue", ""))),
		"toasts": _side_reward_toasts(reward)}


## 支线奖励行（含 items 字典；reward_lines 只认单数 item，这里补上）。
func _side_reward_toasts(reward: Dictionary) -> Array:
	var out: Array = []
	for line in reward_lines(reward):
		out.append(String(line))
	var ritems: Variant = reward.get("items", {})
	if ritems is Dictionary:
		for key in (ritems as Dictionary):
			out.append("%s ×%d" % [item_name(String(key)), int((ritems as Dictionary)[key])])
	return out


## 城内 NPC 支线交互（CityScene 打开对话时调）。
## 返回 {kind:"accept"/"turn_in", qid, title, line, toasts}；无支线动作返回 {}。
func side_npc_interact(npc_id: String) -> Dictionary:
	var rows := _side_live_rows()
	var action := QuestService.side_npc_action(act1_state(), rows, npc_id)
	if action.is_empty():
		return {}
	var qid := String(action.get("qid", ""))
	var row := QuestService.side_row(rows, qid)
	if String(action.get("kind", "")) == "turn_in":
		var done := _side_complete(qid)
		if done.is_empty():
			return {}
		return {"kind": "turn_in", "qid": qid,
			"title": String(row.get("title", "")),
			"line": String(row.get("completion_dialogue", "")),
			"toasts": done.get("toasts", [])}
	var acc := side_accept(qid)
	if not bool(acc.get("ok", false)):
		return {}
	var toasts: Array = ["已接取支线：%s" % String(row.get("title", ""))]
	var give := String(row.get("accept_item", ""))
	if not give.is_empty():
		toasts.append("获得 %s ×1" % item_name(give))
	return {"kind": "accept", "qid": qid,
		"title": String(row.get("title", "")),
		"line": String(row.get("accept_dialogue", "")),
		"toasts": toasts}


## NPC 的支线台词（CityScene 台词优先级：支线 > 每日委托 > 随机闲聊）。
## 可交付 > 进行中 > 完成后的世界变化台词；无相关支线返回空串。
func side_npc_line(npc_id: String) -> String:
	var act1 := act1_state()
	var completed_line := ""
	for row_v in _side_live_rows():
		var row := row_v as Dictionary
		var qid := String(row.get("id", ""))
		var st := QuestService.side_status(act1, qid)
		if st.is_empty():
			continue
		var is_giver := String(row.get("giver", "")) == npc_id
		var is_turn := String(row.get("turn_in", "")) == npc_id
		if not (is_giver or is_turn):
			continue
		if st == QuestService.SIDE_READY and is_turn:
			return String(row.get("ready_dialogue", ""))
		if st == QuestService.SIDE_ACTIVE:
			return String(row.get("progress_dialogue", ""))
		if st == QuestService.SIDE_DONE:
			var choice := String(QuestService.side_get(act1, qid).get("choice", ""))
			var chosen: Dictionary = (row.get("choices", {}) as Dictionary).get(choice, {})
			completed_line = String(chosen.get("dialogue", row.get("completion_dialogue", "")))
	return completed_line


## HUD 支线蓝签文案（只显示追踪中的那一条）。
func side_line() -> String:
	var qid := side_tracked()
	if qid.is_empty():
		return ""
	var rows := _side_live_rows()
	var info := QuestService.side_progress_info(act1_state(), rows, qid)
	if info.is_empty():
		return ""
	var title := String(info.get("title", "支线"))
	var st := String(info.get("status", ""))
	if st == QuestService.SIDE_READY:
		return "支线 · %s（可交付：%s）" % [title, side_target_name(String(info.get("turn_in", "")))]
	if st == QuestService.SIDE_DONE:
		return ""
	return "支线 · %s %d/%d" % [title, int(info.get("progress", 0)), int(info.get("need", 1))]


## 支线日志（蓝签点击/任务详情）。qid 空时取当前追踪的一条。
func side_info_lines(qid := "") -> Array:
	var q := qid if not qid.is_empty() else side_tracked()
	if q.is_empty():
		return ["当前没有追踪的支线。", "城内可接线索：老赵、小满、青姨、阿豆、行脚商人。"]
	var rows := _side_live_rows()
	var row := QuestService.side_row(rows, q)
	var info := QuestService.side_progress_info(act1_state(), rows, q)
	if row.is_empty() or info.is_empty():
		return []
	var st := String(info.get("status", ""))
	var lines: Array = ["目标：%s" % String(info.get("objective_text", ""))]
	if st == QuestService.SIDE_READY:
		lines.append("进度：目标已完成，回去交付")
	elif st == QuestService.SIDE_DONE:
		lines.append("进度：已完成")
	else:
		lines.append("进度：%d/%d" % [int(info.get("progress", 0)), int(info.get("need", 1))])
	var map_name := String(TableCache.main_world_map(String(row.get("map", ""))).get("name", ""))
	if not map_name.is_empty():
		lines.append("地点：%s" % map_name)
	if st != QuestService.SIDE_DONE:
		lines.append("交付：%s（%s）" % [side_target_name(String(info.get("turn_in", ""))),
			String(TableCache.main_world_map(String(info.get("turn_in_map", ""))).get("name", ""))])
	for line in _side_reward_toasts(row.get("reward", {})):
		lines.append("奖励：%s" % String(line))
	return lines


## 支线交付对象显示名：城内 NPC 走 city.json，野外实体走地图实体配置的 name。
func side_target_name(id: String) -> String:
	var npc := city_npc(id)
	if not npc.is_empty():
		return String(npc.get("name", id))
	var maps: Variant = TableCache.main_world_config().get("maps", {})
	if maps is Dictionary:
		for mid in (maps as Dictionary):
			var cfg: Variant = (maps as Dictionary)[mid]
			if not (cfg is Dictionary):
				continue
			var ents: Variant = (cfg as Dictionary).get("entities", {})
			if ents is Dictionary and (ents as Dictionary).has(id):
				var row: Variant = (ents as Dictionary)[id]
				if row is Dictionary:
					return String((row as Dictionary).get("name", id))
	return id


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
	var nodes_cfg: Dictionary = TableCache.nodes_config()
	var rewards: Dictionary = nodes_cfg.get("rewards", {})
	if rewards.is_empty():
		push_error("nodes.json 缺 rewards，扫荡拒绝执行（不消耗券）")
		return {}
	var yield_pct := float(nodes_cfg.get("sweep_yield", 0.7))
	var gains := {"gold": 0, "expedition": 0, "soul": 0, "exp": 0, "honor": 0}
	for kind in _sweep_plan(nodes_cfg):
		var row: Dictionary = rewards.get(kind, {})
		for k in gains:
			gains[k] += int(row.get(k, 0))
	for k in gains:
		gains[k] = int(float(gains[k]) * yield_pct)
	# 先把收益算完再扣券：表配坏了就整单拒绝，不能让玩家白掉一张券（失败零副作用）
	var total := 0
	for k in gains:
		total += int(gains[k])
	if total <= 0:
		push_error("扫荡收益核算为 0（rewards/sweep_yield 配置异常），不消耗券")
		return {}
	if not consume_item("ticket_sweep", 1):
		return {}
	deposit(int(gains["gold"]), int(gains["expedition"]), int(gains["soul"]), int(gains["honor"]))
	gains["level_ups"] = gain_exp(int(gains["exp"]))
	return gains


## 扫荡的结算构成：每层 1 个普通节点 + 最终 1 个 BOSS。
## 层数读 nodes.json 的 layers——以前写死 ["normal","normal","normal","boss"]（问题 #37），
## 层数一改成 4 层，扫荡收益就与真实路线对不上，而且没有任何用例会红。
## 注意：扫荡**不吃苦行加成**，它是"免跑图"的保底收益。
func _sweep_plan(cfg: Dictionary) -> Array:
	# （已做故障注入验证：把它写死成 3 后 VerifySweep 报「期望 896，实为 812」，用例确实抓得住）
	var layers := maxi(1, int(cfg.get("layers", 3)))
	var plan: Array = []
	for i in layers:
		plan.append("normal")
	plan.append("boss")
	return plan


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


# ---------- 图鉴收集里程（轮次 20）：把"收了多少只"变成可领取的回报 ----------
# 此前图鉴只有一行"已收集 N / 8"的计数，收集本身没有任何回报——多抽到的宠物除了炼金
# 就没有别的意义。里程把"收集"变成有终点的短目标，且奖励直接落回抽卡/养成循环。

## 里程表（data/codex.json）。表写坏时返回空数组，图鉴照常能开。
func codex_milestones() -> Array:
	var arr: Variant = TableCache.codex_config().get("milestones", [])
	if not (arr is Array):
		return []
	var out: Array = []
	for m in arr:
		if not (m is Dictionary):
			push_warning("codex.json 里程条目不是对象，已忽略")
			continue
		var d := m as Dictionary
		if String(d.get("id", "")).is_empty() or int(d.get("need", 0)) <= 0:
			push_warning("codex.json 里程条目缺 id 或 need，已忽略：%s" % str(d))
			continue
		out.append(d)
	out.sort_custom(func(a, b):
		return int((a as Dictionary).get("need", 0)) < int((b as Dictionary).get("need", 0)))
	return out


func codex_claimed() -> Array:
	var arr: Variant = prog.get("codex_claimed", [])
	return arr if arr is Array else []


## 每条里程的当前状态：claimed / ready / missing。
func codex_milestone_state() -> Array:
	var owned := owned_pets().size()
	var claimed := codex_claimed()
	var out: Array = []
	for m in codex_milestones():
		var mid := String(m.get("id", ""))
		var need := int(m.get("need", 0))
		var done := claimed.has(mid)
		out.append({
			"id": mid, "need": need, "name": String(m.get("name", mid)),
			"rewards": m.get("rewards", {}), "item": m.get("item", {}),
			"claimed": done, "ready": (not done) and owned >= need,
			"missing": maxi(0, need - owned), "owned": owned,
		})
	return out


## 第一条可领取的里程（没有就返回空字典）。图鉴面板据此决定"领取"按钮能不能点。
func codex_next_ready() -> Dictionary:
	for s in codex_milestone_state():
		if bool((s as Dictionary).get("ready", false)):
			return s
	return {}


## 领取一条里程：存在 / 未领过 / 收集数达标，三者缺一即拒绝，且不做任何部分发放。
func codex_claim(mid: String) -> Dictionary:
	if mid.is_empty():
		return {"ok": false, "err": "暂时没有可领取的收集奖励"}
	var target: Dictionary = {}
	for m in codex_milestones():
		if String((m as Dictionary).get("id", "")) == mid:
			target = m
			break
	if target.is_empty():
		return {"ok": false, "err": "未知的收集里程"}
	if codex_claimed().has(mid):
		return {"ok": false, "err": "这份收集奖励已经领过了"}
	var need := int(target.get("need", 0))
	if owned_pets().size() < need:
		return {"ok": false, "err": "还差 %d 只灵宠" % (need - owned_pets().size())}
	var rewards: Variant = target.get("rewards", {})
	var lines: Array = []
	if rewards is Dictionary:
		apply_reward(rewards as Dictionary)
		lines = reward_lines(rewards as Dictionary)
	var item: Variant = target.get("item", {})
	var item_n := 0
	var item_id := ""
	if item is Dictionary:
		item_id = String((item as Dictionary).get("id", ""))
		item_n = maxi(0, int((item as Dictionary).get("n", 0)))
	if item_n > 0 and not item_id.is_empty():
		grant_item(item_id, item_n)
		lines.append("%s ×%d" % [item_name(item_id), item_n])
	var claimed: Array = codex_claimed()
	claimed.append(mid)
	prog["codex_claimed"] = claimed
	save_game()
	_sfx("reward", 0.0)
	return {"ok": true, "err": "", "name": String(target.get("name", mid)),
		"lines": lines, "need": need}


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


## 兼容仍声明为 starter 的伙伴。岩龟已改为第一幕领取；这里不会删掉老档已有伙伴，
## 也不会再给新档越过剧情自动补发。
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
		"story":
			var step := String(u.get("step", ""))
			return "第一幕兽栏结缘" if step == "s04" else "主线剧情结缘"
		"world_clear":
			return "通关「%s」首领" % world_name(String(u.get("world", "")))
		"egg":
			return "沉渊港兽栏孵化潮纹蛋"
	return "未知途径"


# ---------- P05-D2：岩龟剧情领取 ----------

## 老档已经拥有岩龟时直接视为 owned；新档必须完成 s04，绝不因打开面板自动发放。
func rockturtle_status() -> String:
	if owns_pet("pet_rockturtle"):
		return "owned"
	return "ready" if story_step_done("s04") else "locked"


## 在兽栏确认后才结缘。领取与旗标同次写盘，失败整体回滚；重复点击不会复制伙伴。
func claim_rockturtle(persist := true) -> Dictionary:
	var status := rockturtle_status()
	if save_locked or status != "ready":
		return {"ok": false, "reason": "locked" if save_locked else status}
	var before := prog.duplicate(true)
	var arr: Array = prog.get("pets", [])
	arr.append("pet_rockturtle")
	prog["pets"] = arr
	var flags: Variant = prog.get("flags")
	if not (flags is Dictionary):
		flags = {}
		prog["flags"] = flags
	(flags as Dictionary)["act1_rockturtle_claimed"] = true
	if persist and not save_game():
		prog = before
		return {"ok": false, "reason": "save_failed"}
	return {"ok": true, "pet": "pet_rockturtle", "name": "岩龟"}


## P07-D：完成港务交账后在兽栏领首枚蛋，旧 s16 存档同样可领。
func port_egg_claim(persist := true) -> Dictionary:
	if save_locked or not story_step_done("s16"):
		return {"ok": false, "reason": "locked"}
	var flags: Dictionary = prog.get("flags", {})
	if bool(flags.get("act2_port_egg_claimed", false)):
		return {"ok": false, "reason": "claimed"}
	var before_prog := prog.duplicate(true)
	var before_items := items.duplicate(true)
	flags["act2_port_egg_claimed"] = true
	prog["flags"] = flags
	items["tide_egg"] = item_count("tide_egg") + 1
	if persist and not save_game():
		prog = before_prog
		items = before_items
		return {"ok": false, "reason": "save_failed"}
	return {"ok": true}


## 追加购买按一次写盘处理，失败时金币与蛋一起回滚。
func port_egg_buy(persist := true) -> Dictionary:
	if save_locked or not story_step_done("s16"):
		return {"ok": false, "reason": "locked"}
	const PRICE := 500
	if int(wallet.get("gold", 0)) < PRICE:
		return {"ok": false, "reason": "gold"}
	var before_wallet := wallet.duplicate(true)
	var before_items := items.duplicate(true)
	wallet["gold"] = int(wallet.get("gold", 0)) - PRICE
	items["tide_egg"] = item_count("tide_egg") + 1
	if persist and not save_game():
		wallet = before_wallet
		items = before_items
		return {"ok": false, "reason": "save_failed"}
	return {"ok": true, "price": PRICE}


## 孵化消耗一个蛋。已拥有潮羽雏鸥时改为两份宠物粮，重复操作永不复制伙伴。
func port_egg_hatch(persist := true) -> Dictionary:
	if save_locked or not story_step_done("s16") or item_count("tide_egg") <= 0:
		return {"ok": false, "reason": "egg"}
	var before_prog := prog.duplicate(true)
	var before_items := items.duplicate(true)
	items["tide_egg"] = item_count("tide_egg") - 1
	var duplicate_pet := owns_pet("pet_tide_gull")
	if duplicate_pet:
		items["pet_food"] = item_count("pet_food") + 2
	else:
		var pets_owned: Array = prog.get("pets", [])
		pets_owned.append("pet_tide_gull")
		prog["pets"] = pets_owned
	if persist and not save_game():
		prog = before_prog
		items = before_items
		return {"ok": false, "reason": "save_failed"}
	return {"ok": true, "pet": "pet_tide_gull", "duplicate": duplicate_pet,
		"food": 2 if duplicate_pet else 0}


# ---------- P07-D 普通钓鱼 ----------
func fishing_spot(id: String) -> Dictionary:
	for row in (TableCache.fishing_config().get("spots", []) as Array):
		if String((row as Dictionary).get("id", "")) == id:
			return row as Dictionary
	return {}


func fishing_state() -> Dictionary:
	if not (prog.get("fishing") is Dictionary):
		prog["fishing"] = {"day": 0, "counts": {}, "discoveries": [], "pending": {}}
	var state: Dictionary = prog["fishing"]
	var day := int(economy_state().get("day", 1))
	if int(state.get("day", 0)) != day:
		state["day"] = day
		state["counts"] = {}
		state["pending"] = {}
	if not (state.get("discoveries") is Array):
		state["discoveries"] = []
	if not (state.get("counts") is Dictionary):
		state["counts"] = {}
	if not (state.get("pending") is Dictionary):
		state["pending"] = {}
	return state


func fishing_remaining(spot_id: String) -> int:
	if fishing_spot(spot_id).is_empty():
		return 0
	var state := fishing_state()
	return maxi(0, int(TableCache.fishing_config().get("daily_limit", 3))
		- int((state.get("counts", {}) as Dictionary).get(spot_id, 0)))


## 抛竿时先保存次数和具名凭据；中途重启可在同一钓点接回这一竿。
func fishing_begin(spot_id: String, persist := true) -> Dictionary:
	if save_locked or fishing_spot(spot_id).is_empty():
		return {"ok": false, "reason": "locked"}
	var state := fishing_state()
	var pending: Dictionary = state.get("pending", {})
	if String(pending.get("spot", "")) == spot_id:
		return {"ok": true, "cast": pending.duplicate(true), "resumed": true}
	if fishing_remaining(spot_id) <= 0:
		return {"ok": false, "reason": "limit"}
	var before_prog := prog.duplicate(true)
	var counts: Dictionary = state.get("counts", {})
	var attempt := int(counts.get(spot_id, 0)) + 1
	counts[spot_id] = attempt
	state["counts"] = counts
	var token := "fish|%d|%s|%d" % [int(state["day"]), spot_id, attempt]
	var cast := {"spot": spot_id, "token": token,
		"center": 0.35 + float(absi(token.hash()) % 31) / 100.0}
	state["pending"] = cast
	if persist and not save_game():
		prog = before_prog
		return {"ok": false, "reason": "save_failed"}
	return {"ok": true, "cast": cast.duplicate(true), "resumed": false}


## 凭据仅结算一次。成功给普通鱼和图鉴，失败只消耗已预留的次数。
func fishing_finish(token: String, hit: bool, persist := true) -> Dictionary:
	if save_locked:
		return {"ok": false, "reason": "locked"}
	var state := fishing_state()
	var pending: Dictionary = state.get("pending", {})
	if token.is_empty() or String(pending.get("token", "")) != token:
		return {"ok": false, "reason": "stale"}
	var spot := fishing_spot(String(pending.get("spot", "")))
	if spot.is_empty():
		return {"ok": false, "reason": "stale"}
	var before_prog := prog.duplicate(true)
	var before_items := items.duplicate(true)
	var iid := String(spot.get("item", ""))
	var grants := {"item:%s" % iid: 1} if hit and not iid.is_empty() else {}
	var res := RewardLedger.apply(RewardLedger.make(token, {}, grants, {}), ledger(), self)
	if not bool(res.get("ok", false)):
		prog = before_prog
		items = before_items
		return {"ok": false, "reason": "transaction"}
	state["pending"] = {}
	if hit and not (state["discoveries"] as Array).has(iid):
		(state["discoveries"] as Array).append(iid)
	if persist and not save_game():
		prog = before_prog
		items = before_items
		return {"ok": false, "reason": "save_failed"}
	return {"ok": true, "hit": hit, "item": iid if hit else ""}


func fishing_cook(iid: String, persist := true) -> Dictionary:
	if save_locked or not ["fish_salt", "fish_port", "fish_tide"].has(iid) or item_count(iid) < 1:
		return {"ok": false, "reason": "fish"}
	var before_items := items.duplicate(true)
	items[iid] = item_count(iid) - 1
	items["pet_food"] = item_count("pet_food") + 1
	if persist and not save_game():
		items = before_items
		return {"ok": false, "reason": "save_failed"}
	return {"ok": true}


# ---------- P05-D：古道固定奇遇 ----------

const WAYSTONE_CACHE_ID := "act1_waystone_cache"


func waystone_cache_available() -> bool:
	var world_v: Variant = prog.get("main_world", {})
	var world: Dictionary = world_v if world_v is Dictionary else {}
	return not WorldSession.entity_taken(world, WAYSTONE_CACHE_ID) \
		and not RewardLedger.applied(ledger(), RewardLedger.tx_id("act1", "waystone_cache", "first"))


## 旧路石匣只有一份：材料、金币、世界旗、图鉴线索和实体消失一起写盘。
func claim_waystone_cache(persist := true) -> Dictionary:
	if save_locked or not waystone_cache_available():
		return {"ok": false, "reason": "locked" if save_locked else "already_taken", "toasts": []}
	var before_prog := prog.duplicate(true)
	var before_wallet := wallet.duplicate(true)
	var before_items := items.duplicate(true)
	var tx := RewardLedger.make(RewardLedger.tx_id("act1", "waystone_cache", "first"), {},
		{"gold": 30, "item:refine_stone": 1}, {"act1_waystone_cache_found": true})
	var applied := RewardLedger.apply(tx, ledger(), self)
	if not bool(applied.get("ok", false)) or not bool(applied.get("applied", false)):
		prog = before_prog
		wallet = before_wallet
		items = before_items
		return {"ok": false, "reason": String(applied.get("err", "ledger")), "toasts": []}
	var world_v: Variant = prog.get("main_world", {})
	var world := WorldSession.normalize_state(world_v if world_v is Dictionary else {})
	WorldSession.mark_entity_taken(world, WAYSTONE_CACHE_ID, true)
	prog["main_world"] = world
	var discoveries := act1_state()["discoveries"] as Array
	if not discoveries.has(WAYSTONE_CACHE_ID):
		discoveries.append(WAYSTONE_CACHE_ID)
	if persist and not save_game():
		prog = before_prog
		wallet = before_wallet
		items = before_items
		return {"ok": false, "reason": "save_failed", "toasts": []}
	return {"ok": true, "reason": "", "toasts": [
		"旧路石匣：箱盖内刻着断碑坡方位",
		"获得 精炼石 ×1 · 金币 +30",
	]}


# ---------- 主城物资铺（锻造铺；P1-2：金币换养成材料的稳定出口） ----------

## 货架表路径。用 var 而非 const：自动化测试把它指向临时表，才能验证"非法商品被下架"
## 这条路径（生产代码不允许改这个值）。
var SHOP_PATH := "res://data/shop.json"

## 物资铺货架（data/shop.json；读盘失败返回空数组，面板照常可开）
##
## 只返回**合法**货品：id 非空且已登记、价格为正整数、同 id 不重复。
## 旧实现把所有异常价格兜底成 1——表里写成 0/负数/字符串/缺字段，货架照卖 1 金币，
## UI 拦不住的同时购买接口也拦不住（问题 #20）。兜底不是修复，是把配置错误变成白送。
var _shop_shelf: Array = []
var _shop_shelf_built := false
func shop_items() -> Array:
	if _shop_shelf_built:
		return _shop_shelf
	_shop_shelf_built = true
	_shop_shelf = []
	var f := FileAccess.open(SHOP_PATH, FileAccess.READ)
	if f == null:
		push_error("%s 缺失" % SHOP_PATH)
		return _shop_shelf
	var parsed: Variant = json_parse_silent(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		push_error("%s 解析失败或不是对象" % SHOP_PATH)
		return _shop_shelf
	var arr: Variant = (parsed as Dictionary).get("items", [])
	if not (arr is Array):
		push_error("%s items 应为数组" % SHOP_PATH)
		return _shop_shelf
	var seen := {}
	for r in arr:
		if not (r is Dictionary):
			push_warning("shop.json 条目不是对象，已下架")
			continue
		var d := r as Dictionary
		var iid := String(d.get("item", ""))
		if iid.is_empty():
			push_warning("shop.json 条目缺 item 字段，已下架")
			continue
		if seen.has(iid):
			push_warning("shop.json 商品 id 重复：%s，只保留第一条" % iid)
			continue
		if item_name(iid) == iid:
			push_warning("shop.json 商品未登记：%s，已下架" % iid)
			continue
		var price := _shop_valid_price(d.get("price"))
		if price <= 0:
			push_warning("shop.json 商品价格非法（须正整数）：%s，已下架" % iid)
			continue
		var sell_price := _shop_valid_price(d.get("sell_price"))
		if sell_price <= 0 or sell_price >= price:
			# 旧版表没有回收价，按购价四成计；显式错误价格拒绝回收套利。
			sell_price = maxi(1, price * 2 / 5) if not d.has("sell_price") and price > 1 else 0
		seen[iid] = true
		_shop_shelf.append({"item": iid, "price": price, "sell_price": sell_price})
	return _shop_shelf


## 价格字段校验：只接受正整数值（JSON 整数，或数值上等于整数的浮点）。
## 字符串/布尔/缺字段/null/0/负数一律判非法——不做任何"兜底成 1"。
func _shop_valid_price(raw: Variant) -> int:
	if raw is int:
		return int(raw) if int(raw) > 0 else 0
	if raw is float:
		var v := float(raw)
		if v > 0.0 and is_equal_approx(v, roundf(v)):
			return int(v)
	return 0


## 货架缓存失效（改表 / 测试注入非法商品时使用）
func shop_reload() -> void:
	_shop_shelf_built = false
	_shop_shelf = []


## 某货品单价（未登记 / 已下架返回 0，与货架同源）
func shop_price(item_id: String) -> int:
	for r in shop_items():
		var d := r as Dictionary
		if String(d.get("item", "")) == item_id:
			return int(d.get("price", 0))
	return 0


func shop_sell_price(item_id: String) -> int:
	for r in shop_items():
		var d := r as Dictionary
		if String(d.get("item", "")) == item_id:
			return int(d.get("sell_price", 0))
	return 0


## 购买一件：id 非法 / 金币不足一律拒绝；成功扣款并发放（单件购买，防一次买爆经济）。
## 这里必须**独立**再校验一次：面板可以改，购买接口是唯一入口，不能只靠 UI 拦。
func shop_buy(item_id: String) -> Dictionary:
	if item_id.is_empty():
		return {"ok": false, "err": "本店没有这件货"}
	var price := shop_price(item_id)
	if price <= 0:
		return {"ok": false, "err": "本店没有这件货"}
	if int(wallet.get("gold", 0)) < price:
		return {"ok": false, "err": "金币不足（需 %d）" % price}
	wallet["gold"] = int(wallet.get("gold", 0)) - price
	grant_item(item_id, 1, false)
	save_game()
	_sfx("coin", 0.0)
	return {"ok": true, "err": ""}


## 回收只接受本店白名单材料，回收价严格低于买价；扣物与入金同次写档。
func shop_sell(item_id: String) -> Dictionary:
	var price := shop_sell_price(item_id)
	if price <= 0:
		return {"ok": false, "err": "本店不回收这件货"}
	if item_count(item_id) <= 0:
		return {"ok": false, "err": "背包里没有这件货"}
	items[item_id] = item_count(item_id) - 1
	wallet["gold"] = int(wallet.get("gold", 0)) + price
	save_game()
	_sfx("coin", 0.0)
	return {"ok": true, "err": "", "gold": price}


# ================= 主城（据点） =================
# 数据源 data/city.json：建筑（程序绘制，按 style 分支）、NPC（对话池）、活动（冷却产出）。

const REWARD_KEYS := ["gold", "expedition", "soul", "honor", "exp"]
const REWARD_NAMES := {
	"gold": "金币", "expedition": "远征币", "soul": "魂晶", "honor": "荣誉", "exp": "经验",
}


func wallet_info_lines() -> Array:
	var lines: Array = []
	var rows: Variant = TableCache.currencies_config().get("currencies", [])
	if not (rows is Array):
		return lines
	for row_v in rows:
		if not (row_v is Dictionary):
			continue
		var row := row_v as Dictionary
		var id := String(row.get("id", ""))
		if not wallet.has(id):
			continue
		lines.append("%s ×%d · %s" % [String(row.get("name", id)),
			int(wallet[id]), String(row.get("scope", ""))])
		lines.append("获得：%s；用途：%s" % [String(row.get("source", "")),
			String(row.get("use", ""))])
	return lines


func city_config() -> Dictionary:
	return TableCache.city_config()


func city_name() -> String:
	return String(city_config().get("name", "远征主城"))


## 当前时间（unix 秒；**单调**：系统时钟被回拨时取存档水位，日常进度不重放，P1-13）。
## 前跳不设防（离线单机可接受）；水位随存档落盘。
func now_ts() -> int:
	var t := int(Time.get_unix_time_from_system())
	var last := int(prog.get("last_ts", 0))
	if t < last:
		return last
	if t != last:
		prog["last_ts"] = t
	return t


## 当日键（YYYY-MM-DD）。签到翻篇、今日来客都按它算。
func today_key() -> String:
	return Time.get_date_string_from_unix_time(now_ts())


# ---------- 抽奖状态（保底 / 每日免费；P1-1、P2-5） ----------

## 抽奖状态（prog.gacha）：保底计数与每日免费信息。
## 旧档曾把保底寄居在道具背包（items.gacha_pity），_load_save 会自动迁移。
func gacha_state() -> Dictionary:
	if not (prog.get("gacha") is Dictionary):
		prog["gacha"] = {"pity": 0, "free_day": "", "free_streak": 0, "free_last": ""}
	return prog["gacha"]


## 今日免费召唤是否可用（每日 1 次，零点刷新）
func gacha_free_available() -> bool:
	return String(gacha_state().get("free_day", "")) != today_key()


## 记一次免费召唤：连续天数 +1（昨天抽过才算连），满 7 天送灵魂石 ×50 并重新计数。
## 返回本次连抽奖励（0 或 50），UI 据此飘字。
func gacha_mark_free() -> int:
	var gs := gacha_state()
	if String(gs.get("free_last", "")) == _day_key(now_ts() - 86400):
		gs["free_streak"] = int(gs.get("free_streak", 0)) + 1
	else:
		gs["free_streak"] = 1
	gs["free_last"] = today_key()
	gs["free_day"] = today_key()
	var bonus := 0
	if int(gs.get("free_streak", 0)) >= 7:
		gs["free_streak"] = 0   # 满 7 天发一次奖、重新计数
		bonus = 50
		wallet["soul"] = int(wallet.get("soul", 0)) + bonus
		_sfx("level_up", 0.0)
	save_game()
	return bonus


## unix 秒 → 日期键（YYYY-MM-DD）
func _day_key(ts: int) -> String:
	return Time.get_date_string_from_unix_time(ts)


## 局结算上报：连败计数与保底礼包（P1-5）。胜局清零；三连败发魂石 30 + 宠物粮 5，
## 返回礼包文案（无则空串）供结算页展示——世界逐个解锁卡关时的唯一减压阀。
func report_run_result(win: bool) -> String:
	if win:
		prog["lose_streak"] = 0
		save_game()
		return ""
	prog["lose_streak"] = int(prog.get("lose_streak", 0)) + 1
	var gift := ""
	if int(prog["lose_streak"]) >= 3:
		prog["lose_streak"] = 0
		wallet["soul"] = int(wallet.get("soul", 0)) + 30
		grant_item("pet_food", 5)   # 内部落盘
		gift = "连败慰礼 · 灵魂石 +30 · 宠物粮 ×5"
	save_game()
	return gift


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
	for map_id in (TableCache.main_world_config().get("maps", {}) as Dictionary):
		for n in TableCache.city_config_for(map_id).get("npcs", []):
			if String((n as Dictionary).get("id", "")) == id:
				return n
	return {}


## 取一句对话：按「当天 + NPC + 已聊次数」推进，避免每次都是同一句
func npc_line(id: String, turn: int) -> String:
	var npc := city_npc(id)
	var lines: Array = npc.get("lines", [])
	var choice := String((prog.get("flags", {}) as Dictionary).get("act3_supply_choice", ""))
	var responses: Dictionary = npc.get("choice_lines", {})
	if responses.has(choice):
		lines = responses[choice]
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
	var reward_item := String(reward.get("item", ""))
	if not reward_item.is_empty():
		out.append("%s ×%d" % [item_name(reward_item), maxi(1, int(reward.get("count", 1)))])
	var floor_reward: Dictionary = reward.get("campaign_gear", {})
	if not floor_reward.is_empty():
		var tpl := equip_tpl(String(floor_reward.get("tpl", "")))
		out.append("主线保底：%s（Lv%d）" % [String(tpl.get("name", "装备")), int(tpl.get("requires_level", 1))])
		for id in floor_reward.get("materials", {}):
			out.append("保底材料：%s ×%d" % [item_name(String(id)), int(floor_reward.materials[id])])
		out.append("只发一次；随机战利另算，满包进入待领取。")
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
	if item_id in ["fish_salt", "fish_port", "fish_tide"]:
		return "itm_fish_common"
	if item_id.begins_with("gem_"):
		return item_id
	if item_id.begins_with("trade_"):
		var good := EconomyService.good(TableCache.economy_config(), item_id)
		if not good.is_empty():
			return String(good.get("icon", "itm_" + item_id))
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


func equip_templates() -> Array:
	return equip_cfg().get("templates", [])


## 模板 id → 模板字典（找不到返回 {}）
func equip_tpl(tpl_id: String) -> Dictionary:
	for t in equip_templates():
		var td := t as Dictionary
		if String(td.get("id", "")) == tpl_id:
			return td
	return {}


## 槽位的基础模板（tpl_<slot>_basic）：base 与 slots[<slot>].base 逐字段相等，
## 这是「旧档等值迁移」的支点（见 SaveData._ensure_v5）。
func equip_basic_tpl(slot_id: String) -> Dictionary:
	return equip_tpl("tpl_%s_basic" % slot_id)


func equip_rarity_cfg(rarity_id: int) -> Dictionary:
	return Inventory.rarity_row(equip_cfg(), rarity_id)


## 稀有度展示色（缺省回落普通灰，避免空串造出黑框）
func equip_rarity_color(rarity_id: int) -> Color:
	var hex := String(equip_rarity_cfg(rarity_id).get("color", ""))
	return Color(hex) if not hex.is_empty() else Color("b8b8b8")


func equip_rarity_name(rarity_id: int) -> String:
	return String(equip_rarity_cfg(rarity_id).get("name", "普通"))


## 当前角色对应的武器槽（剑→破军/枪→穿杨/杖→霜语/锤→晨星）
func equip_weapon_slot(role_id := "") -> String:
	var rid := role_id if not role_id.is_empty() else selected_role
	for s in equip_cfg().get("slots", []):
		var sd := s as Dictionary
		if String(sd.get("kind", "")) == "weapon" and String(sd.get("role", "")) == rid:
			return String(sd.get("id", ""))
	return ""


# 容器口径（P04）：instances[] 是**拥有池** —— 背包里的与正穿在身上的实例都在里面，
# 穿在身上的由 prog.equip[slot] = uid 指向；背包已用格 = 未被指向的条数（装备不占格）。

## 装备实例拥有池（prog.inventory）。SaveData 的 v5 迁移已保证存在，这里再兜一层。
func _inventory() -> Dictionary:
	var invv: Variant = prog.get("inventory")
	if not (invv is Dictionary):
		invv = {"instances": [], "pending": [], "next_uid": 1}
		prog["inventory"] = invv
	return Inventory.ensure(invv as Dictionary)


func inv_instances() -> Array:
	return _inventory()["instances"] as Array


func inv_pending() -> Array:
	return _inventory()["pending"] as Array


## 槽 → uid 映射（活对象，就地改写会落进 prog）
func _equip_map() -> Dictionary:
	var em: Variant = prog.get("equip")
	if not (em is Dictionary):
		em = {}
		prog["equip"] = em
	return em as Dictionary


## 背包已用格（装备不占格）
func inv_count() -> int:
	return Inventory.count(_inventory(), _equip_map())


## 正穿在身上的实例 uid 集合（背包列表据此排除在身装备）
func inv_worn_uids() -> Dictionary:
	return Inventory.worn_uids(_equip_map())


func inv_capacity() -> int:
	return Inventory.capacity(equip_cfg())


## 按 uid 找实例（找到返回活对象，找不到返回 {}）
func inv_find(uid: int) -> Dictionary:
	return Inventory.find_by_uid(inv_instances(), uid)


## 槽位**在身实例**（未装备返回 {}）。返回的是 instances 里的活对象，
## 调用方就地改写（+lv / 加宝石 / 洗词条）后只需 save_game()。
func equip_state(slot_id: String) -> Dictionary:
	var uid := int(_equip_map().get(slot_id, 0))
	if uid <= 0:
		return {}
	return Inventory.find_by_uid(inv_instances(), uid)


## 取在身实例；create=true 且该槽为空时用基础模板现场补一件（老档缺槽兜底）。
func _equip_worn(slot_id: String, create := false) -> Dictionary:
	var st := equip_state(slot_id)
	if not st.is_empty() or not create:
		return st
	var tpl := equip_basic_tpl(slot_id)
	if tpl.is_empty():
		return {}
	var inv := _inventory()
	var inst := Inventory.new_instance(inv, tpl, int(tpl.get("rarity", 1)))
	(inv["instances"] as Array).append(inst)
	_equip_map()[slot_id] = int(inst["uid"])
	return inst


## 新档/空档保底：6 个槽各发一件基础装备并全部穿上，保证开局战力与 P03 完全一致。
## force=true（仅供测试重置）先清空实例与背包再重建，得到确定性初始态。
func ensure_starter_equip(force := false) -> void:
	var inv := _inventory()
	var em := _equip_map()
	var any_uid := false
	for s in equip_cfg().get("slots", []):
		if int(em.get(String((s as Dictionary).get("id", "")), 0)) > 0:
			any_uid = true
			break
	if force:
		for k in em.keys():
			em.erase(k)
		inv["instances"] = []
		inv["pending"] = []
	elif any_uid or not (inv["instances"] as Array).is_empty() \
			or not (inv["pending"] as Array).is_empty():
		return   # 已有装备或已有实例：是玩家自己的状态，不擅自补发
	for s2 in equip_cfg().get("slots", []):
		var sid := String((s2 as Dictionary).get("id", ""))
		if int(em.get(sid, 0)) > 0:
			continue
		var tpl := equip_basic_tpl(sid)
		if tpl.is_empty():
			continue
		var inst := Inventory.new_instance(inv, tpl, int(tpl.get("rarity", 1)))
		(inv["instances"] as Array).append(inst)
		em[sid] = int(inst["uid"])


# ---------- 背包 / 待领取箱 / 换装 / 卖出 / 宝石合成（P04 薄封装，逻辑都在 Inventory） ----------

## 发一件装备（掉落/奖励）。spec = {"tpl": <模板id>, "rarity": <稀有度>, "n": <数量>}。
## 满包 → 进待领取箱，绝不丢物。
func inv_grant_equip(spec: Dictionary, persist := true) -> Dictionary:
	if save_locked: return {"ok": false, "err": "存档暂不可写"}
	var tpl_id := String(spec.get("tpl", ""))
	var tpl := equip_tpl(tpl_id)
	if tpl.is_empty():
		return {"ok": false, "err": "未知装备模板：%s" % tpl_id}
	var rarity := int(spec.get("rarity", tpl.get("rarity", 1)))
	var n := maxi(1, int(spec.get("n", 1)))
	var before := prog.duplicate(true)
	var inv := _inventory()
	var cfg := equip_cfg()
	var em := _equip_map()
	var to_pending := false
	for i in n:
		var inst := Inventory.new_instance(inv, tpl, rarity)
		if not String(spec.get("source_id", "")).is_empty(): inst["source_id"] = String(spec.source_id)
		var r := Inventory.add(inv, cfg, em, inst)
		if bool(r.get("to_pending", false)):
			to_pending = true
	if persist:
		if not save_game():
			prog = before
			return {"ok": false, "err": "装备发放未保存，已回滚"}
	return {"ok": true, "to_pending": to_pending, "n": n}


## 待领取箱 → 背包（背包满则拒绝并保留）
##
## R-04：写盘失败时不得让界面显示"已领取" —— 把刚领取的实例回滚回待领取箱，
## 并返回 ok=false，调用方据此提示失败（内存与盘上状态一致：装备仍在待领取箱）。
func inv_claim(uid: int) -> Dictionary:
	var inv := _inventory()
	var em := _equip_map()
	var r := Inventory.claim(inv, equip_cfg(), em, uid)
	if not bool(r.get("ok", false)):
		return r
	if not save_game():
		Inventory.return_to_pending(inv, uid)
		return {"ok": false, "err": "存档写入失败，领取未生效（装备仍在待领取箱）"}
	return r


## 穿上 uid 指向的实例（同槽旧装备自动回背包，永不因满包失败）
func inv_equip(uid: int) -> Dictionary:
	if save_locked: return {"ok": false, "err": "存档暂不可写"}
	var inst := inv_find(uid)
	var need := int(equip_tpl(String(inst.get("tpl", ""))).get("requires_level", 1))
	if int(prog.get("level", 1)) < need: return {"ok": false, "err": "需 Lv%d 才能装备" % need}
	var before := prog.duplicate(true)
	var r := Inventory.equip(_inventory(), _equip_map(), uid)
	if bool(r.get("ok", false)) and not save_game():
		prog = before
		return {"ok": false, "err": "换装未保存，已回滚"}
	return r


func inv_unequip(slot_id: String) -> Dictionary:
	if save_locked: return {"ok": false, "err": "存档暂不可写"}
	var before := prog.duplicate(true)
	var r := Inventory.unequip(_inventory(), equip_cfg(), _equip_map(), slot_id)
	if bool(r.get("ok", false)) and not save_game():
		prog = before
		return {"ok": false, "err": "卸装未保存，已回滚"}
	return r


func inv_set_locked(uid: int, on: bool) -> Dictionary:
	var r := Inventory.set_locked(_inventory(), uid, on)
	if bool(r.get("ok", false)):
		save_game()
	return r


## 实例回收价（找不到返回 0）
func inv_sell_price(uid: int) -> int:
	var inst := Inventory.find_by_uid(inv_instances(), uid)
	if inst.is_empty():
		return 0
	return Inventory.sell_price(equip_cfg(), equip_tpl(String(inst.get("tpl", ""))), inst)


## 卖出（在身/锁定拒绝；强化过或稀有需 confirm=true）。所得金币进钱包。
func inv_sell(uid: int, confirm := false) -> Dictionary:
	var r := Inventory.sell(_inventory(), equip_cfg(), _equip_map(),
		Callable(self, "equip_tpl"), uid, confirm)
	if bool(r.get("ok", false)):
		wallet["gold"] = int(wallet.get("gold", 0)) + int(r.get("gold", 0))
		save_game()
	return r


## 拆下一颗宝石（免金币），归还到 items
func inv_gem_pop(uid: int, idx: int) -> Dictionary:
	if save_locked:
		return {"ok": false, "err": "存档暂不可写"}
	var inst := Inventory.find_by_uid(inv_instances(), uid)
	if inst.is_empty():
		return {"ok": false, "err": "找不到这件装备"}
	var before_prog := prog.duplicate(true)
	var before_items := items.duplicate(true)
	var r := Inventory.gem_pop(inst, idx)
	if bool(r.get("ok", false)):
		var gem := String(r.get("gem", ""))
		items[gem] = item_count(gem) + 1
		if not save_game():
			prog = before_prog
			items = before_items
			return {"ok": false, "err": "拆卸未保存，已回滚"}
	return r


## 宝石 3 合 1（同级同色 → 高一级），扣金币费
func inv_gem_merge(gem_id: String) -> Dictionary:
	if save_locked:
		return {"ok": false, "err": "存档暂不可写"}
	var before_items := items.duplicate(true)
	var before_wallet := wallet.duplicate(true)
	var r := Inventory.gem_merge(items, wallet, equip_cfg(), gem_id)
	if bool(r.get("ok", false)) and not save_game():
		items = before_items
		wallet = before_wallet
		return {"ok": false, "err": "合成未保存，已回滚"}
	return r


## 地图外观钩子（P04 §6.4）：当前角色在身武器 → {weapon_tpl, weapon_icon, weapon_name, rarity, color}
func equip_appearance() -> Dictionary:
	var ws := equip_weapon_slot()
	if ws.is_empty():
		return {}
	return Inventory.appearance(Callable(self, "equip_tpl"), equip_cfg(), equip_state(ws))


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


## 低阶确定成功；高阶在原基础率上公开累加本实例的失败积累。
func equip_enhance_rate(slot_id: String) -> float:
	var ec: Dictionary = equip_cfg().get("enhance", {})
	var st := equip_state(slot_id)
	var target := int(st.get("lv", 0)) + 1
	if target <= int(ec.get("guaranteed_target", 3)): return 1.0
	return minf(1.0, pow(float(ec.get("success_base", 0.9)), float(target)) \
		+ int(st.get("enhance_failures", 0)) * float(ec.get("failure_rate_bonus", 0.15)))


func equip_enhance_failure_limit(slot_id: String) -> int:
	var ec: Dictionary = equip_cfg().get("enhance", {})
	var target := int(equip_state(slot_id).get("lv", 0)) + 1
	if target <= int(ec.get("guaranteed_target", 3)): return 0
	var base := pow(float(ec.get("success_base", 0.9)), float(target))
	return ceili((1.0 - base) / maxf(0.001, float(ec.get("failure_rate_bonus", 0.15))))


## 强化：校验 → 扣费 → 掷点（失败不掉级）；返回 {ok, success, err}
func equip_enhance(slot_id: String, rng: RandomNumberGenerator = null) -> Dictionary:
	if save_locked: return {"ok": false, "err": "存档暂不可写"}
	var cfg := equip_slot_cfg(slot_id)
	if cfg.is_empty():
		return {"ok": false, "err": "没有这个装备槽"}
	var st := equip_state(slot_id)
	if st.is_empty():
		return {"ok": false, "err": "请先装备一件物品"}
	var lv := int(st.get("lv", 0))
	if lv >= equip_enhance_max():
		return {"ok": false, "err": "已强化至上限"}
	var cost := equip_enhance_cost(slot_id)
	if int(wallet.get("gold", 0)) < int(cost["gold"]):
		return {"ok": false, "err": "金币不足"}
	if item_count(String(cost["item"])) < int(cost["item_n"]):
		return {"ok": false, "err": "强化石不足"}
	var before_prog := prog.duplicate(true)
	var before_wallet := wallet.duplicate(true)
	var before_items := items.duplicate(true)
	var rate := equip_enhance_rate(slot_id)
	wallet["gold"] = int(wallet.get("gold", 0)) - int(cost["gold"])
	items[String(cost["item"])] = item_count(String(cost["item"])) - int(cost["item_n"])
	var r := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var rng_state := r.state
	var ok := rate >= 1.0 or r.randf() < rate
	if ok:
		st["lv"] = lv + 1   # 实例是活对象，就地改写即落进 prog.inventory
		st["enhance_failures"] = 0
	else:
		st["enhance_failures"] = int(st.get("enhance_failures", 0)) + 1
	if not save_game():
		prog = before_prog
		wallet = before_wallet
		items = before_items
		r.state = rng_state
		return {"ok": false, "err": "强化未保存，已回滚"}
	return {"ok": true, "success": ok, "lv": int(st.get("lv", 0)),
		"failures": int(st.get("enhance_failures", 0)), "next_rate": equip_enhance_rate(slot_id)}


## 槽位强化后基础属性 = 模板 base × (1 + 0.1×lv)。
## 在身实例取其实例模板的 base；空槽回落到槽配置 base（老行为，保证聚合值不变）。
func equip_base_stat(slot_id: String) -> Dictionary:
	var st := equip_state(slot_id)
	var base: Dictionary = {}
	if st.is_empty():
		base = equip_slot_cfg(slot_id).get("base", {})
	else:
		base = equip_tpl(String(st.get("tpl", ""))).get("base", {})
	var lv := int(st.get("lv", 0))
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


## 宝石显示名（如「攻击宝石 · 3 级」）。tooltip 不该裸露内部 id（问题 #14）。
## 未登记/缺等级的 id 原样返回，避免把内部串彻底藏掉、排查时无从下手。
func gem_label(gem_id: String) -> String:
	if gem_id.is_empty():
		return ""
	for c in equip_gem_colors():
		var cd := c as Dictionary
		var prefix := String(cd.get("id", ""))
		if gem_id.begins_with("gem_%s_" % prefix):
			var lv := int(gem_id.get_slice("_", 2))
			return "%s · %d 级" % [String(cd.get("name", prefix)), lv]
	return gem_id


## 镶嵌：消耗 1 颗宝石 + 开孔费；孔满返回 false
func equip_socket_gem(slot_id: String, gem_id: String) -> Dictionary:
	if save_locked:
		return {"ok": false, "err": "存档暂不可写"}
	var before_prog := prog.duplicate(true)
	var before_items := items.duplicate(true)
	var before_wallet := wallet.duplicate(true)
	var st := _equip_worn(slot_id, true)
	if st.is_empty():
		return {"ok": false, "err": "没有这个装备槽"}
	var gems: Array = st.get("gems", [])
	if gems.size() >= int(st.get("sockets", equip_gem_sockets())):
		return {"ok": false, "err": "孔位已满"}
	if equip_gem_value(gem_id) <= 0:
		return {"ok": false, "err": "无效宝石"}
	if item_count(gem_id) < 1:
		return {"ok": false, "err": "没有这颗宝石"}
	var cost := equip_socket_cost()
	if int(wallet.get("gold", 0)) < cost:
		return {"ok": false, "err": "金币不足"}
	wallet["gold"] = int(wallet.get("gold", 0)) - cost
	items[gem_id] = item_count(gem_id) - 1
	gems.append(gem_id)
	st["gems"] = gems
	if not save_game():
		prog = before_prog
		items = before_items
		wallet = before_wallet
		return {"ok": false, "err": "镶嵌未保存，已回滚"}
	return {"ok": true}


## 精炼：重洗未锁定词条（满 4 条）；每条锁定额外耗 1 锁符
func equip_refine(slot_id: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var rc: Dictionary = equip_cfg().get("refine", {})
	var st := _equip_worn(slot_id, true)
	if st.is_empty():
		return {"ok": false, "err": "没有这个装备槽"}
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
	save_game()
	return {"ok": true, "affixes": affixes}


## 切换词条锁定状态（免费，只是标记）
func equip_toggle_lock(slot_id: String, idx: int) -> void:
	var st := _equip_worn(slot_id, true)
	if st.is_empty():
		return
	var affixes: Array = st.get("affixes", [])
	if idx >= 0 and idx < affixes.size():
		var a := affixes[idx] as Dictionary
		a["locked"] = not bool(a.get("locked", false))
		save_game()


## 任意实例的加成（强化基础 + 宝石 + 精炼词条）。
## 与 equip_slot_bonus 同一套算法，背包比较区据此算"换上会多几点"。
func equip_instance_bonus(inst: Dictionary) -> Dictionary:
	var out := {"atk": 0, "def": 0, "hp": 0, "crit": 0.0,
		"atk_pct": 0.0, "def_pct": 0.0, "maxhp_pct": 0.0, "spd_pct": 0.0, "crit_add": 0.0}
	if inst.is_empty():
		return out
	var base: Dictionary = equip_tpl(String(inst.get("tpl", ""))).get("base", {})
	var mult := 1.0 + float(equip_cfg().get("enhance", {}).get("pct_per_level", 0.1)) * int(inst.get("lv", 0))
	for k in base.keys():
		if String(k) == "crit":
			out["crit"] = float(base[k])  # 暴击值不吃强化倍率
		else:
			out[k] = int(roundf(float(base[k]) * mult))
	for g in (inst.get("gems", []) as Array):
		var gid := String(g)
		var v := equip_gem_value(gid)
		if gid.begins_with("gem_atk_"):
			out["atk"] += v
		elif gid.begins_with("gem_def_"):
			out["def"] += v
		elif gid.begins_with("gem_hp_"):
			out["hp"] += v
	for a in (inst.get("affixes", []) as Array):
		var ad := a as Dictionary
		var stat := String(ad.get("stat", ""))
		if out.has(stat):
			out[stat] = float(out[stat]) + float(ad.get("v", 0.0))
	return out


## 槽位总加成（强化基础 + 宝石 + 精炼词条）。
## 空槽用基础模板（tpl_<slot>_basic）算，等价于老的"槽配置 base、0 级"口径。
func equip_slot_bonus(slot_id: String) -> Dictionary:
	var st := equip_state(slot_id)
	if st.is_empty():
		return equip_instance_bonus({"tpl": "tpl_%s_basic" % slot_id, "lv": 0})
	return equip_instance_bonus(st)


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


## 首骑是剧情奖励；已有付费马的旧档直接视为拥有，不重复赠送或覆盖选择。
func first_mount_cfg() -> Dictionary:
	var row: Variant = TableCache.act1_growth_config().get("first_mount", {})
	return row as Dictionary if row is Dictionary else {}


func first_mount_status() -> String:
	var cfg := first_mount_cfg()
	var mid := String(cfg.get("mount_id", "horse"))
	if mount_tier(mid) > 0:
		return "owned"
	if not story_step_done(String(cfg.get("unlock_after", "s06"))):
		return "locked"
	return "ready"


func claim_first_mount(persist := true) -> Dictionary:
	if save_locked or first_mount_status() != "ready":
		return {"ok": false, "reason": "locked" if save_locked else first_mount_status()}
	var before := prog.duplicate(true)
	var mid := String(first_mount_cfg().get("mount_id", "horse"))
	var mts: Dictionary = prog.get("mounts", {"owned": {}, "active": ""})
	var owned: Dictionary = mts.get("owned", {})
	owned[mid] = 1
	mts["owned"] = owned
	if String(mts.get("active", "")).is_empty():
		mts["active"] = mid
	mts["riding"] = false
	prog["mounts"] = mts
	var flags: Dictionary = prog.get("flags", {})
	flags["act1_first_mount_claimed"] = true
	prog["flags"] = flags
	if persist and not save_game():
		prog = before
		return {"ok": false, "reason": "save_failed"}
	return {"ok": true, "mount_id": mid,
		"name": String(mount_cfg(mid).get("name", mid))}


## 装备中的马与此刻上马分开；老档只有 active 时默认是步行。
## 首骑素材目前只覆盖 horse，其他六线坐骑仍按原局外属性结算。
func mount_riding() -> bool:
	return mount_active() == String(first_mount_cfg().get("mount_id", "horse")) \
		and mount_tier(mount_active()) > 0 \
		and bool((prog.get("mounts", {}) as Dictionary).get("riding", false))


func mount_set_riding(ride: bool, persist := true) -> bool:
	if save_locked or (ride and (mount_active() != String(first_mount_cfg().get("mount_id", "horse"))
			or mount_tier(mount_active()) <= 0)):
		return false
	var before := prog.duplicate(true)
	var mts: Dictionary = prog.get("mounts", {})
	mts["riding"] = ride
	prog["mounts"] = mts
	if persist and not save_game():
		prog = before
		return false
	return true


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
	mts["riding"] = false
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


## 宠物进化（P1-3）：每只一次，全属性 +25％（由 pet_stat_mult 承接）；耗进化晶石。
## 数值从 pets.json 的 evolve 段读；素材换用 <pid>_evo（图鉴卡自动切换）。
func pet_evolve(pid: String) -> Dictionary:
	if not owns_pet(pid):
		return {"ok": false, "err": "尚未结缘"}
	var st := pet_stat(pid)
	if bool(st.get("evolved", false)):
		return {"ok": false, "err": "已经进化过了"}
	var ev: Dictionary = TableCache.get_pet(pid).get("evolve", {})
	if ev.is_empty():
		return {"ok": false, "err": "该灵宠不可进化"}
	var cost := 3
	if ev.get("cost") is Dictionary:
		cost = maxi(1, int((ev["cost"] as Dictionary).get("evolve_crystal", 3)))
	if item_count("evolve_crystal") < cost:
		return {"ok": false, "err": "进化晶石不足（需 %d）" % cost}
	consume_item("evolve_crystal", cost)
	st["evolved"] = true
	var all: Dictionary = prog.get("pet_stat", {})
	all[pid] = st
	prog["pet_stat"] = all
	save_game()
	_sfx("level_up", 0.0)
	return {"ok": true, "err": ""}


## 宠物战斗属性倍率：突破 +8%/层；进化 ×(1 + hp_pct)（表值，默认 25％）；
## 资质影响每级成长（1星0.8 / 3星1.2 / 5星1.6）
func pet_stat_mult(pid: String) -> float:
	var st := pet_stat(pid)
	var m := 1.0 + 0.08 * float(st.get("brk", 0))
	if bool(st.get("evolved", false)):
		var ev: Dictionary = TableCache.get_pet(pid).get("evolve", {})
		m *= 1.0 + float(ev.get("hp_pct", 0.25))
	return m


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
			"growth_mult": pet_growth_mult(id), "companion_traits":CompanionService.snapshot(prog,id)}
	return out


func companion_active() -> String:
	var selected := String((prog.get("companions",{}) as Dictionary).get("active",""))
	if owns_pet(selected): return selected
	var pets := owned_pets()
	return String(pets[0]) if not pets.is_empty() else ""


func companion_select(pid: String) -> Dictionary:
	if save_locked or not owns_pet(pid) or not story_step_done(String(CompanionService.config().get("requires_story","s24"))) \
			or not bool(TableCache.main_world_map(String((prog.get("main_world",{}) as Dictionary).get("map_id",""))).get("city",false)):
		return {"ok":false,"err":"找回矿道记录后，在城镇选择已拥有伙伴"}
	var before := prog.duplicate(true)
	var root: Dictionary = prog.get("companions",{}).duplicate(true)
	root["active"] = pid
	prog["companions"] = root
	if not save_game():
		prog = before
		return {"ok":false,"err":"本次选择未能保存"}
	return {"ok":true}


func companion_train(pid: String, slot: int, tid: String) -> Dictionary:
	var cfg := CompanionService.config()
	var slots: Array = cfg.get("slots",[])
	if save_locked or not owns_pet(pid) or slot < 0 or slot >= slots.size() \
			or not (cfg.get("traits",{}) as Dictionary).has(tid) \
			or not story_step_done(String(cfg.get("requires_story","s24"))) \
			or String((prog.get("main_world",{}) as Dictionary).get("map_id","")) != String(cfg.get("training_site","frost_post")):
		return {"ok":false,"err":"找回矿道记录后，在霜关驿舍训练已拥有伙伴"}
	var state := CompanionService.state(prog,pid)
	var traits: Array = state.get("traits",[])
	if slot < traits.size() and traits[slot] == tid: return {"ok":true,"unchanged":true}
	if traits.has(tid): return {"ok":false,"err":"两项不能重复选择同一特性"}
	if int(state.get("wins",0)) < int(slots[slot].get("wins",0)):
		return {"ok":false,"err":"该伙伴胜利协战不足 %d 次" % int(slots[slot].wins)}
	var cost := int(slots[slot].get("pet_food",1))
	if item_count("pet_food") < cost: return {"ok":false,"err":"需要宠物粮 ×%d" % cost}
	var before := prog.duplicate(true)
	var before_items := items.duplicate(true)
	while traits.size() <= slot: traits.append("")
	traits[slot] = tid
	state["traits"] = traits
	var root: Dictionary = prog.get("companions",{}).duplicate(true)
	var pets: Dictionary = root.get("pets",{})
	pets[pid] = state
	root["pets"] = pets
	prog["companions"] = root
	items["pet_food"] = item_count("pet_food") - cost
	if not save_game():
		prog = before
		items = before_items
		return {"ok":false,"err":"本次训练未能保存，宠粮已保留"}
	return {"ok":true}


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
		var qd := q as Dictionary
		# 只上「当前打得动」的委托：带 theme 的（讨伐/击杀）必须该世界已解锁（P1-13）
		var th := String(qd.get("theme", ""))
		if th != "" and not is_world_unlocked(th):
			continue
		pool.append(String(qd.get("id", "")))
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
	# 完整口径（P0-4）：钱包/道具/养成/主城/委托/段位/账号资料全清；头像文件保留但不启用；
	# 补发初始伙伴与初始建筑后落盘
	_init_state_defaults()
	ensure_starter_pets()
	ensure_starter_buildings()
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
	# 小型任务图标采用代码原生矢量；保留 res_tex 的名称契约与纹理缓存。
	_res_index["itm_frost_letter.png"] = "res://image/third_act/itm_frost_letter.svg"
	_res_index["itm_mine_record.png"] = "res://image/third_act/itm_mine_record.svg"
	for id in ["gate_stamp", "frost_reply", "veil_seal", "frost_nameplate", "frost_parcel"]:
		_res_index["itm_%s.png" % id] = "res://image/third_act/itm_%s.svg" % id
	for id in ["mon_redsand_guard", "mon_snowveil_lord"]:
		_res_index[id + ".png"] = "res://image/third_act/%s.png" % id
	_res_index["mon_frost_eye.png"] = "res://image/third_act/mon_frost_eye.svg"
	var batches := ["generated_001_100", "generated_101_200", "generated_201_333",
		"generated_334_341", "generated_342_353", "generated_362_xajh"]
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

## 参考像素界面用硬边；保留工厂签名，不再铺大面积软投影。
func _apply_shadow(sb: StyleBoxFlat, _size: float, _off_y: float, _alpha: float) -> void:
	sb.shadow_color = Color.TRANSPARENT
	sb.shadow_size = 0
	sb.shadow_offset = Vector2.ZERO


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
	# 坑：父级还没进树时 parent.get_tree() 在 4.7 会直接刷
	#   ERROR: Parameter "data.tree" is null. at: get_tree (scene/main/node.h:559)
	# （TraitPicker.setup 在 add_child 之前就建浮层，headless 测试里每局刷 7 条）。
	# 必须先 is_inside_tree() 再问 get_tree()，拿不到就退回 480×800 基准。
	if not parent.is_inside_tree():
		return Vector2(480, 800)
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
	sb.set_corner_radius_all(0)
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
	sb.set_corner_radius_all(0)
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
	root.add_child(_ReferenceFrame.new())
	return root


## 羊皮纸面板（金边，内部留白）
func parchment_box(w := 400, h := 200, pad := 18.0) -> PanelContainer:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(w, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PARCHMENT
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(3)
	sb.border_color = WOOD_DARK
	_apply_shadow(sb, 7.0, 3.0, 0.38)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.7
	sb.content_margin_bottom = pad * 0.6
	root.add_theme_stylebox_override("panel", sb)
	root.add_child(_ReferenceFrame.new(), false, Node.INTERNAL_MODE_BACK)
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
	sb.set_corner_radius_all(0)
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
	sb.set_corner_radius_all(0)
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


## 主世界统一入口：登录、序章、营帐与跨图只走同一份角色/地图配置。
## arrival 是目标地图的落地点 id；留空时恢复该地图保存位置或使用 spawn。
func enter_main_world(map_id := "", arrival := "") -> void:
	const WORLD_SCENE := "res://src/explore/MapScene.tscn"
	if not can_go(WORLD_SCENE):
		return
	var state: Variant = prog.get("main_world", {})
	var target := map_id
	if target.is_empty() and state is Dictionary:
		target = String((state as Dictionary).get("map_id", ""))
	if TableCache.main_world_map(target).is_empty():
		target = TableCache.default_main_world_map()
	var map_cfg := TableCache.main_world_map(target)
	if map_cfg.is_empty():
		push_error("主世界地图配置缺失：%s" % target)
		return
	var catchup := campaign_growth_catchup()
	if not bool(catchup.get("ok", false)):
		var anchor := get_tree().current_scene as Control
		if anchor != null:
			show_info_popup(anchor, "经验补记未保存", ["请检查存档位置后重试，当前进度已保留。"])
		return
	if int(catchup.get("exp", 0)) > 0:
		_pending_campaign_note = "旅途经验补记 +%d · Lv%d" % [int(catchup.exp), int(prog.get("level", 1))]
	var gear := campaign_gear_claim()
	if not bool(gear.get("ok", false)):
		var anchor := get_tree().current_scene as Control
		if anchor != null: show_info_popup(anchor, "主线保底未保存", [String(gear.get("err", "请检查存档位置后重试。"))])
		return
	if int(gear.get("count", 0)) > 0:
		if not _pending_campaign_note.is_empty(): _pending_campaign_note += "\n"
		_pending_campaign_note += "主线保底 %d 件 · 请查看背包／待领取" % int(gear.count)
	var pets := owned_pets()
	var run := RunState.new()
	run.setup({
		"theme": String(map_cfg.get("theme", "forest")),
		"role_id": selected_role if not selected_role.is_empty() else "zs",
		"level": int(prog.get("level", 1)),
		"active_pet": companion_active(),
		"bench_pet": String(pets.filter(func(pid): return String(pid) != companion_active())[0]) if pets.size() > 1 else "",
		"potions": run_potions_base(),
		"seed": randi(),
	})
	run.growth_bonus = growth_bonuses(run.role_id)
	MapScene.pending_cfg = {
		"mode": "main_world", "main_map_id": target, "arrival": arrival,
		"run": run,
		"node": {"type": String(map_cfg.get("node_type", "normal")), "layer": 0, "index": 0},
	}
	go(WORLD_SCENE)


func transit_busy() -> bool:
	return _transit_busy


# ---------- 演武场 ----------
## 段位名（铜/银/金/铂/钻印）——阈值在 data/arena.json ranks，改段位不动代码
func arena_rank() -> String:
	var s := int(arena.get("score", 0))
	var ranks: Variant = TableCache.arena_config().get("ranks", [])
	var best_name := "铜印"
	var best_min := -1
	if ranks is Array:
		for r in ranks:
			if not (r is Dictionary):
				continue
			var lo := int((r as Dictionary).get("min", 0))
			if s >= lo and lo >= best_min:
				best_min = lo
				best_name = String((r as Dictionary).get("name", "铜印"))
		return best_name
	if s >= 1800:
		return "钻印"
	if s >= 1600:
		return "铂印"
	if s >= 1400:
		return "金印"
	if s >= 1200:
		return "银印"
	return "铜印"


## 生成一个演武傀儡：血量/攻防按当前职业面板生成（P1-8——不再是固定 520 血的"墙"），
## ai 用 basic（去掉首领 <30% 狂暴）；超时平局见 BattleSim（口径 D3）。
func make_arena_foe(level: int) -> Dictionary:
	var lvl := maxi(1, level)
	var rid := selected_role if selected_role != "" else "zs"
	var stats := TableCache.role_stats(rid, lvl)
	return {
		"id": "mon_arena_dummy",
		"name": "演武傀儡 · %d 级" % lvl,
		"tier": "boss", "ai": "basic", "attack_range": "melee",
		"base": {"hp": maxi(180, int(float(stats.max_hp) * 2.2)),
			"atk": maxi(1, int(float(stats.atk) * 1.15)),
			"def": maxi(0, int(stats.def)), "spd": 0.95},
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


## 连胜参数（data/arena.json）：每 step 连胜发一次荣誉，另按连胜长度追加段位分加成
func arena_streak_cfg() -> Dictionary:
	var c: Variant = TableCache.arena_config().get("streak", {})
	return c if c is Dictionary else {}


## 当前连胜（败/平局不清零之外的口径见 arena_result）
func arena_streak() -> int:
	return maxi(0, int(arena.get("streak", 0)))


## 结算一场切磋：胜 +18~26（数值来自 data/arena.json）、负 -12（保底 0）。
## 连胜：胜则 +1，负则清零；平局/撤退还走 ArenaPanel 的早退分支，不进这里，连胜保持不变。
## 每满 step 连胜额外发荣誉（演武场此前只给段位分，赢了没有可花的产出——连胜奖补上这一环）。
## 返回 {delta, score, rank, streak, best, honor, milestone}
func arena_result(win: bool) -> Dictionary:
	var cfg := arena_streak_cfg()
	var scfg: Variant = TableCache.arena_config().get("score", {})
	var sc: Dictionary = scfg if scfg is Dictionary else {}
	var step := maxi(1, int(cfg.get("step", 3)))
	var honor_per := maxi(0, int(cfg.get("honor_per_milestone", 0)))
	var per_streak := maxi(0, int(cfg.get("score_bonus_per_streak", 0)))
	var cap := maxi(0, int(cfg.get("score_bonus_cap", 0)))

	var delta := 0
	var streak := arena_streak()
	var honor := 0
	var milestone := false
	if win:
		var wmin := int(sc.get("win_min", 18))
		var wmax := int(sc.get("win_max", 26))
		delta = wmin + (randi() % maxi(1, wmax - wmin + 1))
		streak += 1
		arena["wins"] = int(arena.get("wins", 0)) + 1
		if streak % step == 0:
			milestone = true
			honor = honor_per
		if per_streak > 0:
			delta += mini(cap, per_streak * (streak - 1))
	else:
		delta = -mini(int(sc.get("loss", 12)), int(arena.get("score", 0)))
		streak = 0
		arena["losses"] = int(arena.get("losses", 0)) + 1
	arena["streak"] = streak
	var best := maxi(int(arena.get("best_streak", 0)), streak)
	arena["best_streak"] = best
	if honor > 0:
		wallet["honor"] = int(wallet.get("honor", 0)) + honor
	arena["score"] = maxi(0, int(arena.get("score", 0)) + delta)
	save_game()
	return {"delta": delta, "score": int(arena["score"]), "rank": arena_rank(),
		"streak": streak, "best": best, "honor": honor, "milestone": milestone}


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


## 羊皮纸详情弹层：遮罩 / 「知道了」/ ESC / 归属面板退出 —— 四条路都走同一个释放函数。
##
## 这块以前是一团散沙（问题 #6）：CanvasLayer 挂在根节点上、没有 owner、ESC 无人处理、
## 也不参与 ui_blocked，于是出现两类真实故障：
##   1. 开着详情弹层按 ESC，ESC 会穿到底下的面板把它关掉，详情弹层反而留在屏幕上；
##   2. 详情弹层的父面板被关掉后，弹层还挂在根上，成了点不掉也没人能收的孤儿。
## 现在用一个模态栈统一管理：栈非空 = ui_blocked（见 ui_blocked 的 getter），
## ESC 只关栈顶，owner 退出时自动出栈释放。
var _modals: Array = []
var _modal_seq := 0


## 栈里可能留着已被别处释放的弹层：读数与关栈顶之前先清一遍，
## 否则一个失效条目会永久占着栈顶、让所有 ESC 都打在空气上。
func _prune_modals() -> void:
	for i in range(_modals.size() - 1, -1, -1):
		var l: Variant = _modals[i].get("layer")
		if l == null or not is_instance_valid(l) or (l as CanvasLayer).is_queued_for_deletion():
			_modals.remove_at(i)


func modal_count() -> int:
	_prune_modals()
	return _modals.size()


## 返回弹层句柄（CanvasLayer），调用方可用 close_info_popup 主动关闭
func show_info_popup(anchor: Control, title: String, lines: Array, owner: Node = null) -> CanvasLayer:
	return _build_popup(anchor, title, lines, owner, [])


## 带选项的弹层：choices = [{"text": "...", "cb": Callable}, ...]，点了先关弹层再回调。
## 空数组 = 只有一个「知道了」（与 show_info_popup 等价）。
## 存档被判非法时用得上：玩家必须能在「继续（放弃原档）」与「导入旧档」之间显式选一条（A7）。
func show_choice_popup(anchor: Control, title: String, lines: Array, choices: Array,
		owner: Node = null) -> CanvasLayer:
	return _build_popup(anchor, title, lines, owner, choices)


func _build_popup(anchor: Control, title: String, lines: Array, owner: Node,
		choices: Array) -> CanvasLayer:
	var tree := anchor.get_tree()
	if tree == null:
		return null
	var own: Node = owner if owner != null else _top_owner_for(anchor)
	var layer := CanvasLayer.new()
	layer.layer = 90   # 低于 GM 控制台(100)，高于一切面板
	tree.root.add_child(layer)

	# 统一浮层底衬（深棕 + 暗角 + 斜纹）；要能接 gui_input 以便点空白关闭，
	# 所以不再走独立 ColorRect，直接用 veil 返回的那层 Control。
	# 入栈：ui_blocked 立刻为真，底下的面板不会再把 ESC / 输入抢走
	_modal_seq += 1
	var mid := _modal_seq
	_modals.append({"id": mid, "layer": layer, "owner": own})
	if own != null:
		# owner 退出（关面板 / 切场景）时必须一起释放，否则弹层会成为孤儿。
		# 闭包捕获的是**整数 id 而不是弹层对象**：捕获对象的话，对象被释放后
		# 回调触发时会打印 "Lambda capture at index 0 was freed. Passed null instead."
		own.tree_exiting.connect(func(): close_info_popup_by_id(mid), CONNECT_ONE_SHOT)
	# 锚点兜底：_top_owner_for 假定面板直挂场景根，嵌套容器或测试夹具里锚点先走，
	# 不兜底就留孤儿弹层压住 ui_blocked（VerifyNav 的 ESC 复位失败就是这么来的）
	if anchor != null and anchor != own:
		anchor.tree_exiting.connect(func(): close_info_popup_by_id(mid), CONNECT_ONE_SHOT)

	var dim := veil_at(layer, 0.55)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close_info_popup(layer))

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

	var btn_y := 42.0 + content_h + 12.0
	var picks: Array = []
	for c in choices:
		if c is Dictionary and String((c as Dictionary).get("text", "")) != "":
			picks.append(c)
	if picks.is_empty():
		picks = [{"text": "知道了", "cb": Callable()}]
	var bw := 120.0 if picks.size() == 1 else 150.0
	var gap := 12.0
	var total_w := float(picks.size()) * bw + float(picks.size() - 1) * gap
	var x0 := (PW - 32.0 - total_w) * 0.5
	for i in picks.size():
		var pc: Dictionary = picks[i]
		var cb: Callable = pc.get("cb", Callable())
		var ok := gold_button(String(pc.get("text", "知道了")), bw, 40, FS_SM)
		ok.position = Vector2(x0 + float(i) * (bw + gap), btn_y)
		ok.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				close_info_popup(layer)
				if cb.is_valid():
					cb.call())
		content.add_child(ok)
	return layer


## 唯一的释放路径：出栈 + 释放。可重复调用（已释放/无效都不报错）。
func close_info_popup(layer: CanvasLayer) -> void:
	if layer == null:
		return
	_forget_modal(layer)
	if is_instance_valid(layer) and not layer.is_queued_for_deletion():
		layer.queue_free()


## 按 id 关闭（给"捕获整数"的回调用，避免闭包持有已释放对象）
func close_info_popup_by_id(mid: int) -> void:
	for i in range(_modals.size() - 1, -1, -1):
		if int(_modals[i].get("id", -1)) == mid:
			var l: Variant = _modals[i].get("layer")
			_modals.remove_at(i)
			if l != null and is_instance_valid(l) and not (l as CanvasLayer).is_queued_for_deletion():
				(l as CanvasLayer).queue_free()
			return


func _forget_modal(layer: CanvasLayer) -> void:
	for i in range(_modals.size() - 1, -1, -1):
		var l: Variant = _modals[i].get("layer")
		if l == null or not is_instance_valid(l) or l == layer:
			_modals.remove_at(i)


## 弹层的自然归属：从锚点往上找到"最外层、但不是场景根"的那个节点（通常是整块面板/场景）
func _top_owner_for(anchor: Node) -> Node:
	var cur: Node = anchor
	var root := anchor.get_tree().root if anchor.get_tree() != null else null
	while cur != null and cur.get_parent() != null and cur.get_parent() != root:
		cur = cur.get_parent()
	return cur


## ESC 只关最上层弹层；没有弹层时什么都不做，把 ESC 让给正常流程。
## G 是 autoload，在输入传播顺序上先于场景节点，所以这里标记 handled 后
## 底下的面板不会再收到这次 ESC（这正是"时灵时不灵"的根因之一）。
func _unhandled_input(event: InputEvent) -> void:
	_prune_modals()
	if _modals.is_empty():
		return
	if event.is_action_pressed("ui_cancel"):
		# 只关栈顶：底下的弹层/面板必须等下一次 ESC，不能再出现"一次 ESC 关两层"
		close_info_popup_by_id(int(_modals.back().get("id", -1)))
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()


## Node2D 不参与容器布局或GUI拾取，保留按钮/内容的原有热区。
class _ReferenceFrame extends Node2D:
	func _ready() -> void:
		(get_parent() as Control).resized.connect(queue_redraw)
	func _draw() -> void:
		var dimensions := (get_parent() as Control).size
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			for block in [Rect2(4, 4, 14, 2), Rect2(4, 4, 2, 14),
					Rect2(9, 9, 9, 2), Rect2(9, 9, 2, 9), Rect2(14, 14, 4, 4)]:
				var at: Vector2 = block.position
				if corner.x == 1: at.x = dimensions.x-block.end.x
				if corner.y == 1: at.y = dimensions.y-block.end.y
				draw_rect(Rect2(at, block.size), Color("c5a14f"))
