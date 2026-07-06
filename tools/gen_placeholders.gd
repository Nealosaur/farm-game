extends SceneTree
## Generates flat-color placeholder PNGs at final art dimensions, with
## differentiated silhouettes so items/chars/crops read distinctly instead of
## being anonymous colored squares. Rerun any time (it overwrites, and is
## byte-stable/deterministic — no RNG anywhere in this file). Real art later
## replaces files, SAME names/sizes.
## Run: "$GODOT" --headless --path . -s res://tools/gen_placeholders.gd

const OUT := "res://assets/placeholder/"

const TILES := {
	"tile_grass": "4a7a3a",
	"tile_grass_dark": "3f6a31",
	"tile_soil_tilled": "6b4a2f",
	"tile_soil_watered": "4a3320",
	"tile_stone_floor": "6e6e78",
	"tile_wall": "3a3a44",
	"tile_water": "2f5f8f",
	"tile_path": "9a8a6a",
	"tile_sand": "d8c888",
}

# Silhouette kind per sprite: "" = flat square (tiles/most props, unchanged).
const KIND_CIRCLE_CHAR := "circle_char"    # rounded blob: slimes
const KIND_TRIANGLE := "triangle"          # wisp
const KIND_HEADBAND := "headband"          # player/marta/goblin: rect + darker head band
const KIND_CIRCLE_ITEM := "circle_item"    # crops/materials: filled circle
const KIND_DIAMOND := "diamond"            # seeds
const KIND_BLADE := "blade"                # swords: diagonal stripe
const KIND_CROSS := "cross"                # tools
const KIND_CIRCLE_DOT := "circle_dot"      # cooked dishes: filled circle + contrasting center dot
const KIND_BLADE_ACCENT := "blade_accent"  # Craft Stride 2: blade stripe + a contrasting accent tick near the tip (fangsteel_blade)
const KIND_CAN_WIDE := "can_wide"          # Craft Stride 2: cross (tool silhouette) + a wider spout mark (copper_can)

