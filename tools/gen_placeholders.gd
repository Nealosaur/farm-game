extends SceneTree
## LOOK V1: real parametric pixel-art generator (replaces the flat-shape
## generator). Produces, at the SAME filenames/sizes the old generator used
## (so nothing downstream breaks), actual readable pixel art built from
## tools/pixelart.gd primitives in the tools/proto_char.gd style: shaded
## volume, 1px silhouette outline, soft ground shadow.
##
## Also emits, per character/enemy, a NEW `char_<id>_sheet.png` multi-frame
## sheet (see assets/placeholder/char_frames.json for the row/col contract)
## for Look V2's animation slicer — while the single-frame `char_<id>.png`
## (down-facing idle) is KEPT so the game keeps rendering unchanged today.
##
## Deterministic: no Date/random anywhere; any variation is seeded from
## PixelArt.hash_seed(name). Rerun -> git status clean.
## Run: "$GODOT" --headless --path . -s res://tools/gen_placeholders.gd

const OUT := "res://assets/placeholder/"
const PROTO_OUT := "res://tools/_proto/"

const OUTLINE := Color("2b2233")


## ---- shared palette bits ----

const SKIN_TONES := {
	"warm": ["e8b88a", "c99268"],
	"light": ["f0d0b0", "d4ac82"],
	"tan": ["c99568", "a8764a"],
	"deep": ["9a6a42", "7a4f30"],
}


## ---- per-character definition ----
## palette: skin, skin_shade, hair, shirt, shirt_shade, pants, boots, accent
class CharDef:
	var id: String
	var skin: Color
	var skin_shade: Color
	var hair: Color
	var shirt: Color
	var shirt_shade: Color
	var pants: Color
	var boots: Color
	var accent: Color  # apron/scarf/hat accent, used loosely per-character
	var hair_style: String  # "short", "long", "bald", "cap", "wild"

	func _init(p_id: String, p_skin: String, p_skin_shade: String, p_hair: String,
			p_shirt: String, p_shirt_shade: String, p_pants: String, p_boots: String,
			p_accent: String, p_hair_style: String) -> void:
		id = p_id
		skin = Color(p_skin)
		skin_shade = Color(p_skin_shade)
		hair = Color(p_hair)
		shirt = Color(p_shirt)
		shirt_shade = Color(p_shirt_shade)
		pants = Color(p_pants)
		boots = Color(p_boots)
		accent = Color(p_accent)
		hair_style = p_hair_style


# 9 distinct characters: player + 8 NPCs. Palette/hair-style chosen to match
# each NPC's established vibe (see docs bible + CLAUDE.md project notes).
static func _char_defs() -> Array:
	return [
		CharDef.new("player", "e8b88a", "c99268", "6b4423", "4a7ac0", "35609a", "33405a", "6b4a2f", "3a2a1a", "short"),
		CharDef.new("marta", "e0b090", "c08e6a", "8a5a3a", "b04898", "8a3675", "4a3050", "5a3a2a", "d8b048", "long"),
		CharDef.new("sten", "c99568", "a8764a", "2a2a2a", "3a3a3e", "28282b", "26262a", "3a3a3a", "8a4a2a", "bald"),  # sooty smith, apron
		CharDef.new("bram", "e8c8a0", "c8a878", "d8d8d0", "6a7888", "515e6c", "38404a", "4a4038", "9a9a9a", "short"),  # grey/old, weathered
		CharDef.new("rosa", "e8b898", "c8967a", "5a2a18", "d84848", "a83636", "5a3020", "6a3a28", "e8d0a0", "long"),  # warm, apron
		CharDef.new("alden", "d8c0a0", "b8a080", "d8d8e0", "384868", "283850", "1c2438", "2a2a30", "c0c8d8", "cap"),  # pale coat, doc
		CharDef.new("finn", "e8b878", "c89858", "e0a838", "3a7050", "2a5a3e", "3a2818", "5a3a20", "e8c848", "wild"),  # sunny fisher
		CharDef.new("willow", "d8b898", "b89878", "3a5a30", "588858", "3f6a40", "2a3a26", "4a3a28", "88a868", "long"),  # green ranger
		CharDef.new("garrick", "b88860", "986840", "605850", "605850", "484038", "302820", "3a3028", "8a7a68", "cap"),  # stern guard/miner
	]


## ---- tool script bodies ----

func _init() -> void:
	var dir_err := DirAccess.make_dir_recursive_absolute(OUT)
	assert(dir_err == OK, "Cannot create " + OUT)
	DirAccess.make_dir_recursive_absolute(PROTO_OUT)
	var count := 0

	count += _write_tiles()
	count += _write_characters()
	count += _write_enemies()
	count += _write_crops()
	count += _write_items()
	count += _write_props()

	_write_contact_sheet()
	_write_characters_preview()
	_write_tiles_and_props_preview()

	print("placeholders written: ", count)
	quit(0)


## =====================================================================
## TILES
## =====================================================================

func _write_tiles() -> int:
	var n := 0
	_save(OUT + "tile_grass.png", _tile_grass("tile_grass", Color("4a7a3a"), Color("3f6a31"), 0))
	_save(OUT + "tile_grass_dark.png", _tile_grass("tile_grass_dark", Color("3f6a31"), Color("355c2a"), 1))
	_save(OUT + "tile_soil_tilled.png", _tile_soil(false))
	_save(OUT + "tile_soil_watered.png", _tile_soil(true))
	_save(OUT + "tile_stone_floor.png", _tile_stone())
	_save(OUT + "tile_wall.png", _tile_wall())
	_save(OUT + "tile_water.png", _tile_water())
	_save(OUT + "tile_path.png", _tile_path())
	_save(OUT + "tile_sand.png", _tile_sand())
	n += 9
	return n


func _tile_grass(name: String, base: Color, dark: Color, variant: int) -> Image:
	var img := PixelArt.blank(16, 16)
	img.fill(base)
	# subtle dither noise so a field of tiles doesn't look flat.
	PixelArt.dither(img, 0, 0, 16, 16, dark, 0.22, PixelArt.hash_seed(name, variant))
	PixelArt.dither(img, 0, 0, 16, 16, base.lightened(0.12), 0.08, PixelArt.hash_seed(name, variant + 50))
	# a couple of small grass-tuft ticks (deterministic positions from seed)
	var tuft := base.darkened(0.25)
	var seed_val := PixelArt.hash_seed(name, variant + 100)
	var positions := _det_positions(seed_val, 3, 16, 16)
	for p: Vector2i in positions:
		PixelArt.px(img, p.x, p.y, tuft)
		PixelArt.px(img, p.x, p.y - 1, tuft)
	return img


## Deterministic scatter of `count` points in a wxh grid from a seed.
func _det_positions(seed_val: int, count: int, w: int, h: int) -> Array:
	var state := [seed_val if seed_val != 0 else 1]
	var pts: Array = []
	for i in count:
		state[0] = (int(state[0]) * 1103515245 + 12345) & 0x7fffffff
		var x: int = int(state[0]) % w
		state[0] = (int(state[0]) * 1103515245 + 12345) & 0x7fffffff
		var y: int = 1 + (int(state[0]) % (h - 2))
		pts.append(Vector2i(x, y))
	return pts


