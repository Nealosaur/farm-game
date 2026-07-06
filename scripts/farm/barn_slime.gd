class_name BarnSlime
extends Area2D
## Craft Stride 3 (Taming): a tamed slime living in the farm's pen. Purely
## decorative/interactive — no combat (bible: "no combat interactions on the
## farm"), so this is an Area2D like Bed/Kitchen/ShippingBin, NOT an Enemy
## CharacterBody2D (no hitbox/hurtbox/HealthComponent at all).
##
## Wander: reuses EnemyWander's "pick a random direction every 1-2s, drift at
## a slow speed" shape (own small re-implementation, not the same node, since
## EnemyWander is keyed to an Enemy owner/StateMachine this node doesn't
## have) but constrained to `pen_rect` (farm.gd's PEN_RECT, in CELL
## coordinates) instead of a leash-from-spawn radius — clamps position back
## inside the interior rect in pixels every frame rather than pathfinding,
## which is plenty for a small pen with no obstacles.
##
## Pettable: interact(player) -> toast, per the bible. No cooldown/bond — a
## flavor-only interaction.

const SPEED := 14.0
const MIN_INTERVAL := 1.0
const MAX_INTERVAL := 2.0

var pen_rect: Rect2i  # CELL coords; interior the slime is allowed to wander within
var sprite: Sprite2D
var _rng := RandomNumberGenerator.new()
var _dir := Vector2.ZERO
var _timer := 0.0


func _ready() -> void:
	_rng.randomize()
	_pick_new_direction()


func setup(rect: Rect2i) -> void:
	pen_rect = rect
	sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load("res://assets/placeholder/char_barn_slime.png")
	add_child(sprite)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 14)
	col.shape = shape
	add_child(col)


func _pick_new_direction() -> void:
	_timer = _rng.randf_range(MIN_INTERVAL, MAX_INTERVAL)
	var angle := _rng.randf_range(0.0, TAU)
	_dir = Vector2.RIGHT.rotated(angle)


func _process(delta: float) -> void:
	if pen_rect.size == Vector2i.ZERO:
		return
	_timer -= delta
	if _timer <= 0.0:
		_pick_new_direction()
	position += _dir * SPEED * delta
	_clamp_to_pen()


func _clamp_to_pen() -> void:
	## Keeps the slime's cell within the interior rect (in world pixels),
	## reversing direction on the axis it would otherwise cross so it drifts
	## back toward the middle instead of sticking to the fence line.
	var min_pos := MapBuilder.cell_center(Vector2i(pen_rect.position))
	var max_pos := MapBuilder.cell_center(Vector2i(pen_rect.position + pen_rect.size - Vector2i.ONE))
	if position.x < min_pos.x:
		position.x = min_pos.x
		_dir.x = absf(_dir.x)
	elif position.x > max_pos.x:
		position.x = max_pos.x
		_dir.x = -absf(_dir.x)
	if position.y < min_pos.y:
		position.y = min_pos.y
		_dir.y = absf(_dir.y)
	elif position.y > max_pos.y:
		position.y = max_pos.y
		_dir.y = -absf(_dir.y)


func interact(_player) -> void:
	EventBus.toast_requested.emit("Squish. It seems content.")