const SPRITES := {
	"char_player": [16, 32, "e0b070", KIND_HEADBAND],
	"char_marta": [16, 32, "c070c0", KIND_HEADBAND],
	"char_slime": [16, 16, "50c050", KIND_CIRCLE_CHAR],
	"char_wisp": [16, 16, "70c0e0", KIND_TRIANGLE],
	"char_goblin": [16, 24, "a05030", KIND_HEADBAND],
	"char_slime_king": [48, 48, "208020", KIND_CIRCLE_CHAR],
	# World Stride C: the remaining seven NPCs, distinct headband colors.
	"char_sten": [16, 32, "704838", KIND_HEADBAND],
	"char_bram": [16, 32, "d8d8d8", KIND_HEADBAND],
	"char_rosa": [16, 32, "e04848", KIND_HEADBAND],
	"char_alden": [16, 32, "384868", KIND_HEADBAND],
	"char_finn": [16, 32, "e0a838", KIND_HEADBAND],
	"char_willow": [16, 32, "588858", KIND_HEADBAND],
	"char_garrick": [16, 32, "605850", KIND_HEADBAND],
	"prop_bed": [16, 24, "b03030", ""],
	"prop_shipping_bin": [16, 16, "8a5a2a", ""],
	"prop_stairs_down": [16, 16, "222230", "chevron_down"],
	"prop_stairs_up": [16, 16, "d0d0e0", "chevron_up"],
	"prop_house": [48, 48, "7a4a3a", ""],
	"prop_counter": [32, 16, "5a3a2a", ""],
	"prop_sign": [16, 24, "8a6a3a", ""],
	"prop_boat_shed": [24, 16, "5a4a3a", ""],
	"prop_kitchen": [24, 16, "8a6248", ""],  # Craft Stride 1: farm kitchen, beside the house
	"item_turnip": [16, 16, "e8e0d0", KIND_CIRCLE_ITEM],
	"item_carrot": [16, 16, "e07820", KIND_CIRCLE_ITEM],
	"item_pumpkin": [16, 16, "d06010", KIND_CIRCLE_ITEM],
	"item_turnip_seeds": [16, 16, "c8c0a0", KIND_DIAMOND],
	"item_carrot_seeds": [16, 16, "c09060", KIND_DIAMOND],
	"item_pumpkin_seeds": [16, 16, "b08040", KIND_DIAMOND],
	"item_hoe": [16, 16, "808890", KIND_CROSS],
	"item_watering_can": [16, 16, "4080b0", KIND_CROSS],
	"item_wooden_sword": [16, 16, "9a6a3a", KIND_BLADE],
	"item_iron_sword": [16, 16, "c0c8d0", KIND_BLADE],
	# Craft Stride 2 (Forging): steel is a LIGHTER blade stripe than iron
	# (bible: "steel lighter"); fangsteel is a DARKER stripe with a
	# contrasting accent tick near the tip (bible: "fangsteel darker w/
	# accent") — both deterministic, no new draw primitive needed for steel.
	"item_steel_sword": [16, 16, "e0e8f0", KIND_BLADE],
	"item_fangsteel_blade": [16, 16, "586070", KIND_BLADE_ACCENT],
	"item_copper_can": [16, 16, "c07840", KIND_CAN_WIDE],
	"item_slime_gel": [16, 16, "60d060", KIND_CIRCLE_ITEM],
	"item_wisp_dust": [16, 16, "90d0f0", KIND_CIRCLE_ITEM],
	"item_goblin_fang": [16, 16, "e0d0b0", KIND_CIRCLE_ITEM],
	# World Stride A content: produce + forage circles, seed diamonds.
	"item_strawberry": [16, 16, "e04060", KIND_CIRCLE_ITEM],
	"item_tomato": [16, 16, "d84030", KIND_CIRCLE_ITEM],
	"item_corn": [16, 16, "e8c840", KIND_CIRCLE_ITEM],
	"item_melon": [16, 16, "70c880", KIND_CIRCLE_ITEM],
	"item_eggplant": [16, 16, "7048a8", KIND_CIRCLE_ITEM],
	"item_amberleaf": [16, 16, "d89838", KIND_CIRCLE_ITEM],
	"item_strawberry_seeds": [16, 16, "d0a0a8", KIND_DIAMOND],
	"item_tomato_seeds": [16, 16, "c89078", KIND_DIAMOND],
	"item_corn_seeds": [16, 16, "d8c890", KIND_DIAMOND],
	"item_melon_seeds": [16, 16, "98c0a0", KIND_DIAMOND],
	"item_eggplant_seeds": [16, 16, "9880b0", KIND_DIAMOND],
	"item_amberleaf_seeds": [16, 16, "c8a878", KIND_DIAMOND],
	"item_wildroot": [16, 16, "a87848", KIND_CIRCLE_ITEM],
	"item_emberberry": [16, 16, "e06828", KIND_CIRCLE_ITEM],
	"item_frostcap": [16, 16, "a8d8e8", KIND_CIRCLE_ITEM],
	"item_tideshell": [16, 16, "e0d0b8", KIND_CIRCLE_ITEM],
	"item_driftglass": [16, 16, "78c8c0", KIND_CIRCLE_ITEM],
	# Craft Stride 1: cooked dishes — circle-with-dot silhouette, distinct
	# from raw produce's plain KIND_CIRCLE_ITEM (bible: "distinct from raw
	# produce"). Filenames are "dish_<id>" (not "item_<id>") so ItemDB's
	# generic item icon convention still reads correctly at a glance.
	"dish_roast_turnip": [16, 16, "e8b070", KIND_CIRCLE_DOT],
	"dish_carrot_soup": [16, 16, "e08838", KIND_CIRCLE_DOT],
	"dish_berry_jam": [16, 16, "c83858", KIND_CIRCLE_DOT],
	"dish_corn_chowder": [16, 16, "e8d060", KIND_CIRCLE_DOT],
	"dish_melon_sorbet": [16, 16, "80d0a0", KIND_CIRCLE_DOT],
	"dish_pumpkin_pie": [16, 16, "d87018", KIND_CIRCLE_DOT],
	"dish_forest_stew": [16, 16, "886038", KIND_CIRCLE_DOT],
	"dish_miners_meal": [16, 16, "8868a8", KIND_CIRCLE_DOT],
}

# 4 growth-stage sprites per crop: stage 0 (seeded, soil brown) -> 3 (ripe, final color).
# Growing circle radius per stage instead of a full-square fill.
# (Forage items have NO stage sprites — they're plain pickups, not plantable.)
const CROPS := {
	"turnip": "e8e0d0",
	"carrot": "e07820",
	"pumpkin": "d06010",
	"strawberry": "e04060",
	"tomato": "d84030",
	"corn": "e8c840",
	"melon": "70c880",
	"eggplant": "7048a8",
	"amberleaf": "d89838",
}
const CROP_STAGE_RADII := [2, 4, 6, 8]


func _init() -> void:
	var dir_err := DirAccess.make_dir_recursive_absolute(OUT)
	assert(dir_err == OK, "Cannot create " + OUT)
	var count := 0
	for n: String in TILES:
		_write_flat(n, 16, 16, Color(TILES[n]))
		count += 1
	for n: String in SPRITES:
		var s: Array = SPRITES[n]
		_write_kind(n, s[0], s[1], Color(s[2]), s[3])
		count += 1
	for c: String in CROPS:
		for stage in 4:
			var col := Color("6b4a2f").lerp(Color(CROPS[c]), stage / 3.0)
			_write_crop_stage("crop_%s_%d" % [c, stage], 16, 16, col, CROP_STAGE_RADII[stage])
			count += 1
	print("placeholders written: ", count)
	quit(0)


