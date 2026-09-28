class_name Synth
extends RefCounted
## Offline sound synthesis helpers. Everything works on PackedFloat32Array buffers in the
## range [-1, 1] and converts to 16-bit AudioStreamWAV at the end. Thread-safe.

const RATE := 32000


static func buffer(seconds: float, rate := RATE) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * rate))
	return b


## Converts float samples to a 16-bit WAV stream. `right` makes it stereo.
static func to_stream(left: PackedFloat32Array, loop := false, rate := RATE, right := PackedFloat32Array()) -> AudioStreamWAV:
	var stereo := right.size() == left.size() and right.size() > 0
	var n := left.size()
	var bytes := PackedByteArray()
	bytes.resize(n * (4 if stereo else 2))
	if stereo:
		for i in n:
			bytes.encode_s16(i * 4, int(clampf(left[i], -1.0, 1.0) * 32767.0))
			bytes.encode_s16(i * 4 + 2, int(clampf(right[i], -1.0, 1.0) * 32767.0))
	else:
		for i in n:
			bytes.encode_s16(i * 2, int(clampf(left[i], -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = stereo
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = n
	return s


static func normalize(b: PackedFloat32Array, peak := 0.9) -> void:
	var m := 0.0001
	for v in b:
		m = maxf(m, absf(v))
	var k := peak / m
	for i in b.size():
		b[i] *= k


## One-pole lowpass in place. `cutoff` in Hz.
static func lowpass(b: PackedFloat32Array, cutoff: float, rate := RATE) -> void:
	var a := 1.0 - exp(-TAU * cutoff / rate)
	var y := 0.0
	for i in b.size():
		y += a * (b[i] - y)
		b[i] = y


## One-pole highpass in place.
static func highpass(b: PackedFloat32Array, cutoff: float, rate := RATE) -> void:
	var a := 1.0 - exp(-TAU * cutoff / rate)
	var y := 0.0
	for i in b.size():
		y += a * (b[i] - y)
		b[i] = b[i] - y


## Two-pole resonant band-pass (state variable filter) in place.
static func bandpass(b: PackedFloat32Array, center: float, q: float, rate := RATE) -> void:
	var f := 2.0 * sin(PI * minf(center, rate * 0.24) / rate)
	var damp := 1.0 / maxf(q, 0.5)
	var low := 0.0
	var band := 0.0
	for i in b.size():
		var high := b[i] - low - damp * band
		band += f * high
		low += f * band
		b[i] = band


static func white(b: PackedFloat32Array, amp: float, seed_value := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in b.size():
		b[i] += rng.randf_range(-amp, amp)


## Brown-ish noise (integrated white noise with leak).
static func brown(b: PackedFloat32Array, amp: float, seed_value := 2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var y := 0.0
	for i in b.size():
		y = y * 0.985 + rng.randf_range(-1.0, 1.0) * 0.12
		b[i] += y * amp


static func mix_into(dst: PackedFloat32Array, src: PackedFloat32Array, gain: float, offset := 0) -> void:
	var n := mini(src.size(), dst.size() - offset)
	for i in n:
		dst[offset + i] += src[i] * gain


## Makes a buffer loop seamlessly by crossfading its tail into its head.
static func loopify(b: PackedFloat32Array, fade_samples: int) -> PackedFloat32Array:
	var n := b.size() - fade_samples
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = b[i]
	for i in fade_samples:
		var t := float(i) / fade_samples
		out[i] = b[n + i] * (1.0 - t) + b[i] * t
	return out


static func env_ar(b: PackedFloat32Array, attack: float, release: float, rate := RATE) -> void:
	## Applies attack/exponential release envelope over the whole buffer.
	var a := int(attack * rate)
	for i in b.size():
		var e := 1.0
		if i < a:
			e = float(i) / maxf(a, 1)
		else:
			e = exp(-float(i - a) / (release * rate))
		b[i] *= e


static func tone(seconds: float, freq: float, wave := "sine", amp := 0.5, rate := RATE) -> PackedFloat32Array:
	var b := buffer(seconds, rate)
	var ph := 0.0
	var inc := freq / rate
	for i in b.size():
		ph = fmod(ph + inc, 1.0)
		var v := 0.0
		match wave:
			"sine":
				v = sin(ph * TAU)
			"square":
				v = 1.0 if ph < 0.5 else -1.0
			"saw":
				v = ph * 2.0 - 1.0
			"tri":
				v = 1.0 - 4.0 * absf(ph - 0.5)
		b[i] = v * amp
	return b


## Frequency sweep (for UI blips and kicks).
static func sweep(seconds: float, f0: float, f1: float, amp := 0.5, curve := 2.0, wave := "sine", rate := RATE) -> PackedFloat32Array:
	var b := buffer(seconds, rate)
	var ph := 0.0
	var n := b.size()
	for i in n:
		var t := float(i) / n
		var f := lerpf(f1, f0, pow(1.0 - t, curve))
		ph = fmod(ph + f / rate, 1.0)
		var v := sin(ph * TAU) if wave == "sine" else (1.0 - 4.0 * absf(ph - 0.5))
		b[i] = v * amp
	return b


static func midi_to_hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)
