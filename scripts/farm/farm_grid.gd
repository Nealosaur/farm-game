class_name FarmGrid
extends Node
## Farm plot state and rules. Logic only — rendering is FarmRenderer's job.
## Serializes into SaveManager.world["farm_grid"] per the world-data contract.
##
## World Stride A: planting is season-gated (CropData.seasons vs Clock),
## crops wilt when a rollover crosses into a season they don't grow in, and
## regrowing crops (regrow_days > 0) survive their harvest — held at the
## final growth stage with the "regrown" flag, they re-ripen on the regrow
## clock. Harvest commits go through harvest() so THIS class owns the
## clear-vs-regrow decision; peek_harvest() stays a read-only query.

signal plot_changed(cell: Vector2i)

@export var tillable := Rect2i(0, 0, 0, 0)

## cell -> {tilled: bool, watered: bool, crop_id: String, stage: int,
##          days_in_stage: int, regrown: bool}
var plots := {}

## Wilt tally from the most recent advance_day() — DayFlow reads this after
## a live rollover (the day_passed signal path can't return a value).
var last_wilt_count := 0


func _ready() -> void:
	add_to_group("farm_grid")
	# Named method, NOT a lambda: method connections are auto-disconnected
	# when this node is freed; lambda connections would outlive it and crash.
	EventBus.day_passed.connect(_on_day_passed)


func _on_day_passed(_day) -> void:
	advance_day()


func till(cell: Vector2i) -> bool:
	if not tillable.has_point(cell) or plots.has(cell):
		return false
	plots[cell] = {"tilled": true, "watered": false, "crop_id": "", "stage": 0,
		"days_in_stage": 0, "regrown": false}
	plot_changed.emit(cell)
	return true


func water(cell: Vector2i) -> bool:
	var p = plots.get(cell)
	if p == null or p.watered:
		return false
	p.watered = true
	plot_changed.emit(cell)
	return true


func till_wide(target: Vector2i, facing: Vector2i, width: int) -> bool:
	## DEPTH stride (tool tiers): tills `target` plus its flanking cells,
	## same geometry as water_wide()/flanking_cells() — a wider hoe (Copper
	## Hoe, till_width 3) tills a small row across the field the same way
	## the Copper Watering Can waters one. Each cell independently attempts
	## till() (an already-tilled or out-of-bounds flank just no-ops for that
	## cell — same "edge-of-field partial applies what it can" contract).
	## Returns true if ANY cell was newly tilled, so callers spend RP exactly
	## once per swing on ANY success (mirrors water_wide()'s doc).
	var any_tilled := false
	for cell: Vector2i in flanking_cells(target, facing, width):
		if till(cell):
			any_tilled = true
	return any_tilled


static func flanking_cells(target: Vector2i, facing: Vector2i, width: int) -> Array[Vector2i]:
	## Craft Stride 2 (Copper Watering Can): target cell + the (width-1)/2
	## cells flanking it PERPENDICULAR to facing, on each side. width <= 1
	## returns just [target] (every pre-Forge can, and any even/invalid width
	## defensively treated the same way — the bible only ever specifies odd
	## widths). Facing up/down -> flank left/right; facing left/right -> flank
	## up/down. Does NOT filter by tillable/existing-plot bounds — callers
	## (water_wide()) run each cell through the ordinary water() gate anyway,
	## so an out-of-bounds or untilled flank cell just harmlessly fails there
	## (bible: "edge-of-field partial applies what it can").
	var cells: Array[Vector2i] = [target]
	var half := (width - 1) / 2
	if half <= 0:
		return cells
	var perp: Vector2i = Vector2i(1, 0) if (facing == Vector2i.UP or facing == Vector2i.DOWN) else Vector2i(0, 1)
	for i in range(1, half + 1):
		cells.append(target + perp * i)
		cells.append(target - perp * i)
	return cells


func water_wide(target: Vector2i, facing: Vector2i, width: int) -> bool:
	## Waters `target` plus its flanking cells (see flanking_cells()) — each
	## cell independently attempts water() (so an already-watered or
	## untilled/out-of-bounds flank simply no-ops for that one cell, per the
	## bible's "edge-of-field partial applies what it can"). Returns true if
	## ANY cell was newly watered, so the caller (player.gd) charges RP
	## exactly once per swing on ANY success, never per-cell.
	var any_watered := false
	for cell: Vector2i in flanking_cells(target, facing, width):
		if water(cell):
			any_watered = true
	return any_watered


