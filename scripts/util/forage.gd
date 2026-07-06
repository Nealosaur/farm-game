class_name Forage
extends RefCounted
## Pure dict logic for daily forage spawns/pickup persistence (World Stride C).
## Mirrors DungeonState's shape/rules exactly (see scripts/util/dungeon_state.gd):
## a per-map "day" stamp plus a "taken" ledger, reset whenever the stored day
## falls behind Clock.day.
##
## Blob shape — SaveManager.world["forage"] (documented in save_manager.gd's
## sanctioned-keys contract too):
##   {
##     map_id: {
##       "day": int,               # last day this map's forage was rolled
##       "taken": ["x,y", ...],    # cell keys (see cell_key()) already picked today
##     },
##   }
##
## Spawn determinism (bible: "seed with Clock.day so re-entering the map same
## day gives same layout"): spawn_cells() takes an explicit seed int (callers
## pass Clock.day, or day*many-primes mixed with a per-map salt so Riverwoods
## and Beach don't roll identical layouts on the same day) and a list of
## candidate walkable cells; it deterministically shuffles + slices that list
## with a seeded RandomNumberGenerator, so calling it twice with the same
## inputs always returns the same cells in the same order.
##
## Winter list swap (bible): callers pass the correct item pool for the
## current season — this file has no seasonal knowledge itself, it just spawns
## whatever pool it's given.

const MIN_SPAWNS := 2
const MAX_SPAWNS := 4


static func ensure_day(blob: Dictionary, day: int) -> Dictionary:
	## Returns a blob guaranteed to have "day"/"taken" keys, resetting "taken"
	## when `day` has advanced past the stored day (new-day reroll). Does not
	## mutate `blob` in place — caller re-assigns the result.
	var out := blob.duplicate(true)
	if int(out.get("day", -1)) != day:
		out["day"] = day
		out["taken"] = []
	elif not out.has("taken"):
		out["taken"] = []
	return out


static func cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


static func is_taken(blob: Dictionary, cell: Vector2i) -> bool:
	var taken: Array = blob.get("taken", [])
	var key := cell_key(cell)
	for v in taken:
		if String(v) == key:
			return true
	return false


static func record_taken(blob: Dictionary, cell: Vector2i) -> Dictionary:
	## Returns a new blob with `cell` recorded as taken. Idempotent.
	var out := blob.duplicate(true)
	if not out.has("taken"):
		out["taken"] = []
	if not is_taken(out, cell):
		var list: Array = (out["taken"] as Array).duplicate()
		list.append(cell_key(cell))
		out["taken"] = list
	return out


static func spawn_cells(candidates: Array, seed_value: int, count_seed: int = 0) -> Array:
	## Deterministically picks 2-4 cells from `candidates` (a caller-supplied
	## list of walkable Vector2i cells, already excluding portals/props/spawns)
	## using a seeded RNG — same seed_value always yields the same cells in
	## the same order, so re-entering a map the same day reproduces today's
	## layout exactly. `count_seed` lets callers vary the spawn COUNT
	## deterministically too (defaults to reusing seed_value's low bits).
	if candidates.is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pool: Array = candidates.duplicate()
	# Fisher-Yates shuffle, seeded — deterministic order for a given seed.
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var count_rng := RandomNumberGenerator.new()
	count_rng.seed = seed_value if count_seed == 0 else count_seed
	var count: int = MIN_SPAWNS + (count_rng.randi() % (MAX_SPAWNS - MIN_SPAWNS + 1))
	count = mini(count, pool.size())
	return pool.slice(0, count)


static func item_pool_for_season(season: int, normal_pool: Array, winter_pool: Array) -> Array:
	## Winter (season index 3) swaps to the winter-only pool per the bible
	## ("Winter replaces lists with {frostcap} on both maps").
	return winter_pool if season == 3 else normal_pool


static func map_seed(map_id: String, day: int) -> int:
	## Distinct per-map seed for the SAME day so two maps don't roll identical
	## layouts — a simple string hash mixed with the day keeps this
	## deterministic without needing per-map magic-number salts maintained by
	## hand.
	return int(map_id.hash()) ^ (day * 2654435761)
