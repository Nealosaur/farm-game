class_name ShopLogic
extends RefCounted
## Pure(ish) buy/sell rules over GameState + Inventory + ItemDB, extracted so
## ShopScreen stays a thin UI shell (project convention: testable helper under
## the UI). Mirrors Shipping's static-class pattern.
##
## buy()/sell() mutate the real autoloads (GameState, Inventory) directly —
## same "static class that touches autoloads" shape as Shipping.payout() and
## shipping_bin.gd's interact(), which the existing test suite already
## exercises this way headless (see test_shipping.gd).

enum Result {
	OK,
	INSUFFICIENT_GOLD,
	NOT_FOR_SALE,
	INVENTORY_FULL,
	UNSELLABLE,
	NOTHING_TO_SELL,
}


static func buy(item_id: String, count: int = 1, discount: float = 1.0) -> Result:
	## `discount` is a price MULTIPLIER (1.0 = full price), applied per-unit
	## then rounded down — Marta's L4/L7 shop discount (0.95 / 0.90, World
	## Stride B) is the only caller that passes anything but the default.
	var data := ItemDB.get_item(item_id)
	if data == null or data.buy_price <= 0:
		return Result.NOT_FOR_SALE
	var unit_cost := unit_price(data.buy_price, discount)
	var cost: int = unit_cost * count
	if GameState.gold < cost:
		return Result.INSUFFICIENT_GOLD
	if not GameState.try_spend_gold(cost):
		return Result.INSUFFICIENT_GOLD
	var leftover := Inventory.add_item(item_id, count)
	if leftover > 0:
		# Partial or total failure to fit: refund the un-delivered portion.
		GameState.add_gold(unit_cost * leftover)
		if leftover == count:
			return Result.INVENTORY_FULL
	return Result.OK


static func unit_price(base_price: int, discount: float = 1.0) -> int:
	return int(floorf(base_price * discount))


static func sell(item_id: String, count: int = 1) -> Result:
	var data := ItemDB.get_item(item_id)
	if data == null or data.sell_price <= 0:
		return Result.UNSELLABLE
	if Inventory.count_of(item_id) < count:
		return Result.NOTHING_TO_SELL
	if not Inventory.remove_item(item_id, count):
		return Result.NOTHING_TO_SELL
	GameState.add_gold(data.sell_price * count)
	return Result.OK


static func is_open(hour: int) -> bool:
	## Store hours: 9 AM (inclusive) to 5 PM (exclusive), per spec.
	return hour >= 9 and hour < 17


static func buyable_items() -> Array[ItemData]:
	## Every ItemDB item with buy_price > 0, sorted by id for a stable list
	## (dictionary iteration order isn't guaranteed stable across Godot
	## versions, and the UI must not jitter row order on refresh).
	## Season filter (World Stride A): Marta stocks IN-SEASON seeds only — a
	## seed whose crop can't be planted this season is skipped. Non-seed
	## stock (tools, the iron sword) is season-blind.
	var out: Array[ItemData] = []
	var ids := ItemDB.items.keys()
	ids.sort()
	for id: String in ids:
		var item: ItemData = ItemDB.items[id]
		if item.buy_price <= 0:
			continue
		if item is SeedData:
			var crop := ItemDB.get_crop((item as SeedData).crop_id)
			if crop != null and not (Clock.season() in crop.seasons):
				continue
		out.append(item)
	return out


static func sellable_stacks() -> Array[Dictionary]:
	## Inventory stacks (by item id) with sell_price > 0, merged across slots
	## and sorted by id — the SELL tab lists one row per item id, not per
	## slot, since a stack can be split across multiple inventory slots.
	var totals := {}
	for s in Inventory.slots:
		if s == null:
			continue
		var data := ItemDB.get_item(s.id)
		if data != null and data.sell_price > 0:
			totals[s.id] = int(totals.get(s.id, 0)) + int(s.count)
	var ids := totals.keys()
	ids.sort()
	var out: Array[Dictionary] = []
	for id: String in ids:
		out.append({"id": id, "count": totals[id]})
	return out
