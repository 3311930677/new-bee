extends SceneTree
## Run this external script with --main-pack against the actual exported PCK.
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var game := root.get_node("G")
	game.set("SAVE_PATH","user://export_probe_isolated.json")
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/resource_manifest.json"))
	var failures: Array[String]=[]
	var count := 0
	for key in manifest:
		var id:=String(key).trim_suffix(".png")
		var texture: Texture2D=game.call("res_tex",id)
		if texture==null: failures.append(id)
		count+=1
		if count%24==0: game.get("_tex_cache").clear()
	var audio:=root.get_node("Audio")
	print("EXPORTED_AUDIO_NAMES ",audio.get("SFX_NAMES"))
	for name in audio.get("SFX_NAMES"):
		if String(audio.call("sfx_path",name)).is_empty():failures.append("audio:"+name)
	for name in ["cast_blade","cast_bow","cast_frost","cast_radiant","hit_blade","hit_arrow","hit_frost","hit_radiant"]:
		if not ResourceLoader.exists("res://assets/audio/"+name+".wav"):failures.append("expected:"+name)
	print("EXPORTED_VISUALS_OK count=%d failures=%s"%[count,str(failures)])
	quit(0 if failures.is_empty() else 1)