func _tile_soil(watered: bool) -> Image:
	var img := PixelArt.blank(16, 16)
	var base := Color("6b4a2f") if not watered else Color("4a3320")
	var furrow := base.darkened(0.35)
	var damp_hi := base.lightened(0.15) if watered else base.lightened(0.2)
	img.fill(base)
	# horizontal furrow lines (tilled rows), every 4px, with a highlight above each.
	for y in [3, 7, 11]:
		PixelArt.hline(img, 0, y, 16, furrow)
		PixelArt.hline(img, 0, y - 1, 16, damp_hi)
	if watered:
		# a few darker "damp" specks for wet look
		PixelArt.dither(img, 0, 0, 16, 16, base.darkened(0.2), 0.1, PixelArt.hash_seed("tile_soil_watered", 3))
	return img


func _tile_stone() -> Image:
	var img := PixelArt.blank(16, 16)
	var base := Color("6e6e78")
	var mortar := Color("54545e")
	var hi := base.lightened(0.15)
	img.fill(base)
	# brick-ish grout lines: offset every other row (running bond)
	PixelArt.hline(img, 0, 0, 16, mortar)
	PixelArt.hline(img, 0, 8, 16, mortar)
	PixelArt.vline(img, 8, 0, 8, mortar)
	PixelArt.vline(img, 4, 8, 8, mortar)
	PixelArt.vline(img, 12, 8, 8, mortar)
	PixelArt.dither(img, 0, 0, 16, 16, hi, 0.08, PixelArt.hash_seed("tile_stone_floor"))
	return img


func _tile_wall() -> Image:
	var img := PixelArt.blank(16, 16)
	var base := Color("3a3a44")
	var mortar := base.darkened(0.35)
	var brick_hi := base.lightened(0.2)
	var top_hi := base.lightened(0.35)
	img.fill(base)
	# brick face: 2 rows of bricks with running-bond offset
	PixelArt.hline(img, 0, 5, 16, mortar)
	PixelArt.hline(img, 0, 10, 16, mortar)
	PixelArt.hline(img, 0, 15, 16, mortar)
	PixelArt.vline(img, 7, 0, 5, mortar)
	PixelArt.vline(img, 3, 5, 5, mortar)
	PixelArt.vline(img, 11, 5, 5, mortar)
	PixelArt.vline(img, 7, 10, 5, mortar)
	# top highlight strip (light catches the top edge of the wall)
	PixelArt.hline(img, 0, 0, 16, top_hi)
	PixelArt.dither(img, 0, 0, 16, 16, brick_hi, 0.06, PixelArt.hash_seed("tile_wall"))
	return img


func _tile_water() -> Image:
	var img := PixelArt.blank(16, 16)
	var base := Color("2f5f8f")
	var deep := Color("264d76")
	var glint := Color("aee0f0")
	img.fill(base)
	PixelArt.dither(img, 0, 0, 16, 16, deep, 0.18, PixelArt.hash_seed("tile_water"))
	# light glint band, wavy via a couple offset segments
	PixelArt.hline(img, 2, 4, 5, glint)
	PixelArt.hline(img, 9, 6, 4, glint)
	PixelArt.hline(img, 4, 11, 3, glint.darkened(0.1))
	return img


func _tile_path() -> Image:
	var img := PixelArt.blank(16, 16)
	var base := Color("9a8a6a")
	var pebble := base.darkened(0.3)
	var hi := base.lightened(0.15)
	img.fill(base)
	PixelArt.dither(img, 0, 0, 16, 16, pebble, 0.14, PixelArt.hash_seed("tile_path"))
	PixelArt.dither(img, 0, 0, 16, 16, hi, 0.06, PixelArt.hash_seed("tile_path", 1))
	return img


func _tile_sand() -> Image:
	var img := PixelArt.blank(16, 16)
	var base := Color("d8c888")
	var dark := base.darkened(0.15)
	var hi := base.lightened(0.12)
	img.fill(base)
	PixelArt.dither(img, 0, 0, 16, 16, dark, 0.12, PixelArt.hash_seed("tile_sand"))
	PixelArt.dither(img, 0, 0, 16, 16, hi, 0.1, PixelArt.hash_seed("tile_sand", 1))
	return img


## =====================================================================
## CHARACTERS (player + 8 NPCs) — 16x32 single-frame + 64x128 sheet
## =====================================================================

func _write_characters() -> int:
	var n := 0
	for def: CharDef in _char_defs():
		var idle_down := _draw_character(def, "down", 0)
		_save(OUT + "char_%s.png" % def.id, idle_down)
		n += 1

		var frames: Array = []
		for row_dir in ["down", "up", "left", "right"]:
			for frame_i in 4:  # idle, walk1, walk2, walk3
				frames.append(_draw_character(def, row_dir, frame_i))
		var sheet := PixelArt.build_sheet(frames, 16, 32, 4)
		_save(OUT + "char_%s_sheet.png" % def.id, sheet)
		n += 1
	return n


## Draws one 16x32 character frame. `facing`: down/up/left/right.
## `frame_i`: 0 = idle, 1..3 = walk cycle (contact/passing/contact-ish via a
## small leg/arm offset — deterministic, no interpolation library needed).
func _draw_character(def: CharDef, facing: String, frame_i: int) -> Image:
	var img := PixelArt.blank(16, 32)
	var eyes := Color("2a2030")

	# ground shadow first (not outlined)
	PixelArt.ground_shadow(img, 8, 30, 4)

	# walk-cycle leg offset: frame 1/3 step one leg forward/back by 1px,
	# frame 2 is the "passing" pose (legs together, slight bob up).
	var leg_off := 0
	var bob := 0
	match frame_i:
		1:
			leg_off = 1
		2:
			bob = -1
		3:
			leg_off = -1

	var leg_y := 22 + bob
	var torso_y := 15 + bob
	var head_y := 8 + bob

	if facing == "left" or facing == "right":
		_draw_character_side(img, def, facing, leg_y, torso_y, head_y, leg_off, eyes)
	else:
		_draw_character_front_back(img, def, facing, leg_y, torso_y, head_y, leg_off, eyes)

	# per-character accent (apron/scarf/hat trim) — a horizontal band on the
	# torso so Sten/Rosa read as apron-wearing, Alden as coated, etc. Skipped
	# on the back view since the accent is a front-worn garment.
	if facing != "up":
		PixelArt.hline(img, 5, torso_y + 5, 6, def.accent)

	PixelArt.outline(img, OUTLINE)
	return img


## Down (front) / up (back) silhouette — same blocky body, differing only in
## face (both eyes visible from the front, none from the back).
func _draw_character_front_back(img: Image, def: CharDef, facing: String, leg_y: int, torso_y: int, head_y: int, leg_off: int, eyes: Color) -> void:
	# legs + boots (offset for walk cycle)
	PixelArt.rect(img, 5 - leg_off, leg_y, 2, 6, def.pants)
	PixelArt.rect(img, 9 + leg_off, leg_y, 2, 6, def.pants)
	PixelArt.rect(img, 5 - leg_off, leg_y + 6, 2, 2, def.boots)
	PixelArt.rect(img, 9 + leg_off, leg_y + 6, 2, 2, def.boots)

	# torso (shirt) with shaded right side for volume
	PixelArt.rect(img, 5, torso_y, 6, 7, def.shirt)
	PixelArt.shade_right(img, 5, torso_y, 6, 7, def.shirt_shade, 2)
	# arms (skin)
	PixelArt.rect(img, 4, torso_y, 1, 5, def.skin)
	PixelArt.rect(img, 11, torso_y, 1, 5, def.skin_shade)

	# head + shaded side
	PixelArt.rect(img, 5, head_y, 6, 7, def.skin)
	PixelArt.shade_right(img, 5, head_y, 6, 7, def.skin_shade, 2)

	_draw_hair(img, def, head_y, facing == "up")

	if facing == "down":
		PixelArt.px(img, 6, head_y + 3, eyes)
		PixelArt.px(img, 9, head_y + 3, eyes)
	# "up": no face drawn — hair (drawn full-coverage by _draw_hair) reads as
	# the back of the head.


