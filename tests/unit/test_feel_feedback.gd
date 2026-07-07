extends GutTest
## FEEL Stride 6: floating bond/damage numbers, the tool-target cell
## highlight, and the interactable "E" prompt.


## ---- FloatingNumber ----

func test_floating_number_spawns_under_the_given_layer() -> void:
	var layer := CanvasLayer.new()
	add_child_autofree(layer)
	var label := FloatingNumber.spawn(layer, Vector2(50, 50), "+15", FloatingNumber.BOND_COLOR)
	assert_not_null(label)
	assert_eq(label.text, "+15")
	assert_eq(label.get_parent(), layer)


func test_floating_number_rises_and_fades_then_frees() -> void:
	var layer := CanvasLayer.new()
	add_child_autofree(layer)
	var label := FloatingNumber.spawn(layer, Vector2(50, 50), "+15", FloatingNumber.BOND_COLOR)
	var start_y := label.position.y
	var id := label.get_instance_id()
	await wait_seconds(FloatingNumber.DURATION * 0.5)
	if is_instance_id_valid(id):
		assert_true((instance_from_id(id) as Label).position.y < start_y, "should have risen")
	await wait_seconds(FloatingNumber.DURATION * 0.7)
	assert_false(is_instance_id_valid(id), "should have freed itself after rising/fading")


func test_floating_number_returns_null_for_freed_layer() -> void:
	assert_null(FloatingNumber.spawn(null, Vector2.ZERO, "+1", FloatingNumber.BOND_COLOR))


## ---- bond number wired to relationship_changed ----

func test_bond_gain_spawns_floating_number_over_the_live_npc() -> void:
	var hud := (load("res://scripts/ui/hud.gd") as GDScript).new() as Hud
	add_child_autofree(hud)
	var npc := NPCFactory.make_npc("marta")
	add_child_autofree(npc)
	npc.global_position = Vector2(100, 80)

	var before := hud.get_child_count()
	Relationships.talk("marta")
	var found_label := false
	for child in hud.get_children():
		if child is Label and (child as Label).text == "+%d" % Relationships.TALK_GAIN:
			found_label = true
	assert_true(found_label, "bond gain should spawn a floating '+15' label on the HUD layer")


func test_bond_loss_does_not_crash_and_still_no_number_without_npc() -> void:
	var hud := (load("res://scripts/ui/hud.gd") as GDScript).new() as Hud
	add_child_autofree(hud)
	# No live NPC node registered for "nonexistent_npc" — must no-op quietly,
	# not spawn a floating number with nowhere sensible to put it.
	var before := hud.get_child_count()
	hud._on_relationship_changed_bond_number("nonexistent_npc", 15)
	hud._on_relationship_changed_bond_number("nonexistent_npc", -20)
	assert_eq(hud.get_child_count(), before)


func test_zero_delta_does_not_spawn_a_number() -> void:
	var hud := (load("res://scripts/ui/hud.gd") as GDScript).new() as Hud
	add_child_autofree(hud)
	var npc := NPCFactory.make_npc("marta")
	add_child_autofree(npc)
	var before := hud.get_child_count()
	hud._on_relationship_changed_bond_number("marta", 0)
	assert_eq(hud.get_child_count(), before)


## ---- damage number wired to a landed hit ----

func test_landed_hit_spawns_damage_number_when_hud_present() -> void:
	var hud := (load("res://scripts/ui/hud.gd") as GDScript).new() as Hud
	add_child_autofree(hud)
	var enemy: Enemy = (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate()
	enemy.enemy_id = "slime"
	add_child_autofree(enemy)
	enemy._on_hurtbox_hit_taken(3, Vector2(5, 0))
	var found := false
	for child in hud.get_children():
		if child is Label and (child as Label).text == "-3":
			found = true
	assert_true(found, "a landed hit should spawn a floating '-3' damage number")


func test_landed_hit_without_hud_does_not_crash() -> void:
	var enemy: Enemy = (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate()
	enemy.enemy_id = "slime"
	add_child_autofree(enemy)
	var hp_before := enemy.health.hp
	enemy._on_hurtbox_hit_taken(3, Vector2(5, 0))  # no "hud" group member registered — must no-op, not crash
	assert_eq(enemy.health.hp, hp_before - 3, "damage should still apply even with no HUD to show a number on")


## ---- tool-target cell highlight ----

func test_highlight_hidden_by_default_with_no_selection() -> void:
	GameState.reset_new_game()
	Inventory.reset()
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	player._process(0.016)
	assert_false(player._target_highlight.visible)


func test_highlight_shown_while_holding_a_hoe() -> void:
	GameState.reset_new_game()
	Inventory.reset()
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	Inventory.add_item("hoe")
	_select(player, "hoe")
	player._process(0.016)
	assert_true(player._target_highlight.visible)


func test_highlight_shown_while_holding_seeds() -> void:
	GameState.reset_new_game()
	Inventory.reset()
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	Inventory.add_item("turnip_seeds")
	_select(player, "turnip_seeds")
	player._process(0.016)
	assert_true(player._target_highlight.visible)


func test_highlight_hidden_while_holding_the_sword() -> void:
	GameState.reset_new_game()
	Inventory.reset()
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	Inventory.add_item("wooden_sword")
	_select(player, "wooden_sword")
	player._process(0.016)
	assert_false(player._target_highlight.visible, "a weapon has no cell it affects")


func test_highlight_follows_facing_cell() -> void:
	GameState.reset_new_game()
	Inventory.reset()
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	player.global_position = Vector2(100, 100)
	Inventory.add_item("hoe")
	_select(player, "hoe")

	player.facing = Vector2i.RIGHT
	player._process(0.016)
	var right_x := player._target_highlight.position.x

	player.facing = Vector2i.LEFT
	player._process(0.016)
	var left_x := player._target_highlight.position.x

	assert_true(right_x > left_x, "highlight should shift toward whichever cell the player is facing")


## ---- interactable "E" prompt ----

func test_prompt_hidden_with_nothing_in_range() -> void:
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	player._process(0.016)
	assert_false(player._interact_prompt.visible)


func test_prompt_shown_when_an_npc_is_in_range() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	world.add_child(player)
	player.global_position = Vector2(200, 200)
	player.facing = Vector2i.DOWN

	var npc := NPCFactory.make_npc("marta")
	world.add_child(npc)
	npc.global_position = player.interact_zone.global_position
	npc.monitorable = true
	npc.collision_layer = Layers.bit(Layers.WORLD)

	await wait_physics_frames(3)  # let the Area2D overlap register
	player._process(0.016)
	assert_true(player._interact_prompt.visible)


func test_prompt_hides_again_once_out_of_range() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	world.add_child(player)
	player.global_position = Vector2(200, 200)
	player.facing = Vector2i.DOWN

	var npc := NPCFactory.make_npc("marta")
	world.add_child(npc)
	npc.global_position = player.interact_zone.global_position
	npc.monitorable = true
	npc.collision_layer = Layers.bit(Layers.WORLD)
	await wait_physics_frames(3)
	player._process(0.016)
	assert_true(player._interact_prompt.visible)

	npc.global_position = Vector2(5000, 5000)
	await wait_physics_frames(3)
	player._process(0.016)
	assert_false(player._interact_prompt.visible)


func _select(player: Player, id: String) -> void:
	for i in Inventory.HOTBAR:
		var s = Inventory.slots[i]
		if s != null and s.id == id:
			Inventory.select_hotbar(i)
			return
	fail_test("item not on hotbar: " + id)
