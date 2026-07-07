extends GutTest
## FEEL Stride 3: ParticleFX spawner + the gameplay hooks that call it.
## Verifies each spawn_* builds a correctly-configured one-shot node parented
## under the given node at the given world position, and that the real
## gameplay call sites (footstep cadence, till/water/harvest, landed hit,
## enemy death, pickup collect, sword swing) actually invoke it.

var host: Node2D


func before_each() -> void:
	host = Node2D.new()
	add_child_autofree(host)


## ---- ParticleFX itself ----

func test_spawn_dust_returns_one_shot_emitting_particles_at_position() -> void:
	var p := ParticleFX.spawn_dust(host, Vector2(10, 20))
	assert_not_null(p)
	assert_true(p.one_shot)
	assert_true(p.emitting)
	assert_eq(p.global_position, Vector2(10, 20))
	assert_eq(p.get_parent(), host)
	p.queue_free()


func test_spawn_till_uses_dirt_clod_texture() -> void:
	var p := ParticleFX.spawn_till(host, Vector2.ZERO)
	assert_eq(p.texture.resource_path, "res://assets/particles/dirt_clod.png")
	p.queue_free()


func test_spawn_water_uses_water_droplet_texture() -> void:
	var p := ParticleFX.spawn_water(host, Vector2.ZERO)
	assert_eq(p.texture.resource_path, "res://assets/particles/water_droplet.png")
	p.queue_free()


func test_spawn_harvest_uses_leaf_texture() -> void:
	var p := ParticleFX.spawn_harvest(host, Vector2.ZERO)
	assert_eq(p.texture.resource_path, "res://assets/particles/leaf.png")
	p.queue_free()


func test_spawn_hit_uses_impact_spark_texture() -> void:
	var p := ParticleFX.spawn_hit(host, Vector2.ZERO)
	assert_eq(p.texture.resource_path, "res://assets/particles/impact_spark.png")
	p.queue_free()


func test_spawn_death_splat_uses_slime_splat_texture() -> void:
	var p := ParticleFX.spawn_death_splat(host, Vector2.ZERO)
	assert_eq(p.texture.resource_path, "res://assets/particles/slime_splat.png")
	p.queue_free()


func test_spawn_sparkle_uses_sparkle_texture() -> void:
	var p := ParticleFX.spawn_sparkle(host, Vector2.ZERO)
	assert_eq(p.texture.resource_path, "res://assets/particles/sparkle.png")
	p.queue_free()


func test_spawn_swing_arc_rotates_toward_facing() -> void:
	var s := ParticleFX.spawn_swing_arc(host, Vector2.ZERO, Vector2.RIGHT)
	assert_almost_eq(s.rotation, 0.0, 0.01)
	s.queue_free()
	var s2 := ParticleFX.spawn_swing_arc(host, Vector2.ZERO, Vector2.UP)
	assert_almost_eq(s2.rotation, Vector2.UP.angle(), 0.01)
	s2.queue_free()


func test_spawn_returns_null_for_null_parent() -> void:
	assert_null(ParticleFX.spawn_dust(null, Vector2.ZERO))


func test_particles_self_free_after_lifetime() -> void:
	var p := ParticleFX.spawn_hit(host, Vector2.ZERO)  # shortest lifetime (0.25s)
	var id := p.get_instance_id()
	await wait_seconds(0.5)
	assert_false(is_instance_id_valid(id), "particle node should have queue_freed itself")


## ---- gameplay hooks: till/water/harvest ----

func test_till_spawns_dirt_particles() -> void:
	GameState.reset_new_game()
	Inventory.reset()
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	player.global_position = Vector2(200, 200)
	player.facing = Vector2i.DOWN
	var grid := FarmGrid.new()
	grid.tillable = Rect2i(-100, -100, 200, 200)
	add_child_autofree(grid)

	Inventory.add_item("hoe")
	_select(player, "hoe")
	var before := player.get_child_count()
	player.try_use_selected()
	assert_true(player.get_child_count() > before, "till should have spawned a particle child on the player")


func test_water_spawns_droplet_particles() -> void:
	GameState.reset_new_game()
	Inventory.reset()
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	player.global_position = Vector2(200, 200)
	player.facing = Vector2i.DOWN
	var grid := FarmGrid.new()
	grid.tillable = Rect2i(-100, -100, 200, 200)
	add_child_autofree(grid)
	grid.till(player.target_cell())

	Inventory.add_item("watering_can")
	_select(player, "watering_can")
	var before := player.get_child_count()
	player.try_use_selected()
	assert_true(player.get_child_count() > before, "watering should have spawned a particle child on the player")


