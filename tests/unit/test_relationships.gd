extends GutTest
## World Stride B: Relationships autoload — level/tier math, talk/gift daily
## gates, decay floors, heart-event/perk gates, and the world["relationships"]
## JSON round-trip.

const NPC_ID := "marta"


func before_each() -> void:
	Relationships._state = {}
	SaveManager.world.erase("relationships")
	Clock.day = 1


func after_each() -> void:
	Relationships._state = {}
	SaveManager.world.erase("relationships")
	Clock.day = 1


# ---- level / tier math ----

func test_level_zero_at_zero_points() -> void:
	assert_eq(Relationships.level_for_points(0), 0)


func test_level_boundaries() -> void:
	assert_eq(Relationships.level_for_points(99), 0)
	assert_eq(Relationships.level_for_points(100), 1)
	assert_eq(Relationships.level_for_points(199), 1)
	assert_eq(Relationships.level_for_points(200), 2)
	assert_eq(Relationships.level_for_points(999), 9)
	assert_eq(Relationships.level_for_points(1000), 10)


func test_level_clamped_to_ten_max() -> void:
	assert_eq(Relationships.level_for_points(5000), 10)


func test_tier_names_by_level() -> void:
	assert_eq(Relationships.tier_name_for_level(0), Relationships.TIER_STRANGER)
	assert_eq(Relationships.tier_name_for_level(1), Relationships.TIER_STRANGER)
	assert_eq(Relationships.tier_name_for_level(2), Relationships.TIER_ACQUAINT)
	assert_eq(Relationships.tier_name_for_level(3), Relationships.TIER_ACQUAINT)
	assert_eq(Relationships.tier_name_for_level(4), Relationships.TIER_FRIEND)
	assert_eq(Relationships.tier_name_for_level(6), Relationships.TIER_FRIEND)
	assert_eq(Relationships.tier_name_for_level(7), Relationships.TIER_CLOSE)
	assert_eq(Relationships.tier_name_for_level(9), Relationships.TIER_CLOSE)
	assert_eq(Relationships.tier_name_for_level(10), Relationships.TIER_KINDRED)


func test_tier_base_points() -> void:
	assert_eq(Relationships.tier_base_points(Relationships.TIER_STRANGER), 0)
	assert_eq(Relationships.tier_base_points(Relationships.TIER_ACQUAINT), 200)
	assert_eq(Relationships.tier_base_points(Relationships.TIER_FRIEND), 400)
	assert_eq(Relationships.tier_base_points(Relationships.TIER_CLOSE), 700)
	assert_eq(Relationships.tier_base_points(Relationships.TIER_KINDRED), 1000)


# ---- talk ----

func test_talk_once_grants_fifteen() -> void:
	assert_true(Relationships.talk(NPC_ID))
	assert_eq(Relationships.points(NPC_ID), 15)


func test_talk_twice_same_day_only_grants_once() -> void:
	assert_true(Relationships.talk(NPC_ID))
	assert_false(Relationships.talk(NPC_ID))
	assert_eq(Relationships.points(NPC_ID), 15)


func test_talk_again_next_day_grants_again() -> void:
	Relationships.talk(NPC_ID)
	Clock.day += 1
	assert_true(Relationships.talk(NPC_ID))
	assert_eq(Relationships.points(NPC_ID), 30)


func test_talk_on_festival_day_grants_bonus() -> void:
	Clock.day = 14  # Spring 14 — Sowing Festival
	assert_true(Relationships.talk(NPC_ID))
	assert_eq(Relationships.points(NPC_ID), 15 + 30)


func test_talk_emits_relationship_changed() -> void:
	watch_signals(EventBus)
	Relationships.talk(NPC_ID)
	assert_signal_emitted_with_parameters(EventBus, "relationship_changed", [NPC_ID])


# ---- gift ----

func _npc(loved: Array = [], liked: Array = [], disliked: Array = [],
		liked_categories: Array = [], birthday_season: int = -1, birthday_day: int = -1) -> NPCData:
	var d := NPCData.new()
	d.id = NPC_ID
	var loved_typed: Array[String] = []
	loved_typed.assign(loved)
	d.loved_items = loved_typed
	var liked_typed: Array[String] = []
	liked_typed.assign(liked)
	d.liked_items = liked_typed
	var disliked_typed: Array[String] = []
	disliked_typed.assign(disliked)
	d.disliked_items = disliked_typed
	var categories_typed: Array[String] = []
	categories_typed.assign(liked_categories)
	d.liked_categories = categories_typed
	d.birthday_season = birthday_season
	d.birthday_day = birthday_day
	return d


