extends GutTest
## World Stride A: calendar derivation (season/day-of-season/year from the
## single Clock.day counter), festival scaffold, weather rolls, and the
## world["calendar"] persistence blob (JSON float-coercion safe).

const TEST_PATH := "user://test_calendar_save.json"


func before_each() -> void:
	Clock.paused = true
	Clock.day = 1


func after_each() -> void:
	# Weather/day leak-proofing: later test files assume day 1 + clear skies.
	Clock.day = 1
	Clock.weather = "clear"
	Clock.weather_rolled_day = 0
	SaveManager.world.erase("calendar")
	SaveManager.save_path = "user://save1.json"
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


# ---- date derivation ----

func test_day_1_is_spring_1_year_1() -> void:
	Clock.day = 1
	assert_eq(Clock.season(), 0)
	assert_eq(Clock.day_of_season(), 1)
	assert_eq(Clock.year(), 1)
	assert_eq(Clock.date_string(), "Spring 1, Yr 1")


func test_day_28_is_last_day_of_spring() -> void:
	Clock.day = 28
	assert_eq(Clock.season(), 0)
	assert_eq(Clock.day_of_season(), 28)
	assert_eq(Clock.year(), 1)


func test_day_29_rolls_into_summer() -> void:
	Clock.day = 29
	assert_eq(Clock.season(), 1)
	assert_eq(Clock.day_of_season(), 1)
	assert_eq(Clock.date_string(), "Summer 1, Yr 1")


func test_fall_and_winter_starts() -> void:
	Clock.day = 57  # 2*28 + 1
	assert_eq(Clock.season(), 2)
	assert_eq(Clock.day_of_season(), 1)
	Clock.day = 85  # 3*28 + 1
	assert_eq(Clock.season(), 3)
	assert_eq(Clock.day_of_season(), 1)


func test_day_112_is_winter_28_year_1() -> void:
	Clock.day = 112
	assert_eq(Clock.season(), 3)
	assert_eq(Clock.day_of_season(), 28)
	assert_eq(Clock.year(), 1)
	assert_eq(Clock.date_string(), "Winter 28, Yr 1")


func test_day_113_is_spring_1_year_2() -> void:
	Clock.day = 113
	assert_eq(Clock.season(), 0)
	assert_eq(Clock.day_of_season(), 1)
	assert_eq(Clock.year(), 2)
	assert_eq(Clock.date_string(), "Spring 1, Yr 2")


func test_season_of_day_static_matches_instance() -> void:
	for d in [1, 28, 29, 56, 57, 84, 85, 112, 113]:
		Clock.day = d
		assert_eq(Clock.season_of_day(d), Clock.season(), "day %d" % d)


# ---- festival scaffold ----

func test_festival_days_return_ids() -> void:
	Clock.day = 14   # Spring 14
	assert_eq(Clock.is_festival_today(), "sowing")
	Clock.day = 49   # Summer 21
	assert_eq(Clock.is_festival_today(), "sunfire")
	Clock.day = 72   # Fall 16
	assert_eq(Clock.is_festival_today(), "harvest_fair")
	Clock.day = 108  # Winter 24
	assert_eq(Clock.is_festival_today(), "winter_star")


func test_non_festival_days_return_empty() -> void:
	Clock.day = 1
	assert_eq(Clock.is_festival_today(), "")
	Clock.day = 15
	assert_eq(Clock.is_festival_today(), "")


func test_festivals_repeat_every_year() -> void:
	Clock.day = 112 + 14  # Spring 14, Yr 2
	assert_eq(Clock.is_festival_today(), "sowing")


# ---- weather ----

func test_winter_never_rains() -> void:
	Clock.day = 85  # Winter 1 — RAIN_CHANCE[3] is 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var rains := 0
	for i in 200:
		if Clock.roll_weather(rng) == "rain":
			rains += 1
	assert_eq(rains, 0, "winter is always clear/frozen")


func test_spring_rains_sometimes_but_not_always() -> void:
	Clock.day = 1  # Spring — 30% rain
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var rains := 0
	for i in 200:
		if Clock.roll_weather(rng) == "rain":
			rains += 1
	assert_gt(rains, 0, "200 seeded spring rolls should hit rain at least once")
	assert_lt(rains, 200, "and should not rain every single day")


func test_roll_emits_weather_changed_and_persists_blob() -> void:
	watch_signals(EventBus)
	Clock.day = 5
	Clock.roll_weather()
	assert_signal_emitted(EventBus, "weather_changed")
	var cal: Dictionary = SaveManager.world.get("calendar", {})
	assert_eq(String(cal.get("weather", "")), Clock.weather)
	assert_eq(int(cal.get("rolled_day", -1)), 5)


func test_is_raining_accessor_tracks_weather() -> void:
	Clock.weather = "clear"
	assert_false(Clock.is_raining())
	Clock.weather = "rain"
	assert_true(Clock.is_raining())


func test_end_day_rolls_weather_for_the_new_day() -> void:
	Clock.day = 3
	Clock.weather_rolled_day = 0
	Clock.end_day()
	assert_eq(Clock.day, 4)
	assert_eq(Clock.weather_rolled_day, 4, "end_day must roll weather for the day it wakes into")


# ---- world["calendar"] round-trip ----

func test_restore_calendar_survives_json_float_coercion() -> void:
	# JSON round-trips numbers as floats — restore must int() them back.
	SaveManager.world["calendar"] = {"weather": "rain", "rolled_day": 42.0}
	Clock.restore_calendar()
	assert_eq(Clock.weather, "rain")
	assert_true(Clock.is_raining())
	assert_eq(Clock.weather_rolled_day, 42)
	assert_eq(typeof(Clock.weather_rolled_day), TYPE_INT)


func test_restore_calendar_defaults_when_blob_missing() -> void:
	SaveManager.world.erase("calendar")
	Clock.weather = "rain"
	Clock.restore_calendar()
	assert_eq(Clock.weather, "clear", "old saves without a calendar blob wake to clear skies")


func test_weather_survives_a_real_save_load_cycle() -> void:
	SaveManager.save_path = TEST_PATH
	SaveManager.new_game()
	# Force a deterministic rain day: try seeds until one rolls rain (spring
	# is 30% — seed 0..49 all-clear odds ~0.7^50, and the sequence is fixed
	# per Godot version, so this is stable).
	var rng := RandomNumberGenerator.new()
	var got_rain := false
	for s in 50:
		rng.seed = s
		Clock.day = 10  # mid-spring
		if Clock.roll_weather(rng) == "rain":
			got_rain = true
			break
	assert_true(got_rain, "expected at least one rainy seed in 50 spring rolls")
	assert_true(SaveManager.save_game())
	Clock.weather = "clear"
	Clock.weather_rolled_day = 0
	assert_true(SaveManager.load_game())
	assert_eq(Clock.weather, "rain", "load must restore the saved weather")
	assert_eq(Clock.weather_rolled_day, 10)
	assert_eq(Clock.day, 10)