func water_all() -> int:
	## Rain overnight: waters every tilled plot (plots only holds tilled
	## cells, cropped or not). Returns how many newly got water.
	var count := 0
	for cell: Vector2i in plots:
		var p = plots[cell]
		if not p.watered:
			p.watered = true
			count += 1
			plot_changed.emit(cell)
	return count


func water_random_unwatered(count: int, seed_value: int) -> int:
	## Craft Stride 3 (Taming — morning help): waters up to `count` random
	## UNWATERED tilled cells, deterministic for a given seed_value (DayFlow
	## seeds this with Clock.day so the same day always waters the same
	## cells, even if replayed/re-simulated). Returns how many cells were
	## actually newly watered (<=count if fewer unwatered cells exist).
	## Runs BEFORE the rain check per the bible ("before rain check") — called
	## from DayFlow ahead of its own is_raining() water_all() branch, so on a
	## rain day the slime's 8 cells simply get overwritten as "already
	## watered" by water_all() right after (harmless double-water, same as
	## any other watered cell rolling into a rain morning).
	var unwatered: Array[Vector2i] = []
	for cell: Vector2i in plots:
		if not plots[cell].watered:
			unwatered.append(cell)
	if unwatered.is_empty():
		return 0
	# Sort first so iteration order (a Dictionary's key order isn't
	# guaranteed stable across runs) can't affect which cells the seeded RNG
	# picks — same seed must always pick the same cells.
	unwatered.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var picked := 0
	var pool := unwatered.duplicate()
	while picked < count and not pool.is_empty():
		var idx := rng.randi() % pool.size()
		var cell: Vector2i = pool[idx]
		pool.remove_at(idx)
		if water(cell):
			picked += 1
	return picked


func plant(cell: Vector2i, crop_id: String) -> bool:
	var p = plots.get(cell)
	var crop := ItemDB.get_crop(crop_id)
	if p == null or p.crop_id != "" or crop == null:
		return false
	if not (Clock.season() in crop.seasons):
		return false  # out of season — no side effects (player spends nothing)
	p.crop_id = crop_id
	p.stage = 0
	p.days_in_stage = 0
	p.regrown = false
	plot_changed.emit(cell)
	return true


func is_ripe(cell: Vector2i) -> bool:
	var p = plots.get(cell)
	if p == null or p.crop_id == "":
		return false
	var crop := ItemDB.get_crop(p.crop_id)
	return p.stage >= crop.stage_days.size()


func peek_harvest(cell: Vector2i) -> String:
	if not is_ripe(cell):
		return ""
	return ItemDB.get_crop(plots[cell].crop_id).product_id


func harvest(cell: Vector2i) -> String:
	## Commits a harvest: returns the product id ("" if not ripe) and applies
	## the clear-vs-regrow decision HERE so callers can't get it wrong.
	## Callers must fit the product into the inventory FIRST and only call
	## this on success — an inventory-full attempt must leave the crop ripe
	## and untouched (player.gd's try_interact does exactly that).
	var product := peek_harvest(cell)
	if product == "":
		return ""
	var p = plots[cell]
	var crop := ItemDB.get_crop(p.crop_id)
	if crop.regrow_days > 0:
		# Crop stays planted, held at its final growth stage (renderer shows
		# the near-ripe sprite); advance_day() re-ripens it after regrow_days
		# watered days — "regrown" swaps that stage's threshold.
		p.regrown = true
		p.stage = crop.stage_days.size() - 1
		p.days_in_stage = 0
		plot_changed.emit(cell)
	else:
		clear_crop(cell)
	return product


func clear_crop(cell: Vector2i) -> void:
	var p = plots.get(cell)
	if p == null:
		return
	p.crop_id = ""
	p.stage = 0
	p.days_in_stage = 0
	p.regrown = false
	plot_changed.emit(cell)


