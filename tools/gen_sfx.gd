extends SceneTree
## FEEL Stride 5: procedural SFX generator. Writes short, soft, low-volume
## PCM16 mono WAV files to res://assets/sfx/ via WavWriter (AudioStreamWAV has
## no save-to-disk method in this Godot build, so WavWriter hand-writes a
## standard RIFF/WAVE header — see its class doc).
##
## Every tone is built from a few simple oscillators (sine/triangle/noise)
## shaped by a short ADSR-ish envelope (fast attack, exponential-ish decay,
## no hard clicks at the boundaries) — intentionally simple/placeholder-grade,
## NOT an attempt at "real" sound design. Filenames are STABLE (id -> path is
## a straight lookup in AudioManager) so a real SFX pack can drop in later
## with no code changes, only file replacement.
##
## DETERMINISM CONTRACT: every synth function is pure math over explicit
## parameters (frequency, duration, seed for noise) — no Time/randomize()
## anywhere, so rerun -> git status clean, same as every other tools/gen_*.gd.
##
## Run: "$GODOT" --headless --path . -s res://tools/gen_sfx.gd

const OUT := "res://assets/sfx/"
const MIX_RATE := WavWriter.MIX_RATE
const MASTER_GAIN := 0.35  # keeps every generated tone comfortably quiet


func _init() -> void:
	var dir_err := DirAccess.make_dir_recursive_absolute(OUT)
	assert(dir_err == OK, "Cannot create " + OUT)

	var count := 0
	count += _write("footstep", _footstep())
	count += _write("till", _till())
	count += _write("water", _water())
	count += _write("plant", _plant())
	count += _write("harvest", _harvest())
	count += _write("sword_swing", _sword_swing())
	count += _write("hit", _hit())
	count += _write("enemy_die", _enemy_die())
	count += _write("coin", _coin())
	count += _write("menu_move", _menu_move())
	count += _write("menu_confirm", _menu_confirm())
	count += _write("level_up", _level_up())
	count += _write("sleep", _sleep())
	count += _write("bond_up", _bond_up())

	print("sfx written: ", count)
	quit(0)


func _write(id: String, samples: PackedFloat32Array) -> int:
	WavWriter.write(OUT + id + ".wav", samples)
	return 1


## ---- oscillators ----

static func _sine(freq: float, t: float, phase: float = 0.0) -> float:
	return sin(TAU * freq * t + phase)


static func _triangle(freq: float, t: float) -> float:
	var ph: float = fmod(freq * t, 1.0)
	return 4.0 * absf(ph - 0.5) - 1.0


## Deterministic noise: a tiny seeded LCG (mirrors PixelArt._lcg_next so no
## engine RNG state is touched), sampled once per output frame.
static func _noise_sample(state: Array) -> float:
	var next_val: int = (int(state[0]) * 1103515245 + 12345) & 0x7fffffff
	state[0] = next_val
	return (next_val / float(0x7fffffff)) * 2.0 - 1.0


## ---- envelope ----

## Linear attack to 1.0 over `attack` seconds, then exponential-ish decay to
## 0 over the rest of `duration` — avoids a hard click at either boundary
## (the "soft, tasteful" mandate from the contract).
static func _envelope(t: float, duration: float, attack: float) -> float:
	if t < attack:
		return t / attack
	var rem: float = duration - attack
	if rem <= 0.0:
		return 0.0
	var dt: float = (t - attack) / rem
	return pow(1.0 - clampf(dt, 0.0, 1.0), 1.6)


## ---- shared render loop ----

## `voice(t) -> float` returns a raw (unenveloped, [-1,1]-ish) sample at time
## t; this wraps it with the envelope + MASTER_GAIN and renders `duration`
## seconds at MIX_RATE.
static func _render(duration: float, attack: float, voice: Callable) -> PackedFloat32Array:
	var n := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t: float = float(i) / float(MIX_RATE)
		var env := _envelope(t, duration, attack)
		out[i] = float(voice.call(t)) * env * MASTER_GAIN
	return out


## ---- individual SFX ----

