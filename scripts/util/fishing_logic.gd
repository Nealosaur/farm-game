class_name FishingLogic
extends RefCounted
## Pure logic for the fishing minigame (DEPTH stride). No scene tree, no
## autoload state — every method is a deterministic function of its inputs,
## same "pure helper under a thin UI" convention as ForgeLogic/ShopLogic/
## CookingLogic (see forge_logic.gd's class doc).
##
## Flow (mirrors the bible: "cast -> short wait -> bite -> timing minigame ->
## success/fail"), owned end-to-end by FishingScreen (the thin UI) calling
## into this file:
##   1. Player faces water + uses a FISHING_ROD tool -> can_fish_at() gates it.
##   2. Cast: a short random wait (bite_delay()) before the bite.
##   3. Bite -> minigame: a marker sweeps back and forth across a 0..1 track
##      at marker_speed(); the player presses at some sampled position
##      (bite_result() takes the marker's position 0..1 and the target
##      zone's [start,end) and returns whether it landed inside).
##   4. On success, roll_species() picks which fish was caught (rarity-
##      weighted, seeded) for the water body the player was facing.
##
## Determinism: every roll takes an explicit seed (or RandomNumberGenerator)
## — no engine randomize() anywhere in this file, so the "seeded species
## weighting" test requirement holds bit-for-bit.

const WATER_RIVER := "river"
const WATER_SEA := "sea"

## species id -> weight (higher = more common). Mirrors EnemyData.drop_chance
## style tables elsewhere: plain ints, not normalized fractions, since
## roll_species() sums them itself.
const RIVER_POOL := {
	"rivertrout": 50,
	"bluegill": 35,
	"eel": 15,
}

const SEA_POOL := {
	"sardine": 50,
	"bass": 35,
	"pufferfish": 15,
}

## Target-zone width as a fraction of the 0..1 track — narrower = harder.
## A flat difficulty this stride (bible: "pick the cleaner one" — kept simple,
## no per-species/per-depth difficulty curve yet).
const TARGET_ZONE_WIDTH := 0.22

const MIN_BITE_DELAY := 0.6
const MAX_BITE_DELAY := 1.6

## Full sweep (0 -> 1 -> 0) per second — tuned so the timing window is
## readable but not trivial (see docs/design/visual-overhaul.md's "simple
## timing/skill minigame" framing).
const MARKER_SPEED := 1.4


static func pool_for_water(water_body: String) -> Dictionary:
	return SEA_POOL if water_body == WATER_SEA else RIVER_POOL


static func can_fish_at(has_rod: bool, is_facing_water: bool) -> bool:
	## Both a rod AND facing water are required to cast (bible: "rod required
	## + must face water") — a pure gate so the UI/player-input layer can ask
	## "is casting even allowed here" without duplicating this AND.
	return has_rod and is_facing_water


static func roll_bite_delay(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(MIN_BITE_DELAY, MAX_BITE_DELAY)


static func marker_position(elapsed: float, speed: float = MARKER_SPEED) -> float:
	## Triangle-wave sweep 0..1..0..1..." over time — deterministic pure
	## function of elapsed seconds, so a fixed elapsed value always maps to
	## the same marker position (the minigame UI just samples this every
	## frame; tests can probe specific elapsed values directly).
	var t: float = fmod(elapsed * speed, 2.0)
	return t if t <= 1.0 else 2.0 - t


static func roll_target_zone(rng: RandomNumberGenerator, width: float = TARGET_ZONE_WIDTH) -> Vector2:
	## Random [start, end) zone fully inside 0..1, given a seeded RNG — the
	## "target zone" the player must press the marker inside of.
	var start := rng.randf_range(0.0, 1.0 - width)
	return Vector2(start, start + width)


## Vector2 components are 32-bit floats in Godot (even though GDScript's own
## `float` literals are 64-bit) — zone.x/zone.y round-trip through that
## truncation, so a marker_pos sampled at the EXACT boundary value (e.g. 0.4)
## can compare as fractionally less-than the stored zone.x (0.400000006...).
## A tiny epsilon keeps the boundary genuinely inclusive as documented,
## instead of leaking a float32/float64 precision gotcha into gameplay feel.
const _EPSILON := 0.0001


static func is_within_zone(marker_pos: float, zone: Vector2) -> bool:
	return marker_pos >= zone.x - _EPSILON and marker_pos <= zone.y + _EPSILON


static func roll_species(water_body: String, rng: RandomNumberGenerator) -> String:
	## Weighted pick from the water body's pool, using the SAME "sum weights,
	## roll under total, walk the accumulator" technique as
	## MineState.roll_floor_type — kept identical in shape so both weighted-
	## table rolls in the codebase read the same way.
	var pool := pool_for_water(water_body)
	var ids := pool.keys()
	ids.sort()  # stable order: Dictionary iteration order isn't guaranteed
	var total := 0
	for id: String in ids:
		total += int(pool[id])
	var roll := rng.randi() % total
	var acc := 0
	for id: String in ids:
		acc += int(pool[id])
		if roll < acc:
			return id
	return ids[0]
