extends GutTest
## World Stride D: Quests autoload — grant/progress/complete/hand-in
## lifecycle for new_roots/prove_it/king_below, plus the JSON round-trip.


func before_each() -> void:
	Quests._quests = {}
	SaveManager.world.erase("quests")
	GameState.flags = {}
	Clock.day = 1


func after_each() -> void:
	Quests._quests = {}
	SaveManager.world.erase("quests")
	GameState.flags = {}
	Clock.day = 1


# ---- new_roots ----

func test_grant_new_roots_makes_it_active() -> void:
	Quests.grant_new_roots()
	assert_true(Quests.is_active(Quests.ID_NEW_ROOTS))
	assert_eq(Quests.met_npcs(Quests.ID_NEW_ROOTS), [])


func test_grant_new_roots_twice_is_idempotent() -> void:
	Quests.grant_new_roots()
	Quests.record_talk("marta")
	Quests.grant_new_roots()  # must not reset progress
	assert_eq(Quests.met_npcs(Quests.ID_NEW_ROOTS), ["marta"])


func test_record_talk_tracks_first_ever_meeting() -> void:
	Quests.grant_new_roots()
	Quests.record_talk("marta")
	assert_eq(Quests.met_npcs(Quests.ID_NEW_ROOTS), ["marta"])


func test_record_talk_does_not_duplicate_same_npc() -> void:
	Quests.grant_new_roots()
	Quests.record_talk("marta")
	Quests.record_talk("marta")
	assert_eq(Quests.met_npcs(Quests.ID_NEW_ROOTS), ["marta"])


func test_record_talk_ignored_when_new_roots_not_active() -> void:
	Quests.record_talk("marta")
	assert_eq(Quests.met_npcs(Quests.ID_NEW_ROOTS), [])


func test_record_talk_ignores_unknown_npc_ids() -> void:
	Quests.grant_new_roots()
	Quests.record_talk("not_a_real_npc")
	assert_eq(Quests.met_npcs(Quests.ID_NEW_ROOTS), [])


func test_new_roots_completes_once_all_eight_met() -> void:
	Quests.grant_new_roots()
	for npc_id: String in Quests.NEW_ROOTS_NPCS:
		Quests.record_talk(npc_id)
	assert_true(Quests.is_done(Quests.ID_NEW_ROOTS))


func test_new_roots_not_done_with_seven_of_eight() -> void:
	Quests.grant_new_roots()
	for i in 7:
		Quests.record_talk(Quests.NEW_ROOTS_NPCS[i])
	assert_true(Quests.is_active(Quests.ID_NEW_ROOTS))
	assert_false(Quests.is_done(Quests.ID_NEW_ROOTS))


func test_new_roots_progress_text() -> void:
	Quests.grant_new_roots()
	Quests.record_talk("marta")
	Quests.record_talk("sten")
	assert_eq(Quests.progress_text(Quests.ID_NEW_ROOTS), "Met 2/8")


func test_hand_in_new_roots_grants_gold_and_seeds() -> void:
	Inventory.reset()
	GameState.gold = 0
	Quests.grant_new_roots()
	for npc_id: String in Quests.NEW_ROOTS_NPCS:
		Quests.record_talk(npc_id)
	assert_true(Quests.hand_in_new_roots())
	assert_eq(GameState.gold, 300)
	assert_eq(Inventory.count_of("turnip_seeds"), 5)
	assert_false(Quests.has_quest(Quests.ID_NEW_ROOTS), "hand-in retires the quest")


func test_hand_in_new_roots_fails_before_completion() -> void:
	Quests.grant_new_roots()
	assert_false(Quests.hand_in_new_roots())


func test_hand_in_new_roots_only_pays_once() -> void:
	Inventory.reset()
	GameState.gold = 0
	Quests.grant_new_roots()
	for npc_id: String in Quests.NEW_ROOTS_NPCS:
		Quests.record_talk(npc_id)
	Quests.hand_in_new_roots()
	assert_false(Quests.hand_in_new_roots(), "second hand-in attempt must no-op")
	assert_eq(GameState.gold, 300)


# ---- prove_it ----

func test_grant_prove_it_makes_it_active() -> void:
	Quests.grant_prove_it()
	assert_true(Quests.is_active(Quests.ID_PROVE_IT))


func test_record_floor_entered_dungeon_2_completes_prove_it() -> void:
	Quests.grant_prove_it()
	Quests.record_floor_entered("dungeon_2")
	assert_true(Quests.is_done(Quests.ID_PROVE_IT))


