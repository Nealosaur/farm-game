class_name FarmGrid
extends Node
## Farm plot state and rules. Logic only — rendering is FarmRenderer's job.
## Serializes into SaveManager.world["farm_grid"] per the world-data contract.

signal plot_changed(cell: Vector2i)

@export var tillable := Rect2i(0, 0, 0, 0)

## cell -> {tilled: bool, watered: bool, crop_id: String, stage: int, days_in_stage: int}
var plots := {}


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
	plots[cell] = {"tilled": true, "watered": false, "crop_id": "", "stage": 0, "days_in_stage": 0}
	plot_changed.emit(cell)
	return true


func water(cell: Vector2i) -> bool:
	var p = plots.get(cell)
	if p == null or p.watered:
		return false
	p.watered = true
	plot_changed.emit(cell)
	return true


func plant(cell: Vector2i, crop_id: String) -> bool:
	var p = plots.get(cell)
	if p == null or p.crop_id != "" or ItemDB.get_crop(crop_id) == null:
		return false
	p.crop_id = crop_id
	p.stage = 0
	p.days_in_stage = 0
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


func clear_crop(cell: Vector2i) -> void:
	var p = plots.get(cell)
	if p == null:
		return
	p.crop_id = ""
	p.stage = 0
	p.days_in_stage = 0
	plot_changed.emit(cell)


func advance_day() -> void:
	for cell: Vector2i in plots:
		var p = plots[cell]
		if p.crop_id != "" and p.watered:
			var crop := ItemDB.get_crop(p.crop_id)
			if p.stage < crop.stage_days.size():
				p.days_in_stage += 1
				if p.days_in_stage >= crop.stage_days[p.stage]:
					p.stage += 1
					p.days_in_stage = 0
		p.watered = false
		plot_changed.emit(cell)


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
		}
		plot_changed.emit(cell)


func store() -> void:
	SaveManager.world["farm_grid"] = to_dict()


func restore() -> void:
	from_dict(SaveManager.world.get("farm_grid", {}))
