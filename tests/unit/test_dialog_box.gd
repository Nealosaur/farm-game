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