func test_record_floor_entered_dungeon_3_also_completes_prove_it() -> void:
	Quests.grant_prove_it()
	Quests.record_floor_entered("dungeon_3")
	assert_true(Quests.is_done(Quests.ID_PROVE_IT))


func test_record_floor_entered_dungeon_1_does_not_complete_prove_it() -> void:
	Quests.grant_prove_it()
	Quests.record_floor_entered("dungeon_1")
	assert_true(Quests.is_active(Quests.ID_PROVE_IT))


func test_record_floor_entered_ignored_when_prove_it_not_active() -> void:
	Quests.record_floor_entered("dungeon_2")
	assert_false(Quests.has_quest(Quests.ID_PROVE_IT))


func test_hand_in_prove_it_grants_gold_and_chains_king_below() -> void:
	GameState.gold = 0
	Quests.grant_prove_it()
	Quests.record_floor_entered("dungeon_2")
	assert_true(Quests.hand_in_prove_it())
	assert_eq(GameState.gold, 200)
	assert_false(Quests.has_quest(Quests.ID_PROVE_IT))
	assert_true(Quests.is_active(Quests.ID_KING_BELOW), "hand-in prove_it must grant king_below")


# ---- king_below ----

func test_grant_king_below_active_when_boss_not_yet_defeated() -> void:
	GameState.flags.erase("boss_defeated")
	Quests.grant_king_below()
	assert_true(Quests.is_active(Quests.ID_KING_BELOW))


func test_grant_king_below_instantly_done_when_boss_already_defeated() -> void:
	GameState.flags["boss_defeated"] = true
	Quests.grant_king_below()
	assert_true(Quests.is_done(Quests.ID_KING_BELOW))


func test_boss_defeated_signal_completes_active_king_below() -> void:
	Quests.grant_king_below()
	assert_true(Quests.is_active(Quests.ID_KING_BELOW))
	GameState.flags["boss_defeated"] = true
	EventBus.boss_defeated.emit()
	assert_true(Quests.is_done(Quests.ID_KING_BELOW))


func test_hand_in_king_below_ordinary_path() -> void:
	GameState.gold = 0
	GameState.flags.erase("boss_defeated")
	Quests.grant_king_below()
	GameState.flags["boss_defeated"] = true
	Quests.check_boss_defeated()
	var result := Quests.hand_in_king_below()
	assert_true(result["handed_in"])
	assert_false(result["already_met_king"])
	assert_eq(GameState.gold, 500)
	assert_false(Quests.has_quest(Quests.ID_KING_BELOW))


func test_hand_in_king_below_already_defeated_path() -> void:
	GameState.gold = 0
	GameState.flags["boss_defeated"] = true
	Quests.grant_king_below()  # instantly done, already_met_king = true
	var result := Quests.hand_in_king_below()
	assert_true(result["handed_in"])
	assert_true(result["already_met_king"])
	assert_eq(GameState.gold, 500)


func test_hand_in_king_below_fails_before_completion() -> void:
	GameState.flags.erase("boss_defeated")
	Quests.grant_king_below()
	var result := Quests.hand_in_king_below()
	assert_false(result["handed_in"])


# ---- JSON round-trip ----

func test_quests_blob_survives_json_round_trip() -> void:
	Quests.grant_new_roots()
	Quests.record_talk("marta")
	Quests.record_talk("sten")
	var stringified := JSON.stringify(SaveManager.world)
	var round_tripped = JSON.parse_string(stringified)
	Quests._quests = {}
	SaveManager.world = round_tripped
	Quests.restore()
	assert_true(Quests.is_active(Quests.ID_NEW_ROOTS))
	assert_eq(Quests.met_npcs(Quests.ID_NEW_ROOTS), ["marta", "sten"])
	assert_eq(typeof(Quests.met_npcs(Quests.ID_NEW_ROOTS)[0]), TYPE_STRING)


func test_restore_defaults_when_blob_missing() -> void:
	SaveManager.world.erase("quests")
	Quests.restore()
	assert_false(Quests.has_quest(Quests.ID_NEW_ROOTS))


# ---- journal helpers ----

func test_active_quest_ids_sorted() -> void:
	Quests.grant_prove_it()
	Quests.grant_new_roots()
	assert_eq(Quests.active_quest_ids(), [Quests.ID_NEW_ROOTS, Quests.ID_PROVE_IT])


func test_done_quest_ids_only_lists_done() -> void:
	Quests.grant_prove_it()
	Quests.record_floor_entered("dungeon_2")
	Quests.grant_new_roots()
	assert_eq(Quests.done_quest_ids(), [Quests.ID_PROVE_IT])
	assert_eq(Quests.active_quest_ids(), [Quests.ID_NEW_ROOTS])
