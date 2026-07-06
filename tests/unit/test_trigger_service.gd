extends GutTest
## Alive Stride 2: TriggerService precondition matrix + events_seen bookkeeping
## helpers + pick_scene() selection. Touches GameState.flags/Relationships/
## Clock directly (autoload reads, no scene tree) — same convention as
## test_npc_perks.gd.

func before_each() -> void:
	GameState.flags = {}
	Clock.day = 1
	Clock.minutes = Clock.DAY_START_MINUTES


func after_each() -> void:
	GameState.flags = {}
	Clock.day = 1
	Clock.minutes = Clock.DAY_START_MINUTES
	SaveManager.world.erase("relationships")
	Relationships.restore()


## ---- flag_set / flag_absent ----

func test_flag_set_passes_when_flag_true() -> void:
	GameState.flags["foo"] = true
	assert_true(TriggerService.evaluate({"flag_set": "foo"}))


func test_flag_set_fails_when_flag_missing() -> void:
	assert_false(TriggerService.evaluate({"flag_set": "foo"}))


func test_flag_set_fails_when_flag_false() -> void:
	GameState.flags["foo"] = false
	assert_false(TriggerService.evaluate({"flag_set": "foo"}))


func test_flag_absent_passes_when_flag_missing() -> void:
	assert_true(TriggerService.evaluate({"flag_absent": "foo"}))


func test_flag_absent_fails_when_flag_true() -> void:
	GameState.flags["foo"] = true
	assert_false(TriggerService.evaluate({"flag_absent": "foo"}))


## ---- min_hearts ----

func test_min_hearts_passes_when_level_meets_threshold() -> void:
	SaveManager.world["relationships"] = {"garrick": {"points": 700}}  # L7
	Relationships.restore()
	assert_true(TriggerService.evaluate({"min_hearts": {"npc": "garrick", "level": 7}}))


func test_min_hearts_fails_when_level_below_threshold() -> void:
	SaveManager.world["relationships"] = {"garrick": {"points": 300}}  # L3
	Relationships.restore()
	assert_false(TriggerService.evaluate({"min_hearts": {"npc": "garrick", "level": 7}}))


## ---- season ----

func test_season_passes_when_matching() -> void:
	Clock.day = 1  # spring (season 0)
	assert_true(TriggerService.evaluate({"season": 0}))


func test_season_fails_when_not_matching() -> void:
	Clock.day = 1  # spring
	assert_false(TriggerService.evaluate({"season": 3}))


## ---- day_range ----

func test_day_range_passes_within_bounds() -> void:
	Clock.day = 5  # day_of_season 5
	assert_true(TriggerService.evaluate({"day_range": [1, 10]}))


func test_day_range_fails_below_bounds() -> void:
	Clock.day = 1
	assert_false(TriggerService.evaluate({"day_range": [5, 10]}))


func test_day_range_fails_above_bounds() -> void:
	Clock.day = 20
	assert_false(TriggerService.evaluate({"day_range": [1, 10]}))


## ---- block/hours ----

func test_block_hours_passes_when_matching() -> void:
	Clock.minutes = 10 * 60  # 9-12 block
	assert_true(TriggerService.evaluate({"block/hours": "9-12"}))


func test_block_hours_fails_when_not_matching() -> void:
	Clock.minutes = 10 * 60  # 9-12 block
	assert_false(TriggerService.evaluate({"block/hours": "17-20"}))


## ---- map ----

func test_map_passes_when_current_map_matches() -> void:
	assert_true(TriggerService.evaluate({"map": "town"}, "town"))


func test_map_fails_when_current_map_differs() -> void:
	assert_false(TriggerService.evaluate({"map": "town"}, "farm"))


func test_map_precondition_ignored_when_caller_omits_current_map() -> void:
	## Pure-logic callers (unit tests) that don't pass a map argument aren't
	## penalized for a scene that happens to gate on one.
	assert_true(TriggerService.evaluate({"map": "town"}))


## ---- combined preconditions (matrix) ----

func test_all_preconditions_must_pass_together() -> void:
	GameState.flags["garrick_l7_choice_a"] = true
	Clock.minutes = 10 * 60  # 9-12
	var preconditions := {
		"flag_set": "garrick_l7_choice_a",
		"flag_absent": "garrick_sten_reconciled",
		"block/hours": "9-12",
		"map": "town",
	}
	assert_true(TriggerService.evaluate(preconditions, "town"))


