extends GutTest


func before_each() -> void:
	Clock.paused = true
	Clock.day = 1
	Clock.minutes = Clock.DAY_START_MINUTES
	Clock._curfew_fired = false


func test_starts_at_6am() -> void:
	assert_eq(Clock.hour(), 6)
	assert_eq(Clock.minute(), 0)


func test_advance_updates_time() -> void:
	Clock.advance_minutes(90)
	assert_eq(Clock.hour(), 7)
	assert_eq(Clock.minute(), 30)


func test_time_string_formats() -> void:
	assert_eq(Clock.time_string(), "6:00 AM")
	Clock.advance_minutes(7 * 60)
	assert_eq(Clock.time_string(), "1:00 PM")


func test_clock_stops_at_curfew() -> void:
	Clock.advance_minutes(24 * 60)
	assert_eq(Clock.minutes, Clock.DAY_END_MINUTES)


func test_curfew_signal_fires_once() -> void:
	watch_signals(EventBus)
	Clock.advance_minutes(Clock.DAY_END_MINUTES - Clock.DAY_START_MINUTES + 50)
	assert_signal_emit_count(EventBus, "curfew_reached", 1)


func test_end_day_increments_and_resets() -> void:
	watch_signals(EventBus)
	Clock.advance_minutes(200)
	Clock.end_day()
	assert_eq(Clock.day, 2)
	assert_eq(Clock.minutes, Clock.DAY_START_MINUTES)
	assert_signal_emitted_with_parameters(EventBus, "day_passed", [2])
