extends Node
## Bounded voices, cancellable transitions and real bus mute.
const DIR := "res://assets/audio/"
const EXTS := [".wav", ".ogg", ".mp3"]
const FADE := 0.5
const VOL_MIN_DB := -80.0
const SFX_POOL := 16
const PITCH_JITTER := 0.015
const SFX_NAMES := ["ui_click","ui_open","ui_close","ui_page","ui_confirm","ui_cancel","ui_locked","coin","reward","level_up","hit_light","hit_heavy","hit_crit","skill_cast","boss_warn","low_hp","victory","defeat","pickup","altar","mount_toggle","mount_hoof","hoof_stone","hoof_snow","hoof_sand","hoof_wood","cast_blade","cast_bow","cast_frost","cast_radiant","hit_blade","hit_arrow","hit_frost","hit_radiant"]
const LIMITS := {"UI":2,"Combat":5,"Rewards":2,"Alerts":2,"Movement":1}
var _ambient: AudioStreamPlayer
var _ambient_name := ""
var _bgm: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_i := 0
var _last_pitch := 1.0
var _bgm_name := ""
var _fade: Tween
var _cache := {}
var _save_timer: Timer
var _generation := 0
var _suspended := false
var _last_events := {}
var _semantic_ui_at := -1000
var event_log: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in ["Music","UI","Combat","Rewards","Alerts","Movement","Ambience"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index,bus_name)
			AudioServer.set_bus_send(index,"Master")
	if not AudioServer.has_meta("expedition_limiter"):
		var limiter := AudioEffectLimiter.new()
		limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(0,limiter)
		AudioServer.set_meta("expedition_limiter",true)
	_bgm = AudioStreamPlayer.new()
	_bgm.name = "Bgm"
	_bgm.bus = "Music"
	add_child(_bgm)
	for i in SFX_POOL:
		var voice := AudioStreamPlayer.new()
		voice.name = "Sfx%d" % i
		add_child(voice)
		_sfx_pool.append(voice)
	_ambient = AudioStreamPlayer.new()
	_ambient.name = "RegionAmbience"
	_ambient.bus = "Ambience"
	add_child(_ambient)
	_apply_vol()

func _cancel_fade() -> void:
	_generation += 1
	if _fade != null and _fade.is_valid(): _fade.kill()
	_fade = null

func play_bgm(name: String) -> void:
	if name != "bgm_map": stop_ambience()
	if name.is_empty():
		stop_bgm()
		return
	if name == _bgm_name and (_bgm.playing or (_fade != null and _fade.is_valid())): return
	_cancel_fade()
	_bgm_name = name
	var stream := _stream(name)
	if stream == null:
		_bgm.stop()
		return
	var ticket := _generation
	if _bgm.playing and not _suspended and not muted() and bgm_vol() > 0:
		_fade = create_tween()
		_fade.tween_property(_bgm,"volume_db",VOL_MIN_DB,FADE*.5)
		_fade.tween_callback(func():
			if ticket != _generation: return
			_bgm.stream = stream
			_bgm.play()
			_bgm.stream_paused = _suspended)
		_fade.tween_property(_bgm,"volume_db",_bgm_db(),FADE*.5)
	else:
		_bgm.stream = stream
		_bgm.volume_db = _bgm_db()
		_bgm.play()
		_bgm.stream_paused = _suspended

func stop_bgm() -> void:
	_cancel_fade()
	stop_ambience()
	_bgm_name = ""
	_bgm.stop()

func category(name: String) -> String:
	if name in ["victory","defeat","boss_warn","low_hp"]: return "Alerts"
	if name.begins_with("ui_"): return "UI"
	if name.begins_with("hit_") or name.begins_with("cast_") or name == "skill_cast": return "Combat"
	if name.begins_with("hoof_") or name.begins_with("mount_"): return "Movement"
	return "Rewards"

func priority(name: String) -> int:
	if name in ["victory","defeat"]: return 100
	return int({"Alerts":90,"Rewards":60,"Combat":40,"UI":20,"Movement":10}[category(name)])

