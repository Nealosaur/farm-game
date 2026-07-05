extends GutTest
## Portal guard branches via can_trigger(). The actual SceneChanger.travel a
## triggered portal performs is NOT tested here: change_scene_to_file would
## tear down GUT's own running scene, so real travel is integration-hard
## headless — it's exercised in play via the farm stairs and the F3 debug
## key. What IS testable (and tested): arm-delay, player-only filtering,
## the SceneChanger.is_busy guard, and the Clock.paused guard.

var portal: Portal
var player: Player
var _clock_paused_before: bool


func before_each() -> void:
	_clock_paused_before = Clock.paused
	Clock.paused = false
	portal = Portal.new()
	portal.target_scene = "res://scenes/maps/farm.tscn"
	portal.target_spawn = "default"
	add_child_autofree(portal)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)


func after_each() -> void:
	Clock.paused = _clock_paused_before
	SceneChanger._traveling = false


func test_not_armed_immediately_after_ready() -> void:
	assert_false(portal.can_trigger(player),
		"portal must ignore bodies during the %.1fs arm-delay" % Portal.ARM_DELAY)


func test_armed_after_delay_accepts_player() -> void:
	await wait_seconds(Portal.ARM_DELAY + 0.2)
	assert_true(portal.can_trigger(player))


func test_rejects_non_player_bodies() -> void:
	await wait_seconds(Portal.ARM_DELAY + 0.2)
	var body := CharacterBody2D.new()
	add_child_autofree(body)
	assert_false(portal.can_trigger(body))


func test_busy_scene_changer_blocks_trigger() -> void:
	await wait_seconds(Portal.ARM_DELAY + 0.2)
	SceneChanger._traveling = true   # simulate a travel in flight
	assert_false(portal.can_trigger(player))
	SceneChanger._traveling = false
	assert_true(portal.can_trigger(player))


func test_paused_clock_blocks_trigger() -> void:
	# DayFlow pauses the Clock for the whole sleep/collapse blackout; the
	# player must not be able to slide into a portal mid-sequence.
	await wait_seconds(Portal.ARM_DELAY + 0.2)
	Clock.paused = true
	assert_false(portal.can_trigger(player))
	Clock.paused = false
	assert_true(portal.can_trigger(player))


func test_collision_filter_watches_player_body_layer() -> void:
	assert_eq(portal.collision_layer, 0, "portal lives on no layer")
	assert_eq(portal.collision_mask, Layers.bit(Layers.PLAYER_BODY))


func test_make_factory_builds_configured_portal() -> void:
	var made := Portal.make({
		"cell": Vector2i(4, 7),
		"target_scene": "res://scenes/maps/dungeon_1.tscn",
		"target_spawn": "entrance",
		"sprite": "res://assets/placeholder/prop_stairs_down.png",
		"label": "Down we go",
	})
	autofree(made)
	assert_eq(made.target_scene, "res://scenes/maps/dungeon_1.tscn")
	assert_eq(made.target_spawn, "entrance")
	assert_eq(made.label, "Down we go")
	assert_eq(made.position, MapBuilder.cell_center(Vector2i(4, 7)))
	var has_sprite := false
	var has_shape := false
	for child in made.get_children():
		has_sprite = has_sprite or child is Sprite2D
		has_shape = has_shape or child is CollisionShape2D
	assert_true(has_sprite and has_shape)
