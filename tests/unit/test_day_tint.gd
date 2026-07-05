extends GutTest
## Pure curve breakpoints for DayTint.tint_for_minutes — no live tree needed.


func test_daytime_is_full_white() -> void:
	assert_eq(DayTint.tint_for_minutes(6 * 60), DayTint.WHITE)
	assert_eq(DayTint.tint_for_minutes(12 * 60), DayTint.WHITE)
	assert_eq(DayTint.tint_for_minutes(16 * 60), DayTint.WHITE)


func test_mid_dusk_at_1730_is_halfway_between_white_and_dusk() -> void:
	var expected: Color = DayTint.WHITE.lerp(DayTint.DUSK, 0.5)
	assert_eq(DayTint.tint_for_minutes(17 * 60 + 30), expected)


func test_dusk_end_at_1900_is_full_dusk() -> void:
	# 19:00 is the boundary into the dusk->night lerp, t=0 there.
	assert_eq(DayTint.tint_for_minutes(19 * 60), DayTint.DUSK)


func test_night_at_2200_is_full_night() -> void:
	assert_eq(DayTint.tint_for_minutes(22 * 60), DayTint.NIGHT)


func test_night_holds_at_1am_next_day() -> void:
	# 1:00 AM next day == 25:00 in Clock's 0-1560 minute space.
	assert_eq(DayTint.tint_for_minutes(25 * 60), DayTint.NIGHT)


func test_night_holds_to_curfew() -> void:
	assert_eq(DayTint.tint_for_minutes(Clock.DAY_END_MINUTES), DayTint.NIGHT)