func test_gift_loved_grants_eighty() -> void:
	var npc := _npc(["pumpkin"])
	assert_eq(Relationships.gift(NPC_ID, "pumpkin", npc), "loved")
	assert_eq(Relationships.points(NPC_ID), 80)


func test_gift_liked_grants_forty_five() -> void:
	var npc := _npc([], ["turnip"])
	assert_eq(Relationships.gift(NPC_ID, "turnip", npc), "liked")
	assert_eq(Relationships.points(NPC_ID), 45)


func test_gift_neutral_grants_twenty() -> void:
	var npc := _npc()
	assert_eq(Relationships.gift(NPC_ID, "iron_sword", npc), "neutral")
	assert_eq(Relationships.points(NPC_ID), 20)


func test_gift_disliked_loses_twenty() -> void:
	var npc := _npc([], [], ["slime_gel"])
	assert_eq(Relationships.gift(NPC_ID, "slime_gel", npc), "disliked")
	assert_eq(Relationships.points(NPC_ID), -20)


func test_gift_liked_category_matches() -> void:
	var npc := _npc([], [], [], ["any_crop"])
	assert_eq(Relationships.gift(NPC_ID, "carrot", npc), "liked")


func test_gift_once_per_day() -> void:
	var npc := _npc(["pumpkin"])
	Relationships.gift(NPC_ID, "pumpkin", npc)
	assert_eq(Relationships.gift(NPC_ID, "turnip", npc), "already")
	assert_eq(Relationships.points(NPC_ID), 80, "second gift attempt today must not add points")


func test_gift_again_next_day_works() -> void:
	var npc := _npc(["pumpkin"])
	Relationships.gift(NPC_ID, "pumpkin", npc)
	Clock.day += 1
	assert_eq(Relationships.gift(NPC_ID, "pumpkin", npc), "loved")
	assert_eq(Relationships.points(NPC_ID), 160)


func test_gift_on_birthday_multiplies_by_eight() -> void:
	Clock.day = 19  # Spring 19 (Marta's canonical birthday)
	var npc := _npc(["pumpkin"], [], [], [], 0, 19)
	assert_eq(Relationships.gift(NPC_ID, "pumpkin", npc), "loved")
	assert_eq(Relationships.points(NPC_ID), 80 * 8)


func test_gift_disliked_on_birthday_also_multiplied() -> void:
	Clock.day = 19
	var npc := _npc([], [], ["slime_gel"], [], 0, 19)
	assert_eq(Relationships.gift(NPC_ID, "slime_gel", npc), "disliked")
	assert_eq(Relationships.points(NPC_ID), -20 * 8)


func test_gift_reaction_preview_does_not_mutate_state() -> void:
	var npc := _npc(["pumpkin"])
	assert_eq(Relationships.gift_reaction(NPC_ID, "pumpkin", npc), "loved")
	assert_eq(Relationships.points(NPC_ID), 0, "preview must not add points")
	assert_false(Relationships.has_gifted_today(NPC_ID))


# ---- decay ----

func test_decay_untalked_at_stranger_does_not_decay() -> void:
	Relationships._get_or_create(NPC_ID)["points"] = 50
	Clock.day = 2
	Relationships._on_day_passed(2)
	assert_eq(Relationships.points(NPC_ID), 50, "decay only applies at L2+")


func test_decay_untalked_at_acquaintance_loses_two() -> void:
	Relationships._get_or_create(NPC_ID)["points"] = 250
	Relationships._on_day_passed(2)
	assert_eq(Relationships.points(NPC_ID), 248)


func test_decay_floors_at_tier_base_never_drops_a_tier() -> void:
	Relationships._get_or_create(NPC_ID)["points"] = 201
	for i in 20:
		Relationships._on_day_passed(i)
	assert_eq(Relationships.points(NPC_ID), 200, "must floor at ACQUAINT's base, never reach STRANGER")


func test_decay_skips_npc_talked_today() -> void:
	Clock.day = 1
	Relationships._get_or_create(NPC_ID)["points"] = 250
	Relationships.talk(NPC_ID)  # sets talked_day = 1, adds points
	var before := Relationships.points(NPC_ID)
	Relationships._on_day_passed(1)
	assert_eq(Relationships.points(NPC_ID), before, "talked today must not also decay same tick")


func test_day_passed_signal_triggers_decay() -> void:
	Relationships._get_or_create(NPC_ID)["points"] = 250
	Clock.day = 2
	EventBus.day_passed.emit(2)
	assert_eq(Relationships.points(NPC_ID), 248)


# ---- heart-event gate ----

func test_pending_event_empty_below_level_three() -> void:
	Relationships._get_or_create(NPC_ID)["points"] = 299
	assert_eq(Relationships.pending_event(NPC_ID), "")


