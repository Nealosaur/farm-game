class_name PixelArt
extends RefCounted
## Reusable parametric pixel-art helpers (LOOK V1).
##
## Extracted from the proven `tools/proto_char.gd` spike style: rect/pixel
## primitives, a shaded side for volume, a 1px silhouette outline (~#2b2233),
## a soft translucent ground shadow, dithered fills for texture, plus a
## nearest-scaled preview and a contact-sheet composer for the mandatory
## review loop (docs/design/visual-overhaul.md).
##
## DETERMINISM CONTRACT: no Time/Date/randomize() anywhere in this file or
## its callers. `hash_seed(name)` gives a stable per-asset seed; `dither()`
## takes that seed explicitly so two runs of the generator always produce
## byte-identical PNGs (rerun -> git status clean).

const OUTLINE := Color("2b2233")


## ---- canvas + primitives ----

static func blank(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


static func px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			px(img, xx, yy, c)


static func hline(img: Image, x: int, y: int, w: int, c: Color) -> void:
	for xx in range(x, x + w):
		px(img, xx, y, c)


static func vline(img: Image, x: int, y: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		px(img, x, yy, c)


## ---- deterministic pseudo-randomness (no engine RNG state) ----

## Stable 32-bit-ish hash seed from an asset name (+ optional index), so
## variation is reproducible: same name -> same seed -> same pixels, always.
static func hash_seed(name: String, index: int = 0) -> int:
	var h := name.hash()
	h = (h ^ (index * 2654435761)) & 0x7fffffff
	return h


## A tiny deterministic LCG so we don't touch Godot's global RNG (which
## would make output order-dependent / non-deterministic across a run).
static func _lcg_next(state: Array) -> int:
	# state[0] holds the current value; classic Numerical-Recipes LCG.
	var next_val: int = (int(state[0]) * 1103515245 + 12345) & 0x7fffffff
	state[0] = next_val
	return next_val


## Deterministic dither: scatters `c` over rect (x,y,w,h) at `density`
## (0..1) using a seeded LCG, for grass/soil/stone texture noise.
static func dither(img: Image, x: int, y: int, w: int, h: int, c: Color, density: float, seed_val: int) -> void:
	var state := [seed_val if seed_val != 0 else 1]
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			var r := _lcg_next(state) / float(0x7fffffff)
			if r < density:
				px(img, xx, yy, c)


## ---- shading / finishing ----

## Shades the right-hand `width` columns of rect (x,y,w,h) with `shade_c`,
## giving flat fills a simple lit-from-upper-left volume cue (matches the
## proto's shirt/torso/head shading).
static func shade_right(img: Image, x: int, y: int, w: int, h: int, shade_c: Color, width: int = -1) -> void:
	var sw := width if width > 0 else maxi(1, w / 3)
	rect(img, x + w - sw, y, sw, h, shade_c)


## Shades the bottom `height` rows — used for domed/round bodies (slimes).
static func shade_bottom(img: Image, x: int, y: int, w: int, h: int, shade_c: Color, height: int = -1) -> void:
	var sh := height if height > 0 else maxi(1, h / 3)
	rect(img, x, y + h - sh, w, sh, shade_c)


## Adds a 1px dark outline around the opaque silhouette (transparent pixel
## touching an opaque one -> outline pixel). Ported verbatim from the proto.
static func outline(img: Image, outline_c: Color = OUTLINE) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var edges: Array = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a < 0.5:
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx >= 0 and ny >= 0 and nx < w and ny < h and img.get_pixel(nx, ny).a >= 0.5:
						edges.append(Vector2i(x, y))
						break
	for e: Vector2i in edges:
		img.set_pixel(e.x, e.y, outline_c)


## Soft translucent ground-shadow ellipse (drawn BEFORE the subject, never
## outlined) — an oval `w`x2 centered at (cx, bottom_y).
static func ground_shadow(img: Image, cx: int, bottom_y: int, half_w: int, alpha: float = 0.28) -> void:
	var shadow := Color(0, 0, 0, alpha)
	for x in range(cx - half_w, cx + half_w):
		px(img, x, bottom_y, shadow)
	for x in range(cx - half_w + 1, cx + half_w - 1):
		px(img, x, bottom_y + 1, shadow)


## ---- circle / polygon fills (shared by items/crops/enemies) ----

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


static func fill_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, c)


## ---- preview / contact sheet (review loop) ----

## Nearest-scaled nx preview on a checker background so shape + alpha both
## read clearly at a glance.
static func save_preview(img: Image, out_path: String, scale: int) -> void:
	var big := scaled_preview(img, scale)
	big.save_png(out_path)


static func scaled_preview(img: Image, scale: int) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var big := blank(w * scale, h * scale)
	var a := Color("3a3a46")
	var b := Color("2e2e38")
	for y in big.get_height():
		for x in big.get_width():
			big.set_pixel(x, y, a if ((x / 8 + y / 8) % 2 == 0) else b)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a >= 0.5:
				for sy in scale:
					for sx in scale:
						big.set_pixel(x * scale + sx, y * scale + sy, c)
	return big


## Tiles a list of {name, image} entries into a labeled grid contact sheet.
## `cols` = tiles per row; `scale` = nearest-neighbor zoom per sprite;
## `cell_pad` = px gap between cells; a small pixel-font-free label strip
## (just a colored tick, since a real font isn't guaranteed) sits under
## each tile — the filename itself is encoded via the caller's grouping/
## ordering, since the sheet is for the orchestrator to eyeball shapes, not
## read text off. A caption row height reserves space regardless.
static func compose_contact_sheet(entries: Array, cols: int, scale: int, cell_pad: int = 6, caption_h: int = 6) -> Image:
	if entries.is_empty():
		return blank(cell_pad, cell_pad)
	var max_w := 0
	var max_h := 0
	for e: Dictionary in entries:
		var im: Image = e["image"]
		max_w = maxi(max_w, im.get_width() * scale)
		max_h = maxi(max_h, im.get_height() * scale)
	var cell_w := max_w + cell_pad
	var cell_h := max_h + caption_h + cell_pad
	var rows := int(ceil(float(entries.size()) / cols))
	var sheet_w := cell_w * cols + cell_pad
	var sheet_h := cell_h * rows + cell_pad
	var sheet := blank(sheet_w, sheet_h)
	var bg := Color("1c1c22")
	sheet.fill(bg)
	var grid_c := Color("2a2a32")
	for i in entries.size():
		var e: Dictionary = entries[i]
		var im: Image = e["image"]
		var col := i % cols
		var row := i / cols
		var ox := cell_pad + col * cell_w
		var oy := cell_pad + row * cell_h
		# cell background so transparent sprites are still visible
		rect(sheet, ox, oy, max_w, max_h, grid_c)
		var prev := scaled_preview(im, scale)
		for y in prev.get_height():
			for x in prev.get_width():
				px(sheet, ox + x, oy + y, prev.get_pixel(x, y))
		# caption tick: a short colored bar whose hue is derived from the
		# entry's own average color, just to visually separate rows/groups.
		var tick_c: Color = e.get("tick_color", Color("6a6a76"))
		hline(sheet, ox, oy + max_h + 1, mini(max_w, 24), tick_c)
	return sheet


static func average_color(img: Image) -> Color:
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var n := 0
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a >= 0.5:
				r += c.r
				g += c.g
				b += c.b
				n += 1
	if n == 0:
		return Color("6a6a76")
	return Color(r / n, g / n, b / n)


## ---- tiny bitmap font (review-artifact labels only) ----
##
## SPRITE FORMAT ALIGNMENT: a minimal 3x5-px monospace glyph set so review
## PNGs (format_reference.png) can print real row labels ("WALK DOWN", "ACTION
## LEFT", row indices) instead of only colored ticks — a real Font resource
## isn't guaranteed to draw onto a plain Image from a headless SceneTree tool
## script, so this hand-rolled font sidesteps that entirely. Covers exactly
## the character set the review labels need: A-Z, 0-9, space; unknown chars
## fall back to a blank cell. Not used for any in-game UI text.

const _FONT_W := 3
const _FONT_H := 5

## Each glyph is 5 rows of a 3-bit mask (bit 2 = leftmost column), MSB-first
## per row, top to bottom.
const _FONT_GLYPHS := {
	"A": [0b010, 0b101, 0b111, 0b101, 0b101],
	"B": [0b110, 0b101, 0b110, 0b101, 0b110],
	"C": [0b011, 0b100, 0b100, 0b100, 0b011],
	"D": [0b110, 0b101, 0b101, 0b101, 0b110],
	"E": [0b111, 0b100, 0b110, 0b100, 0b111],
	"F": [0b111, 0b100, 0b110, 0b100, 0b100],
	"G": [0b011, 0b100, 0b101, 0b101, 0b011],
	"H": [0b101, 0b101, 0b111, 0b101, 0b101],
	"I": [0b111, 0b010, 0b010, 0b010, 0b111],
	"J": [0b001, 0b001, 0b001, 0b101, 0b010],
	"K": [0b101, 0b101, 0b110, 0b101, 0b101],
	"L": [0b100, 0b100, 0b100, 0b100, 0b111],
	"M": [0b101, 0b111, 0b111, 0b101, 0b101],
	"N": [0b101, 0b111, 0b111, 0b111, 0b101],
	"O": [0b010, 0b101, 0b101, 0b101, 0b010],
	"P": [0b110, 0b101, 0b110, 0b100, 0b100],
	"Q": [0b010, 0b101, 0b101, 0b111, 0b011],
	"R": [0b110, 0b101, 0b110, 0b101, 0b101],
	"S": [0b011, 0b100, 0b010, 0b001, 0b110],
	"T": [0b111, 0b010, 0b010, 0b010, 0b010],
	"U": [0b101, 0b101, 0b101, 0b101, 0b111],
	"V": [0b101, 0b101, 0b101, 0b101, 0b010],
	"W": [0b101, 0b101, 0b111, 0b111, 0b101],
	"X": [0b101, 0b101, 0b010, 0b101, 0b101],
	"Y": [0b101, 0b101, 0b010, 0b010, 0b010],
	"Z": [0b111, 0b001, 0b010, 0b100, 0b111],
	"0": [0b111, 0b101, 0b101, 0b101, 0b111],
	"1": [0b010, 0b110, 0b010, 0b010, 0b111],
	"2": [0b111, 0b001, 0b111, 0b100, 0b111],
	"3": [0b111, 0b001, 0b111, 0b001, 0b111],
	"4": [0b101, 0b101, 0b111, 0b001, 0b001],
	"5": [0b111, 0b100, 0b111, 0b001, 0b111],
	"6": [0b111, 0b100, 0b111, 0b101, 0b111],
	"7": [0b111, 0b001, 0b001, 0b001, 0b001],
	"8": [0b111, 0b101, 0b111, 0b101, 0b111],
	"9": [0b111, 0b101, 0b111, 0b001, 0b111],
	"-": [0b000, 0b000, 0b111, 0b000, 0b000],
	":": [0b000, 0b010, 0b000, 0b010, 0b000],
	" ": [0b000, 0b000, 0b000, 0b000, 0b000],
}


## Draws `text` (auto-uppercased) starting at (x, y) with the 3x5 font, one
## glyph column-major bit per pixel, `scale`x nearest-neighbor per pixel,
## `spacing` px gap between glyphs (already scaled). Unknown characters draw
## as a blank cell (still advances the cursor) so a stray lowercase/punct
## char never crashes a review-artifact build.
static func draw_text(img: Image, x: int, y: int, text: String, c: Color, scale: int = 1, spacing: int = 1) -> void:
	var cursor_x := x
	for ch in text.to_upper():
		var glyph: Array = _FONT_GLYPHS.get(ch, _FONT_GLYPHS[" "])
		for row in _FONT_H:
			var bits: int = glyph[row]
			for col in _FONT_W:
				var bit := (bits >> (_FONT_W - 1 - col)) & 1
				if bit == 1:
					rect(img, cursor_x + col * scale, y + row * scale, scale, scale, c)
		cursor_x += (_FONT_W * scale) + spacing


## Width in px of `text` if drawn with draw_text at the given scale/spacing.
static func text_width(text: String, scale: int = 1, spacing: int = 1) -> int:
	if text.is_empty():
		return 0
	return text.length() * (_FONT_W * scale + spacing) - spacing


## ---- UI ninepatch primitives (V3 UI skin pass) ----
##
## A "ninepatch" here is just a small square PNG with a symmetric border
## (`margin` px on all four sides) meant to be stretched via
## StyleBoxTexture.texture_margin_* / NinePatchRect so the border pixels stay
## crisp corners/edges while the middle tiles/stretches to fill any panel
## size. These helpers only draw the raw pixels; UITheme (scripts/ui/
## ui_theme.gd) wraps the saved PNGs in actual StyleBoxTexture resources.

## Flat bordered panel: `frame_c` for the `margin`-px border ring, `fill_c`
## for the inset interior, optional 1px `hi_c` bevel just inside the frame's
## top/left edge for a slight raised/warm look. Used for the wood/parchment
## window panel and (with different colors) the button ninepatch.
static func ninepatch_panel(size: int, margin: int, frame_c: Color, fill_c: Color, hi_c: Color = Color(0, 0, 0, 0)) -> Image:
	var img := blank(size, size)
	img.fill(frame_c)
	rect(img, margin, margin, size - margin * 2, size - margin * 2, fill_c)
	if hi_c.a > 0.0:
		hline(img, margin, margin, size - margin * 2, hi_c)
		vline(img, margin, margin, size - margin * 2, hi_c)
	return img


## Recessed slot ninepatch: darker inset fill with a dark top/left bevel and
## a lighter bottom/right bevel, so it reads as "pressed into" the panel
## rather than sitting flush on top of it (inventory/hotbar/recipe slots).
static func ninepatch_slot(size: int, margin: int, frame_c: Color, fill_c: Color, dark_bevel: Color, light_bevel: Color) -> Image:
	var img := blank(size, size)
	img.fill(frame_c)
	rect(img, margin, margin, size - margin * 2, size - margin * 2, fill_c)
	hline(img, margin, margin, size - margin * 2, dark_bevel)
	vline(img, margin, margin, size - margin * 2, dark_bevel)
	hline(img, margin, size - margin - 1, size - margin * 2, light_bevel)
	vline(img, size - margin - 1, margin, size - margin * 2, light_bevel)
	return img


## Bright full-ring border used as a selected-slot highlight overlay (drawn
## on a transparent canvas so it composites ON TOP of a normal slot piece).
static func ninepatch_highlight_ring(size: int, thickness: int, ring_c: Color) -> Image:
	var img := blank(size, size)
	for t in thickness:
		hline(img, t, t, size - t * 2, ring_c)
		hline(img, t, size - 1 - t, size - t * 2, ring_c)
		vline(img, t, t, size - t * 2, ring_c)
		vline(img, size - 1 - t, t, size - t * 2, ring_c)
	return img


## ---- sheet assembly (characters / enemies) ----

## Lays a list of frame Images (already same size) into a grid PNG:
## `frames_per_row` columns, rows = frames.size() / frames_per_row.
## Used for char_<id>_sheet.png (4 dirs x 4 frames) and enemy sheets.
static func build_sheet(frames: Array, frame_w: int, frame_h: int, frames_per_row: int) -> Image:
	var rows := int(ceil(float(frames.size()) / frames_per_row))
	var sheet := blank(frame_w * frames_per_row, frame_h * rows)
	for i in frames.size():
		var im: Image = frames[i]
		var col := i % frames_per_row
		var row := i / frames_per_row
		sheet.blit_rect(im, Rect2i(0, 0, frame_w, frame_h), Vector2i(col * frame_w, row * frame_h))
	return sheet
