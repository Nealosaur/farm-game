extends GutTest
## Headless integration for World Stride B's NPC framework wired into the
## real town scene: Marta is placed per NPCRegistry block (driven via
## Clock.minutes / EventBus.time_ticked), talking through the real Marta
## node grants bond once/day, and a heart event fires + applies its choice
## at the real gate thresholds.
##
## NOT covered headless (same documented tradeoff as test_dungeon_integration):
## actual portal travel. This only instantiates town.tscn directly and drives
## time within it.

const TOWN_SCENE := "res://scenes/maps/town.tscn"


func before_each() -> void:
	Clock.paused = true
	SaveManager.world.erase("relationships")
	SaveManager.save_path = "user://test_town_npc.json"
	SaveManager.new_game()  # rolls REAL weather (Spring day 1 is 30% rain) — force clear right after
	Clock.weather = "clear"  # Marta's schedule has a documented rain override; force clear so
	                         # block-placement assertions below test the NORMAL schedule, not rain's.
	Clock.day = 1
	Clock.minutes = 10 * 60  # 10 AM: store-counter block (9-12)
	Relationships._state = {}
	SceneChanger.spawn_name = "default"


func after_each() -> void:
	Clock.paused = false
	Clock.minutes = Clock.DAY_START_MINUTES
	Clock.day = 1
	Clock.weather = "clear"
	Relationships._state = {}
	SaveManager.world.erase("relationships")
	SceneChanger.spawn_name = "default"
	SaveManager.save_path = "user://save1.json"
	if FileAccess.file_exists("user://test_town_npc.json"):
		DirAccess.remove_absolute("user://test_town_npc.json")


func _make_town() -> Node2D:
	return (load(TOWN_SCENE) as PackedScene).instantiate()


func test_town_boots_with_marta_placed_at_counter_during_store_hours() -> void:
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	assert_not_null(town.marta)
	assert_true(town.marta.visible)
	assert_eq(town.marta.position, MapBuilder.cell_center(MartaData.CELL_COUNTER))


func test_marta_moves_to_plaza_bench_at_block_change() -> void:
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	Clock.minutes = 18 * 60  # 17-20 block: plaza bench
	EventBus.time_ticked.emit(Clock.hour(), Clock.minute())
	assert_eq(town.marta.position, MapBuilder.cell_center(MartaData.CELL_PLAZA_BENCH))


func test_marta_stays_at_counter_all_day_when_raining() -> void:
	# Bible: Marta's rain override is "all blocks store" (except she still
	# goes home for the night). Force rain and confirm the 17-20 block
	# does NOT move her to the plaza bench like it does on a clear day.
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	Clock.weather = "rain"
	Clock.minutes = 18 * 60  # 17-20 block
	EventBus.time_ticked.emit(Clock.hour(), Clock.minute())
	assert_eq(town.marta.position, MapBuilder.cell_center(MartaData.CELL_COUNTER))


func test_marta_moves_home_at_night_block() -> void:
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	Clock.minutes = 21 * 60  # 20-2 block: home
	EventBus.time_ticked.emit(Clock.hour(), Clock.minute())
	assert_eq(town.marta.position, MapBuilder.cell_center(MartaData.CELL_HOME))


func test_talking_to_real_marta_node_grants_bond_once_per_day() -> void:
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	var dialog := town.get_node("DialogBox") if town.has_node("DialogBox") else get_tree().get_first_node_in_group("dialog_box")
	assert_not_null(dialog, "town must auto-instance a DialogBox")

	town.marta.interact(town.player)
	assert_eq(Relationships.points("marta"), 15)

	# Advance through the resolved line + choices to fully close, then talk again same day.
	dialog._advance()
	if dialog.is_open() and dialog.choice_box.get_child_count() > 0:
		var last := dialog.choice_box.get_child(dialog.choice_box.get_child_count() - 1) as Button
		last.pressed.emit()
	await wait_process_frames(2)

	town.marta.interact(town.player)
	assert_eq(Relationships.points("marta"), 15, "same-day second talk must not add points again")
	# This interact() opened a second dialog (a talk still shows a line even
	# when talk() itself no-ops) that would otherwise leak get_tree().paused
	# = true past this test — every later test in the suite that relies on
	# real frame/timer processing (wait_seconds, etc.) would then hang
	# forever waiting on a permanently-paused tree (World Stride C found this
	# the hard way via a full-suite hang). Close it synchronously (no await —
	# the tree may still be paused right now) before the test ends.
	if dialog.is_open():
		dialog._advance()
		if dialog.is_open() and dialog.choice_box.get_child_count() > 0:
			(dialog.choice_box.get_child(dialog.choice_box.get_child_count() - 1) as Button).pressed.emit()
	assert_false(get_tree().paused, "no test may leave the SceneTree paused for the next test")


func test_heart_event_fires_at_gate_and_choice_applies_delta() -> void:
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	Relationships._get_or_create("marta")["points"] = 300  # L3 gate

	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	town.marta.interact(town.player)
	assert_true(dialog.is_open())
	assert_eq(dialog.label.text, MartaDialog.DATA["heart_events"]["l3"]["lines"][0])

	dialog._advance()  # reveal the two-option choice
	assert_eq(dialog.choice_box.get_child_count(), 2)
	(dialog.choice_box.get_child(0) as Button).pressed.emit()  # empathetic [A]
	assert_eq(Relationships.points("marta"), 330)
	assert_eq(Relationships.pending_event("marta"), "")