func test_pending_event_l3_at_level_three() -> void:
	Relationships._get_or_create(NPC_ID)["points"] = 300
	assert_eq(Relationships.pending_event(NPC_ID), "l3")


func test_pending_event_l3_cleared_after_marking_seen() -> void:
	Relationships._get_or_create(NPC_ID)["points"] = 300
	Relationships.mark_event_seen(NPC_ID, "l3")
	assert_eq(Relationships.pending_event(NPC_ID), "")


func test_pending_event_l7_after_l3_seen() -> void:
	Relationships._get_or_create(NPC_ID)["points"] = 700
	Relationships.mark_event_seen(NPC_ID, "l3")
	assert_eq(Relationships.pending_event(NPC_ID), "l7")


func test_apply_heart_event_choice_empathetic_adds_thirty() -> void:
	Relationships._get_or_create(NPC_ID)["points"] = 300
	Relationships.apply_heart_event_choice(NPC_ID, true)
	assert_eq(Relationships.points(NPC_ID), 330)


func test_apply_heart_event_choice_dismissive_subtracts_thirty() -> void:
	Relationships._get_or_create(NPC_ID)["points"] = 300
	Relationships.apply_heart_event_choice(NPC_ID, false)
	assert_eq(Relationships.points(NPC_ID), 270)


# ---- perk gate ----

func test_pending_perk_empty_below_level_five() -> void:
	Relationships._get_or_create(NPC_ID)["points"] = 499
	assert_eq(Relationships.pending_perk(NPC_ID), "")


func test_pending_perk_l5_at_level_five() -> void:
	Relationships._get_or_create(NPC_ID)["points"] = 500
	assert_eq(Relationships.pending_perk(NPC_ID), "l5")


func test_pending_perk_l8_after_l5_given() -> void:
	Relationships._get_or_create(NPC_ID)["points"] = 800
	Relationships.mark_perk_given(NPC_ID, "l5")
	assert_eq(Relationships.pending_perk(NPC_ID), "l8")


func test_pending_perk_cleared_after_marking_given() -> void:
	Relationships._get_or_create(NPC_ID)["points"] = 500
	Relationships.mark_perk_given(NPC_ID, "l5")
	assert_eq(Relationships.pending_perk(NPC_ID), "")


# ---- shown-line tracking ----

func test_shown_indices_starts_empty() -> void:
	assert_eq(Relationships.shown_indices(NPC_ID, "STRANGER"), [])


func test_mark_line_shown_and_retrieve() -> void:
	Relationships.mark_line_shown(NPC_ID, "STRANGER", 2)
	Relationships.mark_line_shown(NPC_ID, "STRANGER", 0)
	assert_eq(Relationships.shown_indices(NPC_ID, "STRANGER"), [2, 0])


func test_mark_line_shown_idempotent() -> void:
	Relationships.mark_line_shown(NPC_ID, "STRANGER", 1)
	Relationships.mark_line_shown(NPC_ID, "STRANGER", 1)
	assert_eq(Relationships.shown_indices(NPC_ID, "STRANGER"), [1])


func test_reset_shown_clears_tier_only() -> void:
	Relationships.mark_line_shown(NPC_ID, "STRANGER", 0)
	Relationships.mark_line_shown(NPC_ID, "ACQUAINT", 0)
	Relationships.reset_shown(NPC_ID, "STRANGER")
	assert_eq(Relationships.shown_indices(NPC_ID, "STRANGER"), [])
	assert_eq(Relationships.shown_indices(NPC_ID, "ACQUAINT"), [0])


# ---- JSON round-trip ----

func test_relationships_blob_survives_json_round_trip() -> void:
	Relationships.talk(NPC_ID)
	Relationships.mark_event_seen(NPC_ID, "l3")
	Relationships.mark_perk_given(NPC_ID, "l5")
	Relationships.mark_line_shown(NPC_ID, "STRANGER", 3)
	var stringified := JSON.stringify(SaveManager.world)
	var round_tripped = JSON.parse_string(stringified)
	Relationships._state = {}
	SaveManager.world = round_tripped
	Relationships.restore()
	assert_eq(Relationships.points(NPC_ID), 15)
	assert_true(Relationships.has_talked_today(NPC_ID))
	assert_eq(Relationships.pending_event(NPC_ID), "")
	assert_eq(Relationships.pending_perk(NPC_ID), "")
	assert_eq(Relationships.shown_indices(NPC_ID, "STRANGER"), [3])
	assert_eq(typeof(Relationships.points(NPC_ID)), TYPE_INT)


func test_restore_defaults_when_blob_missing() -> void:
	SaveManager.world.erase("relationships")
	Relationships.restore()
	assert_eq(Relationships.points(NPC_ID), 0)
	assert_eq(Relationships.level(NPC_ID), 0)
