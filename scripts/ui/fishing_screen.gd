class_name FishingScreen
extends CanvasLayer
## Fishing minigame UI (DEPTH stride), opened by player.gd's _try_cast() when
## the player uses a FISHING_ROD tool while facing water. Tree-paused while
## open (menu convention — see ForgeScreen/CookingScreen's class docs);
## process_mode ALWAYS so this node's own timers/tween keep running under the
## pause it itself sets.
##
## Data/rolls all come from FishingLogic (bite delay, marker sweep, target
## zone, catch check, species weighting) — this stays a thin display + input
## listener over the testable pure helper, same "UI mirrors: list/roll,
## affordability, resolve" convention as every other screen in this codebase.
##
## Flow: start_cast() -> "Casting..." label, wait bite_delay seconds -> show
## the marker+zone bar -> player presses "use_item" -> resolve hit/miss ->
## toast + (on hit) grant the rolled species item -> close (unpauses).

var _dim: ColorRect
var _panel: Panel
var _status_label: Label
var _bar_bg: ColorRect
var _zone_rect: ColorRect
var _marker_rect: ColorRect

const BAR_WIDTH := 220.0
const BAR_HEIGHT := 16.0

var _rng: RandomNumberGenerator
var _water_body := FishingLogic.WATER_RIVER
var _zone := Vector2(0.4, 0.6)
var _elapsed := 0.0
var _phase := "idle"  # "idle" | "casting" | "biting" | "resolved"
var _bite_timer: SceneTreeTimer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("fishing_screen")
	visible = false
	_rng = RandomNumberGenerator.new()
	_rng.randomize()

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-140, -50)
	_panel.size = Vector2(280, 100)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(8, 8)
	vbox.size = Vector2(264, 84)
	_panel.add_child(vbox)

	_status_label = Label.new()
	_status_label.text = "Casting..."
	vbox.add_child(_status_label)

	var bar_holder := Control.new()
	bar_holder.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	vbox.add_child(bar_holder)

	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.15, 0.15, 0.18)
	_bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_holder.add_child(_bar_bg)

	_zone_rect = ColorRect.new()
	_zone_rect.color = Color(0.3, 0.75, 0.35, 0.8)
	bar_holder.add_child(_zone_rect)

	_marker_rect = ColorRect.new()
	_marker_rect.color = Color(0.95, 0.85, 0.2)
	_marker_rect.size = Vector2(4, BAR_HEIGHT)
	bar_holder.add_child(_marker_rect)

	var hint := Label.new()
	hint.text = "Press use-item when the marker is in the zone"
	hint.add_theme_font_size_override("font_size", 10)
	vbox.add_child(hint)


func is_open() -> bool:
	return visible


## ---- entry point (called by player.gd) ----

func start_cast(water_body: String) -> void:
	if is_open():
		return
	_water_body = water_body
	visible = true
	get_tree().paused = true
	_phase = "casting"
	_status_label.text = "Casting..."
	_marker_rect.visible = false
	_zone_rect.visible = false
	var delay := FishingLogic.roll_bite_delay(_rng)
	_bite_timer = get_tree().create_timer(delay)
	_bite_timer.timeout.connect(_on_bite)


func _on_bite() -> void:
	if not is_open():
		return  # closed early (e.g. test teardown) before the timer fired
	_phase = "biting"
	_elapsed = 0.0
	_zone = FishingLogic.roll_target_zone(_rng)
	_status_label.text = "Bite! Press now!"
	_marker_rect.visible = true
	_zone_rect.visible = true
	_zone_rect.position = Vector2(_zone.x * BAR_WIDTH, 0)
	_zone_rect.size = Vector2((_zone.y - _zone.x) * BAR_WIDTH, BAR_HEIGHT)


func _process(delta: float) -> void:
	if _phase != "biting":
		return
	_elapsed += delta
	var pos := FishingLogic.marker_position(_elapsed)
	_marker_rect.position = Vector2(pos * BAR_WIDTH - _marker_rect.size.x / 2.0, 0)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if _phase == "biting" and event.is_action_pressed("use_item"):
		_resolve_catch()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		_close()
		get_viewport().set_input_as_handled()


func _resolve_catch() -> void:
	_phase = "resolved"
	var pos := FishingLogic.marker_position(_elapsed)
	var success := FishingLogic.is_within_zone(pos, _zone)
	if success:
		var species := FishingLogic.roll_species(_water_body, _rng)
		var leftover := Inventory.add_item(species)
		if leftover == 0:
			var data := ItemDB.get_item(species)
			EventBus.toast_requested.emit("Caught a %s!" % (data.display_name if data != null else species))
		else:
			EventBus.toast_requested.emit("Inventory full — the catch got away!")
	else:
		EventBus.toast_requested.emit("It got away...")
	_close()


func _close() -> void:
	if _bite_timer != null and _bite_timer.timeout.is_connected(_on_bite):
		_bite_timer.timeout.disconnect(_on_bite)
	_bite_timer = null
	_phase = "idle"
	visible = false
	get_tree().paused = false
