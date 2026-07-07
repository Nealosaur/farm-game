extends SceneTree
## LOOK V2 review artifact: lays out the player's, two NPCs', and the slime's
## walk/idle frames in a row at 6x nearest-scale so the orchestrator/user can
## confirm frames actually differ (not a slideshow of one frozen sprite) and
## the walk cadence looks sane, per docs/design/visual-overhaul.md's mandatory
## review-loop convention. Reads the SAME sheets SpriteSheets.gd slices at
## runtime (char_<id>_sheet.png), directly as Images (no scene tree needed),
## so this is a pure read of the already-authored art — it does not draw
## anything new.
##
## Layout: one row per subject. Each row = that subject's DOWN-facing walk
## cycle (walk1, walk2, walk3, matching SpriteSheets' walk_down loop order)
## followed by its idle frame, each cell scaled 6x with a thin grid line
## between cells. Enemies (slime) use their single-row idle1/idle2/hurt/die
## sheet instead (no facing rows) — its cells are idle1, idle2, hurt, die.
##
## Run: "$GODOT" --headless --path . -s res://tools/gen_walk_filmstrip.gd
## Output: res://tools/_proto/walk_filmstrip.png (gitignored — review only).

const OUT := "res://assets/placeholder/"
const PROTO_OUT := "res://tools/_proto/"
const SCALE := 6
const PAD := 4
const LABEL_W := 70  # left margin per row for a text-free color tick + spacing

const CHAR_FRAME_W := 16
const CHAR_FRAME_H := 32
const CHAR_ROW_DOWN := 0  # SpriteSheets.CHAR_ROWS: down=0
const CHAR_COLS := 4      # idle, walk1, walk2, walk3


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(PROTO_OUT)

	var rows: Array = []
	rows.append(_char_row("player"))
	rows.append(_char_row("marta"))
	rows.append(_char_row("sten"))
	rows.append(_enemy_row("slime"))

	var sheet := _compose(rows)
	var err := sheet.save_png(PROTO_OUT + "walk_filmstrip.png")
	assert(err == OK, "Failed to write walk_filmstrip.png")
	print("walk_filmstrip.png written: ", rows.size(), " rows")
	quit(0)


## One row for a character id: [walk1, walk2, walk3, idle] from its DOWN row
## (matches SpriteSheets' walk_down = [walk1, walk2, walk3, walk2] cadence in
## spirit; idle appended last here purely for the reviewer to compare against,
## not because it's part of the runtime loop).
func _char_row(id: String) -> Dictionary:
	var sheet_path := OUT + "char_%s_sheet.png" % id
	var sheet := Image.load_from_file(sheet_path)
	var cells: Array[Image] = []
	if sheet == null:
		push_warning("gen_walk_filmstrip: missing sheet for " + id)
		return {"label": id, "cells": cells}
	var y := CHAR_ROW_DOWN * CHAR_FRAME_H
	# order: walk1, walk2, walk3, idle (idle last so the walk cadence itself
	# reads left-to-right in cycle order, with idle as a trailing reference)
	for col_i in [1, 2, 3, 0]:
		var region := Rect2i(col_i * CHAR_FRAME_W, y, CHAR_FRAME_W, CHAR_FRAME_H)
		cells.append(sheet.get_region(region))
	return {"label": id, "cells": cells}


## One row for an enemy id: idle1, idle2, hurt, die (its whole single-row sheet).
func _enemy_row(id: String) -> Dictionary:
	var single_path := OUT + "char_%s.png" % id
	var sheet_path := OUT + "char_%s_sheet.png" % id
	var single := Image.load_from_file(single_path)
	var sheet := Image.load_from_file(sheet_path)
	var cells: Array[Image] = []
	if single == null or sheet == null:
		push_warning("gen_walk_filmstrip: missing sheet for " + id)
		return {"label": id, "cells": cells}
	var fw := single.get_width()
	var fh := single.get_height()
	for col_i in 4:
		var region := Rect2i(col_i * fw, 0, fw, fh)
		cells.append(sheet.get_region(region))
	return {"label": id, "cells": cells}


func _compose(rows: Array) -> Image:
	var max_cells := 0
	var max_cell_w := 0
	var max_cell_h := 0
	for row: Dictionary in rows:
		var cells: Array = row["cells"]
		max_cells = maxi(max_cells, cells.size())
		for c: Image in cells:
			max_cell_w = maxi(max_cell_w, c.get_width() * SCALE)
			max_cell_h = maxi(max_cell_h, c.get_height() * SCALE)

	var cell_w := max_cell_w + PAD
	var cell_h := max_cell_h + PAD
	var sheet_w := LABEL_W + cell_w * max_cells + PAD
	var sheet_h := cell_h * rows.size() + PAD

	var sheet := Image.create(sheet_w, sheet_h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("1c1c22"))

	for row_i in rows.size():
		var row: Dictionary = rows[row_i]
		var cells: Array = row["cells"]
		var row_y := PAD + row_i * cell_h
		# label tick: a small colored swatch (average of the row's first
		# frame) in the left margin so rows are visually distinguishable
		# without needing font rendering in a headless tool script.
		if not cells.is_empty():
			var tick_color := _average_color(cells[0])
			for ty in range(row_y, row_y + max_cell_h):
				for tx in range(4, 20):
					sheet.set_pixel(tx, ty, tick_color)
		for col_i in cells.size():
			var frame: Image = cells[col_i]
			var scaled := frame.duplicate() as Image
			scaled.resize(frame.get_width() * SCALE, frame.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
			var dest_x := LABEL_W + PAD + col_i * cell_w
			sheet.blit_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), Vector2i(dest_x, row_y))

	return sheet


func _average_color(img: Image) -> Color:
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var n := 0
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a > 0.05:
				r += c.r
				g += c.g
				b += c.b
				n += 1
	if n == 0:
		return Color("444444")
	return Color(r / n, g / n, b / n)
