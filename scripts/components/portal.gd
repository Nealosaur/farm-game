class_name Portal
extends Area2D
## Scene-to-scene travel trigger. Maps place one per stairway (see
## dungeon_floor.gd's PORTALS config / farm.gd's dungeon entrance), usually
## with a Sprite2D child added by the map.
##
## Anti-bounce guarding (two independent layers, per design):
##  1. Spawn cells are placed OFF the portal tile (1-2 cells away) by the
##     maps' SPAWNS dicts — landing after travel never starts you inside the
##     twin portal's trigger area (layout sanity test enforces this).
##  2. Arm-delay: body_entered is ignored for ARM_DELAY seconds after _ready,
##     so even a spawn near a portal can't re-trigger before the player moves.
## Both are defence in depth; either alone would likely suffice but both are
## cheap and the design calls for both explicitly.
##
## Guard logic lives in can_trigger() so unit tests cover the branches
## (arm-delay, non-player body, SceneChanger busy, Clock paused) without
## needing a real scene travel — actual travel is integration-hard headless
## and is exercised manually via the F3 debug key / play-through instead.

const ARM_DELAY := 0.5

@export var target_scene: String = ""
@export var target_spawn: String = ""
@export var label: String = ""

var _armed := false


func _ready() -> void:
	# Detect only the player's body; the portal itself lives on no layer.
	collision_layer = 0
	collision_mask = Layers.bit(Layers.PLAYER_BODY)
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(ARM_DELAY).timeout.connect(_on_armed)


func _on_armed() -> void:
	_armed = true


func can_trigger(body: Node) -> bool:
	if not _armed:
		return false
	if not (body is Player):
		return false
	if SceneChanger.is_busy():
		return false
	if Clock.paused:
		# Scripted sequences (DayFlow sleep/collapse) pause the Clock while the
		# screen is dark; the player must not slide into a portal mid-sequence.
		return false
	return true


func _on_body_entered(body: Node2D) -> void:
	if not can_trigger(body):
		return
	if label != "":
		EventBus.toast_requested.emit(label)
	SceneChanger.travel(target_scene, target_spawn)


static func make(cfg: Dictionary) -> Portal:
	## Factory used by maps' PORTALS configs. cfg keys:
	##   cell: Vector2i, target_scene: String, target_spawn: String,
	##   sprite: String (texture path), label: String (optional toast).
	var portal := Portal.new()
	portal.target_scene = cfg["target_scene"]
	portal.target_spawn = cfg["target_spawn"]
	portal.label = cfg.get("label", "")
	portal.position = MapBuilder.cell_center(cfg["cell"])
	var sprite := Sprite2D.new()
	sprite.texture = load(cfg["sprite"])
	portal.add_child(sprite)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 12)
	col.shape = shape
	portal.add_child(col)
	return portal
