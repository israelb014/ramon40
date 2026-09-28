class_name MusicSynth
extends RefCounted
## Procedural synthwave loop for the menus: sidechained detuned-saw pads, pumping octave
## bass, a panned arpeggio and a gated drum kit. Returns [left, right] buffers that loop
## seamlessly (8 bars at 108 BPM in A minor).

const BPM := 108.0
const BARS := 8
# Chord per bar: [bass root, chord notes]
const PROGRESSION := [
	[45, [57, 60, 64]], [41, [57, 60, 65]], [48, [55, 60, 64]], [43, [55, 59, 62]],
	[45, [57, 60, 64]], [41, [57, 60, 65]], [48, [55, 60, 64]], [40, [56, 59, 64]],
]


static func generate() -> Array:
	var rate := Synth.RATE
	var beat := 60.0 / BPM
	var bar := beat * 4.0
	var total := int(round(bar * BARS * rate))
	var L := PackedFloat32Array()
	var R := PackedFloat32Array()
	L.resize(total)
	R.resize(total)
	var duck := _sidechain(total, beat)
	_pads(L, R, bar, duck)
	_bass(L, R, beat, duck)
	_arp(L, R, beat)
	_drums(L, R, beat, total)
	# Master: gentle saturation and normalization.
	var m := 0.0001
	for i in total:
		L[i] = tanh(L[i] * 1.2)
		R[i] = tanh(R[i] * 1.2)
		m = maxf(m, maxf(absf(L[i]), absf(R[i])))
	var k := 0.85 / m
	for i in total:
		L[i] *= k
		R[i] *= k
	return [L, R]


static func _sidechain(total: int, beat: float) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(total)
	var beat_s := int(beat * Synth.RATE)
	for i in total:
		var t := float(i % beat_s) / Synth.RATE
		d[i] = 1.0 - 0.7 * exp(-t / 0.09)
	return d


static func _pads(L: PackedFloat32Array, R: PackedFloat32Array, bar: float, duck: PackedFloat32Array) -> void:
	var rate := Synth.RATE
	var bar_s := int(bar * rate)
	for b in BARS:
		var notes: Array = PROGRESSION[b][1]
		var start := b * bar_s
		for n in notes:
			var f := Synth.midi_to_hz(n)
			for ch in 2:
				var buf := L if ch == 0 else R
				var detunes := [-0.006, 0.004] if ch == 0 else [-0.003, 0.007]
				for dt in detunes:
					var inc: float = f * (1.0 + dt) / rate
					var ph := fmod(float(n) * 0.137 + dt * 50.0, 1.0)
					var lp := 0.0
					var a := 1.0 - exp(-TAU * 1700.0 / rate)
					for i in bar_s + int(0.4 * rate):
						var idx := (start + i) % buf.size()
						ph = fmod(ph + inc, 1.0)
						var saw := ph * 2.0 - 1.0
						lp += a * (saw - lp)
						var t := float(i) / rate
						var env := minf(t / 0.35, 1.0) * (1.0 if i < bar_s else exp(-(t - bar) / 0.12))
						buf[idx] += lp * env * 0.055 * duck[idx]


static func _bass(L: PackedFloat32Array, R: PackedFloat32Array, beat: float, duck: PackedFloat32Array) -> void:
	var rate := Synth.RATE
	var eighth := beat * 0.5
	var steps := BARS * 8
	for s in steps:
		var b := s / 8
		var root: int = PROGRESSION[b][0]
		var note := root + (12 if s % 2 == 1 else 0)
		var f := Synth.midi_to_hz(note)
		var start := int(s * eighth * rate)
		var length := int(eighth * rate * 0.95)
		var ph := 0.0
		var lp := 0.0
		for i in length:
			var t := float(i) / rate
			ph = fmod(ph + f / rate, 1.0)
			var saw := ph * 2.0 - 1.0
			var cutoff := 250.0 + 1400.0 * exp(-t / 0.06)
			var a := 1.0 - exp(-TAU * cutoff / rate)
			lp += a * (saw - lp)
			var env := exp(-t / 0.22) * minf(t / 0.004, 1.0)
			var v := lp * env * 0.32
			var idx := (start + i) % L.size()
			L[idx] += v * (0.6 + 0.4 * duck[idx])
			R[idx] += v * (0.6 + 0.4 * duck[idx])


