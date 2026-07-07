extends GutTest
## LOOK V2: NPCFactory.make_npc() builds a real AnimatedSprite2D wired to the
## sheet-sliced SpriteFrames (not the V1 static Sprite2D), plus a ground
## shadow node — covering the production construction path directly (the
## manually-built fixtures in test_npc.gd/test_npc_walk.gd cover the walk/
## interact BEHAVIOR; this covers what NPCFactory itself wires up).

func test_make_npc_builds_animated_sprite_with_sheet_frames() -> void:
	var npc := NPCFactory.make_npc("marta")
	add_child_autofree(npc)
	var sprite := npc.get_node("Sprite2D") as AnimatedSprite2D
	assert_not_null(sprite, "Sprite2D child must be an AnimatedSprite2D")
	assert_not_null(sprite.sprite_frames)
	assert_true(sprite.sprite_frames.has_animation("walk_down"))
	assert_eq(sprite.sprite_frames.get_frame_count("walk_down"), 4)
	assert_eq(sprite.animation, "idle_down", "should start on idle_down")


func test_make_npc_has_ground_shadow_node() -> void:
	var npc := NPCFactory.make_npc("sten")
	add_child_autofree(npc)
	var shadow := npc.get_node_or_null("GroundShadow")
	assert_not_null(shadow, "NPC should have a GroundShadow child node")
	assert_true(shadow is Polygon2D)


func test_every_registered_npc_builds_a_valid_sheet(params = use_parameters(NPCFactory.ALL_IDS)) -> void:
	var npc := NPCFactory.make_npc(params)
	add_child_autofree(npc)
	var sprite := npc.get_node("Sprite2D") as AnimatedSprite2D
	for dir in ["down", "up", "left", "right"]:
		assert_true(sprite.sprite_frames.has_animation("walk_" + dir), params + " missing walk_" + dir)
		assert_true(sprite.sprite_frames.has_animation("idle_" + dir), params + " missing idle_" + dir)