## Left/right (side profile) silhouette: head + torso shifted toward the
## facing edge, a single trailing arm, one eye near the leading edge, and a
## visible nose/chin bump so the profile doesn't read as a mirrored front.
func _draw_character_side(img: Image, def: CharDef, facing: String, leg_y: int, torso_y: int, head_y: int, leg_off: int, eyes: Color) -> void:
	var dir := 1 if facing == "right" else -1  # +1 = leading edge is the right side

	# legs: near leg forward (leading), far leg trails — walk cycle offsets
	# the leading leg back/forth along the facing axis.
	var near_x := 8 + dir * 2 + leg_off * dir
	var far_x := 8 - dir * 1 - leg_off * dir
	PixelArt.rect(img, far_x, leg_y, 2, 6, def.pants.darkened(0.15))
	PixelArt.rect(img, near_x, leg_y, 2, 6, def.pants)
	PixelArt.rect(img, far_x, leg_y + 6, 2, 2, def.boots.darkened(0.15))
	PixelArt.rect(img, near_x, leg_y + 6, 2, 2, def.boots)

	# torso: narrower than the front view (profile), shaded on the trailing side
	var torso_x := 6 + dir
	PixelArt.rect(img, torso_x, torso_y, 4, 7, def.shirt)
	if dir > 0:
		PixelArt.shade_right(img, torso_x, torso_y, 4, 7, def.shirt_shade, 1)
	else:
		PixelArt.rect(img, torso_x, torso_y, 1, 7, def.shirt_shade)
	# single trailing arm
	PixelArt.rect(img, torso_x - dir * 3, torso_y + 1, 1, 5, def.skin_shade)

	# head: shifted toward the facing side, with a small nose/chin bump on
	# the leading edge so left vs right reads as a profile, not a mirror.
	var head_x := 5 + dir
	PixelArt.rect(img, head_x, head_y, 5, 7, def.skin)
	if dir > 0:
		PixelArt.shade_right(img, head_x, head_y, 5, 7, def.skin_shade, 1)
	else:
		PixelArt.rect(img, head_x, head_y, 1, 7, def.skin_shade)
	# nose bump on the leading edge
	var nose_x := head_x + (4 if dir > 0 else 0)
	PixelArt.px(img, nose_x + dir, head_y + 4, def.skin_shade)

	_draw_hair(img, def, head_y, false)

	# one eye near the leading edge
	var eye_x := head_x + (3 if dir > 0 else 1)
	PixelArt.px(img, eye_x, head_y + 3, eyes)


func _draw_hair(img: Image, def: CharDef, head_y: int, full_back: bool) -> void:
	if full_back:
		# back-of-head view: hair covers the whole head silhouette (a solid
		# "you're looking at their scalp/nape" read), varied a little by
		# style so bald/cap/long still differ from behind.
		match def.hair_style:
			"bald":
				PixelArt.hline(img, 5, head_y, 6, def.hair)
				PixelArt.rect(img, 5, head_y + 5, 6, 2, def.hair)
			"cap":
				PixelArt.rect(img, 4, head_y - 1, 8, 8, def.hair)
			"long":
				PixelArt.rect(img, 5, head_y - 1, 6, 8, def.hair)
			_:
				PixelArt.rect(img, 5, head_y - 1, 6, 5, def.hair)
				PixelArt.rect(img, 5, head_y + 4, 6, 3, def.hair.darkened(0.15))
		return
	match def.hair_style:
		"bald":
			# just a thin fringe, mostly scalp-colored (Sten)
			PixelArt.hline(img, 5, head_y, 6, def.hair)
		"cap":
			PixelArt.rect(img, 4, head_y - 1, 8, 3, def.hair)
		"long":
			PixelArt.rect(img, 5, head_y - 1, 6, 3, def.hair)
			PixelArt.rect(img, 4, head_y + 2, 1, 5, def.hair)
			PixelArt.rect(img, 11, head_y + 2, 1, 5, def.hair)
		"wild":
			PixelArt.rect(img, 4, head_y - 1, 8, 3, def.hair)
			PixelArt.px(img, 3, head_y, def.hair)
			PixelArt.px(img, 12, head_y, def.hair)
			PixelArt.px(img, 5, head_y - 2, def.hair)
			PixelArt.px(img, 9, head_y - 2, def.hair)
		_:  # "short"
			PixelArt.rect(img, 5, head_y - 1, 6, 3, def.hair)
			PixelArt.px(img, 4, head_y, def.hair)
			PixelArt.px(img, 11, head_y, def.hair)


## =====================================================================
## ENEMIES — slime/wisp (16x16), goblin (16x24), slime_king (48x48)
## + a friendlier barn_slime tint. Each gets idle/hurt/die sheet frames.
## =====================================================================

func _write_enemies() -> int:
	var n := 0
	n += _write_enemy_family("char_slime", Color("5fcf5f"), Color("3fa83f"), Color("aef0ae"), 16, 16, false)
	n += _write_enemy_family("char_barn_slime", Color("90e090"), Color("6ac06a"), Color("d8f8d8"), 16, 16, false)
	n += _write_wisp_family()
	n += _write_goblin_family()
	n += _write_slime_king_family()
	return n


func _write_enemy_family(name: String, body: Color, body_shade: Color, hi: Color, w: int, h: int, is_king: bool) -> int:
	var idle1 := _draw_slime(body, body_shade, hi, w, h, 0, false, false)
	_save(OUT + name + ".png", idle1)
	var idle2 := _draw_slime(body, body_shade, hi, w, h, 1, false, false)
	var hurt := _draw_slime(body, body_shade, hi, w, h, 0, true, false)
	var die := _draw_slime(body, body_shade, hi, w, h, 0, false, true)
	var sheet := PixelArt.build_sheet([idle1, idle2, hurt, die], w, h, 4)
	_save(OUT + name + "_sheet.png", sheet)
	return 2


func _draw_slime(body: Color, body_shade: Color, hi: Color, w: int, h: int, bob: int, hurt: bool, dying: bool) -> Image:
	var img := PixelArt.blank(w, h)
	var eyes := Color("203020")
	if hurt:
		body = body.lightened(0.5)
		body_shade = body_shade.lightened(0.4)
		eyes = Color("601010")
	var squash := 1 if dying else 0

	PixelArt.ground_shadow(img, w / 2, h - 1, w / 3)

	var top := int(h * 0.38) + bob + squash * 2
	var bottom := h - 1 - squash
	var cx := w / 2.0
	var max_r := w / 2.0 - 1.0
	# rounded dome: half-width follows a quarter-circle profile (sqrt) so the
	# silhouette curves like a dome instead of tapering in a straight cone.
	for y in range(top, bottom):
		var t := float(y - top) / float(bottom - top)
		var half := max_r * sqrt(maxf(0.0, 1.0 - (1.0 - t) * (1.0 - t)))
		for x in range(int(cx - half), int(cx + half) + 1):
			PixelArt.px(img, x, y, body)
	# shaded lower-right area for volume (rounded, not a hard rectangle)
	var shade_top := top + int((bottom - top) * 0.5)
	for y in range(shade_top, bottom):
		var t2 := float(y - top) / float(bottom - top)
		var half2 := max_r * sqrt(maxf(0.0, 1.0 - (1.0 - t2) * (1.0 - t2)))
		for x in range(int(cx), int(cx + half2) + 1):
			PixelArt.px(img, x, y, body_shade)
	# highlight + eyes
	PixelArt.px(img, int(cx - w * 0.18), top + 2, hi)
	PixelArt.px(img, int(cx - w * 0.18) + 1, top + 2, hi)
	if not dying:
		PixelArt.px(img, int(cx - w * 0.18), top + int(h * 0.28), eyes)
		PixelArt.px(img, int(cx + w * 0.28), top + int(h * 0.28), eyes)
	else:
		# X_X dead eyes
		PixelArt.px(img, int(cx - w * 0.18), top + int(h * 0.28), eyes)
		PixelArt.px(img, int(cx + w * 0.28), top + int(h * 0.28), eyes)

	PixelArt.outline(img, body_shade.darkened(0.5))
	return img


