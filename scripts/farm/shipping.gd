class_name Shipping
extends RefCounted
## Overnight shipping payout math. The bin dict lives in
## SaveManager.world["shipping_bin"] as {item_id: count} — this key is a
## sanctioned raw world-blob (like "farm_grid"): written by ShippingBin's
## interact(), drained by DayFlow at day rollover via payout() below.


static func payout(bin: Dictionary) -> int:
	var total := 0
	for id: String in bin:
		var item := ItemDB.get_item(id)
		if item != null and item.sell_price > 0:
			total += item.sell_price * int(bin[id])
	return total
