# SaveData.gd —— 存档版本、结构校验、逐版迁移与安全写盘
#
# 为什么单独一个模块（问题 #39、#24）：
#   原实现的迁移逻辑散落在 G._load_save 的字段赋值中间（比如 items.gacha_pity → prog.gacha.pity），
#   导入路径 SettingsPanel.do_import 又只检查"是不是 JSON 对象"就把整份文本盖到存档上：
#   没有版本闸门、没有结构校验、没有备份、没有原子替换。导入一个未来版本的档会静默丢字段，
#   导入一个 last_ts 在未来水位的档会让所有按天/按时的刷新长期冻结。
#
# 数据流（导入）：解析 → 结构/版本闸门 → 逐版迁移 → 语义校验 → 备份 → 原子落盘 → 重读内存
# 数据流（启动）：解析 → 结构/版本闸门 → 逐版迁移 → 语义校验 → 应用内存
# 纯静态、不引用任何 autoload：这样它既能被 -s 脚本测试，也能被 UI 与启动流程共用。
class_name SaveData

## 当前写盘版本。G.SAVE_VERSION 只是它的别名，避免两处各写一个数字。
const CURRENT_VERSION := 3
## 低于这个版本的档连迁移入口都没有，直接判定不可读。
const MIN_READABLE_VERSION := 1
## 允许的时钟偏差（秒）：last_ts 超过"现在 + 这个值"就算未来水位异常档。
## 6 小时覆盖跨时区旅行与手动校时，又挡得住明显伪造的未来档。
## ⚠ 这是产品决策，不是技术推导；若玩法需要更长离线进度，改这里并同步设计文档。
const FUTURE_TS_LIMIT_SEC := 6 * 3600
## 备份保留份数（多的按时间从旧到新删）
const BACKUP_KEEP := 3
const WALLET_KEYS := ["gold", "expedition", "soul", "honor"]
## 存档里"必须是字典"的字段（缺省允许，给了就必须是字典）
const DICT_FIELDS := ["wallet", "items", "prog", "city", "quest", "arena", "audio"]


## 版本字段：只接受非负整数（JSON 浮点但数值上是整数也接受）。非法返回 -1。
static func version_of(data: Dictionary) -> int:
	if not data.has("version"):
		return 1   # 历史档没有 version 字段，按 v1 处理
	var v: Variant = data.get("version")
	if v is int:
		return int(v) if int(v) >= 0 else -1
	if v is float:
		var f := float(v)
		if f >= 0.0 and is_equal_approx(f, roundf(f)):
			return int(f)
	return -1


static func is_future(data: Dictionary) -> bool:
	return version_of(data) > CURRENT_VERSION


## 逐版本迁移。每步都是纯函数，对已是目标版本的档再跑一次不会改动数值（幂等）。
## 返回 { ok, err, data, from, to, steps }
static func migrate(raw: Dictionary) -> Dictionary:
	var data := raw.duplicate(true)
	var from := version_of(data)
	if from < 0:
		return _mig_fail(data, from, "存档 version 字段非法（应为非负整数）")
	if from > CURRENT_VERSION:
		return _mig_fail(data, from,
			"存档版本 %d 高于本程序支持的 %d，拒绝导入（避免把它没有的字段当垃圾丢掉）"
			% [from, CURRENT_VERSION])
	if from < MIN_READABLE_VERSION:
		return _mig_fail(data, from, "存档版本 %d 过旧，无法迁移" % from)
	var v := from
	var steps: Array = []
	var guard := 0
	while v < CURRENT_VERSION and guard < 32:
		guard += 1
		match v:
			1:
				_migrate_v1_to_v2(data)
				steps.append("v1→v2")
				v = 2
			2:
				_migrate_v2_to_v3(data)
				steps.append("v2→v3")
				v = 3
			_:
				return _mig_fail(data, from, "缺少 v%d 的迁移步骤（迁移表不完整）" % v)
	data["version"] = CURRENT_VERSION
	# 归一化对**所有**版本都跑（含本来就是当前版的档）：散落过的旧字段不能只靠版本号来清，
	# 因为"已经是 v3 但被旧程序写脏的档"确实存在（例如 items.gacha_pity 残留）。
	_normalize(data)
	return {"ok": true, "err": "", "data": data, "from": from, "to": CURRENT_VERSION, "steps": steps}


## 清理历史遗留字段；幂等。
static func _normalize(data: Dictionary) -> void:
	var items: Variant = data.get("items", {})
	if items is Dictionary and (items as Dictionary).has("gacha_pity"):
		var prog: Variant = data.get("prog", {})
		if prog is Dictionary:
			var gacha: Variant = (prog as Dictionary).get("gacha", {})
			if gacha is Dictionary:
				if int((gacha as Dictionary).get("pity", 0)) == 0:
					(gacha as Dictionary)["pity"] = maxi(0, int((items as Dictionary)["gacha_pity"]))
		(items as Dictionary).erase("gacha_pity")