func _write_wisp_family() -> int:
	var idle1 := _draw_wisp(0, false, false)
	_save(OUT + "char_wisp.png", idle1)
	var idle2 := _draw_wisp(1, false, false)
	var hurt := _draw_wisp(0, true, false)
	var die := _draw_wisp(0, false, true)
	var sheet := PixelArt.build_sheet([idle1, idle2, hurt, die], 16, 16, 4)
	_save(OUT + "char_wisp_sheet.png", sheet)
	return 2


func _draw_wisp(bob: int, hurt: bool, dying: bool) -> Image:
	var img := PixelArt.blank(16, 16)
	var core := Color("d8f8ff") if not hurt else Color("ffe0e0")
	var glow := Color("70c0e0") if not hurt else Color("e08080")
	var glow_soft := Color(glow.r, glow.g, glow.b, 0.5)
	var eyes := Color("14202c")

	# soft outer glow halo (semi-transparent, drawn first, not outlined)
	PixelArt.fill_ellipse(img, 8, 8 - bob, 6, 6, glow_soft)
	# teardrop / flame body: wide top, tapering to a point at bottom
	var top_y := 3 - bob if not dying else 6
	for y in range(top_y, 13):
		var t := float(y - top_y) / 10.0
		var half := 4.0 * (1.0 - t * 0.85)
		for x in range(int(8 - half), int(8 + half) + 1):
			PixelArt.px(img, x, y, glow)
	# inner bright core (face plate the eyes sit on, for contrast)
	PixelArt.fill_ellipse(img, 8, top_y + 4, 3.2, 3.0, core)
	if not dying:
		PixelArt.rect(img, 6, top_y + 3, 1, 2, eyes)
		PixelArt.rect(img, 9, top_y + 3, 1, 2, eyes)
	else:
		# X_X dead eyes: two diagonal ticks each
		PixelArt.px(img, 6, top_y + 3, eyes)
		PixelArt.px(img, 7, top_y + 4, eyes)
		PixelArt.px(img, 9, top_y + 3, eyes)
		PixelArt.px(img, 10, top_y + 4, eyes)

	PixelArt.outline(img, Color("2a4a5a"))
	return img


func _write_goblin_family() -> int:
	var idle1 := _draw_goblin(0, false, false)
	_save(OUT + "char_goblin.png", idle1)
	var idle2 := _draw_goblin(1, false, false)
	var hurt := _draw_goblin(0, true, false)
	var die := _draw_goblin(0, false, true)
	var sheet := PixelArt.build_sheet([idle1, idle2, hurt, die], 16, 24, 4)
	_save(OUT + "char_goblin_sheet.png", sheet)
	return 2


func _draw_goblin(bob: int, hurt: bool, dying: bool) -> Image:
	var img := PixelArt.blank(16, 24)
	var skin := Color("a05030") if not hurt else Color("d08060")
	var skin_shade := Color("7a3a20")
	var cloth := Color("4a3a28")
	var cloth_shade := Color("362a1c")
	var tusk := Color("e8e0c8")
	var eyes := Color("e0a020")
	var squash := 2 if dying else 0

	PixelArt.ground_shadow(img, 8, 22, 5)

	var head_y := 4 - bob + squash
	var torso_y := 11 - bob + squash

	# stocky legs
	PixelArt.rect(img, 5, 18 - squash, 2, 4 - squash, cloth_shade)
	PixelArt.rect(img, 9, 18 - squash, 2, 4 - squash, cloth_shade)
	# stocky torso, wider than a human for a hulking read
	PixelArt.rect(img, 3, torso_y, 10, 8 - squash, cloth)
	PixelArt.shade_right(img, 3, torso_y, 10, 8 - squash, cloth_shade, 3)
	# arms
	PixelArt.rect(img, 1, torso_y, 2, 6, skin)
	PixelArt.rect(img, 13, torso_y, 2, 6, skin_shade)
	# head, wide + jaw
	PixelArt.rect(img, 4, head_y, 8, 7, skin)
	PixelArt.shade_right(img, 4, head_y, 8, 7, skin_shade, 3)
	# tusks
	PixelArt.px(img, 5, head_y + 6, tusk)
	PixelArt.px(img, 10, head_y + 6, tusk)
	# eyes (angry brow via a dark line above)
	if not dying:
		PixelArt.px(img, 6, head_y + 3, eyes)
		PixelArt.px(img, 9, head_y + 3, eyes)
	PixelArt.hline(img, 5, head_y + 2, 6, skin_shade)

	PixelArt.outline(img, Color("2b1f18"))
	return img


func _write_slime_king_family() -> int:
	var idle1 := _draw_slime_king(0, false, false)
	_save(OUT + "char_slime_king.png", idle1)
	var idle2 := _draw_slime_king(1, false, false)
	var hurt := _draw_slime_king(0, true, false)
	var die := _draw_slime_king(0, false, true)
	var sheet := PixelArt.build_sheet([idle1, idle2, hurt, die], 48, 48, 4)
	_save(OUT + "char_slime_king_sheet.png", sheet)
	return 2


func _draw_slime_king(bob: int, hurt: bool, dying: bool) -> Image:
	var body := Color("208020") if not hurt else Color("70c070")
	var body_shade := Color("155a15")
	var hi := Color("90e090")
	var img := _draw_slime(body, body_shade, hi, 48, 48, bob * 2, hurt, dying)
	if not dying:
		# crown suggestion: three gold points across the top of the dome
		var gold := Color("e8c848")
		var gold_shade := Color("b89428")
		var top_y := int(48 * 0.38) + bob * 2
		var cx := 24
		for i in range(-1, 2):
			var px_x := cx + i * 8
			PixelArt.rect(img, px_x - 1, top_y - 4, 3, 4, gold)
			PixelArt.px(img, px_x, top_y - 5, gold)
		PixelArt.hline(img, cx - 10, top_y - 1, 21, gold_shade)
		PixelArt.outline(img, body_shade.darkened(0.5))
	return img


## =====================================================================
## CROPS — 4 stages per crop, each shaped like that crop's silhouette.
## =====================================================================

