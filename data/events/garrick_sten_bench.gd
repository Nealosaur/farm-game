class_name GarrickStenBenchEvent
extends RefCounted
## Alive Stride 2: "The Bench" — Garrick & Sten reconciliation. Authored
## canon, shipped VERBATIM per the contract (also appended to
## docs/design/characters.md under Garrick — see the "Scene: The Bench"
## heading there).
##
## Trigger chain: Garrick's L7 heart event choice A ("Twenty years is long
## enough. Tell HIM that.") sets flag "garrick_l7_choice_a" (wire-up in
## data/dialog/garrick.gd's l7 event application — see npc.gd's
## _on_heart_event_choice, which now also sets this flag on that exact
## choice). This scene then fires the NEXT time the player enters town during
## blocks 6-12 on any later day — preconditions below express "next day or
## later" as simply NOT gating on day at all (the flag itself only exists
## starting the day the L7 event was seen, and TriggerService's callers only
## check for new scenes on map entry/block change, never mid-block, so the
## earliest this can actually fire is the farm->town transition after the L7
## evening event already happened — i.e. always effectively "next day or
## later" in practice; no separate day-tracking needed for a scene this
## simple, and it's a one-time-forever scene besides).
##
## Scene staging: Garrick is temp-spawned at the town entrance (EventRunner's
## actor-resolution fallback — he has no ordinary town schedule slot at the
## entrance) and walks to the smithy; Sten is resolved as whichever LIVE
## instance is already on the map (he's always somewhere in town during
## 6-12). Camera follows Garrick's walk, then frames both by cutting to
## Sten's position (the two are adjacent at the smithy counter by then).
##
## Post-scene content gating (small, surgical — see the contract): Garrick's
## KINDRED line "I told Sten his steel saved my life..." and Sten's new CLOSE
## line are BOTH gated on flag "garrick_sten_reconciled" via
## DialogResolver-adjacent filtering — see npc.gd's tier-pool line filtering
## (dialog_resolver.gd's _pick_from_tier_pool consumes whatever pool the
## caller hands it, so the gating happens one level up, in each NPC's
## dialog DATA-consuming call site — see data/dialog/garrick.gd's and
## data/dialog/sten.gd's own doc comments for exactly which line moved where).

const TOWN_ENTRANCE_CELL := Vector2i(4, 14)   # matches town.gd's FARM_PORTAL_CELL spawn area
const SMITHY_CELL := Vector2i(33, 18)         # StenData.CELL_SMITHY

const DATA := {
	"id": "garrick_sten_bench",
	"preconditions": {
		"flag_set": "garrick_l7_choice_a",
		"flag_absent": "garrick_sten_reconciled",
		"block/hours": "9-12",
		"map": "town",
	},
	"script": [
		"move garrick 4 14 teleport",
		"camera garrick",
		"move garrick 33 17 walk",
		"camera sten",
		"face garrick sten",
		"face sten player",
		"speak garrick \"Sten.\"",
		"speak sten \"Garrick.\"",
		"wait 1.0",
		"speak sten \"Twenty years, and you pick a Tuesday.\"",
		"speak garrick \"Blade did everything right. I didn't. Blocked the slam you told me never to block.\"",
		"wait 1.0",
		"speak sten \"...I know. I measured the break. Told the whole town nothing. Seemed kinder to let them blame my steel than your knee.\"",
		"speak garrick \"Your steel saved my life ten years before the day it didn't. Should have led with that.\"",
		"speak sten \"Hm.\"",
		"face sten left",
		"speak sten \"Forge is hot. Stand there and hand me things.\"",
		"speak garrick \"That an apology?\"",
		"speak sten \"It's a job. Take it.\"",
		"toast \"Something in Emberhollow just got quietly better.\"",
		"bond garrick 50",
		"bond sten 50",
		"flag garrick_sten_reconciled",
		"end",
	],
}
