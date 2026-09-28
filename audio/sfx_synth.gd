class_name SfxSynth
extends RefCounted
## Synthesized sound effects: wind, tire screech, gravel, crashes, impacts, gear shifts,
## backfire pops, track ambiences and interface sounds.


static func wind() -> PackedFloat32Array:
	var b := Synth.buffer(3.2)
	Synth.white(b, 1.0, 11)
	Synth.bandpass(b, 700.0, 0.7)
	var b2 := Synth.buffer(3.2)
	Synth.brown(b2, 1.0, 12)
	for i in b.size():
		var t := float(i) / Synth.RATE
		var gust := 0.75 + 0.25 * sin(t * TAU / 3.2) * sin(t * TAU * 2.0 / 3.2 + 1.0)
		b[i] = (b[i] * 0.7 + b2[i] * 0.8) * gust
	b = Synth.loopify(b, 3200)
	Synth.normalize(b, 0.8)
	return b


static func screech() -> PackedFloat32Array:
	var b := Synth.buffer(1.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var ph := 0.0
	var ph2 := 0.0
	for i in b.size():
		var t := float(i) / Synth.RATE
		var f := 1150.0 + sin(t * TAU * 7.0) * 120.0 + sin(t * TAU * 1.3) * 80.0
		ph = fmod(ph + f / Synth.RATE, 1.0)
		ph2 = fmod(ph2 + f * 1.51 / Synth.RATE, 1.0)
		b[i] = sin(ph * TAU) * 0.5 + sin(ph2 * TAU) * 0.2 + rng.randf_range(-0.35, 0.35)
	Synth.bandpass(b, 1300.0, 2.0)
	b = Synth.loopify(b, 2400)
	Synth.normalize(b, 0.7)
	return b


static func gravel() -> PackedFloat32Array:
	var b := Synth.buffer(1.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	Synth.brown(b, 0.6, 32)
	# Crunchy grain clicks.
	for k in 900:
		var at := rng.randi_range(0, b.size() - 200)
		var amp := rng.randf_range(0.1, 0.5)
		for j in 60:
			b[at + j] += rng.randf_range(-1.0, 1.0) * amp * exp(-j / 12.0)
	Synth.lowpass(b, 2600.0)
	b = Synth.loopify(b, 2000)
	Synth.normalize(b, 0.7)
	return b


static func crash() -> PackedFloat32Array:
	var b := Synth.buffer(2.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	# Initial heavy thump.
	var thump := Synth.sweep(0.35, 140.0, 40.0, 1.0, 2.0)
	Synth.env_ar(thump, 0.002, 0.12)
	Synth.mix_into(b, thump, 1.0)
	# Metal/plastic scraping.
	var scrape := Synth.buffer(2.0)
	Synth.white(scrape, 1.0, 42)
	Synth.bandpass(scrape, 2400.0, 1.4)
	for i in scrape.size():
		var t := float(i) / Synth.RATE
		scrape[i] *= exp(-t / 0.7) * (0.6 + 0.4 * sin(t * 60.0 + sin(t * 13.0) * 3.0))
	Synth.mix_into(b, scrape, 0.6, int(0.05 * Synth.RATE))
	# Debris clatter.
	for k in 26:
		var at := int(rng.randf_range(0.05, 1.6) * Synth.RATE)
		var f := rng.randf_range(600.0, 3000.0)
		var click := Synth.tone(0.06, f, "square", rng.randf_range(0.1, 0.35))
		Synth.env_ar(click, 0.001, 0.012)
		Synth.mix_into(b, click, 1.0, at)
	Synth.normalize(b, 0.95)
	return b


static func impact() -> PackedFloat32Array:
	var b := Synth.sweep(0.25, 220.0, 60.0, 1.0, 2.5)
	var n := Synth.buffer(0.25)
	Synth.white(n, 0.6, 51)
	Synth.lowpass(n, 1800.0)
	for i in b.size():
		b[i] += n[i]
	Synth.env_ar(b, 0.001, 0.05)
	Synth.normalize(b, 0.9)
	return b


static func gear_shift() -> PackedFloat32Array:
	var b := Synth.buffer(0.12)
	Synth.white(b, 1.0, 61)
	Synth.bandpass(b, 900.0, 3.0)
	var click := Synth.tone(0.12, 180.0, "square", 0.4)
	for i in b.size():
		b[i] = b[i] * 0.6 + click[i]
	Synth.env_ar(b, 0.001, 0.018)
	Synth.normalize(b, 0.8)
	return b


static func backfire() -> PackedFloat32Array:
	var b := Synth.buffer(0.22)
	Synth.white(b, 1.0, 71)
	Synth.lowpass(b, 1400.0)
	var boom := Synth.sweep(0.22, 120.0, 45.0, 0.9, 2.0)
	for i in b.size():
		b[i] = b[i] * 0.8 + boom[i]
	Synth.env_ar(b, 0.001, 0.035)
	Synth.normalize(b, 0.95)
	return b


# --- Ambience ----------------------------------------------------------------

static func ambience(style: String) -> PackedFloat32Array:
	var b := Synth.buffer(6.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 81
	match style:
		"deadsea":
			# Distant waves: slowly swelling low noise.
			Synth.brown(b, 1.0, 82)
			Synth.lowpass(b, 600.0)
			for i in b.size():
				var t := float(i) / Synth.RATE
				b[i] *= 0.45 + 0.55 * pow(0.5 + 0.5 * sin(t * TAU / 6.0 * 2.0), 2.0)
		"jerusalem":
			# Night crickets over a soft breeze.
			Synth.white(b, 0.25, 83)
			Synth.lowpass(b, 900.0)
			var ph := 0.0
			for k in 3:
				var base := rng.randf_range(4200.0, 5200.0)
				var rate_hz := rng.randf_range(2.5, 4.0)
				var offset := rng.randf()
				for i in b.size():
					var t := float(i) / Synth.RATE
					var gate := fmod(t * rate_hz + offset, 1.0)
					var chirp := 0.0
					if gate < 0.35:
						var pulse := fmod(gate * 18.0, 1.0)
						chirp = sin(t * TAU * base) * (1.0 - pulse) * 0.18
					b[i] += chirp
		_:
			# Desert wind: airy band-passed noise with gusts.
			Synth.white(b, 1.0, 84)
			Synth.bandpass(b, 450.0, 0.6)
			for i in b.size():
				var t := float(i) / Synth.RATE
				b[i] *= 0.5 + 0.5 * pow(0.5 + 0.5 * sin(t * TAU / 6.0 + sin(t * 1.3)), 1.5)
	b = Synth.loopify(b, 8000)
	Synth.normalize(b, 0.6)
	return b


# --- Interface ---------------------------------------------------------------

static func ui(id: String) -> PackedFloat32Array:
	match id:
		"move":
			var m := Synth.tone(0.05, 1450.0, "sine", 0.25)
			Synth.env_ar(m, 0.002, 0.012)
			return m
		"tick":
			var t := Synth.tone(0.03, 2300.0, "sine", 0.2)
			Synth.env_ar(t, 0.001, 0.006)
			return t
		"click":
			var c := Synth.sweep(0.09, 700.0, 1400.0, 0.4, 1.0, "tri")
			Synth.env_ar(c, 0.002, 0.03)
			return c
		"back":
			var bk := Synth.sweep(0.1, 1100.0, 600.0, 0.35, 1.0, "tri")
			Synth.env_ar(bk, 0.002, 0.035)
			return bk
		"confirm":
			var a := Synth.tone(0.09, 880.0, "tri", 0.35)
			Synth.env_ar(a, 0.002, 0.04)
			var b := Synth.tone(0.16, 1318.5, "tri", 0.35)
			Synth.env_ar(b, 0.002, 0.06)
			var out := Synth.buffer(0.25)
			Synth.mix_into(out, a, 1.0)
			Synth.mix_into(out, b, 1.0, int(0.07 * Synth.RATE))
			return out
		"error":
			var e := Synth.tone(0.18, 150.0, "square", 0.25)
			Synth.lowpass(e, 1200.0)
			Synth.env_ar(e, 0.002, 0.08)
			return e
		"count":
			var cn := Synth.tone(0.25, 660.0, "sine", 0.5)
			var cn2 := Synth.tone(0.25, 1320.0, "sine", 0.12)
			for i in cn.size():
				cn[i] += cn2[i]
			Synth.env_ar(cn, 0.003, 0.09)
			return cn
		"go":
			var g := Synth.tone(0.7, 1320.0, "sine", 0.5)
			var g2 := Synth.tone(0.7, 1980.0, "sine", 0.15)
			for i in g.size():
				g[i] += g2[i]
			Synth.env_ar(g, 0.003, 0.3)
			return g
		"lap":
			var l := Synth.buffer(0.6)
			for k in 3:
				var nt := Synth.tone(0.3, Synth.midi_to_hz(76 + [0, 4, 7][k]), "tri", 0.35)
				Synth.env_ar(nt, 0.002, 0.12)
				Synth.mix_into(l, nt, 1.0, int(k * 0.08 * Synth.RATE))
			return l
		"finish":
			var f := Synth.buffer(1.8)
			var notes := [67, 71, 74, 79, 83]
			for k in notes.size():
				var nt := Synth.tone(0.9, Synth.midi_to_hz(notes[k]), "saw", 0.22)
				Synth.lowpass(nt, 3000.0)
				Synth.env_ar(nt, 0.004, 0.35)
				Synth.mix_into(f, nt, 1.0, int(k * 0.11 * Synth.RATE))
			Synth.normalize(f, 0.8)
			return f
	return Synth.tone(0.05, 1000.0, "sine", 0.2)
