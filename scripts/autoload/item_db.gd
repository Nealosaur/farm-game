extends Node
## Loads all content resources at startup; lookup by string id. Fails loud in dev.

var items := {}
var crops := {}
var enemies := {}


func _ready() -> void:
	_load_dir("res://data/items", items)
	_load_dir("res://data/crops", crops)
	_load_dir("res://data/enemies", enemies)
	if not items.is_empty():
		validate()


func _load_dir(path: String, into: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("ItemDB: missing dir " + path)
		return
	for f in dir.get_files():
		var fname := f
		if not fname.ends_with(".tres"):
			continue
		var res: Resource = load(path + "/" + fname)
		if res == null or not "id" in res:
			push_error("ItemDB: bad resource " + fname)
			continue
		if into.has(res.id):
			push_error("ItemDB: duplicate id " + res.id)
			continue
		into[res.id] = res


func get_item(id: String) -> ItemData:
	return items.get(id) as ItemData


func get_crop(id: String) -> CropData:
	return crops.get(id) as CropData


func get_enemy(id: String) -> EnemyData:
	return enemies.get(id) as EnemyData


func validate() -> bool:
	var ok := true
	for id: String in items:
		var it: ItemData = items[id]
		if it is SeedData and not crops.has(it.crop_id):
			push_error("Seed %s -> unknown crop %s" % [id, it.crop_id])
			ok = false
	for id: String in crops:
		if not items.has(crops[id].product_id):
			push_error("Crop %s -> unknown product %s" % [id, crops[id].product_id])
			ok = false
	for id: String in enemies:
		var e: EnemyData = enemies[id]
		if e.drop_item_id != "" and not items.has(e.drop_item_id):
			push_error("Enemy %s -> unknown drop %s" % [id, e.drop_item_id])
			ok = false
	assert(ok, "ItemDB validation failed — see errors above")
	return ok
