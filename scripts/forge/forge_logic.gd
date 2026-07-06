class_name ForgeLogic
extends RefCounted
## Pure(ish) upgrade rules over GameState + Inventory + ItemDB (Craft Stride
## 2). Mirrors ShopLogic/CookingLogic's "static class that touches the real
## autoloads directly, keeps the UI thin" pattern (see shop_logic.gd's class
## doc) — ForgeScreen stays a thin display over this.
##
## Upgrades are CODE data (not RecipeData .tres) because each one needs an
## old-tool-consumed slot PLUS a materials dict PLUS a gold cost PLUS an
## optional hide-until-flag gate — RecipeData's shape (ingredients -> single
## result) has no room for the "consumes an existing tool" or "gated" halves
## of that, so a small static table here is the more honest fit (bible:
## "Forge UI mirrors: list, affordability, consume+grant").

enum Result {
	OK,
	MISSING_OLD_TOOL,
	MISSING_MATERIALS,
	INSUFFICIENT_GOLD,
	HIDDEN,
}

## Each entry: id, old_tool (consumed, "" if none), materials (item_id -> count),
## gold (int), result_id (granted ToolData id), hidden_until_flag ("" = never hidden).
const UPGRADES := [
	{
		"id": "steel_sword",
		"old_tool": "iron_sword",
		"materials": {"goblin_fang": 3},
		"gold": 800,
		"result_id": "steel_sword",
		"hidden_until_flag": "",
	},
	{
		"id": "fangsteel_blade",
		"old_tool": "steel_sword",
		"materials": {"goblin_fang": 5, "driftglass": 2},
		"gold": 2000,
		"result_id": "fangsteel_blade",
		"hidden_until_flag": "sten_masterwork_done",
	},
	{
		"id": "copper_can",
		"old_tool": "watering_can",
		"materials": {"slime_gel": 3},
		"gold": 500,
		"result_id": "copper_can",
		"hidden_until_flag": "",
	},
]


static func visible_upgrades() -> Array[Dictionary]:
	## Every upgrade whose hidden_until_flag is unset or already true — the
	## GATED entry (fangsteel_blade) simply doesn't appear in the list until
	## "Fang Steel" plays (bible: "HIDDEN until flag sten_masterwork_done").
	var out: Array[Dictionary] = []
	for upgrade: Dictionary in UPGRADES:
		var gate := String(upgrade.get("hidden_until_flag", ""))
		if gate != "" and not bool(GameState.flags.get(gate, false)):
			continue
		out.append(upgrade)
	return out


static func get_upgrade(id: String) -> Dictionary:
	for upgrade: Dictionary in UPGRADES:
		if String(upgrade.get("id", "")) == id:
			return upgrade
	return {}


static func can_afford(upgrade: Dictionary) -> bool:
	var old_tool := String(upgrade.get("old_tool", ""))
	if old_tool != "" and Inventory.count_of(old_tool) < 1:
		return false
	var materials: Dictionary = upgrade.get("materials", {})
	for item_id: String in materials:
		if Inventory.count_of(item_id) < int(materials[item_id]):
			return false
	if GameState.gold < int(upgrade.get("gold", 0)):
		return false
	return true


static func upgrade(id: String) -> Result:
	## Consumes the old tool + materials + gold, grants the new tool. Refuses
	## (no state change at all) if the recipe is hidden, the old tool is
	## missing, materials are short, or gold is short — checked in that order
	## so the caller's UI can show the most relevant refusal reason.
	##
	## Inventory-full edge case (bible: "handle the edge anyway" — the old
	## tool's slot normally frees up room for the new one, but a max_stack=1
	## tool slot might get raided by add_item()'s stacking pass on some OTHER
	## item first in a pathological inventory layout): remove the old tool
	## FIRST, then attempt to add the new one; if it doesn't fit, refund
	## everything (materials + gold + the old tool) rather than eating the
	## player's tool for nothing.
	var upg := get_upgrade(id)
	if upg.is_empty():
		return Result.MISSING_OLD_TOOL
	var gate := String(upg.get("hidden_until_flag", ""))
	if gate != "" and not bool(GameState.flags.get(gate, false)):
		return Result.HIDDEN
	var old_tool := String(upg.get("old_tool", ""))
	if old_tool != "" and Inventory.count_of(old_tool) < 1:
		return Result.MISSING_OLD_TOOL
	var materials: Dictionary = upg.get("materials", {})
	for item_id: String in materials:
		if Inventory.count_of(item_id) < int(materials[item_id]):
			return Result.MISSING_MATERIALS
	var gold_cost := int(upg.get("gold", 0))
	if GameState.gold < gold_cost:
		return Result.INSUFFICIENT_GOLD

	if old_tool != "":
		Inventory.remove_item(old_tool, 1)
	for item_id: String in materials:
		Inventory.remove_item(item_id, int(materials[item_id]))
	GameState.try_spend_gold(gold_cost)

	var result_id := String(upg.get("result_id", ""))
	var leftover := Inventory.add_item(result_id, 1)
	if leftover > 0:
		# Defensive refund path (documented edge case above) — should be
		# unreachable in practice since the old tool's slot just freed, but
		# never silently vanish the player's tool/materials/gold if it happens.
		if old_tool != "":
			Inventory.add_item(old_tool, 1)
		for item_id: String in materials:
			Inventory.add_item(item_id, int(materials[item_id]))
		GameState.add_gold(gold_cost)
		return Result.MISSING_MATERIALS
	return Result.OK
