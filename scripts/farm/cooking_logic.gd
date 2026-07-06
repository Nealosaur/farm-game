class_name CookingLogic
extends RefCounted
## Pure(ish) cooking rules over Inventory + ItemDB (Craft Stride 1). Mirrors
## ShopLogic's "static class that touches the real autoloads directly, keeps
## the UI thin" pattern (see shop_logic.gd's class doc).

enum Result {
	OK,
	MISSING_INGREDIENTS,
	INVENTORY_FULL,
}


static func all_recipes() -> Array[RecipeData]:
	## Stable id-sorted list — same "dictionary order isn't guaranteed, UI
	## must not jitter" rationale as ShopLogic.buyable_items().
	var out: Array[RecipeData] = []
	var ids := ItemDB.recipes.keys()
	ids.sort()
	for id: String in ids:
		out.append(ItemDB.recipes[id])
	return out


static func can_cook(recipe: RecipeData) -> bool:
	for item_id: String in recipe.ingredients:
		var need: int = int(recipe.ingredients[item_id])
		if Inventory.count_of(item_id) < need:
			return false
	return true


static func cook(recipe: RecipeData) -> Result:
	## Consumes ingredients and adds the result dish. Refuses (no state
	## change at all) if ingredients are missing OR the inventory has no room
	## for the result (bible: "inventory-full -> refuse with toast" — checked
	## BEFORE consuming anything, so a full inventory never eats the player's
	## ingredients for nothing).
	if not can_cook(recipe):
		return Result.MISSING_INGREDIENTS
	if not _has_room_for(recipe.result_id):
		return Result.INVENTORY_FULL
	for item_id: String in recipe.ingredients:
		var need: int = int(recipe.ingredients[item_id])
		Inventory.remove_item(item_id, need)
	Inventory.add_item(recipe.result_id, 1)
	return Result.OK


static func _has_room_for(item_id: String) -> bool:
	## Mirrors the "try it, see if it fits" check other systems use (e.g.
	## player.gd's harvest peek), but without mutating state: simulate via
	## add_item's own stacking rule would require a real mutation, so instead
	## check directly — a stack of the same id with room, or any empty slot.
	var data := ItemDB.get_item(item_id)
	if data == null:
		return false
	for s in Inventory.slots:
		if s == null:
			return true
		if s.id == item_id and s.count < data.max_stack:
			return true
	return false
