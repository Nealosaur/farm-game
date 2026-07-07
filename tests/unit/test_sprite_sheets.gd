extends GutTest
## LOOK V2: SpriteSheets slicer — builds the real per-facing walk/idle/use
## SpriteFrames from a character sheet, and idle/hurt/die from an enemy sheet.
## Also covers the "missing/invalid sheet" fallback to PlaceholderFrames
## (single frame per animation, never a hard failure).

const CHAR_ANIM_NAMES := [
	"idle_down", "idle_up", "idle_left", "idle_right",
	"walk_down", "walk_up", "walk_left", "walk_right",
	"use_down", "use_up", "use_left", "use_right",
]
const ENEMY_ANIM_NAMES := ["idle", "hurt", "die"]


func _tex(path: String) -> Texture2D:
	return load(path) as Texture2D


## ---- character sheet slicing ----

func test_build_character_creates_all_twelve_animations() -> void:
	var sf := SpriteSheets.build_character(
		_tex("res://assets/placeholder/char_player_sheet.png"),
		_tex("res://assets/placeholder/char_player.png"),
		PackedStringArray(CHAR_ANIM_NAMES))
	for n in CHAR_ANIM_NAMES:
		assert_true(sf.has_animation(n), "missing animation " + n)


func test_build_character_idle_has_one_frame_and_loops() -> void:
	var sf := SpriteSheets.build_character(
		_tex("res://assets/placeholder/char_player_sheet.png"),
		_tex("res://assets/placeholder/char_player.png"),
		PackedStringArray(CHAR_ANIM_NAMES))
	assert_eq(sf.get_frame_count("idle_down"), 1)
	assert_true(sf.get_animation_loop("idle_down"))


func test_build_character_walk_has_four_frame_loop() -> void:
	var sf := SpriteSheets.build_character(
		_tex("res://assets/placeholder/char_player_sheet.png"),
		_tex("res://assets/placeholder/char_player.png"),
		PackedStringArray(CHAR_ANIM_NAMES))
	for dir in ["down", "up", "left", "right"]:
		var n := "walk_" + dir
		assert_eq(sf.get_frame_count(n), 4, n + " should be a 4-frame cycle")
		assert_true(sf.get_animation_loop(n), n + " should loop")


func test_build_character_use_is_single_frame_non_looping() -> void:
	var sf := SpriteSheets.build_character(
		_tex("res://assets/placeholder/char_player_sheet.png"),
		_tex("res://assets/placeholder/char_player.png"),
		PackedStringArray(CHAR_ANIM_NAMES))
	for dir in ["down", "up", "left", "right"]:
		var n := "use_" + dir
		assert_eq(sf.get_frame_count(n), 1)
		assert_false(sf.get_animation_loop(n))


func test_build_character_regions_are_non_empty_and_within_sheet_bounds() -> void:
	var sheet_tex := _tex("res://assets/placeholder/char_player_sheet.png")
	var sf := SpriteSheets.build_character(sheet_tex, _tex("res://assets/placeholder/char_player.png"),
		PackedStringArray(CHAR_ANIM_NAMES))
	for dir in ["down", "up", "left", "right"]:
		var frame: AtlasTexture = sf.get_frame_texture("walk_" + dir, 0)
		assert_not_null(frame)
		var region: Rect2 = frame.region
		assert_gt(region.size.x, 0.0)
		assert_gt(region.size.y, 0.0)
		assert_true(region.position.x >= 0 and region.position.x + region.size.x <= sheet_tex.get_width())
		assert_true(region.position.y >= 0 and region.position.y + region.size.y <= sheet_tex.get_height())


func test_build_character_rows_map_down_up_left_right_in_order() -> void:
	## char_frames.json contract: row 0=down, 1=up, 2=left, 3=right. Verified
	## by checking each facing's frame region falls in the expected row band
	## (row_i * 32 .. row_i*32+32) rather than trusting draw order blindly.
	var sf := SpriteSheets.build_character(
		_tex("res://assets/placeholder/char_player_sheet.png"),
		_tex("res://assets/placeholder/char_player.png"),
		PackedStringArray(CHAR_ANIM_NAMES))
	var expected_row := {"down": 0, "up": 1, "left": 2, "right": 3}
	for dir in expected_row.keys():
		var frame: AtlasTexture = sf.get_frame_texture("idle_" + dir, 0)
		var row: int = int(frame.region.position.y) / SpriteSheets.CHAR_FRAME_H
		assert_eq(row, expected_row[dir], "idle_" + dir + " should read from sheet row " + str(expected_row[dir]))


