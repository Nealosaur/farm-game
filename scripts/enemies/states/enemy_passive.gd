class_name EnemyPassive
extends State
## Craft Stride 3 (Taming): fed-for-the-day state. A tameable enemy that's
## been fed (see Enemy.feed()) sits here for the rest of the day — no chase
## (never re-aggroes regardless of player distance), no contact damage
## (hitbox disabled on enter, matching EnemyDead's collision-teardown
## pattern). Still fully killable: Hurtbox stays monitoring/monitorable, so
## HurtboxComponent hits still land and can transition to Hurt/Dead exactly
## like any other state (bible: "Fed slimes still count in the dungeon kill
## ledger if killed... no special casing").
##
## Reset: Enemy.data-holding enemies are per-scene-instance, so "passive for
## the rest of the day" simply means this state persists until the enemy is
## killed or the scene is torn down (dungeon floors respawn daily via
## DungeonState, which already clears any still-alive spawn's fed status by
## virtue of instancing a fresh Enemy node next visit — see
## DungeonFloor._spawn_enemies()). No explicit "un-feed" transition exists;
## the day boundary is enforced by that natural respawn, not a timer here.

@onready var enemy: Enemy = owner


func enter() -> void:
	enemy.velocity = Vector2.ZERO
	enemy.sprite.play("idle")
	enemy.hitbox.set_active(false)  # no contact damage while passive


func physics_update(_delta: float) -> void:
	enemy.velocity = Vector2.ZERO
	enemy.move_and_slide()
