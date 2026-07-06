extends GutTest
## Pure block/cell resolution for NPCRegistry — no scene tree.


func _npc(schedule: Dictionary, rain_schedule: Dictionary = {}, festival_cell := Vector2i(-1, -1),
		extra_schedules: Dictionary = {}) -> NPCData:
	var d := NPCData.new()
	d.id = "test_npc"
	d.schedule = schedule
	d.rain_schedule = rain_schedule
	d.festival_cell = festival_cell
	d.extra_schedules = extra_schedules
	return d


func test_block_for_covers_all_five_blocks() -> void:
	assert_eq(NPCRegistry.block_for(6), NPCRegistry.BLOCK_6_9)
	assert_eq(NPCRegistry.block_for(8), NPCRegistry.BLOCK_6_9)
	assert_eq(NPCRegistry.block_for(9), NPCRegistry.BLOCK_9_12)
	assert_eq(NPCRegistry.block_for(11), NPCRegistry.BLOCK_9_12)
	assert_eq(NPCRegistry.block_for(12), NPCRegistry.BLOCK_12_17)
	assert_eq(NPCRegistry.block_for(16), NPCRegistry.BLOCK_12_17)
	assert_eq(NPCRegistry.block_for(17), NPCRegistry.BLOCK_17_20)
	assert_eq(NPCRegistry.block_for(19), NPCRegistry.BLOCK_17_20)
	assert_eq(NPCRegistry.block_for(20), NPCRegistry.BLOCK_20_2)
	assert_eq(NPCRegistry.block_for(23), NPCRegistry.BLOCK_20_2)
	assert_eq(NPCRegistry.block_for(1), NPCRegistry.BLOCK_20_2)


func test_cell_for_normal_block() -> void:
	var npc := _npc({NPCRegistry.BLOCK_9_12: Vector2i(5, 5)})
	assert_eq(NPCRegistry.cell_for(npc, 10, false, false), Vector2i(5, 5))


func test_cell_for_missing_block_returns_sentinel() -> void:
	var npc := _npc({NPCRegistry.BLOCK_9_12: Vector2i(5, 5)})
	assert_eq(NPCRegistry.cell_for(npc, 22, false, false), Vector2i(-1, -1))
	assert_false(NPCRegistry.is_present(npc, 22, false, false))


func test_rain_override_takes_precedence_over_normal_schedule() -> void:
	var npc := _npc(
		{NPCRegistry.BLOCK_9_12: Vector2i(5, 5)},
		{NPCRegistry.BLOCK_9_12: Vector2i(1, 1)})
	assert_eq(NPCRegistry.cell_for(npc, 10, true, false), Vector2i(1, 1))
	assert_eq(NPCRegistry.cell_for(npc, 10, false, false), Vector2i(5, 5))


func test_rain_override_falls_back_when_block_not_overridden() -> void:
	var npc := _npc(
		{NPCRegistry.BLOCK_9_12: Vector2i(5, 5)},
		{NPCRegistry.BLOCK_17_20: Vector2i(9, 9)})
	assert_eq(NPCRegistry.cell_for(npc, 10, true, false), Vector2i(5, 5))


func test_festival_cell_beats_everything() -> void:
	var npc := _npc(
		{NPCRegistry.BLOCK_9_12: Vector2i(5, 5)},
		{NPCRegistry.BLOCK_9_12: Vector2i(1, 1)},
		Vector2i(20, 20))
	assert_eq(NPCRegistry.cell_for(npc, 10, true, true), Vector2i(20, 20))


func test_festival_without_festival_cell_falls_back() -> void:
	var npc := _npc({NPCRegistry.BLOCK_9_12: Vector2i(5, 5)})
	assert_eq(NPCRegistry.cell_for(npc, 10, false, true), Vector2i(5, 5))


## ---- Alive Stride 1: schedule priority keys ----

## Day-of-season constants used across the priority-matrix tests below:
## weekend day 13 (a Sat, per is_weekend's rule), weekday day 10 (a Wed).
const _WEEKEND_DAY := 13
const _WEEKDAY_DAY := 10
const _SPRING := 0  # Clock.season() index; matches NPCRegistry.SEASON_KEYS[0] == "spring"
const _WINTER := 3


func test_is_weekend_matches_the_documented_28_day_rule() -> void:
	# Week 1: days 1-7 -> weekend is 6,7. Week 2: 8-14 -> weekend 13,14. Etc.
	# Day 28 ((28-1)%7==6) is also a weekend day (the month's last day).
	var weekday_days := [1, 2, 3, 4, 5, 8, 9, 10, 11, 12, 15, 16, 22, 23]
	var weekend_days := [6, 7, 13, 14, 20, 21, 27, 28]
	for d: int in weekday_days:
		assert_false(NPCRegistry.is_weekend(d), "day %d must be a weekday" % d)
	for d: int in weekend_days:
		assert_true(NPCRegistry.is_weekend(d), "day %d must be a weekend day" % d)


