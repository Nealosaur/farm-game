extends Node
## FEEL Stride 2: brief global hit-stop via a shallow Engine.time_scale dip.
## Called on a LANDED player sword hit and on a landed boss slam — freezes the
## action for a few frames so a hit reads as an IMPACT, not a tickle, then
## always restores to normal speed.
##
## SAFETY CONTRACT (mirrors GameFlow.cutscene_active's "never stuck" gate):
## the restore is counted in REAL ENGINE FRAMES via _process (Node._process
## still fires once per rendered frame regardless of Engine.time_scale — only
## its `delta` argument is scaled, not the call rate), so the window always
## resolves after `frames` actual ticks tick by tick, and can never be left
## dangling by a wall-clock timer that outlives a fast test or a scene swap.
## _ready() also restores time_scale defensively in case a previous run left
## it stuck, and _exit_tree() restores it too so the autoload being torn down
## can never leave the engine slowed. A second trigger() while already
## stopped simply re-arms the same countdown (extends it) instead of stacking.
##
## Earlier revision used a real-time SceneTreeTimer(ignore_time_scale=true)
## for the restore; that leaked Engine.time_scale=0.02 across fast-running
## GUT test files (a 0.06s wall-clock timer from one test's landed hit could
## still be pending when the NEXT test file started a moment later,
## corrupting THAT test's physics-delta-driven timers). Counting frames
## instead ties the restore to actual ticks of THIS node's own _process,
## which stops entirely once the node/tree it belongs to stops processing
## (e.g. between isolated test runs), so it can't outlive its own test.

const DEFAULT_TIME_SCALE := 0.02   # near-zero, not exactly zero (avoids any div-by-time_scale edge cases)
const DEFAULT_FRAMES := 3          # ~2-4 frames per the contract

var _active := false
var _frames_left := 0


func _ready() -> void:
	Engine.time_scale = 1.0
	set_process(false)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func trigger(frames: int = DEFAULT_FRAMES, scale: float = DEFAULT_TIME_SCALE) -> void:
	_active = true
	_frames_left = frames
	Engine.time_scale = scale
	set_process(true)


func _process(_delta: float) -> void:
	_frames_left -= 1
	if _frames_left <= 0:
		Engine.time_scale = 1.0
		_active = false
		set_process(false)


func is_active() -> bool:
	return _active
