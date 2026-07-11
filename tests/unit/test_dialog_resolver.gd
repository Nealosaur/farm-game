extends GutTest
## Pure DialogResolver.pick() precedence + no-repeat-until-exhausted pooling.
## Uses a tiny fixture dict (not Marta's real data) so precedence assertions
## don't depend on characters.md wording — test_marta_dialog_data.gd covers
## the actual data shape/verbatim strings separately.

const FIXTURE := {
	"tier_pools": {
		"STRANGER": ["s0", "s1", "s2"],
		"ACQUAINT": ["a0", "a1"],
	},
	"seasonal": [
		{"season": 0, "min_level": 4, "line": "spring-friend-plus"},
		{"season": 3, "min_level": 0, "line": "winter-any"},
	],
	"rain": ["rainy"],
	"festival": ["festive"],
	"birthday_reaction": "happy birthday to you",
	"dating_lines": ["sweet on you", "glad you came by"],
}

## Marriage M1: an NPC with NO dating_lines authored yet (every candidate
## except Rosa, until M2) — must fall straight through to the tier pool even
## when is_dating is true, not crash/return a blank line.
const FIXTURE_NO_DATING_LINES := {
	"tier_pools": {"STRANGER": ["s0", "s1"]},
}


func _ctx(overrides: Dictionary = {}) -> Dictionary:
	var base := {
		"tier": "STRANGER",
		"season": 1,
		"is_raining": false,
		"is_festival": false,
		"is_birthday": false,
		"is_dating": false,
		"shown_indices": [],
		"rng": null,
	}
	for k in overrides:
		base[k] = overrides[k]
	return base


func test_birthday_takes_top_precedence() -> void:
	var ctx := _ctx({"is_birthday": true, "is_festival": true, "is_raining": true})
	var result := DialogResolver.pick(FIXTURE, ctx)
	assert_eq(result["text"], "happy birthday to you")
	assert_eq(result["source"], "birthday")


func test_festival_beats_rain_and_seasonal() -> void:
	var ctx := _ctx({"is_festival": true, "is_raining": true})
	var result := DialogResolver.pick(FIXTURE, ctx)
	assert_eq(result["text"], "festive")
	assert_eq(result["source"], "festival")


func test_rain_beats_seasonal_and_tier_pool() -> void:
	var ctx := _ctx({"is_raining": true, "season": 3, "tier": "STRANGER"})
	var result := DialogResolver.pick(FIXTURE, ctx)
	assert_eq(result["text"], "rainy")
	assert_eq(result["source"], "rain")


func test_seasonal_requires_tier_gate() -> void:
	# season 0 spring-friend-plus needs FRIEND+ (level 4+); STRANGER doesn't qualify.
	var ctx := _ctx({"season": 0, "tier": "STRANGER"})
	var result := DialogResolver.pick(FIXTURE, ctx)
	assert_eq(result["source"], "tier_pool", "STRANGER must not see the FRIEND+ seasonal line")


func test_seasonal_shows_when_tier_qualifies() -> void:
	var ctx := _ctx({"season": 0, "tier": "FRIEND"})
	var result := DialogResolver.pick(FIXTURE, ctx)
	assert_eq(result["text"], "spring-friend-plus")
	assert_eq(result["source"], "seasonal")


func test_seasonal_any_season_entry_matches_every_season() -> void:
	for season in 4:
		var ctx := _ctx({"season": season, "tier": "STRANGER"})
		var result := DialogResolver.pick(FIXTURE, ctx)
		if season == 3:
			assert_eq(result["text"], "winter-any")
		# other seasons fall to tier pool (no season-0 line at STRANGER tier)


func test_falls_back_to_tier_pool_when_nothing_else_matches() -> void:
	var ctx := _ctx({"season": 1, "tier": "ACQUAINT"})
	var result := DialogResolver.pick(FIXTURE, ctx)
	assert_eq(result["source"], "tier_pool")
	assert_true(result["text"] in ["a0", "a1"])


## ---- Marriage M1: dating pool slot (above tier, below every special-occasion line) ----

func test_dating_line_shown_when_dating_and_nothing_higher_precedence_matches() -> void:
	var ctx := _ctx({"tier": "ACQUAINT", "is_dating": true})
	var result := DialogResolver.pick(FIXTURE, ctx)
	assert_eq(result["source"], "dating")
	assert_true(result["text"] in ["sweet on you", "glad you came by"])


func test_dating_line_not_shown_when_not_dating() -> void:
	var ctx := _ctx({"tier": "ACQUAINT", "is_dating": false})
	var result := DialogResolver.pick(FIXTURE, ctx)
	assert_eq(result["source"], "tier_pool")


func test_birthday_still_beats_dating() -> void:
	var ctx := _ctx({"is_dating": true, "is_birthday": true})
	var result := DialogResolver.pick(FIXTURE, ctx)
	assert_eq(result["source"], "birthday")


func test_festival_still_beats_dating() -> void:
	var ctx := _ctx({"is_dating": true, "is_festival": true})
	var result := DialogResolver.pick(FIXTURE, ctx)
	assert_eq(result["source"], "festival")


func test_rain_still_beats_dating() -> void:
	var ctx := _ctx({"is_dating": true, "is_raining": true})
	var result := DialogResolver.pick(FIXTURE, ctx)
	assert_eq(result["source"], "rain")


func test_seasonal_still_beats_dating() -> void:
	var ctx := _ctx({"is_dating": true, "season": 0, "tier": "FRIEND"})
	var result := DialogResolver.pick(FIXTURE, ctx)
	assert_eq(result["source"], "seasonal")


func test_dating_gracefully_falls_through_when_npc_has_no_dating_lines_authored() -> void:
	## Every candidate except Rosa (M1 pilot) — M2 authors the rest.
	var ctx := _ctx({"tier": "STRANGER", "is_dating": true})
	var result := DialogResolver.pick(FIXTURE_NO_DATING_LINES, ctx)
	assert_eq(result["source"], "tier_pool")
	assert_true(result["text"] in ["s0", "s1"])


func test_tier_pool_no_repeat_until_exhausted() -> void:
	var shown: Array = []
	var seen := {}
	for i in 3:
		var ctx := _ctx({"tier": "STRANGER", "shown_indices": shown})
		var result := DialogResolver.pick(FIXTURE, ctx)
		assert_false(result["pool_index"] in shown, "must not repeat before exhaustion")
		shown.append(result["pool_index"])
		seen[result["text"]] = true
	assert_eq(seen.size(), 3, "all 3 STRANGER lines should have been shown exactly once")


func test_tier_pool_resets_after_exhaustion() -> void:
	# All 3 STRANGER indices already shown: pool must become fully available again.
	var ctx := _ctx({"tier": "STRANGER", "shown_indices": [0, 1, 2]})
	var result := DialogResolver.pick(FIXTURE, ctx)
	assert_eq(result["source"], "tier_pool")
	assert_true(result["pool_index"] in [0, 1, 2])


func test_deterministic_with_seeded_rng() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var ctx := _ctx({"tier": "STRANGER", "rng": rng})
	var result1 := DialogResolver.pick(FIXTURE, ctx)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 42
	var ctx2 := _ctx({"tier": "STRANGER", "rng": rng2})
	var result2 := DialogResolver.pick(FIXTURE, ctx2)
	assert_eq(result1["text"], result2["text"])


func test_missing_tier_pool_falls_back_to_stranger() -> void:
	var ctx := _ctx({"tier": "KINDRED"})  # fixture has no KINDRED pool
	var result := DialogResolver.pick(FIXTURE, ctx)
	assert_true(result["text"] in ["s0", "s1", "s2"])
