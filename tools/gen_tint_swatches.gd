extends SceneTree
## LOOK V3 review artifact: renders the SAME tint curve tint_for_minutes()
## computes, multiplied over a sample of the farm's own tile/prop palette at
## several times of day, so the orchestrator can judge the day/night ramp
## without a live in-engine render (headless has no way to screenshot an
## actual scene).
##
## DUPLICATION NOTE: this re-implements DayTint's WHITE/DUSK/NIGHT constants
## and tint_for_minutes() curve as plain local consts/a local func, rather
## than referencing the DayTint class directly. A bare `-s <script>` SceneTree
## run (no full project bootstrap) fails to compile any script that reaches
## an autoload (day_tint.gd's _ready() touches EventBus) — gen_placeholders.gd
## avoids this the same way, by never referencing autoload-dependent classes.
## If DayTint's curve ever changes, update BOTH copies (or extract the pure
## math into an autoload-free helper both files share — not done here to
## keep this stride's footprint small).
##
## Each ROW is one time-of-day sample; each COLUMN is one ground/prop swatch
## (grass, soil, stone floor, path, water, house wall) so both "does the
## palette stay readable" and "does the ramp progress sensibly row to row"
## are visible at a glance.
##
## Pure function of the tint curve below + the same source PNGs
## gen_placeholders.gd already wrote to assets/placeholder/ — no engine RNG,
## reruns byte-identical as long as those inputs don't change.
## Run: "$GODOT" --headless --path . -s res://tools/gen_tint_swatches.gd

const PROTO_OUT := "res://tools/_proto/"
const SWATCH_SRC := "res://assets/placeholder/"

## Mirrors scripts/components/day_tint.gd's WHITE/DUSK/NIGHT + breakpoints —
## see the DUPLICATION NOTE above for why this isn't a direct reference.
const TINT_WHITE := Color(1.0, 1.0, 1.0)
const TINT_DUSK := Color(1.0, 0.72, 0.46)
const TINT_NIGHT := Color(0.42, 0.46, 0.7)
const TINT_DUSK_START := 16 * 60
const TINT_DUSK_END := 19 * 60
const TINT_NIGHT_START := 21 * 60


static func tint_for_minutes(m: int) -> Color:
	if m <= TINT_DUSK_START:
		return TINT_WHITE
	if m < TINT_DUSK_END:
		var t: float = float(m - TINT_DUSK_START) / float(TINT_DUSK_END - TINT_DUSK_START)
		return TINT_WHITE.lerp(TINT_DUSK, t)
	if m < TINT_NIGHT_START:
		var t2: float = float(m - TINT_DUSK_END) / float(TINT_NIGHT_START - TINT_DUSK_END)
		return TINT_DUSK.lerp(TINT_NIGHT, t2)
	return TINT_NIGHT

## (label tick color unused for text — GUT/contact-sheet convention: no
## guaranteed pixel font, so rows are ordered top-to-bottom by time of day and
## the accompanying report text (not the PNG) names each row) minutes-of-day
## samples spanning the full DayTint curve: full day, early dusk, mid dusk,
## dusk end (full dusk), early night ramp, full night, deep night (holds to
## curfew).
const TIME_SAMPLES := [
	6 * 60,           # 06:00 — day start, full WHITE
	12 * 60,          # 12:00 — noon, full WHITE
	17 * 60 + 30,     # 17:30 — mid-dusk lerp
	19 * 60,          # 19:00 — DUSK_END, full DUSK
	20 * 60,          # 20:00 — dusk -> night lerp, ~halfway
	21 * 60,          # 21:00 — NIGHT_START, full NIGHT
	25 * 60,          # 01:00 next day — night holds to curfew
]

const SWATCH_TILES := [
	"tile_grass", "tile_soil_tilled", "tile_stone_floor", "tile_path", "tile_water", "prop_house",
]

const TILE_SIZE := 16
const SCALE := 6
const PAD := 4
const ROW_LABEL_W := 14  # thin color-coded strip at the left of each row (bright->dark reads as day->night)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(PROTO_OUT)
	var swatches: Array = []  # Array[Array[Image]]: swatches[row][col]
	for minutes: int in TIME_SAMPLES:
		var tint := tint_for_minutes(minutes)
		var row: Array = []
		for tile_name: String in SWATCH_TILES:
			row.append(_tinted_swatch(tile_name, tint))
		swatches.append(row)

	var sheet := _compose(swatches)
	sheet.save_png(PROTO_OUT + "tint_swatches.png")
	print("tint_swatches.png written: ", TIME_SAMPLES.size(), " rows x ", SWATCH_TILES.size(), " cols")
	quit(0)


func _tinted_swatch(tile_name: String, tint: Color) -> Image:
	var src := Image.load_from_file(SWATCH_SRC + tile_name + ".png")
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			out.set_pixel(x, y, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a))
	return out


func _compose(swatches: Array) -> Image:
	var rows := swatches.size()
	var cols := SWATCH_TILES.size()
	# swatches aren't all the same size (prop_house is 48x48, tiles are
	# 16x16) — use the max cell size so every column lines up in a grid.
	var cell_w := 0
	var cell_h := 0
	for row: Array in swatches:
		for img: Image in row:
			cell_w = maxi(cell_w, img.get_width() * SCALE)
			cell_h = maxi(cell_h, img.get_height() * SCALE)

	var sheet_w := ROW_LABEL_W + PAD + cols * (cell_w + PAD)
	var sheet_h := rows * (cell_h + PAD) + PAD
	var sheet := Image.create(sheet_w, sheet_h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("1c1c22"))

	for r in rows:
		var oy := PAD + r * (cell_h + PAD)
		# Row label strip: brightness proportional to how "day-like" this
		# row's own tint is (r/g/b average), so the sheet reads top(bright)
		# -> bottom(dark) at a glance even without text.
		var tint := tint_for_minutes(TIME_SAMPLES[r])
		var brightness := (tint.r + tint.g + tint.b) / 3.0
		var label_c := Color(brightness, brightness, brightness)
		for ly in range(oy, oy + cell_h):
			for lx in range(0, ROW_LABEL_W):
				sheet.set_pixel(lx, ly, label_c)
		for c in cols:
			var img: Image = swatches[r][c]
			var ox := ROW_LABEL_W + PAD + c * (cell_w + PAD)
			var big := _scaled(img, SCALE)
			for y in big.get_height():
				for x in big.get_width():
					var px := big.get_pixel(x, y)
					if px.a >= 0.02:
						sheet.set_pixel(ox + x, oy + y, px)
	return sheet


func _scaled(img: Image, scale: int) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create(w * scale, h * scale, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			for sy in scale:
				for sx in scale:
					out.set_pixel(x * scale + sx, y * scale + sy, c)
	return out
