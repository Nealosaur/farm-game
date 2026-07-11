extends GutTest
## Marriage M1: Romance autoload — roster gating, dating/marriage state
## machine, world["romance"] blob round-trip + coercion, and the spouse
## relationship-cap lift living on Relationships (max_points_for/max_level_for).

const CANDIDATE := "rosa"
const OTHER_CANDIDATE := "willow"
const NON_CANDIDATE := "marta"


func before_each() -> void:
	Romance._state = {}
	Romance._spouse = ""
	SaveManager.world.erase("romance")
	Relationships._state = {}
	SaveManager.world.erase("relationships")
	GameState.flags = {}
	Clock.day = 1
	Clock.minutes = Clock.DAY_START_MINUTES


func after_each() -> void:
	Romance._state = {}
	Romance._spouse = ""
	SaveManager.world.erase("romance")
	Relationships._state = {}
	SaveManager.world.erase("relationships")
	GameState.flags = {}
	Clock.day = 1
	Clock.minutes = Clock.DAY_START_MINUTES


## ---- roster ----

func test_only_the_five_confirmed_candidates_are_romanceable() -> void:
	assert_true(Romance.is_romanceable("rosa"))
	assert_true(Romance.is_romanceable("willow"))
	assert_true(Romance.is_romanceable("bram"))
	assert_true(Romance.is_romanceable("sten"))
	assert_true(Romance.is_romanceable("garrick"))
	assert_false(Romance.is_romanceable("marta"))
	assert_false(Romance.is_romanceable("alden"))
	assert_false(Romance.is_romanceable("finn"))
	assert_false(Romance.is_romanceable("nonexistent_id"))


func test_roster_matches_all_eight_registered_npcs_minus_the_three_platonic() -> void:
	var romanceable_count := 0
	for npc_id: String in NPCFactory.ALL_IDS:
		if Romance.is_romanceable(npc_id):
			romanceable_count += 1
	assert_eq(romanceable_count, 5)


## ---- dating ----

func test_start_dating_requires_l8_and_romanceable() -> void:
	Relationships._get_or_create(CANDIDATE)["points"] = 799  # just under L8
	assert_false(Romance.start_dating(CANDIDATE), "L7 must not be enough to start dating")
	assert_false(Romance.is_dating(CANDIDATE))

	Relationships._get_or_create(CANDIDATE)["points"] = 800  # exactly L8
	assert_true(Romance.start_dating(CANDIDATE))
	assert_true(Romance.is_dating(CANDIDATE))


func test_start_dating_refuses_non_romanceable_even_at_high_level() -> void:
	Relationships._get_or_create(NON_CANDIDATE)["points"] = 1000  # L10
	assert_false(Romance.start_dating(NON_CANDIDATE))
	assert_false(Romance.is_dating(NON_CANDIDATE))


func test_dating_multiple_candidates_is_allowed() -> void:
	## Bible §2: "Dating multiple candidates is allowed (no jealousy system
	## this phase — keep simple; document)."
	Relationships._get_or_create(CANDIDATE)["points"] = 800
	Relationships._get_or_create(OTHER_CANDIDATE)["points"] = 800
	assert_true(Romance.start_dating(CANDIDATE))
	assert_true(Romance.start_dating(OTHER_CANDIDATE))
	assert_true(Romance.is_dating(CANDIDATE))
	assert_true(Romance.is_dating(OTHER_CANDIDATE))


## ---- marriage ----

func test_marry_sets_married_and_spouse() -> void:
	Relationships._get_or_create(CANDIDATE)["points"] = 1000
	Romance.start_dating(CANDIDATE)
	assert_true(Romance.marry(CANDIDATE))
	assert_true(Romance.is_married_to(CANDIDATE))
	assert_eq(Romance.spouse(), CANDIDATE)
	assert_false(Romance.is_married_to(OTHER_CANDIDATE))


func test_marry_refuses_non_romanceable() -> void:
	assert_false(Romance.marry(NON_CANDIDATE))
	assert_eq(Romance.spouse(), "")


func test_marry_ends_other_dating_with_a_bond_ding() -> void:
	## Bible §2: "Marrying ends other dating (they revert to friends, a small
	## bond ding + a one-line reaction — authored)." M1 covers the mechanism;
	## the reaction LINE is an M2/M3 hook.
	Relationships._get_or_create(CANDIDATE)["points"] = 1000
	Relationships._get_or_create(OTHER_CANDIDATE)["points"] = 800
	Romance.start_dating(CANDIDATE)
	Romance.start_dating(OTHER_CANDIDATE)
	assert_true(Romance.is_dating(OTHER_CANDIDATE))

	var other_points_before := Relationships.points(OTHER_CANDIDATE)
	Romance.marry(CANDIDATE)

	assert_false(Romance.is_dating(OTHER_CANDIDATE), "marrying someone else must end this dating")
	assert_eq(Relationships.points(OTHER_CANDIDATE), other_points_before + Romance.END_OTHER_DATING_BOND_DING)
	# The new spouse's own "dating" flag stays true (now also married=true) —
	# marrying isn't "ending your own dating", just everyone else's.
	assert_true(Romance.is_dating(CANDIDATE))


