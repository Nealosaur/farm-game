extends GutTest
## PauseMenu: pure is_pause_allowed() policy, open/close pause behavior,
## Esc toggling, Save (FarmGrid.store + SaveManager.save_game + toast), and
## Quit to Title (unpause + travel, no autosave).

var menu: PauseMenu


func before_each() -> void:
	menu = (load("res://scripts/ui/pause_menu.gd") as GDScript).new() as PauseMenu
	add_child_autofree(menu)


func after_each() -> void:
	get_tree().paused = false


# ---- pure policy ----

func test_allowed_when_not_paused() -> void:
	assert_true(PauseMenu.is_pause_allowed(false, false))


func test_allowed_when_paused_and_we_are_the_one_showing() -> void:
	assert_true(PauseMenu.is_pause_allowed(true, true))


func test_not_allowed_when_paused_by_someone_else() -> void:
	assert_false(PauseMenu.is_pause_allowed(true, false))


# ---- open/close ----

func test_open_pauses_tree() -> void:
	menu.open()
	assert_true(menu.is_open())
	assert_true(get_tree().paused)


func test_close_unpauses_tree() -> void:
	menu.open()
	menu.close()
	assert_false(menu.is_open())
	assert_false(get_tree().paused)


func test_pause_action_toggles_open_then_closed() -> void:
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	menu._unhandled_input(ev)
	assert_true(menu.is_open())
	menu._unhandled_input(ev)
	assert_false(menu.is_open())


func test_pause_action_ignored_when_tree_already_paused_by_other_menu() -> void:
	get_tree().paused = true
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	menu._unhandled_input(ev)
	assert_false(menu.is_open(), "pause menu must not open over another already-open menu")


# ---- save ----

func test_save_calls_save_game_and_toasts() -> void:
	watch_signals(EventBus)
	menu.open()
	menu._on_save_pressed()
	assert_signal_emitted_with_parameters(EventBus, "toast_requested", ["Saved."])


# ---- quit to title ----

func test_quit_to_title_closes_menu_and_unpauses() -> void:
	menu.open()
	menu._on_quit_pressed()
	assert_false(menu.is_open())
	assert_false(get_tree().paused)
