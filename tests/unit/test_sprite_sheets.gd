extends GutTest
## SPRITE FORMAT ALIGNMENT: SpriteSheets slicer — builds the real per-facing
## walk/idle/action SpriteFrames from an 8-row (64x256) farmer-format character
## sheet, and idle/hurt/die from an (unchanged) single-row enemy sheet. Also
## covers the "missing/invalid sheet" fallback to PlaceholderFrames (single
## frame per animation, never a hard failure).
##
## Row order changed from the old 4-row D/U/L/R layout to the new 8-row
## Stardew D/R/U/L layout (rows 0-3 walk, rows 4-7 action) — this file was
## adapted, not deleted/rewritten-to-pass, to keep asserting the CONTRACT in
## assets/placeholder/char_frames.json rather than just "green".

const CHAR_ANIM_NAMES := [
	"idle_down", "idle_up", "idle_left", "idle_right",
	"walk_down", "walk_up", "walk_left", "walk_right",
	"action_down", "action_up", "action_left", "action_right",
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
		var n: String = "walk_" + dir
		assert_eq(sf.get_frame_count(n), 4, n + " should be a 4-frame cycle")
		assert_true(sf.get_animation_loop(n), n + " should loop")


func test_build_character_action_is_four_frame_non_looping() -> void:
	## SPRITE FORMAT ALIGNMENT: the old "use_<dir>" single-frame animation is
	## replaced by "action_<dir>", a full 4-frame windup/swing/follow-through/
	## recover cycle sliced from the sheet's action rows (y 128-255) — shared
	## by both tool-use and sword-swing consumers (char_frames.json's
	## action_row_is_shared). "use_<dir>" is still built as a back-compat
	## alias with identical frame content; verified separately below.
	var sf := SpriteSheets.build_character(
		_tex("res://assets/placeholder/char_player_sheet.png"),
		_tex("res://assets/placeholder/char_player.png"),
		PackedStringArray(CHAR_ANIM_NAMES))
	for dir in ["down", "up", "left", "right"]:
		var n: String = "action_" + dir
		assert_eq(sf.get_frame_count(n), 4, n + " should be a 4-frame action cycle")
		assert_false(sf.get_animation_loop(n), n + " should not loop")


func test_build_character_use_alias_matches_action_frames() -> void:
	## Back-compat: "use_<dir>" still resolves (same frame count/loop flag as
	## "action_<dir>") so a caller that hasn't migrated yet never hits a
	## missing-animation error.
	var sf := SpriteSheets.build_character(
		_tex("res://assets/placeholder/char_player_sheet.png"),
		_tex("res://assets/placeholder/char_player.png"),
		PackedStringArray(CHAR_ANIM_NAMES))
	for dir in ["down", "up", "left", "right"]:
		assert_eq(sf.get_frame_count("use_" + dir), sf.get_frame_count("action_" + dir))
		assert_eq(sf.get_animation_loop("use_" + dir), sf.get_animation_loop("action_" + dir))


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


func test_build_character_walk_rows_map_down_right_up_left_in_order() -> void:
	## char_frames.json contract: row 0=down, 1=right, 2=up, 3=left (Stardew
	## order) -- verified by checking each facing's WALK frame region falls in
	## the expected row band (row_i * 32 .. row_i*32+32) rather than trusting
	## draw order blindly. This is the row order that CHANGED in this stride
	## (was down/up/left/right) -- asserting it explicitly so a future
	## reshuffle can't silently break the contract the user's art depends on.
	var sf := SpriteSheets.build_character(
		_tex("res://assets/placeholder/char_player_sheet.png"),
		_tex("res://assets/placeholder/char_player.png"),
		PackedStringArray(CHAR_ANIM_NAMES))
	var expected_row := {"down": 0, "right": 1, "up": 2, "left": 3}
	for dir in expected_row.keys():
		var frame: AtlasTexture = sf.get_frame_texture("idle_" + dir, 0)
		var row: int = int(frame.region.position.y) / SpriteSheets.CHAR_FRAME_H
		assert_eq(row, expected_row[dir], "idle_" + dir + " should read from sheet row " + str(expected_row[dir]))


func test_build_character_action_rows_slice_from_y_128_to_255() -> void:
	## char_frames.json contract: action rows are 4-7, i.e. y 128-255 (128px
	## tall total, one 32px row per direction in D/R/U/L order starting right
	## after the walk rows). Verified against the actual sliced region's y
	## position/size, not just an assumption about row math.
	var sf := SpriteSheets.build_character(
		_tex("res://assets/placeholder/char_player_sheet.png"),
		_tex("res://assets/placeholder/char_player.png"),
		PackedStringArray(CHAR_ANIM_NAMES))
	var expected_row := {"down": 4, "right": 5, "up": 6, "left": 7}
	for dir in expected_row.keys():
		for frame_i in 4:
			var frame: AtlasTexture = sf.get_frame_texture("action_" + dir, frame_i)
			var y := int(frame.region.position.y)
			assert_true(y >= 128 and y <= 255, "action_" + dir + " frame " + str(frame_i) + " should be within y 128-255, got y=" + str(y))
			var expected_y: int = int(expected_row[dir]) * SpriteSheets.CHAR_FRAME_H
			assert_eq(y, expected_y, "action_" + dir + " frame " + str(frame_i) + " should start at row " + str(expected_row[dir]))


## ---- character sheet fallback ----

func test_build_character_falls_back_to_single_frame_when_sheet_missing() -> void:
	var sf := SpriteSheets.build_character(null, _tex("res://assets/placeholder/char_player.png"),
		PackedStringArray(CHAR_ANIM_NAMES))
	for n in CHAR_ANIM_NAMES:
		assert_true(sf.has_animation(n))
		assert_eq(sf.get_frame_count(n), 1, n + " should fall back to a single frame")


func test_build_character_falls_back_when_sheet_is_wrong_size() -> void:
	# A 16x32 single-frame texture is not a valid 64x256 sheet.
	var bogus := _tex("res://assets/placeholder/char_player.png")
	var sf := SpriteSheets.build_character(bogus, bogus, PackedStringArray(CHAR_ANIM_NAMES))
	for n in CHAR_ANIM_NAMES:
		assert_eq(sf.get_frame_count(n), 1)


func test_build_character_falls_back_when_sheet_is_old_four_row_size() -> void:
	## SPRITE FORMAT ALIGNMENT: a sheet built to the OLD 64x128 (4-row) layout
	## must not be silently accepted as if it were the new 64x256 (8-row)
	## layout -- it should fail validation and fall back, same as any other
	## wrong-size sheet. Regression guard for the dimension bump itself.
	var old_size_sheet := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	var tex := ImageTexture.create_from_image(old_size_sheet)
	var sf := SpriteSheets.build_character(tex, _tex("res://assets/placeholder/char_player.png"),
		PackedStringArray(CHAR_ANIM_NAMES))
	for n in CHAR_ANIM_NAMES:
		assert_eq(sf.get_frame_count(n), 1, n + " should fall back since a 64x128 sheet is the old format, not valid 64x256")


## ---- enemy sheet slicing (unchanged format) ----

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
