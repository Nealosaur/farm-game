extends GutTest
## DialogBox: line-by-line advance, tree pause while open, finished signal,
## and the documented queue-safe policy (show_lines is ignored while open).

var dialog: DialogBox


func before_each() -> void:
	dialog = (load("res://scripts/ui/dialog_box.gd") as GDScript).new() as DialogBox
	add_child_autofree(dialog)


func after_each() -> void:
	get_tree().paused = false


func test_show_lines_opens_and_pauses_tree() -> void:
	var lines: Array[String] = ["Hello", "World"]
	dialog.show_lines(lines)
	assert_true(dialog.is_open())
	assert_true(get_tree().paused)
	assert_eq(dialog.label.text, "Hello")


func test_advance_moves_to_next_line() -> void:
	var lines: Array[String] = ["Hello", "World"]
	dialog.show_lines(lines)
	dialog._advance()
	assert_true(dialog.is_open())
	assert_eq(dialog.label.text, "World")


func test_advance_past_last_line_closes_and_unpauses() -> void:
	var lines: Array[String] = ["Only one line"]
	dialog.show_lines(lines)
	dialog._advance()
	assert_false(dialog.is_open())
	assert_false(get_tree().paused)


func test_finished_signal_emitted_on_close() -> void:
	watch_signals(dialog)
	var lines: Array[String] = ["Bye"]
	dialog.show_lines(lines)
	dialog._advance()
	assert_signal_emitted(dialog, "finished")


func test_show_lines_ignored_while_already_open() -> void:
	var lines: Array[String] = ["First"]
	dialog.show_lines(lines)
	var other: Array[String] = ["Second", "Third"]
	dialog.show_lines(other)
	assert_eq(dialog.label.text, "First", "second call must be ignored per queue-safe policy")


func test_show_lines_with_empty_array_is_noop() -> void:
	var empty: Array[String] = []
	dialog.show_lines(empty)
	assert_false(dialog.is_open())


# ---- choice-row API (World Stride B) ----

func test_show_choices_plays_lines_then_shows_buttons() -> void:
	var lines: Array[String] = ["Setup line"]
	var choices: Array[String] = ["Option A", "Option B"]
	dialog.show_choices(lines, choices)
	assert_true(dialog.is_open())
	assert_eq(dialog.label.text, "Setup line")
	dialog._advance()  # past the only line -> should reveal buttons, not close
	assert_true(dialog.is_open(), "choices must keep the box open")
	assert_eq(dialog.choice_box.get_child_count(), 2)


func test_picking_a_choice_emits_choice_made_with_index() -> void:
	var lines: Array[String] = ["Line"]
	var choices: Array[String] = ["First", "Second"]
	dialog.show_choices(lines, choices)
	dialog._advance()
	watch_signals(dialog)
	(dialog.choice_box.get_child(1) as Button).pressed.emit()
	assert_signal_emitted_with_parameters(dialog, "choice_made", [1])


func test_picking_a_choice_closes_the_box() -> void:
	var lines: Array[String] = ["Line"]
	var choices: Array[String] = ["Only"]
	dialog.show_choices(lines, choices)
	dialog._advance()
	(dialog.choice_box.get_child(0) as Button).pressed.emit()
	assert_false(dialog.is_open())
	assert_false(get_tree().paused)


func test_advance_ignored_while_choice_buttons_shown() -> void:
	var lines: Array[String] = ["Line"]
	var choices: Array[String] = ["A", "B"]
	dialog.show_choices(lines, choices)
	dialog._advance()  # reveals buttons
	dialog._advance()  # should be a no-op — must not close or clear buttons
	assert_true(dialog.is_open())
	assert_eq(dialog.choice_box.get_child_count(), 2)


func test_show_choices_ignored_while_already_open() -> void:
	var lines: Array[String] = ["First"]
	dialog.show_lines(lines)
	var more_lines: Array[String] = ["Second"]
	var choices: Array[String] = ["X"]
	dialog.show_choices(more_lines, choices)
	assert_eq(dialog.label.text, "First")


func test_show_choices_with_empty_choices_is_noop() -> void:
	var lines: Array[String] = ["Line"]
	var empty: Array[String] = []
	dialog.show_choices(lines, empty)
	assert_false(dialog.is_open())
