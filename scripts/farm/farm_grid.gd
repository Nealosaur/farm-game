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