func test_harvest_spawns_leaf_particles() -> void:
	GameState.reset_new_game()
	Inventory.reset()
	Clock.paused = true
	Clock.day = 10  # mid-spring — turnip is spring-only (see test_farm_grid.gd's same pin)
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	player.global_position = Vector2(200, 200)
	player.facing = Vector2i.DOWN
	var grid := FarmGrid.new()
	grid.tillable = Rect2i(-100, -100, 200, 200)
	add_child_autofree(grid)
	var cell := player.target_cell()
	grid.till(cell)
	grid.plant(cell, "turnip")
	# Force-ripen: set stage past the crop's stage_days so peek_harvest sees it as ripe.
	var crop := ItemDB.get_crop("turnip")
	grid.plots[cell]["stage"] = crop.stage_days.size()

	var before := player.get_child_count()
	player.try_interact()
	assert_true(player.get_child_count() > before, "harvest should have spawned a particle child on the player")


func _select(player: Player, id: String) -> void:
	for i in Inventory.HOTBAR:
		var s = Inventory.slots[i]
		if s != null and s.id == id:
			Inventory.select_hotbar(i)
			return
	fail_test("item not on hotbar: " + id)


## ---- gameplay hooks: landed hit / death / pickup / swing ----

func test_enemy_landed_hit_spawns_impact_spark_under_parent() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var enemy: Enemy = (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate()
	enemy.enemy_id = "slime"
	world.add_child(enemy)
	autofree(enemy)
	var before := world.get_child_count()
	enemy._on_hurtbox_hit_taken(1, Vector2(5, 0))
	assert_true(world.get_child_count() > before, "landed hit should spawn an impact particle under the enemy's parent")


func test_enemy_death_spawns_splat_under_parent() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var enemy: Enemy = (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate()
	enemy.enemy_id = "slime"
	world.add_child(enemy)
	var before := world.get_child_count()
	enemy.health.take_damage(9999)
	# The enemy itself is still alive (mid-fade-tween) right after this call —
	# only the splat has been added as a NEW sibling under `world` so far, the
	# enemy's own queue_free() happens later at the end of its fade tween.
	assert_true(world.get_child_count() > before, "death splat should be parented under the enemy's parent, not the enemy")


func test_pickup_collect_spawns_sparkle_under_parent() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	Inventory.reset()
	var pickup: Pickup = (load("res://scenes/enemies/pickup.tscn") as PackedScene).instantiate()
	pickup.item_id = "slime_gel"
	world.add_child(pickup)
	var player := Node2D.new()
	player.add_to_group("player")
	player.global_position = pickup.global_position
	world.add_child(player)
	autofree(player)
	# The pickup itself gets queue_free()'d by _collect() (removed from
	# `world`), so a raw child-count delta could net to zero even with a
	# sparkle added — check for a NEW CPUParticles2D sibling specifically.
	pickup._physics_process(0.016)  # player is within COLLECT_RANGE (same position)
	var found_sparkle := false
	for child in world.get_children():
		if child is CPUParticles2D:
			found_sparkle = true
			break
	assert_true(found_sparkle, "collecting a pickup should spawn a sparkle particle under its parent")
	await wait_physics_frames(1)  # let the pickup's own queue_free() actually process, avoiding an orphan


func test_swing_spawns_arc_on_player() -> void:
	GameState.reset_new_game()
	Inventory.reset()
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	player.facing = Vector2i.RIGHT
	Inventory.add_item("wooden_sword")
	_select(player, "wooden_sword")
	var before := player.get_child_count()
	player.try_use_selected()
	assert_true(player.get_child_count() > before, "swing should spawn a swing-arc sprite on the player")


## ---- gameplay hook: footstep cadence ----

func test_move_state_spawns_dust_after_footstep_interval() -> void:
	GameState.reset_new_game()
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	Input.action_press("move_right")
	player.machine.transition("Move")
	var before := player.get_child_count()
	var move := player.machine.current
	for i in 60:  # 60 * 0.016 ~= 0.96s, comfortably more than FOOTSTEP_INTERVAL once at speed
		move.physics_update(0.016)
	Input.action_release("move_right")
	assert_true(player.get_child_count() > before, "sustained movement should spawn at least one footstep dust puff")
