extends Node
## In-game time. A day runs 6:00 AM -> 2:00 AM (next day) = 1200 game minutes.

const DAY_START_MINUTES := 6 * 60
const DAY_END_MINUTES := 26 * 60
const REAL_SECONDS_PER_GAME_MINUTE := 0.7  # ~14 real minutes per day

var day: int = 1
var minutes: int = DAY_START_MINUTES
var paused := false

var _accum := 0.0
var _curfew_fired := false


func _process(delta: float) -> void:
	if paused:
		return
	_accum += delta
	while _accum >= REAL_SECONDS_PER_GAME_MINUTE:
		_accum -= REAL_SECONDS_PER_GAME_MINUTE
		advance_minutes(1)


func advance_minutes(n: int) -> void:
	for i in n:
		if minutes >= DAY_END_MINUTES:
			return
		minutes += 1
		EventBus.time_ticked.emit(hour(), minute())
		if minutes >= DAY_END_MINUTES and not _curfew_fired:
			_curfew_fired = true
			EventBus.curfew_reached.emit()


func hour() -> int:
	@warning_ignore("integer_division")
	return (minutes / 60) % 24


func minute() -> int:
	return minutes % 60


func reset_day_timers() -> void:
	## Clears sub-day state that end_day() normally clears. Called by
	## SaveManager.new_game()/load_game() so a fresh/loaded game can't
	## inherit a fired curfew latch from the previous session.
	_accum = 0.0
	_curfew_fired = false


func end_day() -> void:
	day += 1
	minutes = DAY_START_MINUTES
	reset_day_timers()
	EventBus.day_passed.emit(day)


func time_string() -> String:
	var h := hour()
	var ampm := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, minute(), ampm]