static func _arp(L: PackedFloat32Array, R: PackedFloat32Array, beat: float) -> void:
	var rate := Synth.RATE
	var sixteenth := beat * 0.25
	var steps := BARS * 16
	var pattern := [0, 1, 2, 1, 0, 2, 1, 2]
	for s in steps:
		var b := s / 16
		var notes: Array = PROGRESSION[b][1]
		var note: int = notes[pattern[s % pattern.size()]] + 12
		if s % 16 >= 12 and b % 2 == 1:
			note += 12
		var f := Synth.midi_to_hz(note)
		var start := int(s * sixteenth * rate)
		var length := int(sixteenth * rate * 1.6)
		var ph := 0.0
		var lp := 0.0
		var a := 1.0 - exp(-TAU * 2600.0 / rate)
		var pan := 0.25 if s % 2 == 0 else 0.75
		for i in length:
			var t := float(i) / rate
			ph = fmod(ph + f / rate, 1.0)
			var sq := 1.0 if ph < 0.35 else -1.0
			lp += a * (sq - lp)
			var env := exp(-t / 0.07) * minf(t / 0.002, 1.0)
			var v := lp * env * 0.07
			var idx := (start + i) % L.size()
			L[idx] += v * (1.0 - pan) * 2.0
			R[idx] += v * pan * 2.0
		# Echo (dotted eighth) for depth.
		var echo_start := start + int(beat * 0.75 * rate)
		for i in length:
			var t2 := float(i) / rate
			var idx2 := (echo_start + i) % L.size()
			var ph2 := fmod(f * t2, 1.0)
			var sq2 := 1.0 if ph2 < 0.35 else -1.0
			var v2 := sq2 * exp(-t2 / 0.07) * 0.022
			L[idx2] += v2 * pan * 2.0
			R[idx2] += v2 * (1.0 - pan) * 2.0


static func _drums(L: PackedFloat32Array, R: PackedFloat32Array, beat: float, total: int) -> void:
	var rate := Synth.RATE
	var kick := Synth.sweep(0.32, 150.0, 42.0, 0.9, 3.0)
	Synth.env_ar(kick, 0.001, 0.16)
	var snare := Synth.buffer(0.35)
	Synth.white(snare, 0.8, 91)
	Synth.bandpass(snare, 2200.0, 0.8)
	var body := Synth.tone(0.35, 185.0, "sine", 0.5)
	for i in snare.size():
		snare[i] += body[i] * exp(-float(i) / (0.05 * rate))
	Synth.env_ar(snare, 0.001, 0.11)
	var hat := Synth.buffer(0.06)
	Synth.white(hat, 0.5, 92)
	Synth.highpass(hat, 7000.0)
	Synth.env_ar(hat, 0.001, 0.012)
	var open_hat := Synth.buffer(0.25)
	Synth.white(open_hat, 0.4, 93)
	Synth.highpass(open_hat, 6000.0)
	Synth.env_ar(open_hat, 0.001, 0.08)
	var beats := BARS * 4
	for b in beats:
		var start := int(b * beat * rate)
		_add(L, R, kick, start, 0.95, 0.5)
		if b % 4 == 1 or b % 4 == 3:
			_add(L, R, snare, start, 0.55, 0.5)
		for e in 2:
			var hs := start + int(e * beat * 0.5 * rate)
			if e == 1 and b % 2 == 1:
				_add(L, R, open_hat, hs, 0.35, 0.65)
			else:
				_add(L, R, hat, hs, 0.35, 0.35 + 0.3 * e)
	# Fill at the end of the loop.
	for k in 4:
		var s := int((beats - 1 + k * 0.25) * beat * rate)
		_add(L, R, snare, s, 0.25 + k * 0.08, 0.5)


static func _add(L: PackedFloat32Array, R: PackedFloat32Array, src: PackedFloat32Array, start: int, gain: float, pan: float) -> void:
	var n := L.size()
	for i in src.size():
		var idx := (start + i) % n
		L[idx] += src[i] * gain * (1.0 - pan) * 2.0 * 0.5 + src[i] * gain * 0.5 * (1.0 - absf(pan - 0.5))
		R[idx] += src[i] * gain * pan * 2.0 * 0.5 + src[i] * gain * 0.5 * (1.0 - absf(pan - 0.5))
