class_name SlimeKing
extends Enemy
## Dungeon 3 boss. Extends Enemy for the shared HealthComponent/Hurtbox/Hitbox/
## Dead-state plumbing (gold+xp award, drop roll, fade-out, EventBus.enemy_died
## are all reused unmodified), but overrides setup() for a bigger body and adds
## boss-only FSM states (Pursue/Slam/Summon) plus threshold-driven summons and
## a phase-2 speed-up, tracked here rather than in DungeonState (boss death is
## permanent via GameState.flags, not the per-floor kill ledger).
##
## Summon minions are spawned via Enemy.spawn_enemy() with no ledger hookup
## (no health.died -> DungeonState.record_kill binding) — DungeonFloor only
## wires that up for its own ENEMY_SPAWNS loop, so minions the boss spawns
## mid-fight are naturally ledger-less. They vanish with the day (day rollover
## reloads the floor scene) or die in the fight; either way nothing references
## a spawn_index for them.

signal summon_triggered(count: int)
signal phase_changed

const SLAM_COOLDOWN_NORMAL := 3.0
const SLAM_COOLDOWN_PHASE2 := 2.0
const PHASE2_HP_FRACTION := 0.33
const SUMMON_THRESHOLDS := [0.66, 0.33]
const PHASE2_SPEED_MULT := 1.3

var slam_cooldown := SLAM_COOLDOWN_NORMAL
var speed_mult := 1.0
var summon_count := 0
var phase2 := false

var _next_summon_index := 0


func setup(enemy_data: EnemyData) -> void:
	super.setup(enemy_data)

	# Bigger body + hurtbox than a regular enemy (48x48 sprite vs 16x16).
	(collision.shape as RectangleShape2D).size = Vector2(40, 32)
	collision.position = Vector2(0, -16)

	(hurtbox.get_node("Shape") as CollisionShape2D).shape = RectangleShape2D.new()
	((hurtbox.get_node("Shape") as CollisionShape2D).shape as RectangleShape2D).size = Vector2(44, 36)
	hurtbox.position = Vector2(0, -18)

	(hitbox.get_node("Shape") as CollisionShape2D).shape = RectangleShape2D.new()
	((hitbox.get_node("Shape") as CollisionShape2D).shape as RectangleShape2D).size = Vector2(40, 32)
	hitbox.set_active(false)  # boss deals damage only via Slam's ring, not contact

	if not health.damaged.is_connected(_on_damaged):
		health.damaged.connect(_on_damaged)


func _on_damaged(_amount: int) -> void:
	if health.max_hp <= 0:
		return
	var frac: float = float(health.hp) / float(health.max_hp)

	if not phase2 and frac <= PHASE2_HP_FRACTION:
		phase2 = true
		slam_cooldown = SLAM_COOLDOWN_PHASE2
		speed_mult = PHASE2_SPEED_MULT
		phase_changed.emit()

	if _next_summon_index < SUMMON_THRESHOLDS.size() and frac <= SUMMON_THRESHOLDS[_next_summon_index]:
		_next_summon_index += 1
		summon_count += 1
		summon_triggered.emit(summon_count)
		# _on_damaged fires synchronously from take_damage(), BEFORE the
		# caller (_on_hurtbox_hit_taken) transitions to Hurt — so `current`
		# here is still whatever state was active when the hit landed.
		# Only skip if we're already dying/summoning (health <= 0 handled by
		# the death path before this can matter; Summon is skipped so a
		# second threshold crossed mid-cast doesn't reset the cast timer).
		if machine.current != null and machine.current.name not in ["Summon", "Dead"]:
			machine.transition("Summon")


func spawn_minions(world: Node) -> void:
	## Called by BossSummon.enter(). Spawns 2 plain slimes at offsets ±24px.
	## No spawn_index / DungeonState hookup — see class doc.
	for offset in [Vector2(-24, 0), Vector2(24, 0)]:
		var cell := MapBuilder.cell_of(global_position + offset)
		Enemy.spawn_enemy("slime", cell, world)


func _on_hurtbox_hit_taken(damage: int, knockback: Vector2, _is_heavy: bool = false) -> void:
	# FEEL Stride 2: same "every landed player sword hit" hit-stop rule as the
	# base Enemy — this override exists for the boss's own Hurt/Dead wiring,
	# not to change when hit-stop fires.
	HitStop.trigger()
	ParticleFX.spawn_hit(get_parent() if get_parent() != null else self, hurtbox.global_position)
	# FEEL Stride 4: tiny shake on every landed sword hit, same as the base Enemy.
	EventBus.camera_shake.emit(CameraShake.TINY_STRENGTH)
	if machine.current != null and machine.current.name == "Dead":
		return
	health.take_damage(damage)
	if not health.is_alive():
		return
	var hurt := machine.get_node_or_null("Hurt") as BossHurt
	if hurt != null:
		hurt.incoming_knockback = knockback
	machine.transition("Hurt")


func _on_died() -> void:
	GameState.flags["boss_defeated"] = true
	EventBus.boss_defeated.emit()
	# Dead state's normal drop roll already grants 1x slime_gel (drop_chance
	# 1.0 in data, rolled when Dead.enter() runs below); top up to the spec'd
	# guaranteed x3 with 2 more straight to inventory (no world pickup needed
	# for a guaranteed boss reward).
	if data.drop_item_id != "":
		Inventory.add_item(data.drop_item_id, 2)
	machine.transition("Dead")


const BOSS_SCENE := "res://scenes/enemies/slime_king.tscn"


static func spawn_boss(cell: Vector2i, parent: Node) -> SlimeKing:
	## Mirrors Enemy.spawn_enemy but instances the boss scene/scripts.
	var boss: SlimeKing = (load(BOSS_SCENE) as PackedScene).instantiate()
	boss.enemy_id = "slime_king"
	parent.add_child(boss)
	boss.global_position = MapBuilder.cell_center(cell)
	return boss
