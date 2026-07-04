extends Area2D
## Interactable: ships the whole selected stack; payout on day rollover (Task 8).


func interact(_player) -> void:
	var s = Inventory.get_selected()
	if s == null:
		EventBus.toast_requested.emit("Select something to ship")
		return
	var data := ItemDB.get_item(s.id)
	if data == null or data.sell_price <= 0:
		EventBus.toast_requested.emit("Can't sell that")
		return
	var count: int = s.count
	Inventory.remove_item(s.id, count)
	var bin: Dictionary = SaveManager.world.get_or_add("shipping_bin", {})
	bin[s.id] = int(bin.get(s.id, 0)) + count
	EventBus.item_shipped.emit(s.id, count)
	EventBus.toast_requested.emit("Shipped %d× %s" % [count, data.display_name])
