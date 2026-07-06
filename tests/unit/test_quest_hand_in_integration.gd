extends GutTest
## World Stride D: quest grant/hand-in through the REAL town-scene NPC nodes
## (Alden for New Roots, Garrick for Prove It / The King Below) — mirrors
## test_town_npc_integration.gd's shape/cleanup discipline.
##
## NOT covered headless (same documented tradeoff as test_town_npc_integration):
## actual portal travel between scenes.

const TOWN_SCENE := "res://scenes/maps/town.tscn"


func before_each() -> void:
	Clock.paused = true
	SaveManager.world.erase("relationships")
	SaveManager.world.erase("quests")
	SaveManager.save_path = "user://test_quest_hand_in.json"
	SaveManager.new_game()
	Clock.weather = "clear"
	Clock.day = 1
	Clock.minutes = 13 * 60  # 12-17 block: Alden on plaza walk, Garrick at the saloon
	Relationships._state = {}
	Quests._quests = {}
	GameState.flags = {}
	SceneChanger.spawn_name = "default"


func after_each() -> void:
	Clock.paused = false
	Clock.minutes = Clock.DAY_START_MINUTES
	Clock.day = 1
	Clock.weather = "clear"
	Relationships._state = {}
	Quests._quests = {}
	GameState.flags = {}
	SaveManager.world.erase("relationships")
	SaveManager.world.erase("quests")
	SceneChanger.spawn_name = "default"
	SaveManager.save_path = "user://save1.json"
	if FileAccess.file_exists("user://test_quest_hand_in.json"):
		DirAccess.remove_absolute("user://test_quest_hand_in.json")


func _make_town() -> Node2D:
	return (load(TOWN_SCENE) as PackedScene).instantiate()


## Advances through the dialog's own lines, then picks the LAST offered
## choice ("Leave", matching test_town_npc_integration's pattern) so the
## dialog fully closes without side effects from a gift/shop choice.
func _close_dialog_via_leave(dialog: DialogBox) -> void:
	dialog._advance()
	if dialog.is_open() and dialog.choice_box.get_child_count() > 0:
		var last := dialog.choice_box.get_child(dialog.choice_box.get_child_count() - 1) as Button
		last.pressed.emit()


func _force_close_if_open(dialog: DialogBox) -> void:
	## Same "never leave the tree paused for the next test" safety net
	## test_town_npc_integration.gd documents.
	if dialog.is_open():
		dialog._advance()
		if dialog.is_open() and dialog.choice_box.get_child_count() > 0:
			(dialog.choice_box.get_child(dialog.choice_box.get_child_count() - 1) as Button).pressed.emit()


func test_talking_to_alden_before_new_roots_done_is_ordinary_talk() -> void:
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	town.npcs["alden"].interact(town.player)
	assert_true(dialog.is_open())
	_force_close_if_open(dialog)
	assert_false(Quests.has_quest(Quests.ID_NEW_ROOTS))


func test_alden_hands_in_new_roots_on_next_talk_after_completion() -> void:
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	Quests.grant_new_roots()
	for npc_id: String in Quests.NEW_ROOTS_NPCS:
		Quests.record_talk(npc_id)
	assert_true(Quests.is_done(Quests.ID_NEW_ROOTS))

	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	GameState.gold = 0
	town.npcs["alden"].interact(town.player)
	assert_true(dialog.is_open())
	assert_eq(dialog.label.text, AldenDialog.DATA["new_roots_hand_in"],
		"the hand-in line must show FIRST, ahead of the ordinary resolved line")
	_force_close_if_open(dialog)
	assert_eq(GameState.gold, 300)
	# new_game()'s starting kit already grants 5 turnip_seeds (see
	# SaveManager.new_game()) — the hand-in adds 5 MORE on top, so 10 total.
	assert_eq(Inventory.count_of("turnip_seeds"), 10)
	assert_false(Quests.has_quest(Quests.ID_NEW_ROOTS))


func test_talking_to_garrick_grants_prove_it() -> void:
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	town.npcs["garrick"].interact(town.player)
	_force_close_if_open(dialog)
	assert_true(Quests.is_active(Quests.ID_PROVE_IT))


func test_garrick_hands_in_prove_it_and_chains_king_below() -> void:
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	Quests.grant_prove_it()
	Quests.record_floor_entered("dungeon_2")
	assert_true(Quests.is_done(Quests.ID_PROVE_IT))

	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	GameState.gold = 0
	town.npcs["garrick"].interact(town.player)
	assert_true(dialog.is_open())
	assert_eq(dialog.label.text, GarrickDialog.DATA["quests"]["prove_it_hand_in"])
	_force_close_if_open(dialog)
	assert_eq(GameState.gold, 200)
	assert_false(Quests.has_quest(Quests.ID_PROVE_IT))
	assert_true(Quests.is_active(Quests.ID_KING_BELOW))


func test_garrick_hands_in_prove_it_and_king_below_same_talk_when_boss_already_defeated() -> void:
	## If the player somehow beats the Slime King before ever handing in
	## "Prove It" (e.g. speedran floor 3 without talking to Garrick again),
	## the SAME conversation that hands in Prove It also grants AND
	## instantly completes King Below (Quests.grant_king_below() checks the
	## flag) — Garrick should hand in both rewards in one talk.
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	Quests.grant_prove_it()
	Quests.record_floor_entered("dungeon_2")
	GameState.flags["boss_defeated"] = true  # boss beaten before the hand-in talk
	assert_true(Quests.is_done(Quests.ID_PROVE_IT))

	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	GameState.gold = 0
	town.npcs["garrick"].interact(town.player)
	assert_true(dialog.is_open())
	assert_eq(dialog.label.text, GarrickDialog.DATA["quests"]["prove_it_hand_in"],
		"prove_it's hand-in line must show first")
	dialog._advance()
	assert_eq(dialog.label.text, GarrickDialog.DATA["quests"]["king_below_hand_in_already_defeated"],
		"king_below's already-defeated hand-in line must show in the SAME conversation")
	_force_close_if_open(dialog)

	assert_eq(GameState.gold, 200 + 500, "both quests' rewards must be paid out in one talk")
	assert_false(Quests.has_quest(Quests.ID_PROVE_IT))
	assert_false(Quests.has_quest(Quests.ID_KING_BELOW))


func test_garrick_hands_in_king_below_ordinary_line() -> void:
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	GameState.flags.erase("boss_defeated")
	Quests.grant_king_below()
	GameState.flags["boss_defeated"] = true
	Quests.check_boss_defeated()
	assert_true(Quests.is_done(Quests.ID_KING_BELOW))

	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	GameState.gold = 0
	town.npcs["garrick"].interact(town.player)
	assert_eq(dialog.label.text, GarrickDialog.DATA["quests"]["king_below_hand_in"])
	_force_close_if_open(dialog)
	assert_eq(GameState.gold, 500)


func test_garrick_hands_in_king_below_already_defeated_line() -> void:
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	GameState.flags["boss_defeated"] = true
	Quests.grant_king_below()  # boss already defeated -> instantly done, already_met_king=true
	assert_true(Quests.is_done(Quests.ID_KING_BELOW))

	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	GameState.gold = 0
	town.npcs["garrick"].interact(town.player)
	assert_eq(dialog.label.text, GarrickDialog.DATA["quests"]["king_below_hand_in_already_defeated"])
	_force_close_if_open(dialog)
	assert_eq(GameState.gold, 500)
