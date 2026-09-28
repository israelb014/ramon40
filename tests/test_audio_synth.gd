extends GutTest
## Procedural audio sanity: engine loops are seamless and sized to whole engine cycles,
## streams are valid 16-bit PCM, and the music loop has the expected length.


## The loop must be continuous across the wrap: the curvature (second difference) at
## the seam should be no larger than the curvature found right around it.
func _seam_ok(b: PackedFloat32Array, _cycle_samples: int) -> bool:
	var n := b.size()
	var seam := absf(b[1] - 2.0 * b[0] + b[n - 1])
	var near := 0.0
	for i in range(1, 60):
		near = maxf(near, absf(b[i + 1] - 2.0 * b[i] + b[i - 1]))
		near = maxf(near, absf(b[n - i] - 2.0 * b[n - i - 1] + b[n - i - 2]))
	return seam <= near * 1.5 + 0.01


func test_engine_loops_are_seamless():
	for layout in ["inline4", "triple", "single", "twin"]:
		for on in [true, false]:
			var b := EngineSynth.bake(layout, 6000.0, on, 0.5)
			assert_gt(b.size(), 8000, layout)
			assert_true(_seam_ok(b, int(round(120.0 / 6000.0 * Synth.RATE))), "%s seam (%s)" % [layout, on])


func test_engine_loop_length_matches_cycles():
	var rpm := 6000.0
	var b := EngineSynth.bake("inline4", rpm, true, 0.5)
	var cycle_samples := 120.0 / rpm * Synth.RATE
	var cycles := b.size() / cycle_samples
	assert_almost_eq(cycles, roundf(cycles), 0.05)


func test_stream_conversion():
	var b := Synth.tone(0.1, 440.0, "sine", 0.5)
	var s := Synth.to_stream(b, true)
	assert_eq(s.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(s.data.size(), b.size() * 2)
	assert_eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(s.loop_end, b.size())


func test_music_loop_length():
	var lr := MusicSynth.generate()
	var expected := 60.0 / MusicSynth.BPM * 4.0 * MusicSynth.BARS * Synth.RATE
	assert_almost_eq(float(lr[0].size()), expected, 2.0)
	assert_eq(lr[0].size(), lr[1].size())
	var peak := 0.0
	for v in lr[0]:
		peak = maxf(peak, absf(v))
	assert_between(peak, 0.5, 1.0)


func test_ui_sounds_exist():
	for id in ["move", "tick", "click", "back", "confirm", "error", "count", "go", "lap", "finish"]:
		assert_gt(SfxSynth.ui(id).size(), 100, id)