static func _mig_fail(data: Dictionary, from: int, err: String) -> Dictionary:
	push_warning("存档迁移：%s" % err)
	return {"ok": false, "err": err, "data": data, "from": from, "to": from, "steps": []}


## v1 → v2：把顶层容器补成字典。
## v1 时代 wallet/items/prog 允许缺失或为 null，后续所有读取都假定它们是字典。
static func _migrate_v1_to_v2(data: Dictionary) -> void:
	for k in ["wallet", "items", "prog"]:
		if not (data.get(k) is Dictionary):
			data[k] = {}


## v2 → v3：保底计数从道具背包搬进 prog.gacha，并从 items 里清掉。
## 这一步以前混在 G._load_save 的字段赋值之间，没有版本边界，重复读档会反复执行。
static func _migrate_v2_to_v3(data: Dictionary) -> void:
	var items: Variant = data.get("items", {})
	var prog: Variant = data.get("prog", {})
	if not (items is Dictionary):
		items = {}
		data["items"] = items
	if not (prog is Dictionary):
		prog = {}
		data["prog"] = prog
	var gacha: Variant = (prog as Dictionary).get("gacha", {})
	if not (gacha is Dictionary):
		gacha = {}
		(prog as Dictionary)["gacha"] = gacha
	var legacy: Variant = (items as Dictionary).get("gacha_pity")
	if legacy != null:
		if int((gacha as Dictionary).get("pity", 0)) == 0:
			(gacha as Dictionary)["pity"] = maxi(0, int(legacy))
		(items as Dictionary).erase("gacha_pity")


## 语义校验：类型、取值范围、未来时间水位。
## now_sec 由调用方传入（可测，不依赖真实时钟）。
## 返回 { ok, err }
static func validate(data: Dictionary, now_sec: int) -> Dictionary:
	var err := ""
	for k in DICT_FIELDS:
		if data.has(k) and not (data.get(k) is Dictionary):
			err = "字段 %s 应为对象" % k
			return {"ok": false, "err": err}
	var wallet: Variant = data.get("wallet", {})
	if wallet is Dictionary:
		for k in WALLET_KEYS:
			var v: Variant = (wallet as Dictionary).get(k)
			if v == null:
				continue
			if not (v is int or v is float):
				return {"ok": false, "err": "钱包 %s 应为数值" % k}
			if float(v) < 0.0:
				return {"ok": false, "err": "钱包 %s 不应为负数（%s）" % [k, str(v)]}
	var items: Variant = data.get("items", {})
	if items is Dictionary:
		for k in (items as Dictionary):
			var n: Variant = (items as Dictionary)[k]
			if not (n is int or n is float):
				return {"ok": false, "err": "道具 %s 数量应为数值" % str(k)}
			if float(n) < 0.0:
				return {"ok": false, "err": "道具 %s 数量不应为负（%s）" % [str(k), str(n)]}
	var prog: Variant = data.get("prog", {})
	if prog is Dictionary:
		var pd := prog as Dictionary
		var lv: Variant = pd.get("level")
		if lv != null:
			if not (lv is int or lv is float):
				return {"ok": false, "err": "角色等级应为数值"}
			if int(lv) < 1 or int(lv) > 10000:
				return {"ok": false, "err": "角色等级超出范围（%s）" % str(lv)}
		for k in ["pets", "codex_claimed"]:
			var arr: Variant = pd.get(k)
			if arr != null and not (arr is Array):
				return {"ok": false, "err": "prog.%s 应为数组" % k}
		for k in ["talents", "equip", "skills", "mounts", "titles", "pet_stat",
				"tips_seen", "settings", "gacha", "world_cleared", "lore_beats"]:
			var dv: Variant = pd.get(k)
			if dv != null and not (dv is Dictionary):
				return {"ok": false, "err": "prog.%s 应为对象" % k}
		var ts: Variant = pd.get("last_ts")
		if ts != null:
			if not (ts is int or ts is float):
				return {"ok": false, "err": "时间水位 last_ts 应为数值"}
			if float(ts) > float(now_sec) + float(FUTURE_TS_LIMIT_SEC):
				return {"ok": false, "err": "时间水位异常：last_ts 比当前时间超前 %d 小时，会冻结按天/按时的刷新"
					% int((float(ts) - float(now_sec)) / 3600.0)}
	return {"ok": true, "err": ""}


