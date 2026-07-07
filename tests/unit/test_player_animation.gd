extends GutTest
## LOOK V2: Player/NPC/Enemy actually PLAY the right sheet-sliced animation
## name per state + facing (drives the real StateMachine headless, same
## pattern as test_player_dodge.gd/test_player_combat.gd). Frame-slicing
## itself is covered by test_sprite_sheets.gd — this file is "does the right
## state play the right anim name."

var player: Player


func before_each() -> void:
	GameState.reset_new_game()
	Inventory.reset()
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)


## ---- Idle ----

func test_idle_plays_idle_down_by_default() -> void:
	assert_eq(player.machine.current.name, "Idle")
	assert_eq(player.sprite.animation, "idle_down")


func test_idle_after_facing_change_plays_matching_idle_anim() -> void:
	# Move to change facing, then let input drop back to Idle.
	player.update_facing(Vector2.LEFT)
	player.machine.transition("Idle")
	assert_eq(player.sprite.animation, "idle_left")


## ---- Move ----

func test_move_state_plays_walk_anim_matching_facing() -> void:
	player.update_facing(Vector2.RIGHT)
	player.machine.transition("Move")
	assert_eq(player.sprite.animation, "walk_right")


func test_move_state_plays_walk_up() -> void:
	player.update_facing(Vector2.UP)
	player.machine.transition("Move")
	assert_eq(player.sprite.animation, "walk_up")


## ---- UseTool ----

func test_use_tool_plays_use_anim_matching_facing() -> void:
	player.facing = Vector2i.DOWN
	player.machine.transition("UseTool")
	assert_eq(player.sprite.animation, "use_down")


func test_use_tool_plays_use_left_when_facing_left() -> void:
	player.facing = Vector2i.LEFT
	player.machine.transition("UseTool")
	assert_eq(player.sprite.animation, "use_left")


## ---- Swing (sword) ----

func test_swing_state_plays_use_anim_matching_facing() -> void:
	Inventory.add_item("wooden_sword")
	for i in Inventory.HOTBAR:
		var s = Inventory.slots[i]
		if s != null and s.id == "wooden_sword":
			Inventory.select_hotbar(i)
			break
	player.facing = Vector2i.RIGHT
	player.try_use_selected()
	assert_eq(player.machine.current.name, "Swing")
	assert_eq(player.sprite.animation, "use_right")


## ---- Hurt ----

func test_hurt_state_plays_idle_anim_matching_facing() -> void:
	player.facing = Vector2i.UP
	player._on_hurtbox_hit_taken(1, Vector2(0, -10))
	assert_eq(player.machine.current.name, "Hurt")
	assert_eq(player.sprite.animation, "idle_up")


## ---- Dodge ----

func test_dodge_state_plays_walk_anim_matching_facing() -> void:
	player.facing = Vector2i.DOWN
	player.try_dodge()
	assert_eq(player.machine.current.name, "Dodge")
	assert_eq(player.sprite.animation, "walk_down")


## ---- Ground shadow ----

func test_player_has_ground_shadow_node() -> void:
	var shadow := player.get_node_or_null("GroundShadow")
	assert_not_null(shadow, "Player should have a GroundShadow child node")
	assert_true(shadow is Polygon2D)
