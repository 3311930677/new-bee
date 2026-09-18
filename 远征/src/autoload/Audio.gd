# Audio.gd —— 音频总管（BGM 循环 + UI 音效）
# 素材放 assets/audio/，文件名见该目录 README（全部为 CC0 / 公共领域，可商用免署名）。
# 找不到文件时静默降级：不报错、不阻塞，先把框架跑起来，素材后补。
# 音量与静音存进存档（G.audio），设置面板里调。
extends Node

const DIR := "res://assets/audio/"
const EXTS := [".ogg", ".wav", ".mp3"]
const FADE := 0.5          # 换曲淡入淡出秒数
const VOL_MIN_DB := -45.0  # 音量 0% 时的静音替代（比 -80 更自然）
const SFX_POOL := 8        # 音效播放器池：连点/连击不互相掐断
const PITCH_JITTER := 0.03 # 每次播放微调音高（±3%）：同一音反复响也不"机械复读"

## 全量音效名（tools/make_sfx.py 合成；加载页按此预热，VerifyAudio 按此守）
const SFX_NAMES := [
	"ui_click", "ui_open", "ui_close", "ui_page",
	"ui_confirm", "ui_cancel", "ui_locked",
	"coin", "reward", "level_up",
	"hit_light", "hit_heavy", "hit_crit", "skill_cast",
	"boss_warn", "low_hp", "victory", "defeat",
]

var _bgm: AudioStreamPlayer = null
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_i := 0
var _last_pitch := 1.0
var _bgm_name := ""
var _fade: Tween = null
var _cache := {}
var _save_timer: Timer = null


func _ready() -> void:
	_bgm = AudioStreamPlayer.new()
	_bgm.name = "Bgm"
	add_child(_bgm)
	# 音效池：单一播放器在快速连点/连击时会把上一个音掐掉（听感"断"）；
	# 轮转 8 个互不干扰，每个音再叠 ±3% 随机音高防机械复读
	for i in SFX_POOL:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		add_child(p)
		_sfx_pool.append(p)
	_apply_vol()


# ---------- 播放 ----------
## 播放背景音乐（同名不重播）。name 如 "bgm_home"
func play_bgm(name: String) -> void:
	if name == "" or name == _bgm_name:
		return
	var stream := _stream(name)
	_bgm_name = name
	if stream == null:
		_bgm.stop()
		return
	_bgm.stream = stream
	if _bgm.playing and _bgm.volume_db > VOL_MIN_DB:
		# 换曲：先淡出再淡入，避免硬切
		if _fade != null and _fade.is_valid():
			_fade.kill()
		_fade = create_tween()
		_fade.tween_property(_bgm, "volume_db", VOL_MIN_DB, FADE * 0.5)
		_fade.tween_callback(func():
			_bgm.stream = stream
			_bgm.play())
		_fade.tween_property(_bgm, "volume_db", _bgm_db(), FADE * 0.5)
	else:
		_bgm.volume_db = _bgm_db()
		_bgm.play()


func stop_bgm() -> void:
	_bgm_name = ""
	_bgm.stop()


## 播放一次性音效（UI 点击 / 战斗反馈）。name 如 "ui_click"
## jitter：本次音高扰动幅度（默认 ±3%）
func sfx(name: String, jitter := PITCH_JITTER) -> void:
	var stream := _stream(name)
	if stream == null or _muted() or _sfx_pool.is_empty():
		return
	var p := _sfx_pool[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx_pool.size()
	p.stream = stream
	p.volume_db = _sfx_db()
	p.pitch_scale = 1.0 + randf_range(-jitter, jitter)
	_last_pitch = p.pitch_scale
	p.play()


# ---------- 音量（设置面板调） ----------
func set_bgm_vol(v: float) -> void:
	_set_audio_setting("bgm", clampf(v, 0.0, 1.0))
	_queue_save()
	_apply_vol()


func set_sfx_vol(v: float) -> void:
	_set_audio_setting("sfx", clampf(v, 0.0, 1.0))
	_queue_save()
	_apply_vol()


func set_mute(on: bool) -> void:
	_set_audio_setting("mute", on)
	_queue_save()
	_apply_vol()


## 拖滑条会连着触发，攒一下再落盘（0.5s 无操作才写档）
func _queue_save() -> void:
	if _save_timer == null:
		_save_timer = Timer.new()
		_save_timer.one_shot = true
		_save_timer.wait_time = 0.5
		_save_timer.timeout.connect(_save_audio_settings)
		add_child(_save_timer)
	_save_timer.start()


func bgm_vol() -> float:
	return float(_audio_settings().get("bgm", 0.7))


func sfx_vol() -> float:
	return float(_audio_settings().get("sfx", 0.8))


func muted() -> bool:
	return bool(_audio_settings().get("mute", false))


# Audio 与 G 都是自动加载器，不能在编译期互相引用；运行时再取 G 节点可避免循环依赖。
func _game_state() -> Node:
	return get_node_or_null("/root/G")


func _audio_settings() -> Dictionary:
	var game_state := _game_state()
	if game_state != null and game_state.get("audio") is Dictionary:
		return game_state.get("audio") as Dictionary
	return {"bgm": 0.7, "sfx": 0.8, "mute": false}


func _set_audio_setting(key: String, value: Variant) -> void:
	var settings := _audio_settings()
	settings[key] = value
	var game_state := _game_state()
	if game_state != null:
		game_state.set("audio", settings)


func _save_audio_settings() -> void:
	var game_state := _game_state()
	if game_state != null:
		game_state.call("save_game")


# ---------- 内部 ----------
func _muted() -> bool:
	return muted()


func _bgm_db() -> float:
	if muted() or bgm_vol() <= 0.0:
		return VOL_MIN_DB
	return linear_to_db(bgm_vol())


func _sfx_db() -> float:
	if muted() or sfx_vol() <= 0.0:
		return VOL_MIN_DB
	return linear_to_db(sfx_vol())


func _apply_vol() -> void:
	if _bgm != null and _bgm.playing:
		_bgm.volume_db = _bgm_db()
	for p in _sfx_pool:
		if p.playing:
			p.volume_db = _sfx_db()


## 整套素材都还没放时返回 true（设置面板据此提示一句，而不是让人以为坏了）
func has_no_stream() -> bool:
	return _stream("bgm_home") == null and _stream("ui_click") == null


# ---------- 预热与自检（加载页 / VerifyAudio） ----------
## 把所有音效读进缓存（文件都很小，一次性热掉；加载页调用）
func preload_all() -> void:
	for n in SFX_NAMES:
		_stream(n)


## 音效解析到的路径（加载页按此逐个入队预热；找不到返回空串）
func sfx_path(name: String) -> String:
	for e in EXTS:
		var path: String = DIR + name + String(e)
		if ResourceLoader.exists(path):
			return path
	return ""


func sfx_player_count() -> int:
	return _sfx_pool.size()


## 下一个将被使用的池位（VerifyAudio 用它验证"逐次轮转"）
func sfx_slot() -> int:
	return _sfx_i


func sfx_playing_count() -> int:
	var c := 0
	for p in _sfx_pool:
		if p.playing:
			c += 1
	return c


func last_pitch() -> float:
	return _last_pitch


func current_bgm() -> String:
	return _bgm_name


## 按名找音频资源：先查缓存，再依次试 .ogg/.wav/.mp3；都没有返回 null
func _stream(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	for e in EXTS:
		var path: String = DIR + name + String(e)
		if ResourceLoader.exists(path):
			var s := load(path) as AudioStream
			_cache[name] = s
			return s
	_cache[name] = null
	return null
