extends GutTest
## World Stride D: Festival/WinterStar pure-logic helpers — hour windows,
## Willow's early-leave exception, notice board text, contest judging math,
## and Winter Star's deterministic assignment.


func before_each() -> void:
	Clock.day = 1


func after_each() -> void:
	Clock.day = 1
	GameState.flags = {}


# ---- hour windows ----

func test_normal_festival_hours_are_ten_to_eighteen() -> void:
	assert_eq(Festival.hours_for(Festival.ID_SOWING), Vector2i(10, 18))
	assert_eq(Festival.hours_for(Festival.ID_HARVEST_FAIR), Vector2i(10, 18))
	assert_eq(Festival.hours_for(Festival.ID_WINTER_STAR), Vector2i(10, 18))


func test_sunfire_hours_are_sixteen_to_twentytwo() -> void:
	assert_eq(Festival.hours_for(Festival.ID_SUNFIRE), Vector2i(16, 22))


func test_is_festival_hour_half_open_bounds() -> void:
	assert_false(Festival.is_festival_hour(Festival.ID_SOWING, 9))
	assert_true(Festival.is_festival_hour(Festival.ID_SOWING, 10))
	assert_true(Festival.is_festival_hour(Festival.ID_SOWING, 17))
	assert_false(Festival.is_festival_hour(Festival.ID_SOWING, 18))


func test_is_festival_hour_false_for_no_festival() -> void:
	assert_false(Festival.is_festival_hour("", 12))


# ---- is_npc_at_festival (Clock-dependent) ----

func test_npc_at_festival_true_during_window_on_festival_day() -> void:
	Clock.day = 14  # Spring 14 — Sowing
	assert_true(Festival.is_npc_at_festival("marta", 12))


func test_npc_not_at_festival_outside_window() -> void:
	Clock.day = 14
	assert_false(Festival.is_npc_at_festival("marta", 9))
	assert_false(Festival.is_npc_at_festival("marta", 18))


func test_npc_not_at_festival_on_non_festival_day() -> void:
	Clock.day = 15  # Spring 15 — no festival
	assert_false(Festival.is_npc_at_festival("marta", 12))


func test_willow_leaves_at_fifteen_hundred_every_festival() -> void:
	Clock.day = 14  # Sowing
	assert_true(Festival.is_npc_at_festival("willow", 14))
	assert_false(Festival.is_npc_at_festival("willow", 15))
	assert_false(Festival.is_npc_at_festival("willow", 17))


func test_willow_present_for_full_sunfire_window_no_early_leave() -> void:
	# The bible's "Willow leaves at 15:00" note reads against the DEFAULT
	# 10:00-18:00 window; sunfire is a wholly separate 16:00-22:00 evening
	# slot with no early-leave time of its own mentioned anywhere, so Willow
	# stays for the whole sunfire window like every other NPC.
	Clock.day = (1 * Clock.DAYS_PER_SEASON) + 21  # Summer 21 — Sunfire
	assert_true(Festival.is_npc_at_festival("willow", 16))
	assert_true(Festival.is_npc_at_festival("willow", 21))
	assert_false(Festival.is_npc_at_festival("willow", 22), "willow leaves at the ordinary festival end, same as everyone else")


func test_other_npcs_present_all_eight_at_noon_on_harvest_fair() -> void:
	Clock.day = (2 * Clock.DAYS_PER_SEASON) + 16  # Fall 16 — Harvest Fair
	for npc_id: String in ["marta", "sten", "bram", "rosa", "alden", "finn", "garrick"]:
		assert_true(Festival.is_npc_at_festival(npc_id, 12), "%s must be at the festival at noon" % npc_id)
	assert_true(Festival.is_npc_at_festival("willow", 12), "Willow is still present at noon, before her 15:00 leave")


func test_sunfire_evening_window_true_at_night_hour() -> void:
	Clock.day = (1 * Clock.DAYS_PER_SEASON) + 21  # Summer 21 — Sunfire
	assert_true(Festival.is_npc_at_festival("rosa", 20))
	assert_false(Festival.is_npc_at_festival("rosa", 10), "sunfire does NOT use the normal 10:00 start")


# ---- phase_signature ----

func test_phase_signature_differs_across_a_meaningful_boundary() -> void:
	Clock.day = 14  # Sowing
	var before := Festival.phase_signature(14)
	var after := Festival.phase_signature(15)  # Willow leaves at 15
	assert_ne(before, after)


func test_phase_signature_stable_within_a_window() -> void:
	Clock.day = 14
	assert_eq(Festival.phase_signature(10), Festival.phase_signature(11))


# ---- notice board ----

