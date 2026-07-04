extends Node
## Player inventory: SIZE slots, first HOTBAR of them are the hotbar.
## A slot is null or {"id": String, "count": int}.

const SIZE := 30
const HOTBAR := 10

var slots: Array = []
var selected := 0


func _ready() -> void:
	reset()


func reset() -> void:
	slots = []
	for i in SIZE:
		slots.append(null)
	selected = 0
	EventBus.inventory_changed.emit()


func add_item(id: String, count: int = 1) -> int:
	var data := ItemDB.get_item(id)
	if data == null:
		push_warning("Inventory: unknown item id " + id)
		return count
	var remaining := count
	for i in SIZE:
		if remaining <= 0:
			break
		var s = slots[i]
		if s != null and s.id == id and s.count < data.max_stack:
			var take: int = mini(remaining, data.max_stack - s.count)
			s.count += take
			remaining -= take
	for i in SIZE:
		if remaining <= 0:
			break
		if slots[i] == null:
			var take: int = mini(remaining, data.max_stack)
			slots[i] = {"id": id, "count": take}
			remaining -= take
	EventBus.inventory_changed.emit()
	return remaining


func remove_item(id: String, count: int = 1) -> bool:
	if count_of(id) < count:
		return false
	var remaining := count
	for i in SIZE:
		if remaining <= 0:
			break
		var s = slots[i]
		if s != null and s.id == id:
			var take: int = mini(remaining, s.count)
			s.count -= take
			remaining -= take
			if s.count == 0:
				slots[i] = null
	EventBus.inventory_changed.emit()
	return true


func count_of(id: String) -> int:
	var total := 0
	for s in slots:
		if s != null and s.id == id:
			total += s.count
	return total


func select_hotbar(index: int) -> void:
	selected = clampi(index, 0, HOTBAR - 1)
	EventBus.hotbar_selection_changed.emit(selected)


func get_selected() -> Variant:
	return slots[selected]


func to_dict() -> Dictionary:
	return {"selected": selected, "slots": slots}


func from_dict(d: Dictionary) -> void:
	reset()
	selected = int(d.get("selected", 0))
	var raw: Array = d.get("slots", [])
	for i in mini(raw.size(), SIZE):
		var s = raw[i]
		if s is Dictionary and s.has("id"):
			slots[i] = {"id": String(s.id), "count": int(s.count)}
	EventBus.inventory_changed.emit()
