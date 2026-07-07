class_name EnemyDead
extends State
## Death sequence: disable collisions/hitboxes, award gold+xp instantly (with
## a toast), roll a material drop into a Pickup, shrink/fade, then queue_free.
## The gold/xp roll uses enemy.rng so tests can seed it deterministically.

const FADE_DURATION := 0.35

const PICKUP_SCENE := "res://scenes/enemies/pickup.tscn"

@onready var enemy: Enemy = owner


func enter() -> void:
	enemy.collision_layer = 0
	enemy.collision_mask = 0
	enemy.hurtbox.set_deferred("monitoring", false)
	enemy.hurtbox.set_deferred("monitorable", false)
	enemy.hitbox.set_active(false)
	enemy.velocity = Vector2.ZERO
	enemy.sprite.play("die")

	var data := enemy.data
	var gold := enemy.rng.randi_range(data.gold_min, data.gold_max)
	GameState.add_gold(gold)
	GameState.add_xp(data.xp)
	EventBus.toast_requested.emit("+%d XP  +%dg" % [data.xp, gold])
	EventBus.enemy_died.emit(data, enemy.global_position)
	# FEEL Stride 4: tiny shake on an ordinary enemy death (frequent event —
	# stays subtle so it never fatigues; the boss slam is the medium one).
	EventBus.camera_shake.emit(CameraShake.TINY_STRENGTH)
	# FEEL Stride 3: death splat spawned under the enemy's PARENT, not the
	# enemy itself — the tween below shrinks/fades and queue_frees the enemy
	# well before the splat's own lifetime is up.
	ParticleFX.spawn_death_splat(enemy.get_parent() if enemy.get_parent() != null else enemy, enemy.global_position)

	if data.drop_item_id != "" and enemy.rng.randf() < data.drop_chance:
		_spawn_pickup(data.drop_item_id)

	var tween := enemy.create_tween()
	tween.set_parallel(true)
	tween.tween_property(enemy, "scale", Vector2.ZERO, FADE_DURATION)
	tween.tween_property(enemy.sprite, "modulate:a", 0.0, FADE_DURATION)
	tween.set_parallel(false)
	tween.tween_callback(enemy.queue_free)


func _spawn_pickup(item_id: String) -> void:
	if not ResourceLoader.exists(PICKUP_SCENE):
		return
	var pickup: Node2D = (load(PICKUP_SCENE) as PackedScene).instantiate()
	pickup.global_position = enemy.global_position
	pickup.set("item_id", item_id)
	enemy.get_parent().add_child.call_deferred(pickup)