func _write_crops() -> int:
	var n := 0
	n += _write_crop_family("turnip", Color("e8e0d0"), "round_root", Color("5a8a3a"))
	n += _write_crop_family("carrot", Color("e07820"), "round_root", Color("4a8a2a"))
	n += _write_crop_family("pumpkin", Color("d06010"), "pumpkin", Color("4a8a2a"))
	n += _write_crop_family("strawberry", Color("e04060"), "berry", Color("5a9a3a"))
	n += _write_crop_family("tomato", Color("d84030"), "round_root", Color("4a8a2a"))
	n += _write_crop_family("corn", Color("e8c840"), "corn", Color("3a7a2a"))
	n += _write_crop_family("melon", Color("70c880"), "pumpkin", Color("3a7a2a"))
	n += _write_crop_family("eggplant", Color("7048a8"), "berry", Color("4a8a2a"))
	n += _write_crop_family("amberleaf", Color("d89838"), "leafy", Color("6a9a3a"))
	return n


func _write_crop_family(id: String, ripe_c: Color, shape: String, leaf_c: Color) -> int:
	for stage in 4:
		var img := _draw_crop_stage(ripe_c, shape, leaf_c, stage)
		_save(OUT + "crop_%s_%d.png" % [id, stage], img)
	return 4


## stage 0 = sprout (just leaves poking from soil), 1 = leafy (small plant),
## 2 = budding (plant + small colored bud), 3 = ripe (full crop silhouette).
func _draw_crop_stage(ripe_c: Color, shape: String, leaf_c: Color, stage: int) -> Image:
	var img := PixelArt.blank(16, 16)
	var soil := Color("6b4a2f")
	var leaf_shade := leaf_c.darkened(0.3)

	# soil mound at the base, all stages
	PixelArt.fill_ellipse(img, 8, 14, 5, 2, soil)

	match stage:
		0:
			# sprout: two small leaf ticks
			PixelArt.vline(img, 7, 10, 4, leaf_c)
			PixelArt.vline(img, 9, 9, 5, leaf_c)
			PixelArt.px(img, 6, 10, leaf_shade)
			PixelArt.px(img, 10, 9, leaf_shade)
		1:
			# leafy: a small bush of leaves, no fruit color yet
			PixelArt.fill_ellipse(img, 8, 9, 4, 4, leaf_c)
			PixelArt.fill_ellipse(img, 8, 10, 4, 2, leaf_shade)
		2:
			# budding: leaves + a small bud of the ripe color peeking out
			PixelArt.fill_ellipse(img, 8, 9, 4, 4, leaf_c)
			PixelArt.fill_ellipse(img, 8, 10, 4, 2, leaf_shade)
			_draw_crop_shape(img, shape, ripe_c, 8, 11, 2.2)
		3:
			# ripe: full crop silhouette + a leafy top tuft
			PixelArt.fill_ellipse(img, 8, 5, 2.5, 1.6, leaf_c)
			_draw_crop_shape(img, shape, ripe_c, 8, 10, 4.5)

	PixelArt.outline(img, OUTLINE)
	return img


## Draws the ripe crop's distinct silhouette centered at (cx, cy) scaled by
## `r` (roughly the "radius" of the shape) so each crop type reads uniquely.
func _draw_crop_shape(img: Image, shape: String, c: Color, cx: int, cy: int, r: float) -> void:
	var shade := c.darkened(0.25)
	match shape:
		"round_root":
			# carrot/turnip/tomato: round top, tapering point at bottom
			PixelArt.fill_ellipse(img, cx, cy - r * 0.2, r, r * 0.9, c)
			for y in range(int(cy + r * 0.4), int(cy + r * 1.1)):
				var t := (y - (cy + r * 0.4)) / (r * 0.7)
				var half := maxf(0.0, r * 0.5 * (1.0 - t))
				for x in range(int(cx - half), int(cx + half) + 1):
					PixelArt.px(img, x, y, c)
			PixelArt.fill_ellipse(img, cx + r * 0.3, cy, r * 0.4, r * 0.5, shade)
		"pumpkin":
			# pumpkin/melon: wide round body + a small stem nub
			PixelArt.fill_ellipse(img, cx, cy, r, r * 0.85, c)
			PixelArt.fill_ellipse(img, cx + r * 0.35, cy + r * 0.1, r * 0.45, r * 0.55, shade)
			PixelArt.rect(img, cx - 1, int(cy - r * 0.85) - 1, 2, 2, Color("4a7a2a"))
			# ridge lines
			PixelArt.vline(img, cx, int(cy - r * 0.7), int(r * 1.4), shade)
		"berry":
			# strawberry/eggplant: teardrop, wide top narrowing to bottom point
			for y in range(int(cy - r * 0.8), int(cy + r * 0.9)):
				var t := (y - (cy - r * 0.8)) / (r * 1.7)
				var half := r * (0.9 - t * 0.75)
				for x in range(int(cx - half), int(cx + half) + 1):
					PixelArt.px(img, x, y, c)
			PixelArt.fill_ellipse(img, cx + r * 0.25, cy, r * 0.35, r * 0.4, shade)
			# seed/calyx flecks
			var seed_c := Color("f0e8b8") if c != Color("7048a8") else Color("3a2858")
			PixelArt.px(img, cx - 1, cy - 1, seed_c)
			PixelArt.px(img, cx + 1, cy + 2, seed_c)
		"corn":
			# corn: tall narrow cylinder with kernel dither
			PixelArt.rect(img, cx - int(r * 0.5), cy - int(r * 1.1), int(r), int(r * 2.0), c)
			PixelArt.rect(img, cx, cy - int(r * 1.1), int(r * 0.5), int(r * 2.0), shade)
			PixelArt.dither(img, cx - int(r * 0.5), cy - int(r * 1.1), int(r), int(r * 2.0), c.lightened(0.2), 0.25, PixelArt.hash_seed("corn_kernel"))
			# husk leaves at the base
			PixelArt.fill_ellipse(img, cx - r * 0.6, cy + r * 0.9, r * 0.5, r * 0.3, Color("4a7a2a"))
			PixelArt.fill_ellipse(img, cx + r * 0.6, cy + r * 0.9, r * 0.5, r * 0.3, Color("3a6a20"))
		"leafy":
			# amberleaf: a cluster of broad leaves, no round fruit
			PixelArt.fill_ellipse(img, cx - r * 0.4, cy, r * 0.7, r * 0.5, c)
			PixelArt.fill_ellipse(img, cx + r * 0.4, cy - r * 0.2, r * 0.7, r * 0.5, c)
			PixelArt.fill_ellipse(img, cx, cy + r * 0.3, r * 0.6, r * 0.4, shade)


## =====================================================================
## ITEMS — 16x16 readable icons
## =====================================================================

