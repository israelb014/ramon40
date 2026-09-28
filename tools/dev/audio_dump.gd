extends Node
func _ready() -> void:
	var out := "/tmp/audio"
	DirAccess.make_dir_recursive_absolute(out)
	var t0 := Time.get_ticks_msec()
	var lr := MusicSynth.generate()
	var t1 := Time.get_ticks_msec()
	print("music ms ", t1 - t0, " samples ", lr[0].size())
	Synth.to_stream(lr[0], true, Synth.RATE, lr[1]).save_to_wav(out + "/music.wav")
	t0 = Time.get_ticks_msec()
	for bike_id in GameData.BIKE_ORDER:
		var spec: Dictionary = GameData.BIKES[bike_id]
		var rpms := EngineSynth.layer_rpms(spec)
		for i in 3:
			var on := EngineSynth.bake(spec["engine"], rpms[i], true)
			var off := EngineSynth.bake(spec["engine"], rpms[i], false)
			Synth.to_stream(on, true).save_to_wav("%s/%s_on_%d.wav" % [out, bike_id, i])
			Synth.to_stream(off, true).save_to_wav("%s/%s_off_%d.wav" % [out, bike_id, i])
	t1 = Time.get_ticks_msec()
	print("engines ms ", t1 - t0)
	t0 = Time.get_ticks_msec()
	for id in ["wind", "screech", "gravel", "crash", "impact"]:
		var b: PackedFloat32Array = {"wind": SfxSynth.wind(), "screech": SfxSynth.screech(), "gravel": SfxSynth.gravel(), "crash": SfxSynth.crash(), "impact": SfxSynth.impact()}[id]
		Synth.to_stream(b).save_to_wav(out + "/" + id + ".wav")
	for st in ["ramon", "deadsea", "jerusalem"]:
		Synth.to_stream(SfxSynth.ambience(st)).save_to_wav(out + "/amb_" + st + ".wav")
	for u in ["click", "confirm", "go", "finish", "lap"]:
		Synth.to_stream(SfxSynth.ui(u)).save_to_wav(out + "/ui_" + u + ".wav")
	print("sfx ms ", Time.get_ticks_msec() - t0)
	get_tree().quit()
