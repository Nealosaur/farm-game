class_name Taming
extends RefCounted
## Craft Stride 3: owns world["taming"] = {slime_feeds:int, barn:["slime", ...]}.
## Stateless RefCounted utility (same shape as DungeonState/Forage) — callers
## read/write SaveManager.world["taming"] directly through these helpers, no
## autoload/restore() step of its own (nothing here needs a live signal
## connection; every mutation is a direct call from player.gd/npc.gd/DayFlow).
##
## Feeding vs taming (bible): feeding ANY live tameable enemy while holding
## its favorite food always consumes the item and makes it passive for the
## day — feeds_and_maybe_tame() below is the single entry point that also
## decides, on top of that, whether THIS feed instead tames the target
## (slime_feeds >= THRESHOLD before this feed, barn has room). Barn is capped
## at MAX_BARN; a tame attempt against a full barn still consumes the feed
## (the enemy still goes passive) but does NOT despawn/pen it — bible: "Barn
## full -> toast 'Your pen is full.' and the feed still makes it passive".
##
## All ints/arrays coerced on read (JSON floats gotcha, same as every other
## world blob).

const THRESHOLD := 3     # bible: "3 total feeds on ANY slimes... NEXT feed tames"
const MAX_BARN := 2

const RESULT_FED := "fed"        # ordinary feed, stays passive, not tamed
const RESULT_TAMED := "tamed"    # this feed tamed the target (barn had room)
const RESULT_BARN_FULL := "barn_full"  # threshold reached but barn full — fed anyway, not tamed


static func default_blob() -> Dictionary:
	return {"slime_feeds": 0, "barn": []}


static func read(world: Dictionary) -> Dictionary:
	var raw: Dictionary = world.get("taming", {})
	var barn: Array = []
	for entry in raw.get("barn", []):
		barn.append(String(entry))
	return {
		"slime_feeds": int(raw.get("slime_feeds", 0)),
		"barn": barn,
	}


static func barn_count(world: Dictionary) -> int:
	return read(world).get("barn", []).size()


static func has_room(world: Dictionary) -> bool:
	return barn_count(world) < MAX_BARN


## Records one feed of `species_id` (e.g. "slime") and decides whether it
## tames. Returns {"result": RESULT_*, "blob": Dictionary} — caller
## (player.gd) writes the returned blob back to SaveManager.world["taming"]
## and reacts to `result` for the toast/despawn decision. Pure function (no
## SaveManager access) so it stays trivially unit-testable.
static func record_feed(world: Dictionary, species_id: String) -> Dictionary:
	var blob := read(world)
	var would_tame: bool = blob["slime_feeds"] >= THRESHOLD
	blob["slime_feeds"] += 1
	if not would_tame:
		return {"result": RESULT_FED, "blob": blob}
	if blob["barn"].size() >= MAX_BARN:
		return {"result": RESULT_BARN_FULL, "blob": blob}
	blob["barn"].append(species_id)
	blob["slime_feeds"] = 0  # bible: threshold feeds spend down into the tame
	return {"result": RESULT_TAMED, "blob": blob}