func _write_items() -> int:
	var n := 0
	# produce (share the same shape family as their crop's ripe stage)
	var produce := {
		"item_turnip": ["e8e0d0", "round_root"],
		"item_carrot": ["e07820", "round_root"],
		"item_pumpkin": ["d06010", "pumpkin"],
		"item_strawberry": ["e04060", "berry"],
		"item_tomato": ["d84030", "round_root"],
		"item_corn": ["e8c840", "corn"],
		"item_melon": ["70c880", "pumpkin"],
		"item_eggplant": ["7048a8", "berry"],
		"item_amberleaf": ["d89838", "leafy"],
		"item_wildroot": ["a87848", "round_root"],
		"item_emberberry": ["e06828", "berry"],
		"item_frostcap": ["a8d8e8", "pumpkin"],
	}
	for name: String in produce:
		var spec: Array = produce[name]
		var img := PixelArt.blank(16, 16)
		PixelArt.ground_shadow(img, 8, 15, 4, 0.2)
		_draw_crop_shape(img, spec[1], Color(spec[0]), 8, 9, 5.5)
		PixelArt.outline(img, OUTLINE)
		_save(OUT + name + ".png", img)
		n += 1

	# seeds — little cloth packets with a color swatch + tie
	var seeds := {
		"item_turnip_seeds": "c8c0a0", "item_carrot_seeds": "c09060",
		"item_pumpkin_seeds": "b08040", "item_strawberry_seeds": "d0a0a8",
		"item_tomato_seeds": "c89078", "item_corn_seeds": "d8c890",
		"item_melon_seeds": "98c0a0", "item_eggplant_seeds": "9880b0",
		"item_amberleaf_seeds": "c8a878",
	}
	for name: String in seeds:
		_save(OUT + name + ".png", _draw_seed_packet(Color(seeds[name])))
		n += 1

	# tools — recognizable tool silhouettes
	_save(OUT + "item_hoe.png", _draw_hoe())
	_save(OUT + "item_watering_can.png", _draw_watering_can(Color("4080b0"), false))
	_save(OUT + "item_copper_can.png", _draw_watering_can(Color("c07840"), true))
	n += 3

	# swords / blades
	_save(OUT + "item_wooden_sword.png", _draw_sword(Color("9a6a3a"), Color("c8a878"), false))
	_save(OUT + "item_iron_sword.png", _draw_sword(Color("c0c8d0"), Color("8a8a90"), false))
	_save(OUT + "item_steel_sword.png", _draw_sword(Color("e0e8f0"), Color("a8a8b0"), false))
	_save(OUT + "item_fangsteel_blade.png", _draw_sword(Color("586070"), Color("e8d8a0"), true))
	n += 4

	# materials — distinct silhouettes so gel/dust/fang/shells don't blur together
	_save(OUT + "item_slime_gel.png", _draw_gel(Color("60d060")))
	_save(OUT + "item_wisp_dust.png", _draw_dust(Color("90d0f0")))
	_save(OUT + "item_goblin_fang.png", _draw_fang(Color("e0d0b0")))
	_save(OUT + "item_driftglass.png", _draw_gel(Color("78c8c0")))
	_save(OUT + "item_tideshell.png", _draw_shell(Color("e0d0b8")))
	n += 5

	# cooked dishes — bowl/plate silhouettes, distinct from raw produce
	var dishes := {
		"dish_roast_turnip": "e8b070", "dish_carrot_soup": "e08838",
		"dish_berry_jam": "c83858", "dish_corn_chowder": "e8d060",
		"dish_melon_sorbet": "80d0a0", "dish_pumpkin_pie": "d87018",
		"dish_forest_stew": "886038", "dish_miners_meal": "8868a8",
	}
	for name: String in dishes:
		_save(OUT + name + ".png", _draw_dish(Color(dishes[name])))
		n += 1

	return n


func _draw_seed_packet(swatch: Color) -> Image:
	var img := PixelArt.blank(16, 16)
	var paper := Color("d8c8a0")
	var paper_shade := Color("b8a880")
	var tie := Color("5a4028")
	PixelArt.rect(img, 3, 3, 10, 11, paper)
	PixelArt.shade_right(img, 3, 3, 10, 11, paper_shade, 3)
	# fold tie across the top
	PixelArt.hline(img, 3, 5, 10, tie)
	# color swatch (shows what's inside)
	PixelArt.rect(img, 6, 8, 4, 4, swatch)
	PixelArt.outline(img, OUTLINE)
	return img


func _draw_hoe() -> Image:
	var img := PixelArt.blank(16, 16)
	var handle := Color("8a5a2f")
	var head := Color("808890")
	var head_shade := Color("606870")
	# diagonal handle
	for i in 11:
		PixelArt.px(img, 2 + i, 13 - i, handle)
		PixelArt.px(img, 3 + i, 13 - i, handle)
	# hoe head at the top, perpendicular blade
	PixelArt.rect(img, 10, 1, 5, 3, head)
	PixelArt.rect(img, 13, 1, 2, 3, head_shade)
	PixelArt.outline(img, OUTLINE)
	return img


func _draw_watering_can(body_c: Color, wide_spout: bool) -> Image:
	var img := PixelArt.blank(16, 16)
	var body_shade := body_c.darkened(0.25)
	var handle := body_c.darkened(0.15)
	# can body
	PixelArt.rect(img, 3, 7, 8, 6, body_c)
	PixelArt.shade_right(img, 3, 7, 8, 6, body_shade, 3)
	# handle arc on top
	PixelArt.hline(img, 4, 5, 6, handle)
	PixelArt.px(img, 4, 6, handle)
	PixelArt.px(img, 9, 6, handle)
	# spout to the upper-right
	PixelArt.hline(img, 10, 6, 3, body_c)
	if wide_spout:
		PixelArt.hline(img, 12, 5, 3, body_c)
		PixelArt.px(img, 14, 4, body_shade)
		PixelArt.px(img, 13, 4, body_c)
		PixelArt.px(img, 14, 6, body_c)
	else:
		PixelArt.px(img, 13, 5, body_c)
	PixelArt.outline(img, OUTLINE)
	return img


func _draw_sword(blade_c: Color, hilt_c: Color, has_accent: bool) -> Image:
	var img := PixelArt.blank(16, 16)
	var blade_shade := blade_c.darkened(0.2)
	# blade: diagonal from bottom-left hilt to top-right tip
	for i in 11:
		PixelArt.px(img, 3 + i, 12 - i, blade_c)
		if i > 0:
			PixelArt.px(img, 3 + i, 13 - i, blade_shade)
	# cross-guard
	PixelArt.px(img, 3, 12, hilt_c)
	PixelArt.px(img, 4, 13, hilt_c)
	PixelArt.px(img, 2, 11, hilt_c)
	# hilt/handle
	PixelArt.px(img, 1, 14, Color("4a3020"))
	PixelArt.px(img, 2, 14, Color("4a3020"))
	if has_accent:
		var accent_c := blade_c.lightened(0.6)
		PixelArt.px(img, 12, 3, accent_c)
		PixelArt.px(img, 13, 4, accent_c)
	PixelArt.outline(img, OUTLINE)
	return img


func _draw_gel(c: Color) -> Image:
	var img := PixelArt.blank(16, 16)
	var shade := c.darkened(0.25)
	var hi := Color(1, 1, 1, 0.6)
	# wobbly blob silhouette (asymmetric ellipse cluster reads as "gel")
	PixelArt.fill_ellipse(img, 7, 9, 4.5, 3.8, c)
	PixelArt.fill_ellipse(img, 10, 8, 2.8, 2.6, c)
	PixelArt.fill_ellipse(img, 8, 10, 3, 2, shade)
	PixelArt.px(img, 6, 7, hi)
	PixelArt.outline(img, OUTLINE)
	return img


func _draw_dust(c: Color) -> Image:
	var img := PixelArt.blank(16, 16)
	# a loose scatter of small motes (dust cloud), deterministic positions
	var positions := _det_positions(PixelArt.hash_seed("item_wisp_dust"), 9, 12, 12)
	for p: Vector2i in positions:
		var alpha := 0.55 + (p.x % 3) * 0.15
		PixelArt.px(img, p.x + 2, p.y + 2, Color(c.r, c.g, c.b, alpha))
	# denser core
	PixelArt.fill_ellipse(img, 8, 8, 2.5, 2.2, c)
	PixelArt.outline(img, OUTLINE)
	return img


