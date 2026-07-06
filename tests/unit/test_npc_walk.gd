extends GutTest
## Alive Stride 1: NPC walk-controller behavior — block change starts a walk,
## arrival snaps to the cell center, a block change mid-walk snaps instead of
## chaining, and interact() pauses/resumes the walk. Instantiates the REAL
## town.gd map root directly (not the full town.tscn scene, but the same
## script — its own _ready() builds Ground/props/portals/UI, including a
## real auto-instanced DialogBox we look up via the "dialog_box" group, same
## as npc.gd's own interact() does) so NPC's "map_root" group lookup finds a
## real `path_grid`. Drives Sten's real smithy<->saloon schedule data (a
## transition proven reachable in test_path_grid.gd, unlike Marta's
## counter-quirk cell) directly on a standalone NPC node rather than
## town.tscn's own instance, so tests can simulate() frames without waiting
## on the full scene's player/camera/portal setup.

var _map_root: Node2D
var npc: NPC
var dialog: DialogBox


func before_each() -> void:
	Clock.day = 1
	Clock.minutes = 7 * 60  # 6-9 block: smithy

	_map_root = (load("res://scripts/maps/town.gd") as GDScript).new()
	add_child_autofree(_map_root)  # runs town.gd's real _ready(): builds path_grid, joins "map_root", auto-instances a DialogBox
	dialog = get_tree().get_first_node_in_group("dialog_box") as DialogBox
	assert_not_null(dialog, "town.gd's _ready() must auto-instance a DialogBox")

	npc = NPC.new()
	npc.npc_data = StenData.build()
	npc.dialog_data = StenDialog.DATA
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	npc.add_child(sprite)
	add_child_autofree(npc)

	npc.refresh_schedule("town")  # first placement: always a teleport (see class doc)


func after_each() -> void:
	Clock.minutes = Clock.DAY_START_MINUTES
	Clock.day = 1
	get_tree().paused = false


func _advance_to_saloon_block() -> void:
	Clock.minutes = 18 * 60  # 17-20 block: saloon
	npc.refresh_schedule("town")


func test_first_placement_teleports_directly_to_the_smithy_cell() -> void:
	assert_eq(npc.position, MapBuilder.cell_center(StenData.CELL_SMITHY))


func test_block_change_starts_a_walk_instead_of_teleporting() -> void:
	var start_pos: Vector2 = npc.position
	_advance_to_saloon_block()
	# Immediately after the block change, a walk should be IN PROGRESS: the
	# NPC has NOT already snapped to the saloon cell (that would mean it
	# teleported, defeating the point of this stride).
	assert_ne(npc.position, MapBuilder.cell_center(StenData.CELL_SALOON),
		"must not teleport straight to the target when a walk is possible")
	assert_eq(npc.position, start_pos, "position hasn't advanced yet on the same frame refresh_schedule() ran")
	simulate(npc, 10, 0.1)  # 1 simulated second at 40px/s = 40px of travel
	assert_ne(npc.position, start_pos, "position must have advanced toward the target after processing")


func test_walk_arrival_snaps_exactly_to_the_target_cell_center() -> void:
	_advance_to_saloon_block()
	# Smithy->saloon is a ~20-cell path at 40px/s (16px/cell = 0.4s/cell) ->
	# ~8s to fully arrive. Simulate JUST past that (not much longer): once
	# arrived, idle wander (always on, 4-8s timer) will start nudging the NPC
	# away from and back to this exact cell, so over-simulating would make
	# this assertion flaky against an in-progress wander leg rather than
	# proving arrival precision, which is what this test is actually about.
	simulate(npc, 90, 0.1)  # 9 simulated seconds — comfortably past arrival, short of the wander window
	assert_eq(npc.position, MapBuilder.cell_center(StenData.CELL_SALOON))


func test_block_change_mid_walk_snaps_to_the_new_target_instead_of_chaining() -> void:
	_advance_to_saloon_block()
	simulate(npc, 5, 0.1)  # a little travel, walk still very much in progress
	var mid_walk_pos: Vector2 = npc.position
	assert_ne(mid_walk_pos, MapBuilder.cell_center(StenData.CELL_SMITHY))
	assert_ne(mid_walk_pos, MapBuilder.cell_center(StenData.CELL_SALOON))

	# Next block boundary hits WHILE the walk above is still in flight.
	Clock.minutes = 21 * 60  # 20-2 block: home
	npc.refresh_schedule("town")
	assert_eq(npc.position, MapBuilder.cell_center(StenData.CELL_HOME),
		"an in-flight walk must be cut short and SNAPPED to the new target, not queued behind the old one")


func test_facing_updates_toward_movement_direction() -> void:
	# Saloon (19,23) is south-west of the smithy (33,18) -> first steps move
	# along at least one of LEFT/DOWN.
	_advance_to_saloon_block()
	simulate(npc, 3, 0.1)
	assert_true(npc.facing == Vector2.LEFT or npc.facing == Vector2.DOWN or npc.facing == Vector2.UP or npc.facing == Vector2.RIGHT)
	assert_ne(npc.facing, Vector2.ZERO)


func test_interact_pauses_the_walk_and_faces_the_player() -> void:
	_advance_to_saloon_block()
	simulate(npc, 5, 0.1)
	var pos_before_interact: Vector2 = npc.position

	var player := Node2D.new()
	player.global_position = npc.global_position + Vector2(100, 0)  # to the east
	add_child_autofree(player)

	npc.interact(player)
	assert_true(dialog.is_open())
	assert_eq(npc.facing, Vector2.RIGHT, "must face the player (to the east)")

	# Walk must not advance at all while paused, even if _process is driven.
	simulate(npc, 20, 0.1)
	assert_eq(npc.position, pos_before_interact, "position must not change while paused for dialog")


func test_walk_resumes_after_dialog_closes() -> void:
	_advance_to_saloon_block()
	simulate(npc, 5, 0.1)
	var pos_before_interact: Vector2 = npc.position

	var player := Node2D.new()
	player.global_position = npc.global_position
	add_child_autofree(player)
	npc.interact(player)
	assert_true(dialog.is_open())

	# Close the dialog the same way test_npc.gd's existing suite does: keep
	# advancing until it's fully closed (through the resolved line + choices).
	while dialog.is_open():
		dialog._advance()
		if not dialog.is_open():
			break
		if dialog.choice_box.get_child_count() > 0:
			(dialog.choice_box.get_child(dialog.choice_box.get_child_count() - 1) as Button).pressed.emit()
	assert_false(dialog.is_open())

	simulate(npc, 10, 0.1)
	assert_ne(npc.position, pos_before_interact, "walk must resume advancing once the dialog is closed")


func test_interact_still_works_mid_walk_area2d_monitoring_unaffected() -> void:
	## Documents that walking never disables/reparents the Area2D — interact()
	## itself is the proof: it must still open a dialog while a walk is mid-flight.
	_advance_to_saloon_block()
	simulate(npc, 5, 0.1)
	npc.interact(null)
	assert_true(dialog.is_open(), "interact() must still work while the NPC is walking")