## ---- base border helper (every sprite keeps the 1px darker border) ----

static func _bordered(img: Image, c: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var dark := c.darkened(0.4)
	for x in w:
		img.set_pixel(x, 0, dark)
		img.set_pixel(x, h - 1, dark)
	for y in h:
		img.set_pixel(0, y, dark)
		img.set_pixel(w - 1, y, dark)


## ---- draw helpers ----

static func fill_circle(img: Image, cx: float, cy: float, radius: float, c: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var r2 := radius * radius
	for y in h:
		for x in w:
			var dx := x + 0.5 - cx
			var dy := y + 0.5 - cy
			if dx * dx + dy * dy <= r2:
				img.set_pixel(x, y, c)


static func draw_diamond(img: Image, c: Color) -> void:
	## Diamond silhouette on transparent inscribed in the image bounds.
	var w := img.get_width()
	var h := img.get_height()
	var cx := w / 2.0
	var cy := h / 2.0
	for y in h:
		for x in w:
			var dx: float = absf(x + 0.5 - cx) / (w / 2.0)
			var dy: float = absf(y + 0.5 - cy) / (h / 2.0)
			if dx + dy <= 1.0:
				img.set_pixel(x, y, c)


static func draw_blade(img: Image, c: Color) -> void:
	## Diagonal blade stripe from bottom-left to top-right (hilt at the
	## bottom-left corner, tip at the top-right) plus a short cross-guard.
	var w := img.get_width()
	var h := img.get_height()
	img.fill(Color(0, 0, 0, 0))
	var thickness := maxf(1.5, w / 8.0)
	for y in h:
		for x in w:
			# Line from (0, h) to (w, 0): x/w + y/h == 1 -> distance test below.
			var t: float = (float(x) / w) + (float(y) / h) - 1.0
			var dist: float = absf(t) * (w + h) / 2.0
			if dist <= thickness:
				img.set_pixel(x, y, c)
	# Cross-guard: a short perpendicular tick near the hilt (bottom-left third).
	var guard_c := c.darkened(0.3)
	var gx := int(w * 0.28)
	var gy := int(h * 0.72)
	for i in range(-2, 3):
		var px: int = clampi(gx + i, 0, w - 1)
		var py: int = clampi(gy - i, 0, h - 1)
		img.set_pixel(px, py, guard_c)
	_bordered(img, c)


static func draw_cross(img: Image, c: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	img.fill(Color(0, 0, 0, 0))
	var thickness: int = maxi(2, w / 5)
	var half_t := thickness / 2
	var cx := w / 2
	var cy := h / 2
	for y in h:
		for x in w:
			var in_vert: bool = absi(x - cx) <= half_t
			var in_horiz: bool = absi(y - cy) <= half_t
			if in_vert or in_horiz:
				img.set_pixel(x, y, c)
	_bordered(img, c)


static func draw_triangle(img: Image, c: Color) -> void:
	## Simple upward-pointing triangle (apex at top-center, base at the bottom).
	var w := img.get_width()
	var h := img.get_height()
	img.fill(Color(0, 0, 0, 0))
	var apex_x := w / 2.0
	for y in h:
		var t: float = float(y) / float(h - 1)  # 0 at apex row, 1 at base row
		var half_width: float = t * (w / 2.0)
		var left := apex_x - half_width
		var right := apex_x + half_width
		for x in w:
			if x + 0.5 >= left and x + 0.5 <= right:
				img.set_pixel(x, y, c)
	_bordered(img, c)


static func draw_blade_accent(img: Image, c: Color) -> void:
	## Craft Stride 2 (Fangsteel Blade): same diagonal stripe + cross-guard as
	## draw_blade(), plus one extra contrasting accent pixel-cluster near the
	## TIP (top-right third) — a lighter "fang" fleck on the darker base
	## steel, so fangsteel reads distinctly from the plain steel/iron blades
	## at a glance even though all three share KIND_BLADE's geometry.
	draw_blade(img, c)
	var w := img.get_width()
	var h := img.get_height()
	var accent_c := c.lightened(0.6)
	var ax := int(w * 0.74)
	var ay := int(h * 0.24)
	for i in range(-1, 2):
		var px: int = clampi(ax + i, 0, w - 1)
		var py: int = clampi(ay - i, 0, h - 1)
		img.set_pixel(px, py, accent_c)


static func draw_can_wide(img: Image, c: Color) -> void:
	## Craft Stride 2 (Copper Watering Can): same cross silhouette as
	## draw_cross() (tool-family read), plus a WIDER spout mark — three
	## short ticks fanning out from the top-right corner instead of the
	## ordinary can's implicit single-point spout — so the wide-water can
	## reads distinctly from the plain watering_can at a glance.
	draw_cross(img, c)
	var w := img.get_width()
	var h := img.get_height()
	var spout_c := c.darkened(0.3)
	var origin := Vector2i(int(w * 0.78), int(h * 0.22))
	var offsets := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(1, -1)]
	for off: Vector2i in offsets:
		var px: int = clampi(origin.x + off.x, 0, w - 1)
		var py: int = clampi(origin.y + off.y, 0, h - 1)
		img.set_pixel(px, py, spout_c)


static func draw_circle_dot(img: Image, c: Color) -> void:
	## Cooked-dish silhouette: filled circle (like KIND_CIRCLE_ITEM) plus a
	## smaller contrasting dot in the center, so dishes read distinctly from
	## raw produce at a glance.
	var w := img.get_width()
	var h := img.get_height()
	img.fill(Color(0, 0, 0, 0))
	fill_circle(img, w / 2.0, h / 2.0, minf(w, h) / 2.0 - 1.0, c)
	_bordered(img, c)
	fill_circle(img, w / 2.0, h / 2.0, minf(w, h) / 6.0, c.lightened(0.5))


static func draw_headband(img: Image, c: Color) -> void:
	## Filled rect body (already flat-filled by caller) plus a darker band
	## across the head (top ~30% of the sprite) to read as a head silhouette.
	var w := img.get_width()
	var h := img.get_height()
	var band_c := c.darkened(0.35)
	var band_bottom: int = int(h * 0.3)
	for y in range(0, band_bottom):
		for x in w:
			img.set_pixel(x, y, band_c)


static func draw_chevron(img: Image, c: Color, pointing_down: bool) -> void:
	## Inset arrow: rows of pixels forming a chevron (^ or v) centered in the
	## sprite, drawn over the flat fill already applied by the caller.
	var w := img.get_width()
	var h := img.get_height()
	var chevron_c := c.lightened(0.5) if pointing_down else c.darkened(0.3)
	var rows := 5
	var start_y := (h - rows) / 2
	for i in rows:
		var y := start_y + i
		var row_from_point: int = i if pointing_down else (rows - 1 - i)
		var half_width := row_from_point + 1
		var cx := w / 2
		for dx in range(-half_width, half_width + 1):
			var x: int = cx + dx
			if x >= 0 and x < w and y >= 0 and y < h:
				img.set_pixel(x, y, chevron_c)


## ---- top-level writers ----

static func _write_flat(name: String, w: int, h: int, c: Color) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(c)
	_bordered(img, c)
	var err := img.save_png(OUT + name + ".png")
	assert(err == OK, "Failed to write " + name)


static func _write_kind(name: String, w: int, h: int, c: Color, kind: String) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	match kind:
		KIND_CIRCLE_CHAR:
			img.fill(Color(0, 0, 0, 0))
			fill_circle(img, w / 2.0, h / 2.0, minf(w, h) / 2.0 - 1.0, c)
			_bordered(img, c)
		KIND_TRIANGLE:
			draw_triangle(img, c)
		KIND_HEADBAND:
			img.fill(c)
			draw_headband(img, c)
			_bordered(img, c)
		KIND_CIRCLE_ITEM:
			img.fill(Color(0, 0, 0, 0))
			fill_circle(img, w / 2.0, h / 2.0, minf(w, h) / 2.0 - 1.0, c)
			_bordered(img, c)
		KIND_DIAMOND:
			img.fill(Color(0, 0, 0, 0))
			draw_diamond(img, c)
			_bordered(img, c)
		KIND_BLADE:
			draw_blade(img, c)
		KIND_CROSS:
			draw_cross(img, c)
		KIND_CIRCLE_DOT:
			draw_circle_dot(img, c)
		KIND_BLADE_ACCENT:
			draw_blade_accent(img, c)
		KIND_CAN_WIDE:
			draw_can_wide(img, c)
		"chevron_down":
			img.fill(c)
			draw_chevron(img, c, true)
			_bordered(img, c)
		"chevron_up":
			img.fill(c)
			draw_chevron(img, c, false)
			_bordered(img, c)
		_:
			img.fill(c)
			_bordered(img, c)
	var err := img.save_png(OUT + name + ".png")
	assert(err == OK, "Failed to write " + name)


static func _write_crop_stage(name: String, w: int, h: int, c: Color, radius: int) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	fill_circle(img, w / 2.0, h / 2.0, float(radius), c)
	var err := img.save_png(OUT + name + ".png")
	assert(err == OK, "Failed to write " + name)
