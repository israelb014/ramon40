class_name EngineSynth
extends RefCounted
## Bakes seamless engine loops for each engine layout at a reference RPM and load.
## Firing events are modelled as decaying resonant exhaust pulses on top of a harmonic
## series of the firing frequency, plus intake/mechanical noise.

const LAYOUTS := {
	# fires: crank angles (degrees in a 720 cycle) at which cylinders fire.
	"inline4": {"fires": [0, 180, 360, 540], "res": 210.0, "decay": 0.006, "harm": [0.25, 1.0, 0.55, 0.45, 0.3, 0.22, 0.15, 0.1], "noise": 0.12, "bright": 5200.0},
	"triple": {"fires": [0, 240, 480], "res": 160.0, "decay": 0.008, "harm": [0.5, 1.0, 0.7, 0.35, 0.3, 0.2, 0.1], "noise": 0.1, "bright": 4200.0},
	"single": {"fires": [0], "res": 95.0, "decay": 0.02, "harm": [1.0, 0.8, 0.6, 0.45, 0.3, 0.25, 0.2, 0.15], "noise": 0.14, "bright": 3000.0},
	"twin": {"fires": [0, 270], "res": 120.0, "decay": 0.013, "harm": [1.0, 0.75, 0.5, 0.3, 0.2, 0.12], "noise": 0.08, "bright": 3400.0},
}


static func layer_rpms(spec: Dictionary) -> Array:
	var red: float = spec["redline"]
	return [red * 0.28, red * 0.58, red * 0.9]


## Returns a seamless loop (about `seconds` long) for the layout at `rpm`.
static func bake(layout_id: String, rpm: float, on_load: bool, seconds := 0.9, seed_value := 1) -> PackedFloat32Array:
	var L: Dictionary = LAYOUTS.get(layout_id, LAYOUTS["twin"])
	var rate := Synth.RATE
	var cycle := 120.0 / rpm # seconds per 720 degrees
	var n_cycles := maxi(1, int(round(seconds / cycle)))
	var total := int(round(n_cycles * cycle * rate))
	var loop_s := float(total) / rate
	var b := PackedFloat32Array()
	b.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + int(rpm)
	var fires: Array = L["fires"]
	var res: float = L["res"] * lerpf(0.85, 1.6, clampf(rpm / 12000.0, 0.0, 1.0))
	var decay: float = L["decay"] * (1.25 if on_load else 0.9) * lerpf(1.3, 0.7, clampf(rpm / 12000.0, 0.0, 1.0))
	var pulse_len := int(decay * 6.0 * rate)
	# Exhaust pulses.
	for c in n_cycles:
		for f in fires:
			var t0 := (c + float(f) / 720.0) * cycle
			var start := int(t0 * rate)
			var amp := (1.0 if on_load else 0.45) * rng.randf_range(0.82, 1.0)
			var ph := rng.randf() * TAU
			for k in pulse_len:
				var idx := (start + k) % total
				var t := float(k) / rate
				var env := exp(-t / decay)
				var s := sin(ph + TAU * res * t) + rng.randf_range(-0.2, 0.2) * (0.8 if on_load else 0.4)
				b[idx] += s * env * amp
			# Off-throttle burble: occasional extra pops.
			if not on_load and rng.randf() < (0.18 if layout_id in ["twin", "single"] else 0.06):
				var pop_start := start + int(rng.randf_range(0.2, 0.8) * cycle * rate / fires.size())
				for k in pulse_len / 2:
					var idx2 := (pop_start + k) % total
					b[idx2] += rng.randf_range(-1.0, 1.0) * exp(-float(k) / (decay * rate * 0.5)) * 0.5
	# Harmonic body of the firing frequency (exact multiples of the loop length).
	var fire_hz := float(fires.size() * n_cycles) / loop_s
	var harm: Array = L["harm"]
	var hgain := 0.35 if on_load else 0.22
	for h in harm.size():
		var freq := fire_hz * (h + 1) * 0.5 # include half-orders (crank rotation)
		if freq > rate * 0.4:
			break
		var a: float = float(harm[h]) * hgain
		var cycles_in_loop := roundf(freq * loop_s)
		var inc: float = cycles_in_loop / total
		var phh := rng.randf()
		for i in total:
			b[i] += sin(TAU * (phh + inc * i)) * a
	# Intake / mechanical noise (periodic with the loop), band-limited.
	var noise := PackedFloat32Array()
	noise.resize(total)
	Synth.white(noise, 1.0, seed_value + 7)
	var nk: float = L["noise"] * (0.6 if on_load else 0.3) * lerpf(0.5, 1.3, clampf(rpm / 12000.0, 0.0, 1.0))
	# Filters run over a pre-rolled periodic extension so the output loops seamlessly.
	var pre := int(0.12 * rate)
	var e := PackedFloat32Array()
	e.resize(total + pre)
	var nb := PackedFloat32Array()
	nb.resize(total + pre)
	for i in total + pre:
		e[i] = b[i % total]
		nb[i] = noise[i % total]
	Synth.bandpass(nb, lerpf(1300.0, 3200.0, clampf(rpm / 13000.0, 0.0, 1.0)), 1.2)
	for i in total + pre:
		e[i] += nb[i] * nk
	var cutoff: float = L["bright"] * 0.7 * lerpf(0.55, 1.15, clampf(rpm / 12000.0, 0.0, 1.0)) * (1.0 if on_load else 0.6)
	Synth.lowpass(e, cutoff)
	Synth.lowpass(e, cutoff * 1.6)
	Synth.highpass(e, 35.0)
	var out := PackedFloat32Array()
	out.resize(total)
	var peak := 0.0001
	for i in total:
		peak = maxf(peak, absf(e[pre + i]))
	# Gentle saturation on a normalized signal (grit without square-wave fuzz).
	var drive := 1.3 if on_load else 1.05
	var k := drive / peak
	var norm := 1.0 / tanh(drive)
	for i in total:
		out[i] = tanh(e[pre + i] * k) * norm
	Synth.normalize(out, 0.85 if on_load else 0.6)
	return out


## Lowpass applied twice around the loop so the filter state wraps seamlessly.
static func _lowpass_wrap(b: PackedFloat32Array, cutoff: float) -> void:
	var a := 1.0 - exp(-TAU * cutoff / Synth.RATE)
	var y := 0.0
	for pass_i in 2:
		for i in b.size():
			y += a * (b[i] - y)
			if pass_i == 1:
				b[i] = y