func _draw_fang(c: Color) -> Image:
	var img := PixelArt.blank(16, 16)
	var shade := c.darkened(0.2)
	# curved tusk/fang: tapering triangle with a slight curve
	for y in range(3, 13):
		var t := (y - 3) / 9.0
		var half := maxf(0.4, 2.6 * (1.0 - t))
		var bend := int(t * 1.5)
		for x in range(int(8 - half) + bend, int(8 + half) + bend + 1):
			PixelArt.px(img, x, y, c)
	PixelArt.vline(img, 8, 3, 6, shade)
	PixelArt.outline(img, OUTLINE)
	return img


func _draw_shell(c: Color) -> Image:
	var img := PixelArt.blank(16, 16)
	var shade := c.darkened(0.25)
	var ridge := c.darkened(0.4)
	# fan/scallop shell: half-circle with ridge lines fanning from a hinge point
	PixelArt.fill_ellipse(img, 8, 10, 5.5, 4, c)
	for i in range(-2, 3):
		var x0 := 8
		var y0 := 6
		var x1 := 8 + i * 2
		var y1 := 13
		var steps := 8
		for s in steps:
			var t := s / float(steps - 1)
			var x := int(lerp(x0, x1, t))
			var y := int(lerp(y0, y1, t))
			PixelArt.px(img, x, y, ridge)
	PixelArt.fill_ellipse(img, 9, 11, 3, 2, shade)
	PixelArt.outline(img, OUTLINE)
	return img


func _draw_dish(c: Color) -> Image:
	var img := PixelArt.blank(16, 16)
	var bowl := Color("e8e4d8")
	var bowl_shade := Color("c8c4b4")
	var shine := Color(1, 1, 1, 0.5)
	# plate/bowl base
	PixelArt.fill_ellipse(img, 8, 11, 6, 2.6, bowl_shade)
	PixelArt.fill_ellipse(img, 8, 10, 6, 2.6, bowl)
	# food filling on top, colored per-dish
	PixelArt.fill_ellipse(img, 8, 9, 4.2, 2.2, c)
	PixelArt.fill_ellipse(img, 8, 8.3, 4.2, 1.4, c.lightened(0.15))
	PixelArt.px(img, 6, 8, shine)
	PixelArt.outline(img, OUTLINE)
	return img


## =====================================================================
## PROPS — house/barn/fence/bed/bin/kitchen/counter/stairs/sign/boat_shed
## =====================================================================

func _write_props() -> int:
	var n := 0
	_save(OUT + "prop_house.png", _draw_house(48, 48))
	_save(OUT + "prop_barn.png", _draw_barn(32, 24))
	_save(OUT + "prop_fence.png", _draw_fence())
	_save(OUT + "prop_bed.png", _draw_bed())
	_save(OUT + "prop_shipping_bin.png", _draw_bin())
	_save(OUT + "prop_kitchen.png", _draw_kitchen())
	_save(OUT + "prop_counter.png", _draw_counter())
	_save(OUT + "prop_stairs_down.png", _draw_stairs(true))
	_save(OUT + "prop_stairs_up.png", _draw_stairs(false))
	_save(OUT + "prop_sign.png", _draw_sign())
	_save(OUT + "prop_boat_shed.png", _draw_boat_shed())
	n += 11
	return n


func _draw_house(w: int, h: int) -> Image:
	var img := PixelArt.blank(w, h)
	var wall := Color("c8a878")
	var wall_shade := Color("a88858")
	var roof := Color("7a4a3a")
	var roof_shade := Color("5a3428")
	var door := Color("4a3020")
	var window_c := Color("a8d8e8")
	var window_frame := Color("5a3a28")
	var trim := Color("8a6248")

	# walls (bottom 60%)
	var wall_top := int(h * 0.42)
	PixelArt.rect(img, 2, wall_top, w - 4, h - wall_top - 2, wall)
	PixelArt.shade_right(img, 2, wall_top, w - 4, h - wall_top - 2, wall_shade, w / 5)

	# roof: triangular gable
	var roof_base := wall_top + 1
	var apex_x := w / 2
	for y in range(2, roof_base):
		var t := float(y - 2) / float(roof_base - 2)
		var half := t * (w / 2.0 - 1)
		PixelArt.hline(img, int(apex_x - half), y, int(half * 2) + 1, roof)
	# roof shade on the right slope
	for y in range(2, roof_base):
		var t := float(y - 2) / float(roof_base - 2)
		var half := t * (w / 2.0 - 1)
		var sw := maxi(1, int(half * 0.3))
		PixelArt.hline(img, int(apex_x + half) - sw, y, sw, roof_shade)
	# roof trim line
	PixelArt.hline(img, 2, roof_base, w - 4, trim)

	# door, centered near bottom
	var door_w := maxi(6, w / 6)
	var door_h := int((h - wall_top) * 0.6)
	PixelArt.rect(img, apex_x - door_w / 2, h - 2 - door_h, door_w, door_h, door)
	# windows flanking the door
	var win_y := wall_top + 4
	PixelArt.rect(img, 6, win_y, 6, 6, window_frame)
	PixelArt.rect(img, 7, win_y + 1, 4, 4, window_c)
	PixelArt.rect(img, w - 12, win_y, 6, 6, window_frame)
	PixelArt.rect(img, w - 11, win_y + 1, 4, 4, window_c)

	PixelArt.outline(img, OUTLINE)
	return img


func _draw_barn(w: int, h: int) -> Image:
	var img := PixelArt.blank(w, h)
	var wall := Color("8a4a2a")
	var wall_shade := Color("6a3620")
	var roof := Color("4a3428")
	var trim := Color("e8e0d0")
	var door := Color("5a3a20")

	var wall_top := int(h * 0.35)
	PixelArt.rect(img, 1, wall_top, w - 2, h - wall_top - 1, wall)
	PixelArt.shade_right(img, 1, wall_top, w - 2, h - wall_top - 1, wall_shade, w / 5)
	# gambrel-ish roof: two-slope silhouette (barn read vs house's simple gable)
	var apex_x := w / 2
	for y in range(1, wall_top):
		var t := float(y - 1) / float(wall_top - 1)
		var half: float
		if t < 0.5:
			half = lerp(w * 0.15, w * 0.48, t / 0.5)
		else:
			half = lerp(w * 0.48, w * 0.5 - 1, (t - 0.5) / 0.5)
		PixelArt.hline(img, int(apex_x - half), y, int(half * 2) + 1, roof)
	# white trim gable triangle accent + hay loft door
	PixelArt.rect(img, apex_x - 3, wall_top - 3, 6, 3, trim)
	# big double barn door, centered
	var door_w := int(w * 0.32)
	PixelArt.rect(img, apex_x - door_w / 2, h - 1 - (h - wall_top - 2), door_w, h - wall_top - 2, door)
	PixelArt.vline(img, apex_x, wall_top + 1, h - wall_top - 3, trim.darkened(0.3))

	PixelArt.outline(img, OUTLINE)
	return img


func _draw_fence() -> Image:
	var img := PixelArt.blank(16, 16)
	var wood := Color("6a5638")
	var wood_shade := Color("4e3f28")
	# two vertical posts + horizontal rails (classic pen-fence silhouette)
	PixelArt.rect(img, 1, 4, 2, 11, wood)
	PixelArt.rect(img, 13, 4, 2, 11, wood)
	PixelArt.rect(img, 0, 5, 16, 2, wood)
	PixelArt.rect(img, 0, 10, 16, 2, wood)
	PixelArt.shade_right(img, 0, 5, 16, 2, wood_shade, 4)
	PixelArt.shade_right(img, 0, 10, 16, 2, wood_shade, 4)
	PixelArt.outline(img, OUTLINE)
	return img