## 启动路径用：宽容一些。未来版本不阻断（玩家还要能玩），但要报告出来让上层备份原档。
## 返回 { ok, mode, err, data, from, to, steps }，mode ∈ current / migrated / future / invalid
static func load_payload(raw: Dictionary, now_sec: int) -> Dictionary:
	var from := version_of(raw)
	if from < 0:
		return {"ok": false, "mode": "invalid", "err": "存档 version 字段非法", "data": raw,
			"from": from, "to": from, "steps": []}
	if from > CURRENT_VERSION:
		# 按兼容方式读（缺省即默认），但绝不把它当"已知版本"改写；上层负责先备份原档
		return {"ok": true, "mode": "future", "err": "存档版本 %d 高于本程序 %d" % [from, CURRENT_VERSION],
			"data": raw.duplicate(true), "from": from, "to": from, "steps": []}
	var mig := migrate(raw)
	if not bool(mig["ok"]):
		return {"ok": false, "mode": "invalid", "err": String(mig["err"]), "data": raw,
			"from": from, "to": from, "steps": []}
	var v := validate(mig["data"], now_sec)
	if not bool(v["ok"]):
		return {"ok": false, "mode": "invalid", "err": String(v["err"]), "data": mig["data"],
			"from": from, "to": int(mig["to"]), "steps": mig["steps"]}
	var mode := "migrated" if from < CURRENT_VERSION else "current"
	return {"ok": true, "mode": mode, "err": String(mig["err"]), "data": mig["data"],
		"from": from, "to": int(mig["to"]), "steps": mig["steps"]}


## 导入路径用：严格。版本闸门 + 迁移 + 校验任一不过就拒绝，调用方保持原档不动。
## 返回 { ok, err, text, from, to, steps }
static func import_payload(text: String, now_sec: int) -> Dictionary:
	var j := JSON.new()
	if j.parse(text) != OK or not (j.data is Dictionary):
		return {"ok": false, "err": "存档码不是合法的 JSON 对象", "text": "", "from": -1, "to": -1, "steps": []}
	var raw := j.data as Dictionary
	if is_future(raw):
		return {"ok": false,
			"err": "存档版本 %d 来自更新的游戏版本（本程序最高 %d），已拒绝导入；你的当前存档未改动"
				% [version_of(raw), CURRENT_VERSION],
			"text": "", "from": version_of(raw), "to": -1, "steps": []}
	var res := load_payload(raw, now_sec)
	if not bool(res["ok"]):
		return {"ok": false, "err": String(res["err"]), "text": "", "from": int(res["from"]),
			"to": -1, "steps": []}
	return {"ok": true, "err": "", "text": JSON.stringify(res["data"], "\t"),
		"from": int(res["from"]), "to": int(res["to"]), "steps": res["steps"]}


# ---------- 落盘：备份 + 临时文件 + 替换 ----------

## 把 path 现有内容复制成带时间戳的备份，并按 BACKUP_KEEP 修剪旧备份。
## 返回新建备份的路径（没有原档则返回空串）。
static func backup_file(path: String, stamp: int, keep := BACKUP_KEEP) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var src := FileAccess.open(path, FileAccess.READ)
	if src == null:
		return ""
	var text := src.get_as_text()
	src.close()
	var dir := path.get_base_dir()
	var base := path.get_file().get_basename()
	var bpath := "%s/%s_backup_%d.json" % [dir, base, stamp]
	var f := FileAccess.open(bpath, FileAccess.WRITE)
	if f == null:
		push_error("备份写入失败：%s" % bpath)
		return ""
	f.store_string(text)
	f.close()
	# 修剪：按文件名里的时间戳排序，保留最新 keep 份
	var names: Array = []
	var d := DirAccess.open(dir)
	if d != null:
		for n in d.get_files():
			if String(n).begins_with("%s_backup_" % base) and String(n).ends_with(".json"):
				names.append(String(n))
	names.sort()
	while names.size() > keep:
		d.remove(names[0])
		names.remove_at(0)
	return bpath


## 原子写盘：先写 <path>.tmp，完整落盘后再替换目标（Windows 上 rename 覆盖已存在文件会失败，
## 所以先把目标删掉；此时备份已经存在，最坏情况可回滚）。
## 返回 { ok, err }
static func write_text_atomic(path: String, text: String) -> Dictionary:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "err": "临时文件写入失败：%s" % tmp}
	f.store_string(text)
	f.close()
	var g := FileAccess.open(tmp, FileAccess.READ)
	if g == null:
		return {"ok": false, "err": "临时文件回读失败，未替换原档"}
	# 比字符串**不能**比字节数：存档里有中文（昵称/性别），UTF-8 字节数 != 字符数
	var echo := g.get_as_text()
	g.close()
	if echo != text:
		return {"ok": false, "err": "临时文件校验失败（回读内容不一致），未替换原档"}
	var da := DirAccess.open(path.get_base_dir())
	if da == null:
		return {"ok": false, "err": "无法打开存档目录"}
	if FileAccess.file_exists(path):
		var e := da.remove(path.get_file())
		if e != OK:
			return {"ok": false, "err": "无法替换原档（删除失败 %d）" % e}
	var e2 := da.rename(tmp.get_file(), path.get_file())
	if e2 != OK:
		return {"ok": false, "err": "替换失败（rename %d），原档保持不变" % e2}
	return {"ok": true, "err": ""}
