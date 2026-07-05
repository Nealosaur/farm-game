class_name DialogResolver
extends RefCounted
## Pure, testable line-picking logic for NPC dialog data (see
## data/dialog/marta.gd for the shape). No autoload/scene-tree access here —
## callers (npc.gd) gather a `context` dict from Clock/Relationships and pass
## it in, so this stays trivially unit-testable and reusable for every NPC.
##
## Precedence (characters.md header, binding):
##   heart-event-if-pending > birthday > festival > rain > seasonal
##   (if present for the NPC's current tier) > tier pool (random,
##   no-repeat-until-exhausted).
## Heart events are NOT resolved by pick() — npc.gd checks
## Relationships.pending_event() itself and, if set, plays the heart-event
## script directly (it has its own multi-line + choice shape, distinct from
## a single resolved line). pick() covers everything AFTER that gate: the
## ordinary "what does the NPC say when I talk to them" question.
##
## context keys (all required; caller fills from Clock/Relationships):
##   "tier": String            — current tier name (Relationships.tier_name)
##   "season": int             — Clock.season()
##   "is_raining": bool        — Clock.is_raining()
##   "is_festival": bool       — Clock.is_festival_today() != ""
##   "is_birthday": bool       — NPCData.is_birthday_today(npc)
##   "shown_indices": Array[int] — Relationships.shown_indices(npc_id, tier),
##                                  indices already shown THIS pool-cycle for
##                                  the resolved tier pool
##   "rng": RandomNumberGenerator — injectable for deterministic tests;
##                                  gameplay passes a real one
##
## Result shape: {"text": String, "source": String, "pool_index": int}
## `source` is one of "birthday"/"festival"/"rain"/"seasonal"/"tier_pool" —
## npc.gd only needs to call Relationships.mark_line_shown() when
## source == "tier_pool" (the other sources aren't pooled/tracked).
## `pool_index` is -1 unless source == "tier_pool".


static func pick(data: Dictionary, context: Dictionary) -> Dictionary:
	if bool(context.get("is_birthday", false)) and String(data.get("birthday_reaction", "")) != "":
		return {"text": data["birthday_reaction"], "source": "birthday", "pool_index": -1}

	if bool(context.get("is_festival", false)):
		var festival_lines: Array = data.get("festival", [])
		if not festival_lines.is_empty():
			var rng: RandomNumberGenerator = context.get("rng")
			var idx: int = rng.randi() % festival_lines.size() if rng != null else 0
			return {"text": festival_lines[idx], "source": "festival", "pool_index": -1}
		# No festival-specific lines for this NPC: fall through to tier pool
		# below (documented — Marta's plaza-stall flavor is context, not a
		# dedicated line yet; nothing in her data blocks this fallback).

	if bool(context.get("is_raining", false)):
		var rain_lines: Array = data.get("rain", [])
		if not rain_lines.is_empty():
			var rng: RandomNumberGenerator = context.get("rng")
			var idx: int = rng.randi() % rain_lines.size() if rng != null else 0
			return {"text": rain_lines[idx], "source": "rain", "pool_index": -1}

	var tier: String = context.get("tier", "STRANGER")
	var seasonal_line := _seasonal_line_for(data, tier, int(context.get("season", 0)))
	if seasonal_line != "":
		return {"text": seasonal_line, "source": "seasonal", "pool_index": -1}

	return _pick_from_tier_pool(data, tier, context)


static func _seasonal_line_for(data: Dictionary, tier: String, season: int) -> String:
	var tier_rank := _tier_rank(tier)
	var entries: Array = data.get("seasonal", [])
	for entry: Dictionary in entries:
		var entry_season := int(entry.get("season", -1))
		if entry_season != -1 and entry_season != season:
			continue
		var min_level := int(entry.get("min_level", 0))
		if _tier_rank_min_level(min_level) > tier_rank:
			continue
		return String(entry.get("line", ""))
	return ""


## Tier ordering for "does this tier qualify for a min_level-gated seasonal
## line" — compares by tier BAND, not raw level, since dialog data only ever
## gates seasonal lines to "FRIEND+" style bands (characters.md's own
## annotations), never to an exact level.
const _TIER_ORDER := ["STRANGER", "ACQUAINT", "FRIEND", "CLOSE", "KINDRED"]


static func _tier_rank(tier: String) -> int:
	var i := _TIER_ORDER.find(tier)
	return i if i >= 0 else 0


static func _tier_rank_min_level(min_level: int) -> int:
	## Maps a seasonal entry's min_level (a Relationships level 0-10, per the
	## bible's "(Spring/FRIEND+)" == level 4 convention) to the tier rank it
	## requires, via Relationships.tier_name_for_level so the two systems
	## can't drift out of sync.
	return _tier_rank(Relationships.tier_name_for_level(min_level))


static func _pick_from_tier_pool(data: Dictionary, tier: String, context: Dictionary) -> Dictionary:
	var pools: Dictionary = data.get("tier_pools", {})
	var pool: Array = pools.get(tier, [])
	if pool.is_empty():
		# No lines at all for this tier (shouldn't happen with real data, but
		# stay non-crashing): fall back to STRANGER's pool if it has any.
		pool = pools.get("STRANGER", [])
		if pool.is_empty():
			return {"text": "...", "source": "tier_pool", "pool_index": -1}
		tier = "STRANGER"

	var shown: Array = context.get("shown_indices", [])
	var available: Array[int] = []
	for i in pool.size():
		if not (i in shown):
			available.append(i)
	if available.is_empty():
		# Exhausted: the whole pool is eligible again. Array(range(...)) casts
		# range()'s untyped Array to Array[int] explicitly — reassigning an
		# untyped Array into an already-declared Array[int] var throws at
		# runtime in Godot 4 (unlike a fresh inferred-type `var`).
		available.assign(range(pool.size()))

	var rng: RandomNumberGenerator = context.get("rng")
	var pick_i: int = available[rng.randi() % available.size()] if rng != null else available[0]
	return {"text": pool[pick_i], "source": "tier_pool", "pool_index": pick_i}