func test_one_spouse_at_a_time_remarrying_swaps() -> void:
	Relationships._get_or_create(CANDIDATE)["points"] = 1000
	Relationships._get_or_create(OTHER_CANDIDATE)["points"] = 1000
	Romance.start_dating(CANDIDATE)
	Romance.marry(CANDIDATE)
	assert_eq(Romance.spouse(), CANDIDATE)

	Romance.start_dating(OTHER_CANDIDATE)
	Romance.marry(OTHER_CANDIDATE)
	assert_eq(Romance.spouse(), OTHER_CANDIDATE)
	assert_false(Romance.is_married_to(CANDIDATE), "only one spouse at a time")


## ---- engagement (GameState.flags-backed) ----

func test_propose_accept_sets_engaged_and_next_day_wedding() -> void:
	Clock.day = 5
	Romance.propose_accept(CANDIDATE)
	assert_true(Romance.is_engaged())
	assert_eq(Romance.engaged_to(), CANDIDATE)
	assert_false(Romance.is_wedding_due(), "wedding is scheduled for the NEXT day-rollover, not today")

	Clock.day = 6
	assert_true(Romance.is_wedding_due())


func test_clear_engagement_removes_flags() -> void:
	Romance.propose_accept(CANDIDATE)
	Romance.clear_engagement()
	assert_false(Romance.is_engaged())
	assert_eq(Romance.engaged_to(), "")


## ---- world["romance"] blob round-trip + coercion ----

func test_blob_round_trips_through_json() -> void:
	Relationships._get_or_create(CANDIDATE)["points"] = 1000
	Romance.start_dating(CANDIDATE)
	Romance.marry(CANDIDATE)

	var stringified := JSON.stringify(SaveManager.world)
	var round_tripped = JSON.parse_string(stringified)
	Romance._state = {}
	Romance._spouse = ""
	SaveManager.world = round_tripped
	Romance.restore()

	assert_true(Romance.is_married_to(CANDIDATE))
	assert_eq(Romance.spouse(), CANDIDATE)
	assert_true(Romance.is_dating(CANDIDATE))
	assert_eq(typeof(Romance.is_dating(CANDIDATE)), TYPE_BOOL)


func test_restore_defaults_when_blob_missing() -> void:
	SaveManager.world.erase("romance")
	Romance.restore()
	assert_eq(Romance.spouse(), "")
	assert_false(Romance.is_dating(CANDIDATE))
	assert_false(Romance.is_married_to(CANDIDATE))


func test_restore_coerces_bool_fields_from_raw_dict() -> void:
	## Simulates a hand-built/older blob shape rather than a real JSON
	## round-trip (JSON itself preserves bools) — defensive coercion per the
	## project convention every other world blob follows.
	SaveManager.world["romance"] = {
		"rosa": {"dating": true, "married": false},
		"spouse": "",
	}
	Romance.restore()
	assert_true(Romance.is_dating("rosa"))
	assert_false(Romance.is_married_to("rosa"))


## ---- spouse relationship-cap lift (Relationships side) ----

func test_non_spouse_still_capped_at_l10_1000() -> void:
	Relationships._get_or_create(CANDIDATE)["points"] = 5000  # would be way past L10 if uncapped
	Relationships._add_points(CANDIDATE, 0)  # no-op add to re-trigger the clamp path
	assert_eq(Relationships.max_points_for(CANDIDATE), 1000)
	assert_eq(Relationships.max_level_for(CANDIDATE), 10)
	assert_eq(Relationships.level(CANDIDATE), 10)


func test_spouse_can_bank_points_up_to_l14_1400() -> void:
	Relationships._get_or_create(CANDIDATE)["points"] = 1000
	Romance.start_dating(CANDIDATE)
	Romance.marry(CANDIDATE)

	assert_eq(Relationships.max_points_for(CANDIDATE), 1400)
	assert_eq(Relationships.max_level_for(CANDIDATE), 14)

	Relationships.add_flat_bond(CANDIDATE, 1000)  # try to push well past 1400
	assert_eq(Relationships.points(CANDIDATE), 1400, "spouse points must clamp at 1400, not 1000 or unbounded")
	assert_eq(Relationships.level(CANDIDATE), 14)


func test_spouse_cap_lift_does_not_leak_to_other_candidates() -> void:
	Relationships._get_or_create(CANDIDATE)["points"] = 1000
	Romance.start_dating(CANDIDATE)
	Romance.marry(CANDIDATE)

	Relationships._get_or_create(OTHER_CANDIDATE)["points"] = 1000
	Relationships.add_flat_bond(OTHER_CANDIDATE, 1000)
	assert_eq(Relationships.points(OTHER_CANDIDATE), 1000, "only the actual spouse gets the cap lift")


func test_tier_name_for_spouse_levels_above_ten_still_reads_kindred() -> void:
	Relationships._get_or_create(CANDIDATE)["points"] = 1000
	Romance.start_dating(CANDIDATE)
	Romance.marry(CANDIDATE)
	Relationships.add_flat_bond(CANDIDATE, 300)  # -> L13
	assert_eq(Relationships.level(CANDIDATE), 13)
	assert_eq(Relationships.tier_name(CANDIDATE), Relationships.TIER_KINDRED)
