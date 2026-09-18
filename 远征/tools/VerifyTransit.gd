# VerifyTransit.gd —— 场景转场回归（场景模式：godot --headless --path . res://tools/VerifyTransit.tscn）
# 守：转场 API 就位（go / can_go / 遮罩懒创建）、所有场景路径可达（防打错字）、
#     忙碌防重入（连点两次不会切两次场景）、遮罩平时不吃输入，
#     以及"防回退"：src/ 下除白名单外不允许再出现直接 change_scene_to_file。
extends Node

const SCENES := [
	"res://src/main/Main.tscn",
	"res://src/ui/LoadScreen.tscn", "res://src/ui/Title.tscn", "res://src/ui/Login.tscn",
	"res://src/ui/CreateRole.tscn", "res://src/ui/Prologue.tscn", "res://src/ui/GameHome.tscn",
	"res://src/ui/StoryBeat.tscn",
	"res://src/city/CityScene.tscn", "res://src/run/RouteScene.tscn",
	"res://src/explore/MapScene.tscn", "res://src/battle/BattleScene.tscn",
]

## 允许直接 change_scene_to_file 的白名单（G 自身转场实现 + 战斗无人接管的兜底）
const ALLOW := ["src/autoload/G.gd", "src/battle/BattleScene.gd"]

var _fails := 0


func _ready() -> void:
	await _run()
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


func _run() -> void:
	# ---- A. 全部场景路径存在（转场打错字会死得很安静） ----
	var missing: Array = []
	for s in SCENES:
		if not ResourceLoader.exists(String(s)):
			missing.append(s)
	_check(missing.is_empty(), "场景路径不存在（转场会被拒）：%s" % str(missing))

	# ---- B. can_go 预检 ----
	for s in SCENES:
		_check(G.can_go(String(s)), "can_go 应放行存在路径：%s" % s)
	_check(not G.can_go("res://src/ui/NotExist.tscn"), "can_go 应拦住不存在的路径")

	# ---- C. 忙碌防重入（转场进行中不许再发一次） ----
	G._transit_busy = true
	_check(not G.can_go(SCENES[1]), "转场忙碌时 can_go 应返回 false")
	_check(G.transit_busy(), "transit_busy 应反映忙碌状态")
	G._transit_busy = false
	_check(G.can_go(SCENES[1]), "空闲后 can_go 应恢复放行")

	# ---- D. 遮罩：懒创建、压最上层、平时不吃输入、全透明 ----
	G._ensure_veil()
	await get_tree().process_frame
	var veil: ColorRect = G._veil
	_check(veil != null and is_instance_valid(veil), "遮罩应已创建")
	if veil != null:
		_check(veil.mouse_filter == Control.MOUSE_FILTER_IGNORE, "遮罩平时不应吃输入")
		_check(is_zero_approx(veil.modulate.a), "遮罩平时应全透明，实为 %.3f" % veil.modulate.a)
	_check(G._veil_layer != null and G._veil_layer.layer >= 120, "遮罩层应压在最上层（≥120）")

	# ---- E. 防回退：src/ 下不应再有绕过 G.go 的硬切（白名单除外） ----
	var offenders := _scan_hard_switches()
	_check(offenders.is_empty(),
		"这些文件仍在直接 change_scene_to_file（应改走 G.go；白名单：%s）：%s" % [str(ALLOW), str(offenders)])

	if _fails == 0:
		print("TRANSIT_OK all tests passed")
	else:
		print("TRANSIT_FAIL fails=%d" % _fails)


# ---------- 源码扫描（防回退守则） ----------
func _scan_hard_switches() -> Array:
	var out: Array = []
	_scan_dir("res://src", out)
	return out


func _scan_dir(path: String, out: Array) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := path.path_join(name)
		if d.current_is_dir():
			if name != "." and name != "..":
				_scan_dir(full, out)
		elif name.ends_with(".gd"):
			var rel := full.trim_prefix("res://")
			if not ALLOW.has(rel) and _uses_hard_switch(full):
				out.append(rel)
		name = d.get_next()
	d.list_dir_end()


func _uses_hard_switch(file_path: String) -> bool:
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return false   # 读不到（如导出后的二进制脚本）就跳过，不误报
	var txt := f.get_as_text()
	f.close()
	return txt.contains("change_scene_to_file")
