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

# ---------- 共享状态 ----------
var account := ""           # 登录账号（游客登录时为"游客"）
var gender := "男"          # 玩家选择性别
var selected_role := ""     # "zs" / "ck" / "fs" / "fz"
var player_name := ""       # 玩家起的名字
var roles: Array = []       # data/roles.json 内容

# ---------- 存档与钱包（user://save.json；四币 + 角色档案 + 养成进度） ----------
# 用 var 而非 const：自动化测试会把 SAVE_PATH 指向临时文件，避免污染真实存档
var SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2
var wallet := {"gold": 0, "expedition": 0, "soul": 0, "honor": 0}

# ---------- 道具库存（最小实现：id -> 数量；券类先行，后续道具沿用） ----------
var items := {"ticket_ten": 0, "ticket_sweep": 1}


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

# ---------- GM 开发者控制台 ----------
# F10 / ` 唤起；输入口令后解锁全部内容与满级，仅供调试。解锁态只存本次运行，不落盘。
const GM_PASSWORD := "@tsz20060706"
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
	_load_roles()
	_load_save()
	ensure_starter_buildings()


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
		"items": items,
		"account": account,
		"gender": gender,
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
	prog = {"level": 1, "exp": 0, "worlds_unlocked": 1, "world_cleared": {}, "pets": []}
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


# ---------- 生成素材索引（image/generated_*/source/，文件名形如 NNN_名称.png） ----------
# 统一按「名称」寻址（如 res_tex("mon_wolf")），免去在代码里硬编码 300+ 条编号路径；
# 首次访问时扫描一次目录并缓存，后续 O(1) 查表。
var _res_index: Dictionary = {}   # "名称.png" -> "res://image/.../NNN_名称.png"
var _res_indexed := false

func _build_res_index() -> void:
	if _res_indexed:
		return
	_res_indexed = true
	var batches := ["generated_001_100", "generated_101_200", "generated_201_333"]
	# 先收 ready/（成品：已裁到设计尺寸、alpha 已硬化），再拿 source/ 母稿补位。
	# 顺序不能反——source 是 970~2170px 的原始大图，既吃显存，也会把未受容器约束的
	# TextureRect 的最小尺寸钳到原图大小（曾导致召唤横幅 2172×724 铺满面板压住文案）
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
func res_tex(res_name: String) -> Texture2D:
	var p := res_path(res_name)
	if p.is_empty():
		return null
	return load(p) as Texture2D


# ---------- 通用 UI 工厂 ----------

## 柔和投影（偏移向下、低透明，像纸页叠放而非霓虹光晕）
func _apply_shadow(sb: StyleBoxFlat, size: float, off_y: float, alpha: float) -> void:
	sb.shadow_color = Color(0.0, 0.0, 0.0, alpha)
	sb.shadow_size = int(size)
	sb.shadow_offset = Vector2(0, off_y)

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

## 顶部棕色木匾横幅（宋体 + 柔金边；边框降饱和避免荧光感）
func banner_box(text: String, w := 260, h := 52, font_size := FS_BIG) -> PanelContainer:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(w, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.30, 0.18, 0.08, 0.92)
	sb.set_corner_radius_all(5)
	sb.set_border_width_all(2)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.65)
	_apply_shadow(sb, 5.0, 2.0, 0.4)
	# 左右必须等值：以前是 28/20 的「偏左留白」写法，实测文字中心落在 242.5（面板中心 240），
	# 肉眼看就是字往右歪。木匾文字本来就是居中的，左右各留一样多才不歪
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	root.add_theme_stylebox_override("panel", sb)
	var l := serif_label(text, font_size, GOLD_BRIGHT)
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
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 7
	sb.corner_radius_bottom_right = 5
	sb.set_border_width_all(3)
	sb.border_color = GOLD
	_apply_shadow(sb, 7.0, 3.0, 0.38)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.7
	sb.content_margin_bottom = pad * 0.6
	root.add_theme_stylebox_override("panel", sb)
	return root


## 金色实心按钮（棕字，参考"随机取名"）
func gold_button(text: String, w := 0.0, h := 42.0, font_size := FS_MD) -> Control:
	var root := PanelContainer.new()
	if w > 0.0:
		root.custom_minimum_size = Vector2(w, h)
	else:
		root.custom_minimum_size = Vector2(0, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = GOLD_BTN
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	sb.border_color = GOLD_BTN_EDGE
	_apply_shadow(sb, 4.0, 2.0, 0.35)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	root.add_theme_stylebox_override("panel", sb)
	var l := gold_label(text, font_size, true, TEXT_DARK, false)
	root.add_child(l)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	# 按压反馈：微暗 + 微缩，松开回弹（避免静态死板的模板感）
	root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			root.pivot_offset = root.size * 0.5
			var tw := root.create_tween()
			if e.pressed:
				tw.tween_property(root, "modulate", Color(0.9, 0.9, 0.9), 0.06)
				tw.parallel().tween_property(root, "scale", Vector2.ONE * 0.97, 0.06)
			else:
				tw.tween_property(root, "modulate", Color.WHITE, 0.12)
				tw.parallel().tween_property(root, "scale", Vector2.ONE, 0.12))
	return root


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
	focus.bg_color = INPUT_BG_FOCUS
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
