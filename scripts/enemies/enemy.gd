class_name Enemy
extends CharacterBody2D
## Generic enemy body. @export enemy_id is resolved via ItemDB in _ready(),
## which builds the sprite, HealthComponent, hurtbox/hitbox and wires the FSM.
## Per-id quirks (wisp wobble, goblin windup/lunge) are driven by simple flags
## derived from data.id — a match here is fine for 3 enemies; Plan-3 boss can
## extend this file or branch further without restructuring callers.

const ANIM_NAMES := ["idle", "hurt", "die"]
const AGGRO_RANGE := 72.0
const DEAGGRO_RANGE := 120.0

@export var enemy_id: String = ""

var data: EnemyData
var spawn_position: Vector2
var is_wisp := false
var is_goblin := false
var rng: RandomNumberGenerator
var is_fed := false  # Craft Stride 3: true once feed() has taken effect this life

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var collision: CollisionShape2D = $Collision
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var hitbox: HitboxComponent = $Hitbox
@onready var machine: StateMachine = $StateMachine


func _ready() -> void:
	add_to_group("enemy")
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	spawn_position = global_position
	if enemy_id != "":
		setup(ItemDB.get_enemy(enemy_id))


func setup(enemy_data: EnemyData) -> void:
	if enemy_data == null:
		push_error("Enemy.setup: null EnemyData for id " + enemy_id)
		return
	data = enemy_data
	enemy_id = data.id
	is_wisp = data.id == "wisp"
	is_goblin = data.id == "goblin"

	var tex := load("res://assets/placeholder/char_%s.png" % data.id) as Texture2D
	sprite.sprite_frames = PlaceholderFrames.build(tex, PackedStringArray(ANIM_NAMES))
	sprite.play("idle")

	health.max_hp = data.max_hp
	health.hp = data.max_hp

	collision.shape = RectangleShape2D.new()
	(collision.shape as RectangleShape2D).size = Vector2(12, 10)
	collision.position = Vector2(0, -5)

	collision_layer = Layers.bit(Layers.ENEMY_BODY)
	collision_mask = Layers.bit(Layers.WORLD) | Layers.bit(Layers.PLAYER_BODY)

	(hurtbox.get_node("Shape") as CollisionShape2D).shape = RectangleShape2D.new()
	((hurtbox.get_node("Shape") as CollisionShape2D).shape as RectangleShape2D).size = Vector2(14, 12)
	hurtbox.position = Vector2(0, -6)
	hurtbox.collision_layer = Layers.bit(Layers.ENEMY_HURTBOX)
	hurtbox.collision_mask = Layers.bit(Layers.PLAYER_HITBOX)
	if not hurtbox.hit_taken.is_connected(_on_hurtbox_hit_taken):
		hurtbox.hit_taken.connect(_on_hurtbox_hit_taken)

	(hitbox.get_node("Shape") as CollisionShape2D).shape = RectangleShape2D.new()
	((hitbox.get_node("Shape") as CollisionShape2D).shape as RectangleShape2D).size = Vector2(12, 10)
	hitbox.collision_layer = Layers.bit(Layers.ENEMY_HITBOX)
	hitbox.collision_mask = Layers.bit(Layers.PLAYER_HURTBOX)
	hitbox.damage = data.damage
	hitbox.set_active(true)  # contact damage: always on while alive

	if not health.died.is_connected(_on_died):
		health.died.connect(_on_died)


func _on_hurtbox_hit_taken(damage: int, knockback: Vector2) -> void:
	if machine.current != null and machine.current.name == "Dead":
		return
	health.take_damage(damage)
	if not health.is_alive():
		return  # died.emit() -> _on_died() -> Dead; don't also enter Hurt
	var hurt := machine.get_node_or_null("Hurt") as EnemyHurt
	if hurt != null:
		hurt.incoming_knockback = knockback
	machine.transition("Hurt")


func _on_died() -> void:
	machine.transition("Dead")


func player_node() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func is_feedable() -> bool:
	## Craft Stride 3: a live, not-already-fed, tameable enemy the player can
	## feed its favorite food to. Dead/Hurt-transitioning enemies fail the
	## health.is_alive() check implicitly (Dead disables collisions but
	## health.hp is already 0 by the time Dead.enter() runs).
	return data != null and data.tameable and not is_fed and health.is_alive()


func feed() -> void:
	## Makes this enemy passive for the rest of its (in-scene) life — see
	## EnemyPassive's class doc for what "passive" disables. Idempotent
	## no-op if already fed or not feedable, so callers (player.gd) don't
	## need their own extra guard beyond is_feedable() before calling this.
	if not is_feedable():
		return
	is_fed = true
	machine.transition("Passive")


const ENEMY_SCENE := "res://scenes/enemies/enemy.tscn"


static func spawn_enemy(id: String, cell: Vector2i, parent: Node) -> Enemy:
	## Shared spawn helper: instances enemy.tscn, sets enemy_id, positions at
	## the cell center, and adds it under `parent`. Dungeon (next stride)
	## reuses this instead of duplicating the instantiate/position dance.
	var enemy: Enemy = (load(ENEMY_SCENE) as PackedScene).instantiate()
	enemy.enemy_id = id
	parent.add_child(enemy)
	enemy.global_position = MapBuilder.cell_center(cell)
	return enemy