## Soft low thump — a short, quiet triangle blip, so the per-footstep cadence
## doesn't get fatiguing.
func _footstep() -> PackedFloat32Array:
	return _render(0.07, 0.005, func(t): return _triangle(110.0, t) * 0.6)


## A dry, gritty double-tap (soil being broken) — layered noise + a short
## low tone.
func _till() -> PackedFloat32Array:
	var state := [7]
	return _render(0.12, 0.005, func(t):
		return _noise_sample(state) * 0.5 + _triangle(90.0, t) * 0.5
	)


## A bright, quick descending chirp for a splash of water.
func _water() -> PackedFloat32Array:
	return _render(0.18, 0.01, func(t):
		var freq: float = lerpf(900.0, 500.0, t / 0.18)
		return _sine(freq, t)
	)


## A tiny soft pop — planting a seed.
func _plant() -> PackedFloat32Array:
	return _render(0.09, 0.005, func(t):
		var freq: float = lerpf(500.0, 700.0, t / 0.09)
		return _sine(freq, t)
	)


## A warm, quick ascending two-note chime for a harvest.
func _harvest() -> PackedFloat32Array:
	return _render(0.22, 0.005, func(t):
		var freq: float = 520.0 if t < 0.11 else 700.0
		return _sine(freq, t)
	)


## A short bright swish (filtered-noise-ish via a fast sine sweep) for the
## sword swing itself (distinct from the "hit" landing sound below).
func _sword_swing() -> PackedFloat32Array:
	return _render(0.12, 0.005, func(t):
		var freq: float = lerpf(1400.0, 700.0, t / 0.12)
		return _sine(freq, t) * 0.7
	)


## A punchy short thud+click for a landed hit — a low triangle thump plus a
## touch of noise for "impact" texture, deliberately brief so combo-chains
## don't blur together.
func _hit() -> PackedFloat32Array:
	var state := [42]
	return _render(0.09, 0.002, func(t):
		return _triangle(180.0, t) * 0.6 + _noise_sample(state) * 0.3
	)


## A short descending "poof" for an enemy dying — soft, not harsh.
func _enemy_die() -> PackedFloat32Array:
	return _render(0.28, 0.01, func(t):
		var freq: float = lerpf(400.0, 120.0, t / 0.28)
		return _sine(freq, t)
	)


## A bright quick two-note "cha-ching" for gold/selling.
func _coin() -> PackedFloat32Array:
	return _render(0.16, 0.003, func(t):
		var freq: float = 880.0 if t < 0.08 else 1174.0
		return _sine(freq, t) * 0.6
	)


## A tiny neutral tick for menu cursor movement — very short and quiet so
## rapid navigation doesn't get noisy.
func _menu_move() -> PackedFloat32Array:
	return _render(0.045, 0.003, func(t): return _sine(700.0, t))


## A short, pleasant confirm blip — a small upward two-note interval.
func _menu_confirm() -> PackedFloat32Array:
	return _render(0.12, 0.004, func(t):
		var freq: float = 600.0 if t < 0.05 else 900.0
		return _sine(freq, t) * 0.7
	)


## A warm ascending arpeggio for leveling up — the most "celebratory" SFX in
## the set but still kept soft per the contract.
func _level_up() -> PackedFloat32Array:
	return _render(0.45, 0.005, func(t):
		var idx: int = int(t / 0.11)
		var freqs := [523.0, 659.0, 784.0, 1046.0]
		var freq: float = freqs[clampi(idx, 0, freqs.size() - 1)]
		return _sine(freq, t) * 0.6
	)


## A slow, gentle descending tone for going to sleep.
func _sleep() -> PackedFloat32Array:
	return _render(0.5, 0.05, func(t):
		var freq: float = lerpf(440.0, 220.0, t / 0.5)
		return _sine(freq, t) * 0.5
	)


## A soft warm two-note rise for a relationship/bond gain — distinct from
## level_up (shorter, mellower, no arpeggio) so the two don't get confused.
func _bond_up() -> PackedFloat32Array:
	return _render(0.24, 0.01, func(t):
		var freq: float = 660.0 if t < 0.12 else 880.0
		return _sine(freq, t) * 0.55
	)
