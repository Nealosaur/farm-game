class_name Title
extends CanvasLayer
## Title screen: New Game / Continue / Quit. Replaces boot.tscn as the main
## scene — owns the same load-fallback contract boot.gd used to (a corrupt or
## missing save falls back to new_game() gracefully, no crash).
##
## New Game overwrite confirm: simplest correct UX for a keyboard/mouse-only
## placeholder UI — second-click-to-confirm. First click on New Game (when a
## save already exists) relabels the button to "Click again to overwrite" and
## arms a short window; a second click within that window performs the
## overwrite. Any other action (Continue/Quit, or the window expiring) cancels
## the arm and restores the normal label. Documented here rather than a modal
## popup because this whole screen is code-built, single-purpose, and never
## has to nest another menu on top of it.

const FARM_SCENE := "res://scenes/maps/farm.tscn"
const CONFIRM_WINDOW := 3.0

var new_game_btn: Button
var continue_btn: Button
var quit_btn: Button

var _confirm_armed := false
var _confirm_timer: SceneTreeTimer


func _ready() -> void:
	layer = 1

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	# Title banner: framed panel behind the game name (UI skin pass) so the
	# code-built title screen reads as a designed menu, not a debug list.
	var banner := PanelContainer.new()
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.position = Vector2(-90, -110)
	banner.custom_minimum_size = Vector2(180, 40)
	banner.add_theme_stylebox_override("panel", UITheme.panel_stylebox())
	root.add_child(banner)

	var title_label := Label.new()
	title_label.text = "FARM-RPG (working title)"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
	banner.add_child(title_label)

	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.position = Vector2(-70, -50)
	frame.add_theme_stylebox_override("panel", UITheme.panel_stylebox())
	root.add_child(frame)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(140, 0)
	frame.add_child(vbox)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	var btn_theme := UITheme.button_theme()

	new_game_btn = Button.new()
	new_game_btn.text = "New Game"
	new_game_btn.theme = btn_theme
	new_game_btn.pressed.connect(_on_new_game_pressed)
	vbox.add_child(new_game_btn)

	continue_btn = Button.new()
	continue_btn.text = "Continue"
	continue_btn.theme = btn_theme
	continue_btn.pressed.connect(_on_continue_pressed)
	vbox.add_child(continue_btn)

	quit_btn = Button.new()
	quit_btn.text = "Quit"
	quit_btn.theme = btn_theme
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)

	_refresh_continue_enabled()


func _refresh_continue_enabled() -> void:
	continue_btn.disabled = not continue_allowed()


static func continue_allowed() -> bool:
	return SaveManager.has_save()


func _on_new_game_pressed() -> void:
	if SaveManager.has_save() and not _confirm_armed:
		_arm_confirm()
		return
	_disarm_confirm()
	SaveManager.new_game()
	_travel_to_farm("default")


func _arm_confirm() -> void:
	_confirm_armed = true
	new_game_btn.text = "Click again to overwrite"
	_confirm_timer = get_tree().create_timer(CONFIRM_WINDOW)
	_confirm_timer.timeout.connect(_on_confirm_window_expired)


func _on_confirm_window_expired() -> void:
	_disarm_confirm()


func _disarm_confirm() -> void:
	_confirm_armed = false
	if new_game_btn != null:
		new_game_btn.text = "New Game"


func _on_continue_pressed() -> void:
	_disarm_confirm()
	if not continue_allowed():
		return
	if SaveManager.load_game():
		_travel_to_farm("wake")
	else:
		# Corrupt-save fallback: SaveManager already push_warning'd internally.
		# The toast is queued to fire AFTER the scene swap (via
		# swap_scene_while_black) since the title's own HUD-less layer can't
		# display it, and the farm's HUD doesn't exist until the swap lands.
		SaveManager.new_game()
		_travel_to_farm_with_toast("default", "Save file was unreadable — started a new game.")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _travel_to_farm(spawn: String) -> void:
	SceneChanger.travel.call_deferred(FARM_SCENE, spawn)


func _travel_to_farm_with_toast(spawn: String, message: String) -> void:
	_swap_with_toast.call_deferred(spawn, message)


func _swap_with_toast(spawn: String, message: String) -> void:
	if SceneChanger.is_busy():
		return
	await SceneChanger.fade_to_black()
	var toasts := PackedStringArray([message])
	SceneChanger.swap_scene_while_black(FARM_SCENE, spawn, toasts)
