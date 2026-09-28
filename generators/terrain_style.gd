class_name TerrainStyle
extends RefCounted
## Natural (pre-road) terrain height function for each track style.
## Deterministic for a given seed; safe to call from worker threads.

var style := "flat"
var _n_large := FastNoiseLite.new()
var _n_mid := FastNoiseLite.new()
var _n_small := FastNoiseLite.new()
var _n_ridge := FastNoiseLite.new()
var _n_warp := FastNoiseLite.new()


func _init(p_style: String, seed_value: int) -> void:
	style = p_style
	_setup(_n_large, seed_value, 0.0006, 4, FastNoiseLite.FRACTAL_FBM)
	_setup(_n_mid, seed_value + 1, 0.003, 4, FastNoiseLite.FRACTAL_FBM)
	_setup(_n_small, seed_value + 2, 0.02, 3, FastNoiseLite.FRACTAL_FBM)
	_setup(_n_ridge, seed_value + 3, 0.0018, 5, FastNoiseLite.FRACTAL_RIDGED)
	_setup(_n_warp, seed_value + 4, 0.0012, 2, FastNoiseLite.FRACTAL_FBM)


func _setup(n: FastNoiseLite, s: int, freq: float, octaves: int, fractal: int) -> void:
	n.seed = s
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_type = fractal
	n.fractal_octaves = octaves
	n.fractal_lacunarity = 2.1
	n.fractal_gain = 0.5


func height(x: float, z: float) -> float:
	match style:
		"ramon":
			return _ramon(x, z)
		"deadsea":
			return _deadsea(x, z)
		"jerusalem":
			return _jerusalem(x, z)
	return 0.0


## Makhtesh Ramon: a huge elliptical erosion crater. The track sits on the northern rim.
## Outside the ellipse is the plateau, inside the crater floor with low hills, and in
## between a steep terraced escarpment.
func _ramon(x: float, z: float) -> float:
	var a := 6000.0
	var b := 2800.0
	var cz := 2500.0
	var e := sqrt((x / a) * (x / a) + ((z - cz) / b) * ((z - cz) / b))
	var s := (e - 1.0) * b # signed distance from rim, positive outside (plateau)
	s += _n_warp.get_noise_2d(x, z) * 140.0 + _n_mid.get_noise_2d(x, z) * 25.0
	var t := clampf((s + 170.0) / 230.0, 0.0, 1.0)
	# Terraced escarpment: blend a smooth ramp with a stepped one for rock strata ledges.
	var smooth := t * t * (3.0 - 2.0 * t)
	var steps := 6.0
	var st := floorf(smooth * steps) / steps
	var frac := smooth * steps - floorf(smooth * steps)
	var stepped := st + (1.0 / steps) * pow(frac, 3.5)
	var cliff := lerpf(smooth, stepped, 0.55)
	var plateau := 90.0 + _n_large.get_noise_2d(x, z) * 10.0 + _n_small.get_noise_2d(x, z) * 1.2
	var floor_h := _n_large.get_noise_2d(x + 900.0, z) * 8.0 + maxf(_n_ridge.get_noise_2d(x, z), 0.0) * 34.0
	floor_h += _n_small.get_noise_2d(x, z) * 0.8
	return lerpf(floor_h, plateau, cliff)


## Dead Sea: sea to the east, salt flats and beaches, steep Judean cliffs to the west and
## the Moab mountains across the water.
func _deadsea(x: float, z: float) -> float:
	var shore := 170.0 + _n_warp.get_noise_2d(x, z) * 90.0
	var h := 0.0
	# West: cliffs rising from about x=-480.
	var wx := -(x + 470.0 + _n_mid.get_noise_2d(x, z) * 60.0)
	if wx > 0.0:
		var c := clampf(wx / 260.0, 0.0, 1.0)
		h += pow(c, 1.6) * 260.0 + maxf(wx - 260.0, 0.0) * 0.25
		h += absf(_n_ridge.get_noise_2d(x, z)) * 60.0 * c
	# Gentle alluvial fans between the cliffs and the road.
	h += maxf(0.0, _n_large.get_noise_2d(x, z)) * 6.0
	h += _n_small.get_noise_2d(x, z) * 0.6
	# East: shore slopes down under the sea (water plane at -6).
	if x > shore:
		h -= clampf((x - shore) / 90.0, 0.0, 1.0) * 14.0
	# Moab mountains far across the sea.
	if x > 5200.0:
		var m := clampf((x - 5200.0) / 1600.0, 0.0, 1.0)
		h = lerpf(h, 420.0 + _n_ridge.get_noise_2d(x, z) * 260.0, m)
	return h


## Jerusalem hills: rounded limestone ridges and valleys.
func _jerusalem(x: float, z: float) -> float:
	var h := 70.0
	h += _n_large.get_noise_2d(x, z) * 110.0
	h += _n_ridge.get_noise_2d(x * 0.8, z * 0.8) * 45.0
	h += _n_mid.get_noise_2d(x, z) * 14.0
	h += _n_small.get_noise_2d(x, z) * 1.0
	# The city sits high to the east.
	h += clampf((x - 400.0) / 2500.0, 0.0, 1.0) * 90.0
	return h


## Height of the water plane, or -INF when the style has no water.
func water_level() -> float:
	return -6.0 if style == "deadsea" else -INF