func sfx(name: String,jitter := PITCH_JITTER) -> void:
	if muted() or sfx_vol() <= 0 or _suspended: return
	if name == "ui_click":
		_deferred_click.call_deferred(jitter)
		return
	if name.begins_with("ui_"): _semantic_ui_at = Time.get_ticks_msec()
	_play_sfx(name,jitter)

func _deferred_click(jitter: float) -> void:
	if Time.get_ticks_msec()-_semantic_ui_at > 90: _play_sfx("ui_click",jitter)

func _play_sfx(name: String,jitter: float) -> void:
	if muted() or sfx_vol() <= 0 or _suspended: return
	var now := Time.get_ticks_msec()
	var kind := category(name)
	var cooldown := 65 if kind == "Combat" else 80 if kind == "UI" else 140 if kind == "Rewards" else 90
	if now-int(_last_events.get(name,-10000)) < cooldown: return
	var stream := _stream(name)
	if stream == null: return
	var active := 0
	var voice: AudioStreamPlayer = null
	for offset in _sfx_pool.size():
		var candidate := _sfx_pool[(_sfx_i+offset)%_sfx_pool.size()]
		if candidate.playing and candidate.get_meta("category","") == kind: active += 1
		if not candidate.playing and voice == null: voice = candidate
	if active >= int(LIMITS[kind]): return
	if voice == null:
		var weakest := priority(name)
		for candidate in _sfx_pool:
			var rank := int(candidate.get_meta("priority",0))
			if rank < weakest:
				weakest = rank
				voice = candidate
	if voice == null: return
	voice.stop()
	voice.bus = kind
	voice.set_meta("category",kind)
	voice.set_meta("priority",priority(name))
	voice.set_meta("sound",name)
	voice.stream = stream
	voice.volume_db = _sfx_db()+_voice_gain(kind)
	voice.pitch_scale = 1.0+randf_range(-jitter,jitter)
	_last_pitch = voice.pitch_scale
	_last_events[name] = now
	_sfx_i = (_sfx_pool.find(voice)+1)%_sfx_pool.size()
	voice.play()
	if OS.is_debug_build():
		event_log.append({"name":name,"category":kind,"time_ms":now})
		if event_log.size() > 128: event_log.pop_front()

func _voice_gain(kind: String) -> float:
	return float({"UI":-9.0,"Combat":-7.0,"Rewards":-7.0,"Alerts":-6.0,"Movement":-9.0}.get(kind,-8.0))

func hoof(surface: String) -> void:
	sfx("hoof_"+surface if surface in ["stone","snow","sand","wood"] else "mount_hoof",.025)

func cast(role_id: String) -> void:
	sfx(String({"zs":"cast_blade","ck":"cast_bow","fs":"cast_frost","fz":"cast_radiant"}.get(role_id,"skill_cast")),.01)

func hit(role_id: String) -> void:
	sfx(String({"zs":"hit_blade","ck":"hit_arrow","fs":"hit_frost","fz":"hit_radiant"}.get(role_id,"hit_light")),.025)

func play_ambience(region: String) -> void:
	if _ambient == null: return
	var name := "ambient_"+region
	if _ambient_name == name and _ambient.playing: return
	var source := _stream(name) as AudioStreamWAV
	if source == null:
		stop_ambience()
		return
	var stream := source.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
	_ambient_name = name
	_ambient.stream = stream
	_ambient.volume_db = _ambient_db()
	_ambient.play()
	_ambient.stream_paused = _suspended

func _ambient_db() -> float:
	return VOL_MIN_DB if muted() or sfx_vol() <= 0 else linear_to_db(sfx_vol()*.075)

func stop_ambience() -> void:
	_ambient_name = ""
	if _ambient != null: _ambient.stop()

func current_ambience() -> String: return _ambient_name

func set_bgm_vol(v: float) -> void:
	_set_audio_setting("bgm",clampf(v,0,1))
	_queue_save()
	var name := _bgm_name
	var pending := _fade != null and _fade.is_valid()
	_cancel_fade()
	if pending and not name.is_empty():
		_bgm.stream = _stream(name)
		if _bgm.stream != null: _bgm.play()
	_apply_vol()