func _draw_bed() -> Image:
	var img := PixelArt.blank(16, 24)
	var frame := Color("6b3a2a")
	var blanket := Color("b03030")
	var blanket_shade := Color("8a2424")
	var pillow := Color("e8e0d0")
	# frame/legs
	PixelArt.rect(img, 1, 4, 14, 18, frame)
	# pillow at head
	PixelArt.rect(img, 2, 5, 12, 4, pillow)
	# blanket covering the rest
	PixelArt.rect(img, 2, 9, 12, 11, blanket)
	PixelArt.shade_right(img, 2, 9, 12, 11, blanket_shade, 4)
	PixelArt.outline(img, OUTLINE)
	return img


func _draw_bin() -> Image:
	var img := PixelArt.blank(16, 16)
	var body := Color("8a5a2a")
	var body_shade := Color("6a4420")
	var slot := Color("3a2818")
	var trim := Color("c89858")
	PixelArt.rect(img, 2, 4, 12, 11, body)
	PixelArt.shade_right(img, 2, 4, 12, 11, body_shade, 4)
	PixelArt.hline(img, 2, 4, 12, trim)
	# shipping slot
	PixelArt.rect(img, 5, 7, 6, 2, slot)
	PixelArt.outline(img, OUTLINE)
	return img


func _draw_kitchen() -> Image:
	var img := PixelArt.blank(24, 16)
	var body := Color("8a6248")
	var body_shade := Color("6a4a36")
	var stove := Color("3a3a3e")
	var flame := Color("e88838")
	PixelArt.rect(img, 1, 5, 22, 10, body)
	PixelArt.shade_right(img, 1, 5, 22, 10, body_shade, 6)
	# stovetop with burners
	PixelArt.rect(img, 3, 6, 8, 3, stove)
	PixelArt.px(img, 5, 7, flame)
	PixelArt.px(img, 8, 7, flame)
	# counter surface trim
	PixelArt.hline(img, 1, 5, 22, Color("a88868"))
	PixelArt.outline(img, OUTLINE)
	return img


func _draw_counter() -> Image:
	var img := PixelArt.blank(32, 16)
	var body := Color("5a3a2a")
	var body_shade := Color("402a1e")
	var top := Color("8a6a4a")
	PixelArt.rect(img, 0, 6, 32, 9, body)
	PixelArt.shade_right(img, 0, 6, 32, 9, body_shade, 8)
	PixelArt.hline(img, 0, 6, 32, top)
	PixelArt.hline(img, 0, 5, 32, top.lightened(0.15))
	PixelArt.outline(img, OUTLINE)
	return img


func _draw_stairs(pointing_down: bool) -> Image:
	var img := PixelArt.blank(16, 16)
	var frame := Color("222230") if pointing_down else Color("d0d0e0")
	var frame_shade := frame.darkened(0.25)
	var chevron_c := frame.lightened(0.5) if pointing_down else frame.darkened(0.4)
	PixelArt.rect(img, 1, 1, 14, 14, frame)
	PixelArt.shade_right(img, 1, 1, 14, 14, frame_shade, 4)
	# chevron stack pointing down or up
	var rows := 4
	var start_y := 5
	for i in rows:
		var y := start_y + i * 2 if pointing_down else start_y + (rows - 1 - i) * 2
		var row_from_point: int = i if pointing_down else (rows - 1 - i)
		var half_width := row_from_point + 1
		for dx in range(-half_width, half_width + 1):
			PixelArt.px(img, 8 + dx, y, chevron_c)
	PixelArt.outline(img, OUTLINE)
	return img


func _draw_sign() -> Image:
	var img := PixelArt.blank(16, 24)
	var post := Color("6a4a2a")
	var board := Color("c8a868")
	var board_shade := Color("a8885a")
	PixelArt.vline(img, 7, 10, 12, post)
	PixelArt.vline(img, 8, 10, 12, post)
	PixelArt.rect(img, 2, 3, 12, 8, board)
	PixelArt.shade_right(img, 2, 3, 12, 8, board_shade, 3)
	# a couple of "text" ticks so it reads as a sign, not a blank plank
	PixelArt.hline(img, 4, 6, 8, Color("5a4028"))
	PixelArt.hline(img, 5, 8, 6, Color("5a4028"))
	PixelArt.outline(img, OUTLINE)
	return img


func _draw_boat_shed() -> Image:
	var img := PixelArt.blank(24, 16)
	var wall := Color("5a4a3a")
	var wall_shade := Color("40342a")
	var roof := Color("3a4a5a")
	var water_hint := Color("4a7aa0")
	var wall_top := 7
	PixelArt.rect(img, 1, wall_top, 22, 16 - wall_top - 1, wall)
	PixelArt.shade_right(img, 1, wall_top, 22, 16 - wall_top - 1, wall_shade, 6)
	# lean-to roof slope
	for y in range(1, wall_top):
		var t := float(y - 1) / float(wall_top - 1)
		var left := int(lerp(2, 1, t))
		PixelArt.hline(img, left, y, int(lerp(6, 22, t)), roof)
	# open boat-slip gap at the base with a hint of water
	PixelArt.rect(img, 9, wall_top + 4, 6, 16 - wall_top - 5, water_hint)
	PixelArt.outline(img, OUTLINE)
	return img


## =====================================================================
## SAVE + REVIEW ARTIFACTS
## =====================================================================

func _save(path: String, img: Image) -> void:
	var err := img.save_png(path)
	assert(err == OK, "Failed to write " + path)


## Every generated asset, tiled at 5x with grouping, to tools/_proto/
## contact_sheet.png (gitignored) for the mandatory review loop.
func _write_contact_sheet() -> void:
	var entries: Array = []
	var dir := DirAccess.open(OUT)
	if dir == null:
		return
	var names: Array = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".png") and not fname.ends_with(".import"):
			names.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	names.sort()
	for n: String in names:
		var img := Image.load_from_file(OUT + n)
		if img == null:
			continue
		entries.append({"image": img, "tick_color": PixelArt.average_color(img)})
	var sheet := PixelArt.compose_contact_sheet(entries, 12, 5)
	sheet.save_png(PROTO_OUT + "contact_sheet.png")


## All 9 characters' down-facing idle, side by side at 8x.
func _write_characters_preview() -> void:
	var entries: Array = []
	for def: CharDef in _char_defs():
		var img := Image.load_from_file(OUT + "char_%s.png" % def.id)
		if img != null:
			entries.append({"image": img, "tick_color": def.shirt})
	var sheet := PixelArt.compose_contact_sheet(entries, 9, 8)
	sheet.save_png(PROTO_OUT + "characters_8x.png")


## Tiles + props, side by side at 6x.
func _write_tiles_and_props_preview() -> void:
	var names := [
		"tile_grass", "tile_grass_dark", "tile_soil_tilled", "tile_soil_watered",
		"tile_stone_floor", "tile_wall", "tile_water", "tile_path", "tile_sand",
		"prop_house", "prop_barn", "prop_fence", "prop_bed", "prop_shipping_bin",
		"prop_kitchen", "prop_counter", "prop_stairs_up", "prop_stairs_down",
		"prop_sign", "prop_boat_shed",
	]
	var entries: Array = []
	for n: String in names:
		var img := Image.load_from_file(OUT + n + ".png")
		if img != null:
			entries.append({"image": img, "tick_color": PixelArt.average_color(img)})
	var sheet := PixelArt.compose_contact_sheet(entries, 8, 6)
	sheet.save_png(PROTO_OUT + "tiles_and_props_6x.png")