func test_priority_matrix_festival_beats_rain_beats_weekend_beats_season_beats_default() -> void:
	## Same NPC, same block, every key populated with a DIFFERENT cell —
	## confirms the full precedence chain resolves top-down.
	var npc := _npc(
		{NPCRegistry.BLOCK_9_12: Vector2i(0, 0)},           # default
		{NPCRegistry.BLOCK_9_12: Vector2i(1, 1)},           # rain
		Vector2i(9, 9),                                      # festival
		{
			"weekend": {NPCRegistry.BLOCK_9_12: Vector2i(2, 2)},
			"spring_weekend": {NPCRegistry.BLOCK_9_12: Vector2i(3, 3)},
			"spring": {NPCRegistry.BLOCK_9_12: Vector2i(4, 4)},
		})

	# weekday: no weekend key applies, so the plain "spring" season key wins over default.
	assert_eq(NPCRegistry.cell_for(npc, 10, false, false, _SPRING, _WEEKDAY_DAY), Vector2i(4, 4),
		"season key must beat default on an ordinary spring weekday")
	# weekend beats season (weekday -> season "spring" applies; weekend -> "spring_weekend" applies).
	assert_eq(NPCRegistry.cell_for(npc, 10, false, false, _SPRING, _WEEKEND_DAY), Vector2i(3, 3),
		"spring_weekend must beat plain weekend/season/default on a spring weekend day")
	# rain beats everything below it (weekend/season/default), even on a weekend.
	assert_eq(NPCRegistry.cell_for(npc, 10, true, false, _SPRING, _WEEKEND_DAY), Vector2i(1, 1))
	# festival beats rain.
	assert_eq(NPCRegistry.cell_for(npc, 10, true, true, _SPRING, _WEEKEND_DAY), Vector2i(9, 9))


func test_season_key_applies_on_a_weekday_when_no_weekend_table_is_set() -> void:
	var npc := _npc(
		{NPCRegistry.BLOCK_9_12: Vector2i(0, 0)},
		{}, Vector2i(-1, -1),
		{"spring": {NPCRegistry.BLOCK_9_12: Vector2i(4, 4)}})
	assert_eq(NPCRegistry.cell_for(npc, 10, false, false, _SPRING, _WEEKDAY_DAY), Vector2i(4, 4))


func test_plain_weekend_key_applies_when_no_seasonal_weekend_table_is_set() -> void:
	var npc := _npc(
		{NPCRegistry.BLOCK_9_12: Vector2i(0, 0)},
		{}, Vector2i(-1, -1),
		{"weekend": {NPCRegistry.BLOCK_9_12: Vector2i(2, 2)}})
	assert_eq(NPCRegistry.cell_for(npc, 10, false, false, _SPRING, _WEEKEND_DAY), Vector2i(2, 2),
		"plain weekend key must apply when spring_weekend isn't set")


func test_missing_block_in_priority_table_falls_back_to_next_table_not_straight_to_default() -> void:
	## "weekend" table has NO entry for the 17-20 block; "spring" table DOES.
	## On a spring weekend, the 17-20 lookup must fall through weekend -> to
	## the season table, not skip straight to `schedule`.
	var npc := _npc(
		{NPCRegistry.BLOCK_17_20: Vector2i(0, 0)},
		{}, Vector2i(-1, -1),
		{
			"weekend": {NPCRegistry.BLOCK_9_12: Vector2i(2, 2)},  # different block only
			"spring": {NPCRegistry.BLOCK_17_20: Vector2i(4, 4)},
		})
	assert_eq(NPCRegistry.cell_for(npc, 18, false, false, _SPRING, _WEEKEND_DAY), Vector2i(4, 4))


func test_existing_data_with_only_default_schedule_resolves_unchanged() -> void:
	## Backward compat: an NPCData with no extra_schedules at all (every NPC
	## shipped before Alive Stride 1) must resolve EXACTLY as before, on both
	## weekday and weekend days, in every season.
	var npc := _npc({NPCRegistry.BLOCK_9_12: Vector2i(7, 7)})
	for day: int in [_WEEKDAY_DAY, _WEEKEND_DAY]:
		for season_idx in range(4):
			assert_eq(NPCRegistry.cell_for(npc, 10, false, false, season_idx, day), Vector2i(7, 7))


func test_no_explicit_season_or_day_falls_back_to_clock() -> void:
	## Omitting the trailing season/day_of_season args (every pre-stride call
	## site does this) must still resolve using Clock's live season/day —
	## proven here by asserting it does NOT crash and returns the default
	## cell for an NPC with no extra_schedules (Clock's actual season/day
	## can never match a key that doesn't exist).
	var npc := _npc({NPCRegistry.BLOCK_9_12: Vector2i(7, 7)})
	assert_eq(NPCRegistry.cell_for(npc, 10, false, false), Vector2i(7, 7))


func test_sten_winter_schedule_keeps_smithy_through_evening_block() -> void:
	var data := StenData.build()
	assert_eq(NPCRegistry.cell_for(data, 18, false, false, _WINTER, _WEEKDAY_DAY), StenData.CELL_SMITHY,
		"winter: Sten stays at the smithy through 17-20 instead of the saloon")
	assert_eq(NPCRegistry.cell_for(data, 18, false, false, _SPRING, _WEEKDAY_DAY), StenData.CELL_SALOON,
		"non-winter seasons keep the ordinary saloon evening block")


func test_finn_weekend_schedule_sleeps_in_past_the_dawn_pier_block() -> void:
	var data := FinnData.build()
	assert_eq(NPCRegistry.map_for(data, 7, false, false, _SPRING, _WEEKEND_DAY), "town",
		"weekend: Finn's dawn block moves off the beach")
	assert_eq(NPCRegistry.cell_for(data, 7, false, false, _SPRING, _WEEKEND_DAY), FinnData.CELL_PLAZA_FOUNTAIN)
	assert_eq(NPCRegistry.map_for(data, 7, false, false, _SPRING, _WEEKDAY_DAY), "beach",
		"weekday: Finn's dawn block is unchanged (beach pier)")
