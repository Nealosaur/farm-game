class_name SpriteSheets
extends RefCounted
## SPRITE FORMAT ALIGNMENT: builds real multi-frame SpriteFrames from the
## `char_<id>_sheet.png` sheets (see assets/placeholder/char_frames.json for
## the grid contract this reads — the authoritative Stardew-farmer-style
## extended format the user authors real art against). Replaces the
## single-frame PlaceholderFrames.build() call at every character/enemy
## _ready() — PlaceholderFrames itself is kept unchanged as the FALLBACK this
## falls back to when a sheet is missing or the wrong size (so a not-yet-
## sheeted texture never hard-breaks).
##
## Animation NAMES are the stable contract other scripts already call
## (Player.play_anim, NPC._play_anim, Enemy states' sprite.play) — this only
## changes what each name's SpriteFrames animation actually contains.
##
## ---- Character sheets (64x256, 4 cols x 8 rows) ----
## Grid (matches char_frames.json row_map): rows 0-3 = walk cycles in
## Stardew order Down/Right/Up/Left, rows 4-7 = action cycles in the SAME
## D/R/U/L order (tool-use AND sword swing share these — there is no
## separate weapon row). Cell = 16x32, feet at cell bottom, tightly packed.
## The generator (tools/gen_placeholders.gd) draws LEFT and RIGHT as two
## separately-authored side profiles (a leading-edge nose/chin bump makes them
## read as facing, not mirrors) — so this slicer uses both rows AS DRAWN and
## does NOT flip_h. If a future sheet only authors one side, flip_h can be
## added at the call site; documented here so nobody "fixes" a missing mirror
## that was never needed.
##
## Per-facing animations built from the 8 rows' 4-frame cols each:
##   idle_<dir>   = [walk col0]                          (loop, holds; 1 frame)
##     No dedicated idle row exists in the 8-row sheet — idle is column 0 of
##     that direction's WALK row (the standing pose the walker returns to),
##     per char_frames.json's idle_note.
##   walk_<dir>   = [walk1, walk2, walk3, walk2]         (loop, ~8 fps base)
##     Chosen over including the idle frame in the walk loop so the walk
##     cycle never visibly "pauses" on a standing pose mid-stride — walk2 (the
##     passing/mid-stride pose) bridges back to walk1, giving a smooth
##     4-beat cycle from 3 authored frames. Caller (Player) speed-scales fps.
##   action_<dir> = [action0, action1, action2, action3]  (non-loop, ~10 fps)
##     The full 4-frame windup/swing/follow-through/recover cycle sliced
##     directly from that direction's action row (y 128-255). Shared by both
##     tool-use (hoe/water/harvest) and sword-swing consumers.
##
## ---- Enemy sheets (single row: idle1, idle2, hurt, die) ----
## ENEMIES ARE NOT FARMER-FORMAT — this is a separate, simpler, UNCHANGED
## layout (see char_frames.json's enemy_sheets note). Frame size matches the
## enemy's own char_<id>.png (16x16 slime/wisp, 16x24 goblin, 48x48
## slime_king) — read directly off the loaded texture rather than hardcoded,
## so this works for every enemy size without a table.
##   idle = [idle1, idle2]   (loop, ~3 fps slow bob)
##   hurt = [hurt]           (non-loop)
##   die  = [die]            (non-loop)

const CHAR_FRAME_W := 16
const CHAR_FRAME_H := 32
const CHAR_ROW_DIRS := ["down", "right", "up", "left"]  # Stardew order, matches char_frames.json
const CHAR_WALK_ROW_COUNT := 4   # rows 0-3
const CHAR_ACTION_ROW_COUNT := 4  # rows 4-7
const CHAR_ROW_COUNT := CHAR_WALK_ROW_COUNT + CHAR_ACTION_ROW_COUNT  # 8 total
const CHAR_COLS := 4  # per row: col0 idle/windup, cols 1-3 walk/swing frames
const CHAR_SHEET_W := CHAR_FRAME_W * CHAR_COLS        # 64
const CHAR_SHEET_H := CHAR_FRAME_H * CHAR_ROW_COUNT   # 256

## Row index (within the 8-row sheet) where a direction's WALK row starts.
static func _walk_row(dir_i: int) -> int:
	return dir_i

## Row index where a direction's ACTION row starts (rows 4-7).
static func _action_row(dir_i: int) -> int:
	return CHAR_WALK_ROW_COUNT + dir_i

const WALK_FPS := 8.0
const ACTION_FPS := 10.0
const ENEMY_IDLE_FPS := 3.0

const ENEMY_COLS := 4  # idle1, idle2, hurt, die


