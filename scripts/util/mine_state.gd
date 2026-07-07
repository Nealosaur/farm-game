class_name MineState
extends RefCounted
## Pure dict logic for the procedural mine's descent (DEPTH stride). Mirrors
## DungeonState's shape/rules exactly (see scripts/util/dungeon_state.gd) —
## same "ensure_day()-style guard before queries" pattern, adapted for a
## per-RUN kill ledger instead of a per-DAY one (a mine run's kills reset
## whenever the player starts a FRESH dive, not merely on a new calendar day —
## see ensure_run() below).
##
## Blob shape — SaveManager.world["mine"]:
##   {
##     "run_seed": int,       # seed for THIS dive's generation (fresh dive = new seed)
##     "depth": int,          # current depth (1-based; 0 = not currently in the mine)
##     "deepest": int,        # deepest depth ever reached, across all dives (persists)
##     "killed": { "<depth>": [spawn_index, ...] },  # per-depth kill ledger, THIS run only
##   }
##
## Determinism contract (bible: "same (run_seed, depth) -> same layout; new
## seed each fresh dive"): MineFloor derives its layout/floor-type/enemy/loot
## RNG streams from mix_seed(run_seed, depth) — never from Clock.day or engine
## randomize() — so re-entering the same depth on the same run (e.g. ascend
## then descend again) reproduces the exact same floor, while a fresh dive
## (new run_seed) always looks different.

const ENTRY_DEPTH := 1


static func ensure_run(blob: Dictionary, run_seed: int) -> Dictionary:
	## Returns a blob guaranteed to have run_seed/depth/deepest/killed keys.
	## Starting a FRESH dive (run_seed differs from the stored one) resets
	## depth to ENTRY_DEPTH and clears the kill ledger — deepest is NEVER
	## reset here (it's a permanent high-water mark, see record_depth()).
	var out := blob.duplicate(true)
	if int(out.get("run_seed", -1)) != run_seed:
		out["run_seed"] = run_seed
		out["depth"] = ENTRY_DEPTH
		out["killed"] = {}
	if not out.has("deepest"):
		out["deepest"] = 0
	if not out.has("killed"):
		out["killed"] = {}
	return out


static func record_depth(blob: Dictionary, depth: int) -> Dictionary:
	## Sets the current depth and bumps "deepest" if this is a new high-water
	## mark. Does not mutate `blob` in place.
	var out := blob.duplicate(true)
	out["depth"] = depth
	if depth > int(out.get("deepest", 0)):
		out["deepest"] = depth
	return out


static func is_killed(blob: Dictionary, depth: int, spawn_index: int) -> bool:
	var killed: Dictionary = blob.get("killed", {})
	var list: Array = killed.get(str(depth), [])
	# int(v) compare, not list.has(): JSON round-trip turns ints into floats
	# (see DungeonState.is_killed's identical note).
	for v in list:
		if int(v) == spawn_index:
			return true
	return false


static func record_kill(blob: Dictionary, depth: int, spawn_index: int) -> Dictionary:
	## Returns a new blob with spawn_index recorded as killed at `depth` for
	## the CURRENT run. Idempotent (same as DungeonState.record_kill).
	var out := blob.duplicate(true)
	if not out.has("killed"):
		out["killed"] = {}
	var killed: Dictionary = out["killed"]
	var key := str(depth)
	var list: Array = (killed.get(key, []) as Array).duplicate()
	if not is_killed(out, depth, spawn_index):
		list.append(spawn_index)
	killed[key] = list
	out["killed"] = killed
	return out


static func mix_seed(run_seed: int, depth: int) -> int:
	## Deterministic per-(run_seed, depth) integer seed. Not engine RNG — a
	## small hand-rolled mix (same "own the stability contract" reasoning as
	## MapBuilder._cell_hash) so it can never silently change out from under
	## us on an engine upgrade.
	var h := (run_seed * 2654435761) ^ (depth * 668265263)
	h = (h ^ (h >> 13)) & 0x7fffffff
	return h


## ---- floor-type variety ----

enum FloorType { NORMAL, MONSTER_DENSE, TREASURE, QUIET }

const FLOOR_TYPE_NAMES := {
	FloorType.NORMAL: "Normal",
	FloorType.MONSTER_DENSE: "Monster Den",
	FloorType.TREASURE: "Treasure Room",
	FloorType.QUIET: "Quiet Floor",
}

## Weighted roll (bible: "monster / treasure(more pickups, fewer foes) / quiet
## floor variety"). Normal is the common case; the other three are rarer
## flavor floors. Weights are out of 100 so the table is easy to eyeball/tune.
const FLOOR_TYPE_WEIGHTS := [
	[FloorType.NORMAL, 55],
	[FloorType.MONSTER_DENSE, 20],
	[FloorType.TREASURE, 15],
	[FloorType.QUIET, 10],
]


static func roll_floor_type(run_seed: int, depth: int) -> FloorType:
	## Deterministic per-(run_seed, depth) weighted roll — a DIFFERENT RNG
	## stream from the layout/enemy/loot ones (mix_seed XORed with a distinct
	## salt), so tuning the floor-type table never perturbs layout generation
	## for the same seed+depth (and vice versa).
	var rng := RandomNumberGenerator.new()
	rng.seed = mix_seed(run_seed, depth) ^ 0x9e3779b9
	var total := 0
	for entry: Array in FLOOR_TYPE_WEIGHTS:
		total += int(entry[1])
	var roll := rng.randi() % total
	var acc := 0
	for entry: Array in FLOOR_TYPE_WEIGHTS:
		acc += int(entry[1])
		if roll < acc:
			return entry[0]
	return FloorType.NORMAL


static func floor_type_name(t: FloorType) -> String:
	return FLOOR_TYPE_NAMES.get(t, "Normal")


## ---- depth scaling ----

static func enemy_density_for(depth: int, base_count: int) -> int:
	## +1 enemy every 3 depths beyond the first, capped so a layout's fixed
	## room set never gets absurdly overstuffed.
	return mini(base_count + (depth - 1) / 3, base_count + 6)


static func loot_chance_bonus(depth: int) -> float:
	## Small deterministic drop-chance bump per depth (loot scaling with
	## depth, bible requirement) — capped at +0.3 so drops never approach
	## guaranteed and the existing per-enemy drop_chance stays meaningful.
	return minf(0.3, (depth - 1) * 0.02)