func advance_day() -> int:
	## One night: watered crops grow, watered flags reset, then out-of-season
	## crops wilt if this rollover crossed a season boundary. Returns the wilt
	## count (also kept in last_wilt_count for the signal-driven path).
	for cell: Vector2i in plots:
		var p = plots[cell]
		if p.crop_id != "" and p.watered:
			var crop := ItemDB.get_crop(p.crop_id)
			if p.stage < crop.stage_days.size():
				p.days_in_stage += 1
				# Regrowing crops re-ripen from their held final stage on the
				# regrow clock instead of that stage's first-growth days.
				var threshold: int = crop.regrow_days \
					if (p.regrown and p.stage == crop.stage_days.size() - 1) \
					else crop.stage_days[p.stage]
				if p.days_in_stage >= threshold:
					p.stage += 1
					p.days_in_stage = 0
		p.watered = false
		plot_changed.emit(cell)
	last_wilt_count = _wilt_out_of_season()
	return last_wilt_count


func _wilt_out_of_season() -> int:
	## Season-rollover wilt. ORDERING CHOICE (documented): growth ran first,
	## so a crop gets its final-day growth of the OLD season before the new
	## season's check clears it — kinder, and ripe produce stays harvestable
	## only if the crop survives. Wilted plots stay tilled, crop cleared.
	## Uses Clock.day, which already points at the NEW day when day_passed
	## fires (Clock.end_day increments before emitting). Guard day <= 1:
	## there is no "yesterday" on day 1.
	if Clock.day <= 1 or Clock.season_of_day(Clock.day - 1) == Clock.season():
		return 0
	var count := 0
	for cell: Vector2i in plots:
		var p = plots[cell]
		if p.crop_id == "":
			continue
		var crop := ItemDB.get_crop(p.crop_id)
		if crop != null and not (Clock.season() in crop.seasons):
			p.crop_id = ""
			p.stage = 0
			p.days_in_stage = 0
			p.regrown = false
			count += 1
			plot_changed.emit(cell)
	return count


func to_dict() -> Dictionary:
	var out := {}
	for cell: Vector2i in plots:
		out["%d,%d" % [cell.x, cell.y]] = plots[cell].duplicate(true)
	return out


func from_dict(d: Dictionary) -> void:
	plots = {}
	for key: String in d:
		var parts := key.split(",")
		if parts.size() != 2:
			continue
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		var raw: Dictionary = d[key]
		plots[cell] = {
			"tilled": bool(raw.get("tilled", true)),
			"watered": bool(raw.get("watered", false)),
			"crop_id": String(raw.get("crop_id", "")),
			"stage": int(raw.get("stage", 0)),
			"days_in_stage": int(raw.get("days_in_stage", 0)),
			"regrown": bool(raw.get("regrown", false)),
		}
		plot_changed.emit(cell)


func store() -> void:
	SaveManager.world["farm_grid"] = to_dict()


func restore() -> void:
	from_dict(SaveManager.world.get("farm_grid", {}))


func _exit_tree() -> void:
	# World-data contract: scenes write their blob on scene exit. Mattered
	# only theoretically until portals arrived — now leaving the farm for the
	# dungeon must not discard the morning's tilling/planting/watering.
	store()


static func advance_stored_day() -> int:
	## One night of crop growth (and season wilt) applied straight to the
	## saved blob. Used by DayFlow when the day rolls over while the farm
	## scene isn't loaded (slept/collapsed in the dungeon) — day_passed has
	## no live FarmGrid listener then, and crops must never miss a growth
	## night NOR skip a season-boundary wilt. Returns the wilt count so
	## DayFlow can toast it.
	var tmp := FarmGrid.new()
	tmp.from_dict(SaveManager.world.get("farm_grid", {}))
	var wilted := tmp.advance_day()
	SaveManager.world["farm_grid"] = tmp.to_dict()
	tmp.free()
	return wilted


static func water_all_stored() -> void:
	## Rain overnight while the farm scene isn't loaded: water the saved
	## blob directly (companion to advance_stored_day, same pattern).
	var tmp := FarmGrid.new()
	tmp.from_dict(SaveManager.world.get("farm_grid", {}))
	tmp.water_all()
	SaveManager.world["farm_grid"] = tmp.to_dict()
	tmp.free()


static func water_random_unwatered_stored(count: int, seed_value: int) -> int:
	## Morning-help watering while the farm scene isn't loaded (slept/
	## collapsed away from the farm) — same "operate on the saved blob
	## directly" pattern as advance_stored_day()/water_all_stored(). Returns
	## how many cells were newly watered.
	var tmp := FarmGrid.new()
	tmp.from_dict(SaveManager.world.get("farm_grid", {}))
	var watered := tmp.water_random_unwatered(count, seed_value)
	SaveManager.world["farm_grid"] = tmp.to_dict()
	tmp.free()
	return watered