## Builds a full walk/idle/action SpriteFrames for a character (player or NPC)
## from `res://assets/placeholder/char_<id>_sheet.png`. Falls back to
## PlaceholderFrames.build() against `single_tex` (the existing down-idle
## char_<id>.png) if the sheet resource is missing or isn't the expected
## 64x256 grid — so a not-yet-sheeted character never hard-breaks, it just
## keeps rendering the static frame (push_warning'd, not push_error'd, per
## project convention: this is an expected/recoverable path during art
## rollout, not a bug).
static func build_character(sheet_tex: Texture2D, single_tex: Texture2D, anim_names: PackedStringArray) -> SpriteFrames:
	if sheet_tex == null or not _is_valid_char_sheet(sheet_tex):
		push_warning("SpriteSheets.build_character: missing/invalid sheet, falling back to single-frame")
		return PlaceholderFrames.build(single_tex, anim_names)

	var sf := SpriteFrames.new()
	sf.remove_animation("default")

	for dir_i in CHAR_ROW_DIRS.size():
		var dir: String = CHAR_ROW_DIRS[dir_i]

		var walk_frames := _slice_row(sheet_tex, _walk_row(dir_i), CHAR_COLS, CHAR_FRAME_W, CHAR_FRAME_H)
		var idle_f: AtlasTexture = walk_frames[0]
		var walk1: AtlasTexture = walk_frames[1]
		var walk2: AtlasTexture = walk_frames[2]
		var walk3: AtlasTexture = walk_frames[3]

		_add_anim(sf, "idle_" + dir, [idle_f], 1.0, true)
		_add_anim(sf, "walk_" + dir, [walk1, walk2, walk3, walk2], WALK_FPS, true)

		var action_frames := _slice_row(sheet_tex, _action_row(dir_i), CHAR_COLS, CHAR_FRAME_W, CHAR_FRAME_H)
		_add_anim(sf, "action_" + dir, action_frames, ACTION_FPS, false)
		# "use_<dir>" is a back-compat alias: same frames as action_<dir>, so a
		# not-yet-migrated call site (or a mid-transition mixed sheet) still
		# resolves to the correct animation content instead of a missing anim.
		_add_anim(sf, "use_" + dir, action_frames, ACTION_FPS, false)

	return sf


## Builds idle/hurt/die SpriteFrames for an enemy from
## `res://assets/placeholder/char_<id>_sheet.png`. Frame size is derived from
## `single_tex` (the enemy's own char_<id>.png — same size as one sheet cell,
## per the manifest) so this works for every enemy body size without a table.
## Falls back to PlaceholderFrames.build() if the sheet is missing/invalid.
static func build_enemy(sheet_tex: Texture2D, single_tex: Texture2D, anim_names: PackedStringArray) -> SpriteFrames:
	if single_tex == null:
		push_warning("SpriteSheets.build_enemy: no single_tex to size frames from")
		return PlaceholderFrames.build(sheet_tex, anim_names)

	var frame_w := single_tex.get_width()
	var frame_h := single_tex.get_height()

	if sheet_tex == null or not _is_valid_enemy_sheet(sheet_tex, frame_w, frame_h):
		push_warning("SpriteSheets.build_enemy: missing/invalid sheet, falling back to single-frame")
		return PlaceholderFrames.build(single_tex, anim_names)

	var frames := _slice_row(sheet_tex, 0, ENEMY_COLS, frame_w, frame_h)
	var idle1: AtlasTexture = frames[0]
	var idle2: AtlasTexture = frames[1]
	var hurt: AtlasTexture = frames[2]
	var die: AtlasTexture = frames[3]

	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	_add_anim(sf, "idle", [idle1, idle2], ENEMY_IDLE_FPS, true)
	_add_anim(sf, "hurt", [hurt], 1.0, false)
	_add_anim(sf, "die", [die], 1.0, false)
	return sf


## ---- internals ----

static func _is_valid_char_sheet(tex: Texture2D) -> bool:
	return tex.get_width() == CHAR_SHEET_W and tex.get_height() == CHAR_SHEET_H


static func _is_valid_enemy_sheet(tex: Texture2D, frame_w: int, frame_h: int) -> bool:
	return tex.get_width() == frame_w * ENEMY_COLS and tex.get_height() == frame_h


## Deterministic region-slice via AtlasTexture — one atlas region per cell in
## `row_i`, left to right. No guessing: regions are computed directly from
## the fixed frame_w/frame_h grid.
static func _slice_row(sheet_tex: Texture2D, row_i: int, cols: int, frame_w: int, frame_h: int) -> Array[AtlasTexture]:
	var out: Array[AtlasTexture] = []
	for col_i in cols:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet_tex
		atlas.region = Rect2(col_i * frame_w, row_i * frame_h, frame_w, frame_h)
		out.append(atlas)
	return out


static func _add_anim(sf: SpriteFrames, anim_name: String, frames: Array, fps: float, loop: bool) -> void:
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, loop)
	for f in frames:
		sf.add_frame(anim_name, f)
