extends Node
func _ready() -> void:
	var n := 1000000
	var buf := PackedFloat32Array()
	buf.resize(n)
	var t0 := Time.get_ticks_usec()
	var ph := 0.0
	var inc := 440.0 / 32000.0
	for i in n:
		ph += inc
		if ph >= 1.0:
			ph -= 1.0
		buf[i] += (ph * 2.0 - 1.0) * 0.3 + sin(ph * TAU) * 0.2
	var t1 := Time.get_ticks_usec()
	print("1M samples (saw+sin): ", (t1 - t0) / 1000.0, " ms")
	var wt := PackedFloat32Array()
	wt.resize(2048)
	for i in 2048:
		wt[i] = sin(TAU * i / 2048.0)
	t0 = Time.get_ticks_usec()
	var p := 0.0
	for i in n:
		p += 28.16
		if p >= 2048.0:
			p -= 2048.0
		buf[i] += wt[int(p)] * 0.2
	t1 = Time.get_ticks_usec()
	print("1M samples (wavetable): ", (t1 - t0) / 1000.0, " ms")
	get_tree().quit()