func test_notice_board_names_next_festival_when_far_away() -> void:
	Clock.day = 1  # Spring 1 — Sowing (Spring 14) is 13 days away
	var text := Festival.notice_board_text(1)
	assert_true(text.contains("Sowing Festival"))
	assert_true(text.contains("Spring 14"))


func test_notice_board_names_today_when_it_is_the_festival() -> void:
	Clock.day = 14
	var text := Festival.notice_board_text(14)
	assert_true(text.contains("Sowing Festival"))


func test_notice_board_rolls_to_next_year_boundary() -> void:
	# Winter 24 is the last festival of the year; the day after should name
	# NEXT year's Sowing Festival (Spring 14 of year+1).
	var winter_star_day := (3 * Clock.DAYS_PER_SEASON) + 24
	var text := Festival.notice_board_text(winter_star_day + 1)
	assert_true(text.contains("Sowing Festival"))


# ---- wake toast ----

func test_wake_toast_text_normal_festival() -> void:
	assert_eq(Festival.wake_toast_text(Festival.ID_SOWING),
		"The Sowing Festival is today! The plaza, 10:00-18:00.")


func test_wake_toast_text_sunfire_uses_evening_window() -> void:
	assert_eq(Festival.wake_toast_text(Festival.ID_SUNFIRE),
		"The Sunfire Festival is today! The plaza, 16:00-22:00.")


# ---- plaza decor ----

func test_decor_cells_present_for_every_festival() -> void:
	for id in [Festival.ID_SOWING, Festival.ID_SUNFIRE, Festival.ID_HARVEST_FAIR, Festival.ID_WINTER_STAR]:
		assert_gt(Festival.decor_cells_for(id).size(), 0, "%s must have decor cells" % id)


func test_decor_cells_empty_for_no_festival() -> void:
	assert_eq(Festival.decor_cells_for("").size(), 0)


# ---- shop closed gate ----

func test_shop_closed_during_sowing_festival_hours() -> void:
	Clock.day = 14
	assert_true(Festival.shop_closed_for_festival(12))


func test_shop_open_outside_festival_hours() -> void:
	Clock.day = 14
	assert_false(Festival.shop_closed_for_festival(9))


func test_shop_open_on_non_festival_day() -> void:
	Clock.day = 15
	assert_false(Festival.shop_closed_for_festival(12))


# ---- contest judging ----

func test_contest_tier_first_place_threshold() -> void:
	assert_eq(Festival.contest_tier(250), "1st")
	assert_eq(Festival.contest_tier(320), "1st")


func test_contest_tier_second_place_threshold() -> void:
	assert_eq(Festival.contest_tier(100), "2nd")
	assert_eq(Festival.contest_tier(249), "2nd")


func test_contest_tier_participation_below_threshold() -> void:
	assert_eq(Festival.contest_tier(99), "participation")
	assert_eq(Festival.contest_tier(45), "participation")


func test_contest_gold_by_tier() -> void:
	assert_eq(Festival.contest_gold_for_tier("1st"), 500)
	assert_eq(Festival.contest_gold_for_tier("2nd"), 200)
	assert_eq(Festival.contest_gold_for_tier("participation"), 50)


func test_contest_once_per_year_gate() -> void:
	var blob := {}
	assert_false(Festival.has_entered_contest_this_year(blob, 1))
	blob = Festival.record_contest_entry(blob, 1)
	assert_true(Festival.has_entered_contest_this_year(blob, 1))
	assert_false(Festival.has_entered_contest_this_year(blob, 2), "a new year must allow a new entry")


# ---- Winter Star determinism ----

func test_winter_star_target_deterministic_for_same_year() -> void:
	var ids := ["alden", "bram", "finn", "garrick", "marta", "rosa", "sten", "willow"]
	var first := Festival.winter_star_target(3, ids)
	var second := Festival.winter_star_target(3, ids)
	assert_eq(first, second)
	assert_true(first in ids)


func test_winter_star_target_varies_by_year() -> void:
	var ids := ["alden", "bram", "finn", "garrick", "marta", "rosa", "sten", "willow"]
	var targets := {}
	for year in ids.size():
		targets[Festival.winter_star_target(year, ids)] = true
	assert_gt(targets.size(), 1, "different years should (usually) produce different targets across a full cycle")


func test_winter_star_plaza_gifter_differs_from_target() -> void:
	var ids := ["alden", "bram", "finn", "garrick", "marta", "rosa", "sten", "willow"]
	for year in 10:
		var target := Festival.winter_star_target(year, ids)
		var gifter := Festival.winter_star_plaza_gifter(year, ids)
		assert_ne(target, gifter, "the plaza gifter must never be the same NPC as the gift target")


func test_winter_star_empty_ids_returns_empty_string() -> void:
	assert_eq(Festival.winter_star_target(1, []), "")
	assert_eq(Festival.winter_star_plaza_gifter(1, []), "")
