extends GutTest
## Craft Stride 3 (Taming): headless integration through the REAL player.gd
## path — feed-vs-eat precedence, the taming threshold/barn-cap/full-pen
## fallback, and the world["taming"] persistence — driven inside dungeon
## floor 1 (mirrors test_dungeon_integration.gd's own scene-loading shape).
##
## NOT covered headless (documented tradeoff, same as test_dungeon_integration):
## actual portal travel between the dungeon and the farm.

const FLOOR_SCENE := "res://scenes/maps/dungeon_1.tscn"


func before_each() -> void:
	Clock.paused = true
	SaveManager.save_path = "user://test_taming.json"
	SaveManager.new_game()
	SceneChanger.spawn_name = "entrance"
	SaveManager.world.erase("taming")


func after_each() -> void:
	SceneChanger.spawn_name = "default"
	SaveManager.save_path = "user://save1.json"
	SaveManager.world.erase("taming")
	if FileAccess.file_exists("user://test_taming.json"):
		DirAccess.remove_absolute("user://test_taming.json")


func _make_floor() -> Node2D:
	return (load(FLOOR_SCENE) as PackedScene).instantiate()


func _floor_enemies(floor_node: Node) -> Array:
	var out := []
	for child in floor_node.get_node("World").get_children():
		if child is Enemy:
			out.append(child)
	return out


func _floor_player(floor_node: Node) -> Player:
	for child in floor_node.get_node("World").get_children():
		if child is Player:
			return child
	return null


func _select(id: String) -> void:
	for i in Inventory.HOTBAR:
		var s = Inventory.slots[i]
		if s != null and s.id == id:
			Inventory.select_hotbar(i)
			return
	fail_test("item not on hotbar: " + id)


func _stand_facing(player: Player, target: Node2D) -> void:
	player.global_position = target.global_position
	player.facing = Vector2i.RIGHT
	player.interact_zone.position = Vector2(player.facing) * 12.0
	player.interact_zone.global_position = player.global_position + player.interact_zone.position


func test_feeding_takes_precedence_over_eating_when_slime_in_zone() -> void:
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	var player := _floor_player(f)
	var slime: Enemy = _floor_enemies(f)[0]
	_stand_facing(player, slime)
	await wait_physics_frames(2)

	Inventory.add_item("turnip", 1)
	_select("turnip")
	var rp_before := GameState.rp
	player.try_use_selected()

	assert_true(slime.is_fed, "holding turnip while facing a live slime must feed it, not eat it")
	assert_eq(Inventory.count_of("turnip"), 0, "the turnip must be consumed")
	assert_eq(GameState.rp, rp_before, "feeding must NOT restore player RP the way eating would")
	assert_eq(int(Taming.read(SaveManager.world).get("slime_feeds", 0)), 1)


func test_eating_still_works_when_no_tameable_enemy_in_zone() -> void:
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	var player := _floor_player(f)
	player.global_position = Vector2(-500, -500)  # nowhere near any enemy
	await wait_process_frames(1)

	Inventory.add_item("turnip", 1)
	_select("turnip")
	GameState.rp = 10
	player.try_use_selected()

	assert_eq(GameState.rp, 40, "ordinary eating still applies +30 RP when nothing is feedable")
	assert_eq(Inventory.count_of("turnip"), 0)


func test_eating_still_works_when_held_food_is_not_the_targets_favorite() -> void:
	## Goblin is untameable — even standing on it, holding turnip must fall
	## back to ordinary eating (not feeding), since is_feedable() is false.
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	var player := _floor_player(f)
	var slime: Enemy = _floor_enemies(f)[0]
	_stand_facing(player, slime)
	await wait_physics_frames(2)

	Inventory.add_item("carrot", 1)  # not slime's favorite_food ("turnip")
	_select("carrot")
	GameState.rp = 10
	player.try_use_selected()

	assert_false(slime.is_fed, "wrong food must not feed the slime")
	assert_eq(GameState.rp, 60, "falls back to eating the carrot (+50 RP)")


func test_feeding_a_slime_makes_it_passive_for_the_day() -> void:
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	var player := _floor_player(f)
	var slime: Enemy = _floor_enemies(f)[0]
	_stand_facing(player, slime)
	await wait_physics_frames(2)

	Inventory.add_item("turnip", 1)
	_select("turnip")
	player.try_use_selected()

	assert_eq(slime.machine.current.name, "Passive")


func test_fourth_feed_tames_and_despawns_the_slime() -> void:
	## Bible: "3 total feeds on ANY slimes... NEXT feed tames" — i.e. the feed
	## AT count 4 is the one that tames (Taming.THRESHOLD == 3, see
	## test_taming.gd's test_feeds_below_threshold_never_tame_across_repeated_feeds
	## for the same contract at the pure-utility level).
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	var player := _floor_player(f)
	var enemies := _floor_enemies(f)
	assert_gt(enemies.size(), 3, "dungeon_1 needs at least 4 slimes for this test")

	Inventory.add_item("turnip", 4)
	_select("turnip")
	for i in 4:
		var slime: Enemy = enemies[i]
		_stand_facing(player, slime)
		await wait_physics_frames(2)
		player.try_use_selected()

	await wait_process_frames(1)
	var blob := Taming.read(SaveManager.world)
	assert_eq(blob["barn"], ["slime"], "the 4th feed must tame instead of just feeding")
	assert_eq(int(blob["slime_feeds"]), 0)
	assert_false(is_instance_valid(enemies[3]), "the tamed slime must despawn from the dungeon")


func test_barn_caps_at_two_and_full_pen_still_feeds() -> void:
	SaveManager.world["taming"] = {"slime_feeds": Taming.THRESHOLD, "barn": ["slime", "slime"]}
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	var player := _floor_player(f)
	var slime: Enemy = _floor_enemies(f)[0]
	_stand_facing(player, slime)
	await wait_physics_frames(2)

	Inventory.add_item("turnip", 1)
	_select("turnip")
	player.try_use_selected()

	assert_true(slime.is_fed, "a full-pen feed must still consume the item and make the enemy passive")
	assert_true(is_instance_valid(slime), "a full-pen feed must NOT despawn the enemy")
	var blob := Taming.read(SaveManager.world)
	assert_eq((blob["barn"] as Array).size(), Taming.MAX_BARN, "barn roster must not exceed the cap")
