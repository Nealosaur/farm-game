extends Node
## FEEL Stride 2: brief global hit-stop via a shallow Engine.time_scale dip.
## Called on a LANDED player sword hit and on a landed boss slam — freezes the
## action for a few frames so a hit reads as an IMPACT, not a tickle, then
## always restores to normal speed.
##
## SAFETY CONTRACT (mirrors GameFlow.cutscene_active's "never stuck" gate):
## the restore is driven by a REAL-TIME timer (create_timer(..., ..., ...,
## true) — ignore_time_scale=true), so it fires on schedule in wall-clock time
## regardless of the very time_scale dip it's undoing. _ready() also restores
## time_scale defensively in case a previous run/reload left it stuck (e.g. a
## crash mid-dip), and _exit_tree() restores it too so the autoload being torn
## down (scene reload in tests, etc.) can never leave the engine slowed. A
## second trigger while already stopped simply re-arms the same window
## (extends it to the new call's duration) rather than stacking multiple
## overlapping timers/scale writes.

const DEFAULT_TIME_SCALE := 0.02   # near-zero, not exactly zero (avoids any div-by-time_scale edge cases)
const DEFAULT_DURATION := 0.06     # seconds of REAL time the dip lasts (~3-4 frames at 60fps)

var _active := false
var _token := 0  # bumped on every trigger(); a stale restore callback checks this before acting


func _ready() -> void:
	Engine.time_scale = 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func trigger(duration: float = DEFAULT_DURATION, scale: float = DEFAULT_TIME_SCALE) -> void:
	_token += 1
	var my_token := _token
	_active = true
	Engine.time_scale = scale
	# ignore_time_scale=true: this timer counts down in real wall-clock
	# seconds no matter what Engine.time_scale is currently set to, so the
	# restore ALWAYS lands duration-seconds of real time later.
	var timer := get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(_on_restore.bind(my_token))


func _on_restore(my_token: int) -> void:
	if my_token != _token:
		return  # a newer trigger() re-armed the window; that one's own timer owns the restore
	Engine.time_scale = 1.0
	_active = false


func is_active() -> bool:
	return _active
