extends GutTest
## V3: NightVignette's pure curve (night_factor) + its live-tree wiring.


func test_full_daylight_is_zero() -> void:
	assert_eq(NightVignette.night_factor(6 * 60), 0.0)
	assert_eq(NightVignette.night_factor(12 * 60), 0.0)
	assert_eq(NightVignette.night_factor(DayTint.DUSK_START), 0.0)


func test_ramps_up_across_dusk() -> void:
	var mid_dusk := NightVignette.night_factor(DayTint.DUSK_START + (DayTint.DUSK_END - DayTint.DUSK_START) / 2)
	assert_almost_eq(mid_dusk, 0.25, 0.0001)


func test_dusk_end_is_halfway() -> void:
	assert_almost_eq(NightVignette.night_factor(DayTint.DUSK_END), 0.5, 0.0001)


func test_full_night_is_one() -> void:
	assert_eq(NightVignette.night_factor(DayTint.NIGHT_START), 1.0)
	assert_eq(NightVignette.night_factor(Clock.DAY_END_MINUTES), 1.0)


func test_monotonic_non_decreasing_across_the_full_day() -> void:
	var prev := -1.0
	var m := 0
	while m <= Clock.DAY_END_MINUTES:
		var f := NightVignette.night_factor(m)
		assert_gte(f, prev, "night_factor must never decrease as minutes advance")
		prev = f
		m += 15


func test_ready_attaches_a_full_rect_texture_and_tracks_clock() -> void:
	Clock.minutes = 12 * 60  # noon
	var host := Node2D.new()
	add_child_autofree(host)
	var vignette := NightVignette.new()
	host.add_child(vignette)
	await wait_process_frames(1)
	assert_almost_eq(vignette._rect.modulate.a, 0.0, 0.0001)
	Clock.minutes = DayTint.NIGHT_START
	EventBus.time_ticked.emit(Clock.hour(), Clock.minutes % 60)
	assert_almost_eq(vignette._rect.modulate.a, 1.0, 0.0001)
	Clock.minutes = Clock.DAY_START_MINUTES
