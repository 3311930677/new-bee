extends Node
var _fails := 0
var _checks := 0
func _check(ok: bool, words: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		push_error("AUDIO_FAIL: "+words)
func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_audio.json"
	G._init_state_defaults()
	Audio.set_suspended(false)
	Audio.set_mute(false)
	Audio.set_sfx_vol(.8)
	Audio.set_bgm_vol(.7)
	for name in Audio.SFX_NAMES:
		_check(not Audio.sfx_path(name).is_empty(),"effect exists "+name)
	for name in ["bgm_title","bgm_home","bgm_city","bgm_route","bgm_map","bgm_battle"]:
		var stream := Audio._stream(name) as AudioStreamWAV
		_check(stream != null and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,"original loop "+name)
		if stream != null: _check(stream.get_length()>30,"music phrase duration "+name)
	Audio.stop_bgm()
	Audio.play_bgm("bgm_home")
	var home := Audio._bgm.stream
	var at := Audio._bgm.get_playback_position()
	Audio.play_bgm("bgm_home")
	_check(Audio._bgm.stream == home and Audio._bgm.get_playback_position()>=at,"same track does not restart")
	Audio.play_bgm("bgm_city")
	_check(Audio._bgm.stream == home,"old stream survives until fade-out completes")
	Audio.play_bgm("bgm_map")
	await get_tree().create_timer(.65).timeout
	_check(Audio._bgm.stream == Audio._stream("bgm_map") and Audio.current_bgm()=="bgm_map","rapid replacement selects only latest track")
	Audio.play_bgm("bgm_battle")
	Audio.stop_bgm()
	await get_tree().create_timer(.65).timeout
	_check(not Audio._bgm.playing and Audio.current_bgm().is_empty(),"stop cancels all delayed callbacks")
	Audio.play_bgm("bgm_home")
	Audio.play_bgm("bgm_city")
	Audio.set_bgm_vol(.23)
	await get_tree().create_timer(.65).timeout
	_check(is_equal_approx(Audio._bgm.volume_db,linear_to_db(.23)-9),"slider not overwritten by stale fade")
	_check(Audio._bgm.stream == Audio._stream("bgm_city"),"slider preserves requested track")
	Audio.set_bgm_vol(0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),"music zero is actual bus mute")
	Audio.set_bgm_vol(.7)
	Audio._last_events.clear()
	Audio.sfx("reward")
	_check(Audio.sfx_playing_count()>0,"reward plays before mute")
	Audio.set_mute(true)
	_check(Audio.sfx_playing_count()==0,"already playing effects stop on mute")
	for bus in ["Music","UI","Combat","Rewards","Alerts","Movement","Ambience"]:
		_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(bus)),"all categories mute "+bus)
	Audio.set_mute(false)
	Audio.set_sfx_vol(0)
	Audio.sfx("hit_heavy")
	_check(Audio.sfx_playing_count()==0,"sfx zero suppresses new voices")
	Audio.set_sfx_vol(.8)
	Audio._last_events.clear()
	Audio.event_log.clear()
	for i in 30: Audio.sfx("hit_light")
	_check(Audio.event_log.size()==1,"same-event burst coalesces")
	Audio.sfx("victory",0)
	var result_voice: AudioStreamPlayer
	for voice in Audio._sfx_pool:
		if voice.get_meta("sound","")=="victory": result_voice=voice
	for i in 30:
		for sound in ["hit_light","hit_heavy","hit_crit","skill_cast","coin"]: Audio.sfx(sound)
	_check(result_voice != null and result_voice.playing and result_voice.get_meta("sound","")=="victory","combat burst cannot steal result")
	Audio._last_events.clear()
	Audio.event_log.clear()
	Audio.sfx("ui_click")
	Audio.sfx("ui_open")
	await get_tree().process_frame
	_check(Audio.event_log.filter(func(row):return row.name=="ui_click").is_empty(),"semantic UI sound replaces generic click")
	Audio.set_suspended(true)
	_check(Audio._bgm.stream_paused and Audio.sfx_playing_count()==0,"focus loss pauses music and clears transients")
	Audio.set_suspended(false)
	_check(not Audio._bgm.stream_paused,"resume unpauses existing stream")
	for region in ["forest","snow","volcano","tomb","desert","glacier","abyss","castle","port","mine"]:
		Audio.play_ambience(region)
		_check(Audio.current_ambience()=="ambient_"+region,"region ambience "+region)
	Audio.play_bgm("bgm_battle")
	_check(Audio.current_ambience().is_empty(),"battle stops ambience")
	Audio.play_ambience("missing_region")
	_check(Audio.current_ambience().is_empty(),"missing region clears ambience")
	_check(_scan_autoload_cycle().is_empty(),"no compile-time autoload cycle")
	Audio.stop_bgm()
	print("AUDIO_OK checks=%d fails=%d" % [_checks,_fails])
	await get_tree().process_frame
	get_tree().quit(0 if _fails==0 else 1)

func _scan_autoload_cycle() -> Array:
	var out: Array = []
	_scan_compile_refs("res://src/autoload/Audio.gd", "G", out)
	_scan_compile_refs("res://src/autoload/G.gd", "Audio", out)
	return out


func _scan_compile_refs(path: String, other: String, out: Array) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return   # 读不到（如导出后的二进制脚本）就跳过，不误报
	var re := RegEx.new()
	# 形如 `G.` / `Audio.` 的成员访问；前面若是标识符或 `/root/` 的一部分则不算（那是运行时常量串）
	re.compile("(^|[^A-Za-z0-9_./\"])%s\\.[A-Za-z_]" % other)
	var ln := 0
	while not f.eof_reached():
		ln += 1
		var line := f.get_line()
		if line.strip_edges().begins_with("#"):
			continue   # 注释里提对方不算
		if re.search(line) != null:
			out.append("%s:%d" % [path, ln])
	f.close()
