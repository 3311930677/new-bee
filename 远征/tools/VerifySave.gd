# VerifySave.gd —— 存档完整性回归（场景模式：godot --headless --path . res://tools/VerifySave.tscn）
# 守问题清单 #39（版本闸门/逐版迁移/未来版本拒绝写回/坏档 fixture）与 #24（未来时间水位）。
# 用 tools/fixtures/saves/ 下的真实旧档样本，而不是在用例里现编结构。
extends Node

const FIX := "res://tools/fixtures/saves/"

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "user://save_verify_save.json"
	await _run()
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


func _fixture(name: String) -> Dictionary:
	var f := FileAccess.open(FIX + name, FileAccess.READ)
	if f == null:
		push_error("fixture 缺失：" + name)
		return {}
	var t := f.get_as_text()
	f.close()
	var v: Variant = JSON.parse_string(t)
	return v if v is Dictionary else {}


func _fixture_text(name: String) -> String:
	var f := FileAccess.open(FIX + name, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t


func _wipe(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _run() -> void:
	var now := int(Time.get_unix_time_from_system())

	# ---- A. 版本常量同源 ----
	_check(SaveData.CURRENT_VERSION == G.SAVE_VERSION,
		"SaveData.CURRENT_VERSION(%d) 应与 G.SAVE_VERSION(%d) 同源"
		% [SaveData.CURRENT_VERSION, G.SAVE_VERSION])

	# ---- B. 逐版迁移 ----
	var v1 := SaveData.migrate(_fixture("v1.json"))
	_check(bool(v1["ok"]), "v1 档应可迁移（%s）" % String(v1["err"]))
	_check(int(v1["to"]) == SaveData.CURRENT_VERSION, "v1 应迁到 %d" % SaveData.CURRENT_VERSION)
	_check((v1["steps"] as Array).size() == SaveData.CURRENT_VERSION - 1,
		"v1 应逐级走完 %d 步，实为 %s" % [SaveData.CURRENT_VERSION - 1, str(v1["steps"])])
	var v1d: Dictionary = v1["data"]
	_check(v1d.get("prog") is Dictionary,
		"v1→v2 应把 prog=null 归一成字典（否则后面所有读取都会踩空）")
	_check(int((v1d.get("wallet", {}) as Dictionary).get("gold", -1)) == 100, "迁移不该改动已有数值")

	var v2 := SaveData.migrate(_fixture("v2.json"))
	_check(bool(v2["ok"]), "v2 档应可迁移")
	var v2d: Dictionary = v2["data"]
	var v2items: Dictionary = v2d.get("items", {})
	_check(not v2items.has("gacha_pity"), "v2→v3 应从道具背包清掉 gacha_pity")
	_check(int(((v2d.get("prog", {}) as Dictionary).get("gacha", {}) as Dictionary).get("pity", 0)) == 42,
		"v2 的 gacha_pity 应搬进 prog.gacha.pity，实为 %s"
		% str(((v2d.get("prog", {}) as Dictionary).get("gacha", {}) as Dictionary).get("pity")))
	# 幂等：再迁一次不该改动结果
	var v2again: Dictionary = SaveData.migrate(v2d)["data"]
	_check(JSON.stringify(v2again.get("prog", {})) == JSON.stringify(v2d.get("prog", {})),
		"迁移必须幂等：对已迁移的档再跑不改动内容")

	var v3 := SaveData.migrate(_fixture("v3.json"))
	_check(bool(v3["ok"]) and (v3["steps"] as Array).is_empty(), "v3 档不需要迁移步骤")
	_check(int(((v3["data"] as Dictionary).get("wallet", {}) as Dictionary).get("gold", 0)) == 777,
		"v3 迁移不该改动数据")

	var vf := SaveData.migrate(_fixture("future.json"))
	_check(not bool(vf["ok"]), "未来版本档不应通过迁移（应显式拒绝）")
	_check(String(vf["err"]).contains("高于"), "拒绝原因应说明版本过高，实为「%s」" % String(vf["err"]))

	# ---- C. 启动路径 load_payload：未来版本可按兼容方式读，但要报告出来 ----
	var lp_cur := SaveData.load_payload(_fixture("v3.json"), now)
	_check(bool(lp_cur["ok"]) and String(lp_cur["mode"]) == "current", "v3 应是 current 模式")
	var lp_mig := SaveData.load_payload(_fixture("v2.json"), now)
	_check(bool(lp_mig["ok"]) and String(lp_mig["mode"]) == "migrated", "v2 应是 migrated 模式")
	var lp_future := SaveData.load_payload(_fixture("future.json"), now)
	_check(bool(lp_future["ok"]) and String(lp_future["mode"]) == "future",
		"未来版本档在启动路径要能读（不能拿默认档顶掉玩家进度），但必须标成 future 模式")

	# ---- D. 语义校验（含 #24 未来时间水位边界） ----
	_check(not bool(SaveData.validate({"wallet": {"gold": -1}}, now)["ok"]), "负金币应判非法")
	_check(not bool(SaveData.validate({"wallet": {"soul": "10"}}, now)["ok"]), "字符串数量应判非法")
	_check(not bool(SaveData.validate({"items": {"ticket_ten": -3}}, now)["ok"]), "负道具数应判非法")
	_check(not bool(SaveData.validate({"prog": {"pets": "pet_rockturtle"}}, now)["ok"]),
		"prog.pets 不是数组应判非法")
	_check(not bool(SaveData.validate({"prog": {"level": 0}}, now)["ok"]), "等级 0 应判非法")
	_check(not bool(SaveData.validate({"city": []}, now)["ok"]), "city 不是对象应判非法")
	_check(bool(SaveData.validate({"prog": {"last_ts": now + 60}}, now)["ok"]),
		"轻微超前（1 分钟）的水位应放行（跨时区/校时误差）")
	_check(bool(SaveData.validate({"prog": {"last_ts": now + SaveData.FUTURE_TS_LIMIT_SEC}}, now)["ok"]),
		"刚好等于容差边界的水位应放行")
	_check(not bool(SaveData.validate({"prog": {"last_ts": now + SaveData.FUTURE_TS_LIMIT_SEC + 1}}, now)["ok"]),
		"超过容差 1 秒的水位应判非法（边界另一侧）")
	_check(not bool(SaveData.validate(_fixture("future_ts.json"), now)["ok"]),
		"未来水位 fixture 必须被拒（它会让按天刷新长期冻结）")

	# ---- E. 导入路径 import_payload：严格拒绝 ----
	var imp_future := SaveData.import_payload(_fixture_text("future.json"), now)
	_check(not bool(imp_future["ok"]), "未来版本存档码应拒绝导入")
	_check(String(imp_future["err"]).contains("当前存档未改动"), "拒绝文案应安抚玩家（当前档未改动）")
	var imp_corrupt := SaveData.import_payload(_fixture_text("corrupt.json"), now)
	_check(not bool(imp_corrupt["ok"]), "截断的 JSON 应拒绝导入")
	var imp_fts := SaveData.import_payload(_fixture_text("future_ts.json"), now)
	_check(not bool(imp_fts["ok"]), "未来时间水位的存档码应拒绝导入")
	_check(String(imp_fts["err"]).contains("超前"), "拒绝原因应点明时间水位异常，实为「%s」" % String(imp_fts["err"]))
	var imp_ok := SaveData.import_payload(_fixture_text("v2.json"), now)
	_check(bool(imp_ok["ok"]), "合法的旧版本存档码应可导入（%s）" % String(imp_ok["err"]))
	var imp_body: Variant = SaveData.import_payload(_fixture_text("v3.json"), now)
	_check(bool(imp_body["ok"]), "当前版本存档码应可导入")

	# ---- F. 备份与原子写盘 ----
	var tpath := "user://save_verify_atomic.json"
	_wipe(tpath)
	_wipe(tpath + ".tmp")
	_write(tpath, "{\"version\":3,\"wallet\":{\"gold\":1}}\n")
	# 备份保留份数：连做 5 次，只应留 BACKUP_KEEP 份
	for i in 5:
		SaveData.backup_file(tpath, 1000 + i)
	var dir := DirAccess.open("user://")
	var baks: Array = []
	for nm in dir.get_files():
		if String(nm).begins_with("save_verify_atomic_backup_"):
			baks.append(String(nm))
	_check(baks.size() <= SaveData.BACKUP_KEEP,
		"备份应只保留 %d 份，实为 %d" % [SaveData.BACKUP_KEEP, baks.size()])
	_check(baks.size() >= 1, "备份应至少生成一份")
	for nm2 in baks:
		_wipe("user://" + nm2)
	var wres := SaveData.write_text_atomic(tpath, "{\"version\":3,\"wallet\":{\"gold\":4242}}\n")
	_check(bool(wres["ok"]), "原子写盘应成功（%s）" % String(wres["err"]))
	var rf := FileAccess.open(tpath, FileAccess.READ)
	var rtext := rf.get_as_text()
	rf.close()
	_check(rtext.contains("4242"), "写盘后内容应更新")
	_check(not FileAccess.file_exists(tpath + ".tmp"), "写盘后临时文件应已被 rename 掉")
	_wipe(tpath)

	# ---- G. G 层整合：未来版本档 → 备份 + 兼容读取 + 不丢东西 ----
	G.SAVE_PATH = "user://save_verify_save.json"
	_wipe(G.SAVE_PATH)
	_write(G.SAVE_PATH, _fixture_text("future.json"))
	G.save_backup_path = ""
	G.last_load_report = {}
	G._load_save()
	_check(String(G.last_load_report.get("mode", "")) == "future",
		"启动读未来版本档时应记录 future 模式，实为「%s」" % String(G.last_load_report.get("mode", "")))
	_check(G.save_backup_path != "" and FileAccess.file_exists(G.save_backup_path),
		"遇到未来版本档必须先备份原档（备份路径：%s）" % G.save_backup_path)
	_check(int(G.wallet.get("gold", 0)) == 999999,
		"未来版本档仍应按兼容方式读进来（玩家进度不能凭空消失），实为 %d" % int(G.wallet.get("gold", 0)))
	if G.save_backup_path != "":
		_wipe(G.save_backup_path)
	# 写回后版本号必须回到本程序支持的版本，且不再被判为 future
	G.prog["level"] = 60
	G.save_game()
	G.last_load_report = {}
	G._load_save()
	_check(String(G.last_load_report.get("mode", "")) == "current",
		"重新写盘后应回到 current 模式，实为「%s」" % String(G.last_load_report.get("mode", "")))

	# ---- H. 坏档不覆盖玩家档 ----
	_wipe(G.SAVE_PATH)
	_write(G.SAVE_PATH, _fixture_text("corrupt.json"))
	G.wallet = {"gold": 4321, "expedition": 0, "soul": 0, "honor": 0}
	G._load_save()
	_check(int(G.wallet.get("gold", 0)) == 4321, "坏档不该清掉内存里的既有进度")
	var still := FileAccess.open(G.SAVE_PATH, FileAccess.READ)
	var still_text := still.get_as_text()
	still.close()
	_check(still_text.begins_with("{\"version\": 3, \"wallet\""), "坏档读失败不应改写原文件")

	# ---- I. 设置面板导入：拒绝时原档一字不动，成功时备份+替换 ----
	var sp: Control = (load("res://src/ui/SettingsPanel.gd") as GDScript).new()
	add_child(sp)
	await get_tree().process_frame
	_wipe(G.SAVE_PATH)
	_write(G.SAVE_PATH, _fixture_text("v3.json"))
	var before_text := _read(G.SAVE_PATH)
	var bad: Dictionary = sp.do_import_ex(_fixture_text("future.json"))
	_check(not bool(bad["ok"]), "面板导入未来版本应失败")
	_check(_read(G.SAVE_PATH) == before_text, "导入被拒时原存档必须一字不动")
	G.wallet = {"gold": 0, "expedition": 0, "soul": 0, "honor": 0}
	var good: Dictionary = sp.do_import_ex(_fixture_text("v2.json"))
	_check(bool(good["ok"]), "面板导入旧版本档应成功（%s）" % String(good["err"]))
	var after: Variant = JSON.parse_string(_read(G.SAVE_PATH))
	_check(after is Dictionary and int((after as Dictionary).get("version", -1)) == SaveData.CURRENT_VERSION,
		"导入后落盘内容应是当前版本 %d" % SaveData.CURRENT_VERSION)
	_check(int(((after as Dictionary).get("prog", {}) as Dictionary).get("level", 0)) == 3,
		"导入后应保留旧档里的等级")
	G.reload_save()
	_check(int(G.wallet.get("gold", 0)) == 5, "导入后内存应重读为 5，实为 %d" % int(G.wallet.get("gold", 0)))
	sp.queue_free()
	await get_tree().process_frame

	_wipe(G.SAVE_PATH)
	if _fails == 0:
		print("SAVE_OK all tests passed")
	else:
		print("SAVE_FAIL fails=%d" % _fails)


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t
