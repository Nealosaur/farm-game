extends Node
## In-game time. A day runs 6:00 AM -> 2:00 AM (next day) = 1200 game minutes.
##
## Calendar (World Stride A): Clock.day stays the SINGLE source of truth
## (absolute, 1-based). Season / day-of-season / year are DERIVED from it —
## never stored anywhere. 4 seasons x 28 days = a 112-day year.
## Weather also lives here: rolled once per new day (end_day()) and at
## SaveManager.new_game(), persisted as SaveManager.world["calendar"] (see
## save_manager.gd's sanctioned-keys contract). The one accessor other code
## should use is Clock.is_raining().

const DAY_START_MINUTES := 6 * 60
const DAY_END_MINUTES := 26 * 60
const REAL_SECONDS_PER_GAME_MINUTE := 0.7  # ~14 real minutes per day

const DAYS_PER_SEASON := 28
const SEASONS_PER_YEAR := 4
const DAYS_PER_YEAR := DAYS_PER_SEASON * SEASONS_PER_YEAR  # 112
const SEASON_NAMES := ["Spring", "Summer", "Fall", "Winter"]
## Rain chance per season index. Winter is always clear/frozen (0.0).
const RAIN_CHANCE := [0.30, 0.20, 0.20, 0.0]
## season -> {day_of_season: festival id}. Scaffold only — World Stride D
## consumes these (plaza decor, schedules); nothing triggers off them yet.
const FESTIVALS := {
	0: {14: "sowing"},
	1: {21: "sunfire"},
	2: {16: "harvest_fair"},
	3: {24: "winter_star"},
}

var day: int = 1
var minutes: int = DAY_START_MINUTES
var paused := false

var weather := "clear"       # "clear" | "rain" — written only by roll_weather()/restore_calendar()
var weather_rolled_day := 0  # absolute day the current weather was rolled for

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
	# Weather is rolled BEFORE day_passed so listeners (tint, farm) already
	# see the new day's weather when they react to the rollover.
	roll_weather()
	EventBus.day_passed.emit(day)


func time_string() -> String:
	var h := hour()
	var ampm := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, minute(), ampm]


# ---- calendar derivation (World Stride A) ----

static func season_of_day(d: int) -> int:
	## 0 Spring, 1 Summer, 2 Fall, 3 Winter — for any absolute day.
	@warning_ignore("integer_division")
	return ((d - 1) / DAYS_PER_SEASON) % SEASONS_PER_YEAR


func season() -> int:
	return season_of_day(day)


func day_of_season() -> int:
	return ((day - 1) % DAYS_PER_SEASON) + 1


func year() -> int:
	@warning_ignore("integer_division")
	return ((day - 1) / DAYS_PER_YEAR) + 1


func date_string() -> String:
	return "%s %d, Yr %d" % [SEASON_NAMES[season()], day_of_season(), year()]


func is_festival_today() -> String:
	## Festival id ("sowing", "sunfire", "harvest_fair", "winter_star") or "".
	var by_day: Dictionary = FESTIVALS.get(season(), {})
	return by_day.get(day_of_season(), "")


# ---- weather (World Stride A) ----

func is_raining() -> bool:
	return weather == "rain"


func roll_weather(rng: RandomNumberGenerator = null) -> String:
	## Once-per-day roll: end_day() and SaveManager.new_game() call this.
	## Injectable rng so tests can seed/force outcomes; gameplay uses the
	## global RNG. Persists the result and announces it on the EventBus.
	var roll: float = rng.randf() if rng != null else randf()
	weather = "rain" if roll < RAIN_CHANCE[season()] else "clear"
	weather_rolled_day = day
	SaveManager.world["calendar"] = {"weather": weather, "rolled_day": weather_rolled_day}
	EventBus.weather_changed.emit(weather)
	return weather


func restore_calendar() -> void:
	## Called by SaveManager.load_game() after the world blob is read back.
	## int() on read — JSON round-trips numbers as floats (established gotcha).
	var cal: Dictionary = SaveManager.world.get("calendar", {})
	weather = String(cal.get("weather", "clear"))
	weather_rolled_day = int(cal.get("rolled_day", 0))