func test_combined_preconditions_fail_if_any_single_one_fails() -> void:
	GameState.flags["garrick_l7_choice_a"] = true
	GameState.flags["garrick_sten_reconciled"] = true  # this one now fails flag_absent
	Clock.minutes = 10 * 60
	var preconditions := {
		"flag_set": "garrick_l7_choice_a",
		"flag_absent": "garrick_sten_reconciled",
		"block/hours": "9-12",
		"map": "town",
	}
	assert_false(TriggerService.evaluate(preconditions, "town"))


func test_empty_preconditions_always_pass() -> void:
	assert_true(TriggerService.evaluate({}))


## ---- events_seen bookkeeping ----

func test_seen_forever_false_when_absent() -> void:
	assert_false(TriggerService.seen_forever({}, "intro_alden"))


func test_mark_seen_forever_then_seen_forever_true() -> void:
	var seen := TriggerService.mark_seen_forever({}, "intro_alden")
	assert_true(TriggerService.seen_forever(seen, "intro_alden"))


func test_mark_seen_forever_does_not_mutate_the_original_dict() -> void:
	var original := {}
	var updated := TriggerService.mark_seen_forever(original, "intro_alden")
	assert_false(original.has("intro_alden"))
	assert_true(updated.has("intro_alden"))


func test_seen_today_true_only_for_the_exact_day() -> void:
	var seen := TriggerService.mark_seen_today({}, "some_scene", 5)
	assert_true(TriggerService.seen_today(seen, "some_scene", 5))
	assert_false(TriggerService.seen_today(seen, "some_scene", 6))


## ---- at-most-one-scene-per-day ----

func test_fires_at_most_once_per_day_true_when_nothing_fired_yet() -> void:
	assert_true(TriggerService.fires_at_most_once_per_day({}, 3))


func test_fires_at_most_once_per_day_false_after_marking_same_day() -> void:
	var seen := TriggerService.mark_any_fired_today({}, 3)
	assert_false(TriggerService.fires_at_most_once_per_day(seen, 3))


func test_fires_at_most_once_per_day_true_again_on_a_new_day() -> void:
	var seen := TriggerService.mark_any_fired_today({}, 3)
	assert_true(TriggerService.fires_at_most_once_per_day(seen, 4))


## ---- pick_scene ----

func test_pick_scene_returns_first_matching_candidate_in_list_order() -> void:
	var a := {"id": "scene_a", "preconditions": {}}
	var b := {"id": "scene_b", "preconditions": {}}
	var candidates: Array[Dictionary] = [a, b]
	var picked := TriggerService.pick_scene(candidates, {}, 1)
	assert_eq(String(picked.get("id", "")), "scene_a")


func test_pick_scene_skips_candidates_whose_preconditions_fail() -> void:
	var a := {"id": "scene_a", "preconditions": {"flag_set": "nope"}}
	var b := {"id": "scene_b", "preconditions": {}}
	var candidates: Array[Dictionary] = [a, b]
	var picked := TriggerService.pick_scene(candidates, {}, 1)
	assert_eq(String(picked.get("id", "")), "scene_b")


func test_pick_scene_skips_candidates_already_seen_forever() -> void:
	var a := {"id": "scene_a", "preconditions": {}}
	var seen := TriggerService.mark_seen_forever({}, "scene_a")
	var candidates: Array[Dictionary] = [a]
	var picked := TriggerService.pick_scene(candidates, seen, 1)
	assert_true(picked.is_empty())


func test_pick_scene_returns_empty_when_any_scene_already_fired_today() -> void:
	var a := {"id": "scene_a", "preconditions": {}}
	var seen := TriggerService.mark_any_fired_today({}, 1)
	var candidates: Array[Dictionary] = [a]
	var picked := TriggerService.pick_scene(candidates, seen, 1)
	assert_true(picked.is_empty())


func test_pick_scene_returns_empty_when_nothing_qualifies() -> void:
	var candidates: Array[Dictionary] = []
	var picked := TriggerService.pick_scene(candidates, {}, 1)
	assert_true(picked.is_empty())