## ---- character sheet fallback ----

func test_build_character_falls_back_to_single_frame_when_sheet_missing() -> void:
	var sf := SpriteSheets.build_character(null, _tex("res://assets/placeholder/char_player.png"),
		PackedStringArray(CHAR_ANIM_NAMES))
	for n in CHAR_ANIM_NAMES:
		assert_true(sf.has_animation(n))
		assert_eq(sf.get_frame_count(n), 1, n + " should fall back to a single frame")


func test_build_character_falls_back_when_sheet_is_wrong_size() -> void:
	# A 16x32 single-frame texture is not a valid 64x128 sheet.
	var bogus := _tex("res://assets/placeholder/char_player.png")
	var sf := SpriteSheets.build_character(bogus, bogus, PackedStringArray(CHAR_ANIM_NAMES))
	for n in CHAR_ANIM_NAMES:
		assert_eq(sf.get_frame_count(n), 1)


## ---- enemy sheet slicing ----

func test_build_enemy_creates_idle_hurt_die() -> void:
	var sf := SpriteSheets.build_enemy(
		_tex("res://assets/placeholder/char_slime_sheet.png"),
		_tex("res://assets/placeholder/char_slime.png"),
		PackedStringArray(ENEMY_ANIM_NAMES))
	for n in ENEMY_ANIM_NAMES:
		assert_true(sf.has_animation(n))


func test_build_enemy_idle_is_two_frame_loop_hurt_die_single_nonlooping() -> void:
	var sf := SpriteSheets.build_enemy(
		_tex("res://assets/placeholder/char_slime_sheet.png"),
		_tex("res://assets/placeholder/char_slime.png"),
		PackedStringArray(ENEMY_ANIM_NAMES))
	assert_eq(sf.get_frame_count("idle"), 2)
	assert_true(sf.get_animation_loop("idle"))
	assert_eq(sf.get_frame_count("hurt"), 1)
	assert_false(sf.get_animation_loop("hurt"))
	assert_eq(sf.get_frame_count("die"), 1)
	assert_false(sf.get_animation_loop("die"))


func test_build_enemy_works_for_non_square_and_large_frame_sizes() -> void:
	# goblin: 16x24 frames; slime_king: 48x48 frames — both derive frame size
	# from single_tex rather than a hardcoded 16x16, so both must slice clean.
	var goblin_sf := SpriteSheets.build_enemy(
		_tex("res://assets/placeholder/char_goblin_sheet.png"),
		_tex("res://assets/placeholder/char_goblin.png"),
		PackedStringArray(ENEMY_ANIM_NAMES))
	assert_eq(goblin_sf.get_frame_count("idle"), 2)

	var king_sf := SpriteSheets.build_enemy(
		_tex("res://assets/placeholder/char_slime_king_sheet.png"),
		_tex("res://assets/placeholder/char_slime_king.png"),
		PackedStringArray(ENEMY_ANIM_NAMES))
	assert_eq(king_sf.get_frame_count("idle"), 2)
	var frame: AtlasTexture = king_sf.get_frame_texture("hurt", 0)
	assert_eq(frame.region.size, Vector2(48, 48))


func test_build_enemy_falls_back_to_single_frame_when_sheet_missing() -> void:
	var sf := SpriteSheets.build_enemy(null, _tex("res://assets/placeholder/char_slime.png"),
		PackedStringArray(ENEMY_ANIM_NAMES))
	for n in ENEMY_ANIM_NAMES:
		assert_true(sf.has_animation(n))
		assert_eq(sf.get_frame_count(n), 1)


func test_build_enemy_falls_back_when_sheet_size_does_not_match_single_tex() -> void:
	# slime_sheet (64x16, 16x16 cells) doesn't match goblin's 16x24 frame size.
	var mismatched_sheet := _tex("res://assets/placeholder/char_slime_sheet.png")
	var sf := SpriteSheets.build_enemy(mismatched_sheet, _tex("res://assets/placeholder/char_goblin.png"),
		PackedStringArray(ENEMY_ANIM_NAMES))
	for n in ENEMY_ANIM_NAMES:
		assert_eq(sf.get_frame_count(n), 1)
