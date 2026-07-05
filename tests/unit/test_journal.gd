extends GutTest
## Journal: K ("journal" action) toggles, Esc closes while open, SOCIAL tab
## renders every NPCS entry with level/tier/birthday/talked/gifted, QUESTS
## tab shows the placeholder.

var journal: Journal


func before_each() -> void:
	Relationships._state = {}
	SaveManager.world.erase("relationships")
	Clock.day = 1
	journal = (load("res://scripts/ui/journal.gd") as GDScript).new() as Journal
	add_child_autofree(journal)


func after_each() -> void:
	get_tree().paused = false
	Relationships._state = {}
	SaveManager.world.erase("relationships")
	Clock.day = 1


func _press(action: String) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev


# ---- open/close ----

func test_journal_action_opens_and_pauses_tree() -> void:
	journal._unhandled_input(_press("journal"))
	assert_true(journal.is_open())
	assert_true(get_tree().paused)


func test_journal_action_toggles_closed_again() -> void:
	journal._unhandled_input(_press("journal"))
	journal._unhandled_input(_press("journal"))
	assert_false(journal.is_open())
	assert_false(get_tree().paused)


func test_pause_closes_journal_while_open() -> void:
	journal.open()
	journal._unhandled_input(_press("pause"))
	assert_false(journal.is_open())
	assert_false(get_tree().paused)


func test_pause_ignored_while_journal_closed() -> void:
	journal._unhandled_input(_press("pause"))
	assert_false(journal.is_open(), "pause must not open the journal")


# ---- SOCIAL tab ----

func test_social_tab_lists_registered_npcs() -> void:
	journal.open()
	assert_eq(journal.social_list.get_child_count(), journal.NPCS.size())


func test_social_row_shows_level_and_tier() -> void:
	Relationships._get_or_create("marta")["points"] = 250  # level 2, ACQUAINT
	journal.open()
	var row := journal.social_list.get_child(0)
	var header := row.get_child(0) as Label
	assert_true(header.text.contains("Marta"))
	assert_true(header.text.contains("ACQUAINT"))
	assert_true(header.text.contains("Lv 2"))


func test_social_row_shows_talked_and_gifted_checkmarks() -> void:
	Relationships.talk("marta")
	journal.open()
	var row := journal.social_list.get_child(0)
	var detail := row.get_child(2) as Label
	assert_true(detail.text.contains("Talked today: yes"))
	assert_true(detail.text.contains("Gifted today: no"))


func test_social_row_shows_birthday() -> void:
	journal.open()
	var row := journal.social_list.get_child(0)
	var detail := row.get_child(2) as Label
	assert_true(detail.text.contains("Spring 19"), "Marta's birthday must be shown")


func test_relationship_changed_refreshes_open_journal() -> void:
	journal.open()
	Relationships.talk("marta")
	var row := journal.social_list.get_child(0)
	var detail := row.get_child(2) as Label
	assert_true(detail.text.contains("Talked today: yes"))


# ---- QUESTS tab ----

func test_quests_tab_shows_placeholder() -> void:
	assert_eq(journal.quests_label.text, "No active quests")