func set_sfx_vol(v: float) -> void:
	_set_audio_setting("sfx",clampf(v,0,1))
	_queue_save()
	_apply_vol()

func set_mute(on: bool) -> void:
	_set_audio_setting("mute",on)
	_queue_save()
	_apply_vol()

func _queue_save() -> void:
	if _save_timer == null:
		_save_timer = Timer.new()
		_save_timer.one_shot = true
		_save_timer.wait_time = .5
		_save_timer.timeout.connect(_save_audio_settings)
		add_child(_save_timer)
	_save_timer.start()

func bgm_vol() -> float: return float(_audio_settings().get("bgm",.7))
func sfx_vol() -> float: return float(_audio_settings().get("sfx",.8))
func muted() -> bool: return bool(_audio_settings().get("mute",false))
func _muted() -> bool: return muted()
func _game_state() -> Node: return get_node_or_null("/root/G")

func _audio_settings() -> Dictionary:
	var state := _game_state()
	if state != null and state.get("audio") is Dictionary: return state.get("audio")
	return {"bgm":.7,"sfx":.8,"mute":false}

func _set_audio_setting(key: String,value: Variant) -> void:
	var settings := _audio_settings()
	settings[key] = value
	var state := _game_state()
	if state != null: state.set("audio",settings)

func _save_audio_settings() -> void:
	var state := _game_state()
	if state != null: state.call("save_game")

func _bgm_db() -> float: return VOL_MIN_DB if muted() or bgm_vol() <= 0 else linear_to_db(bgm_vol())-9.0
func _sfx_db() -> float: return VOL_MIN_DB if muted() or sfx_vol() <= 0 else linear_to_db(sfx_vol())

func _apply_vol() -> void:
	for bus_name in ["Music","UI","Combat","Rewards","Alerts","Movement","Ambience"]:
		var index := AudioServer.get_bus_index(bus_name)
		if index >= 0: AudioServer.set_bus_mute(index,muted() or _suspended or (bgm_vol() <= 0 if bus_name == "Music" else sfx_vol() <= 0))
	if _ambient != null:
		_ambient.volume_db = _ambient_db()
		_ambient.stream_paused = _suspended
	if _bgm != null:
		if _fade == null or not _fade.is_valid(): _bgm.volume_db = _bgm_db()
		_bgm.stream_paused = _suspended
	for voice in _sfx_pool:
		if muted() or sfx_vol() <= 0 or _suspended: voice.stop()
		elif voice.playing: voice.volume_db = _sfx_db()+_voice_gain(voice.get_meta("category","UI"))

func set_suspended(on: bool) -> void:
	_suspended = on
	if _fade != null and _fade.is_valid():
		if on: _fade.pause()
		else: _fade.play()
	_apply_vol()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT: set_suspended(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN: set_suspended(false)

func has_no_stream() -> bool: return _stream("bgm_home") == null and _stream("ui_click") == null
func preload_all() -> void:
	for name in SFX_NAMES: _stream(name)
func sfx_path(name: String) -> String:
	for ext in EXTS:
		var path: String = DIR+name+String(ext)
		if ResourceLoader.exists(path): return path
	return ""
func sfx_player_count() -> int: return _sfx_pool.size()
func sfx_slot() -> int: return _sfx_i
func sfx_playing_count() -> int:
	var count := 0
	for voice in _sfx_pool:
		if voice.playing: count += 1
	return count
func last_pitch() -> float: return _last_pitch
func current_bgm() -> String: return _bgm_name
func _stream(name: String) -> AudioStream:
	if _cache.has(name): return _cache[name]
	var path := sfx_path(name)
	if path.is_empty(): return null
	var stream := load(path) as AudioStream
	if stream is AudioStreamWAV and name.begins_with("bgm_"):
		stream = stream.duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
	if stream != null: _cache[name] = stream
	return stream
