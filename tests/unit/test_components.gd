extends GutTest


class TrackState:
	extends State
	var entered := 0
	var exited := 0

	func enter() -> void:
		entered += 1

	func exit() -> void:
		exited += 1


func _make_machine() -> StateMachine:
	var root := Node.new()
	var machine := StateMachine.new()
	machine.name = "StateMachine"
	var a := TrackState.new()
	a.name = "A"
	var b := TrackState.new()
	b.name = "B"
	machine.add_child(a)
	machine.add_child(b)
	machine.initial_state = a
	root.add_child(machine)
	add_child_autofree(root)
	return machine


func test_machine_starts_in_initial_state() -> void:
	var m := _make_machine()
	assert_eq(m.current.name, "A")
	assert_eq((m.current as TrackState).entered, 1)


func test_transition_switches_and_calls_hooks() -> void:
	var m := _make_machine()
	var a := m.get_node("A") as TrackState
	m.transition("B")
	assert_eq(m.current.name, "B")
	assert_eq(a.exited, 1)
	assert_eq((m.current as TrackState).entered, 1)


func test_transition_to_unknown_state_is_safe() -> void:
	var m := _make_machine()
	m.transition("Nope")
	assert_eq(m.current.name, "A")


func test_placeholder_frames_builds_all_animations() -> void:
	var tex := load("res://assets/placeholder/char_player.png") as Texture2D
	var names := PackedStringArray(["idle_down", "walk_left", "use_up"])
	var frames := PlaceholderFrames.build(tex, names)
	for n in names:
		assert_true(frames.has_animation(n))
		assert_eq(frames.get_frame_count(n), 1)
	assert_false(frames.has_animation("default"))
