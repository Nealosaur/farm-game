class_name PauseMenu
extends CanvasLayer
## Esc ("pause") toggles this tree-paused menu during gameplay: Resume / Save /
## Quit to Title. Follows the InventoryScreen/ShopScreen/DialogBox convention
## (get_tree().paused, this node keeps running via PROCESS_MODE_ALWAYS).
##
## Guard policy vs. other menus (documented, simplest-correct choice): other
## menus (DialogBox, ShopScreen, InventoryScreen) already pause the tree
## themselves and close on their OWN Esc handler. If the tree is already
## paused when Esc fires and this menu isn't the one showing, we do nothing —
## the owning menu's _unhandled_input handles its own close. This menu only
## ever opens from the unpaused gameplay state, and only ever closes itself
## (never another menu's). See is_pause_allowed() for the pure decision.
##
## C1 fix: also refuses to OPEN while GameFlow.cutscene_active is true (an
## EventRunner scene is mid-play — dialog/wait/move in flight but the tree
## itself isn't paused yet, since EventRunner drives its own frame-based
## wait/move via Clock.paused, not get_tree().paused). Without this gate,
## Quit to Title during a non-dialog cutscene moment (mid `wait`/`move`/
## `camera`, i.e. NOT the DialogBox's own Esc-blocking modal) would free the
## map/EventRunner out from under a live scene; see event_runner.gd's
## _exit_tree() for the matching backstop on the OTHER side of that same bug.
## is_pause_allowed() only decides "who does this Esc belong to" between
## menus already paused/showing — it doesn't know about cutscenes, so this
## check is a separate, earlier gate in open()/_unhandled_input(), not folded
## into that pure function's signature.
##
## Save: stores the live FarmGrid (if present — dungeon/town scenes have
## none) then SaveManager.save_game(), then toasts "Saved." Quit to Title:
## unpauses and travels to the title scene with NO autosave — the contract is
## the player explicitly chose to leave without saving (mirrors DayFlow's
## "only autosave on sleep/collapse" rule).

const TITLE_SCENE := "res://scenes/main/title.tscn"

var resume_btn: Button
var save_btn: Button
var quit_btn: Button


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.position = Vector2(-58, -48)
	frame.add_theme_stylebox_override("panel", UITheme.panel_stylebox())
	add_child(frame)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(100, 0)
	frame.add_child(vbox)

	var title_label := Label.new()
	title_label.text = "Paused"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
	vbox.add_child(title_label)

	var btn_theme := UITheme.button_theme()

	resume_btn = Button.new()
	resume_btn.text = "Resume"
	resume_btn.theme = btn_theme
	resume_btn.pressed.connect(close)
	vbox.add_child(resume_btn)

	save_btn = Button.new()
	save_btn.text = "Save"
	save_btn.theme = btn_theme
	save_btn.pressed.connect(_on_save_pressed)
	vbox.add_child(save_btn)

	quit_btn = Button.new()
	quit_btn.text = "Quit to Title"
	quit_btn.theme = btn_theme
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)


func is_open() -> bool:
	return visible


static func is_pause_allowed(tree_paused: bool, own_visible: bool) -> bool:
	## Pure decision: may this menu act on an Esc press right now?
	## - Not paused at all -> always allowed (opening fresh).
	## - Paused AND we're the ones showing -> allowed (closing ourselves).
	## - Paused by someone else (own_visible false) -> not allowed; let the
	##   owning menu close itself.
	if not tree_paused:
		return true
	return own_visible


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if not is_pause_allowed(get_tree().paused, is_open()):
		return
	if GameFlow.cutscene_active and not is_open():
		return  # C1: never OPEN mid-cutscene; still allow closing ourselves
	toggle()
	get_viewport().set_input_as_handled()


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func open() -> void:
	if is_open():
		return
	if GameFlow.cutscene_active:
		return  # C1: refuse to open mid-cutscene (see class doc)
	visible = true
	get_tree().paused = true


func close() -> void:
	if not is_open():
		return
	visible = false
	get_tree().paused = false


func _on_save_pressed() -> void:
	var grid := get_tree().get_first_node_in_group("farm_grid") as FarmGrid
	if grid != null:
		grid.store()
	SaveManager.save_game()
	EventBus.toast_requested.emit("Saved.")


func _on_quit_pressed() -> void:
	close()
	SceneChanger.travel.call_deferred(TITLE_SCENE)
