class_name WinterStar
extends RefCounted
## World Stride D: Winter Star Night (Winter 24) secret-gift exchange.
##
## Both the secret-gift TARGET (who the player should gift) and the PLAZA
## GIFTER (who hands the player a gift) are derived PURELY from Clock.year()
## via Festival.winter_star_target()/winter_star_plaza_gifter() — no
## additional SaveManager.world state is needed for the assignment itself
## (same year always recomputes the same two NPCs), which is why this class
## has no "restore()"/blob-shape doc the way Relationships/Quests do.
##
## The one thing that DOES need to persist per-day is whether the plaza
## gifter has ALREADY handed over their gift today (so a second talk that
## same day doesn't hand over a second gift) — tracked via
## GameState.flags["winter_star_gift_received_day"] (an absolute Clock.day
## int), since GameState.flags already round-trips through
## GameState.to_dict()/from_dict() like every other flag (see
## save_manager.gd's "intro" doc entry for the same reasoning: no new
## top-level world key needed when an existing round-tripped store already
## covers it).

const TARGET_ITEMS_LOVED_MULT := 5


static func target_npc_id() -> String:
	return Festival.winter_star_target(Clock.year(), NPCFactory.ALL_IDS)


static func plaza_gifter_npc_id() -> String:
	return Festival.winter_star_plaza_gifter(Clock.year(), NPCFactory.ALL_IDS)


static func journal_text() -> String:
	## Bible: "journal shows 'Winter Star: your gift is for <name>'" — reused
	## as day_flow.gd's wake-toast text too (simplest correct: the bible
	## doesn't specify a SEPARATE toast string, and the journal line already
	## reads naturally as one).
	var npc_id := target_npc_id()
	var display := NPCFactory.build_data(npc_id).display_name if npc_id != "" else "no one"
	return "Winter Star: your gift is for %s" % display


static func is_gift_target(npc_id: String) -> bool:
	return npc_id == target_npc_id()


static func gift_bond_multiplier(npc_id: String) -> int:
	## Bible: "gifting THAT NPC today... x5 bond" — regardless of item
	## (loved/liked/neutral/disliked all get the multiplier per the bible's
	## "loved reaction regardless of item AND x5 bond" wording, meaning the
	## REACTION becomes "loved" AND the delta is x5; see forced_reaction()).
	return TARGET_ITEMS_LOVED_MULT if is_gift_target(npc_id) else 1


static func forced_reaction(npc_id: String) -> String:
	## "" means no override (ordinary gift_reaction rules apply). On Winter
	## Star, gifting the assigned target ALWAYS reacts as "loved" regardless
	## of the actual item (bible: "loved reaction regardless of item").
	if Clock.is_festival_today() != Festival.ID_WINTER_STAR:
		return ""
	if not is_gift_target(npc_id):
		return ""
	return "loved"


## ---- plaza gifter (player receives a gift) ----

static func has_received_plaza_gift_today() -> bool:
	return int(GameState.flags.get("winter_star_gift_received_day", -1)) == Clock.day


static func receive_plaza_gift_if_due(npc_id: String) -> Dictionary:
	## Called from npc.gd on ordinary talk during Winter Star hours. Returns
	## {"received": bool, "item_id": String, "gold": int} — item_id is set
	## (gold 0) when the gifter NPC has a loved_items entry to hand over,
	## otherwise falls back to the bible's "100g fallback". No-ops (received
	## = false) outside Winter Star, for any NPC other than the seeded
	## gifter, or if today's gift was already collected.
	if Clock.is_festival_today() != Festival.ID_WINTER_STAR:
		return {"received": false, "item_id": "", "gold": 0}
	if npc_id != plaza_gifter_npc_id():
		return {"received": false, "item_id": "", "gold": 0}
	if has_received_plaza_gift_today():
		return {"received": false, "item_id": "", "gold": 0}
	GameState.flags["winter_star_gift_received_day"] = Clock.day
	var data := NPCFactory.build_data(npc_id)
	if not data.loved_items.is_empty():
		var item_id := String(data.loved_items[0])
		Inventory.add_item(item_id)
		return {"received": true, "item_id": item_id, "gold": 0}
	GameState.add_gold(100)
	return {"received": true, "item_id": "", "gold": 100}
