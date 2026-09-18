# VerifyAudio.gd —— 音频层回归（场景模式：godot --headless --path . res://tools/VerifyAudio.tscn）
# 守：18 个音效素材全部可解析（缺一个就红）、音效池逐次轮转 + 随机音高（防机械复读）、
#     静音早退、BGM 同名不重播 / 换曲 / 缺曲静默降级、音量设置 API。
# 音效由 tools/make_sfx.py 程序合成；新增/重生成后要跑 godot --headless --path . --import。
extends Node

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "user://save_verify_audio.json"
	await _run()
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


func _run() -> void:
	# ---- A. 音效素材完整性（程序合成，不允许缺；缺了先跑 tools/make_sfx.py） ----
	var missing: Array = []
	for n in Audio.SFX_NAMES:
		if Audio.sfx_path(String(n)) == "":
			missing.append(String(n))
	_check(missing.is_empty(), "音效素材缺失：%s" % str(missing))
	_check(Audio.SFX_NAMES.size() >= 17, "音效清单不应少于 17 个，实为 %d" % Audio.SFX_NAMES.size())
	_check(Audio.sfx_path("ui_click").begins_with("res://assets/audio/ui_click"),
		"sfx_path 应指向 assets/audio，实为 %s" % Audio.sfx_path("ui_click"))

	# ---- B. BGM（占位也要在；缺了会整段静默） ----
	var bgm_missing: Array = []
	for b in ["bgm_home", "bgm_city", "bgm_title", "bgm_route", "bgm_map", "bgm_battle"]:
		if not ResourceLoader.exists("res://assets/audio/%s.ogg" % b):
			bgm_missing.append(b)
	_check(bgm_missing.is_empty(), "BGM 缺失：%s" % str(bgm_missing))

	# ---- C. 音效池：连点不掐断（逐次轮转 + 至少能播） ----
	_check(Audio.sfx_player_count() >= 4, "音效池至少 4 个播放器，实为 %d" % Audio.sfx_player_count())
	for i in 12:
		Audio.sfx("ui_click")
	_check(Audio.sfx_playing_count() >= 1, "连发 12 次后应有播放器在播，实为 %d" % Audio.sfx_playing_count())
	var s0 := Audio.sfx_slot()
	Audio.sfx("ui_click")
	var s1 := Audio.sfx_slot()
	Audio.sfx("ui_click")
	var s2 := Audio.sfx_slot()
	var n_pool := Audio.sfx_player_count()
	_check((s0 + 1) % n_pool == s1 and (s1 + 1) % n_pool == s2,
		"音效池应按次轮转（%d → %d → %d）" % [s0, s1, s2])

	# ---- D. 随机音高（同一音反复响也不机械复读） ----
	var pitches := {}
	for i in 20:
		Audio.sfx("ui_click")
		pitches[snappedf(Audio.last_pitch(), 0.0001)] = true
	_check(pitches.size() >= 5, "20 次播放的音高应有多样性，实为 %d 种" % pitches.size())
	var last := Audio.last_pitch()
	_check(last > 0.9 and last < 1.1, "音高扰动应在 ±10％ 内，实为 %.4f" % last)

	# ---- E. 静音早退（静音时 sfx 直接返回，不动播放状态） ----
	Audio.set_mute(true)
	var pitch_before := Audio.last_pitch()
	Audio.sfx("ui_click")
	_check(is_equal_approx(Audio.last_pitch(), pitch_before), "静音时 sfx 应直接返回")
	Audio.set_mute(false)

	# ---- F. BGM 状态机（同名不重播 / 换曲 / 缺曲静默降级 / 停止） ----
	Audio.play_bgm("bgm_home")
	_check(Audio.current_bgm() == "bgm_home", "play_bgm 后状态应为 bgm_home")
	Audio.play_bgm("bgm_home")
	_check(Audio.current_bgm() == "bgm_home", "同名重播不应清状态")
	Audio.play_bgm("bgm_city")
	_check(Audio.current_bgm() == "bgm_city", "换曲后状态应更新")
	Audio.play_bgm("bgm_not_exist")
	_check(Audio.current_bgm() == "bgm_not_exist", "缺曲应静默降级但记录状态")
	Audio.stop_bgm()
	_check(Audio.current_bgm() == "", "stop_bgm 后状态应为空")

	# ---- G. 音量设置（内存态；落盘由 Audio 的防抖计时器负责） ----
	Audio.set_bgm_vol(0.42)
	Audio.set_sfx_vol(0.31)
	_check(is_equal_approx(Audio.bgm_vol(), 0.42), "音乐音量设置未生效")
	_check(is_equal_approx(Audio.sfx_vol(), 0.31), "音效音量设置未生效")
	Audio.set_bgm_vol(0.7)
	Audio.set_sfx_vol(0.8)

	# ---- H. 预载与整体状态 ----
	Audio.preload_all()   # 不崩即过
	_check(not Audio.has_no_stream(), "素材齐全时 has_no_stream 应为 false")

	if _fails == 0:
		print("AUDIO_OK all tests passed")
	else:
		print("AUDIO_FAIL fails=%d" % _fails)
