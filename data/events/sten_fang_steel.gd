class_name StenFangSteelEvent
extends RefCounted
## Craft Stride 2: "Fang Steel" — Sten finishes the masterwork. Authored
## canon, shipped VERBATIM per the contract (also appended to
## docs/design/characters.md under Sten — see the "Scene: Fang Steel"
## heading there). This pays off his L7 heart event "Masterwork", whose
## choice-A response ends "Come back tomorrow. Bring fang steel."
##
## Trigger chain: Sten's L7 heart event choice A ("Patient. Like its maker.")
## sets flag "sten_l7_choice_a" PLUS the companion "sten_l7_choice_a_day"
## day record (wire-up in npc.gd's _on_heart_event_choice — the SAME
## table-driven mechanism as Garrick's garrick_l7_choice_a). This scene then
## fires the next time the player is in town during a 6-12 block on a LATER
## day, carrying the Steel Sword. Unlike The Bench (whose "next day" was
## implicit — Garrick's L7 plays in the evening, after the 9-12 trigger
## window has passed), Sten's L7 event plays AT THE SMITHY during the very
## blocks this scene fires in, so the "Come back tomorrow" rule needs the
## explicit next_day_after_flag precondition below.
##
## The steel_sword requirement ("has_item") is the bible's recipe chain: the
## masterwork's base IS the player's steel sword line — Sten won't stage the
## one-time folding without it in the room.
##
## Scene staging: camera cuts to Sten (always at the smithy during 6-12 —
## resolved as the live town NPC instance, never a temp spawn); he speaks
## from the bench, turns to the forge ("face sten left" — the forge sits
## west of his counter spot, same staging as The Bench's "(turns to the
## forge)"), and finishes the base. No player/NPC movement — this scene is
## a held shot, not a walk.
##
## Post-scene effect: flag "sten_masterwork_done" is what un-hides the
## Fangsteel Blade upgrade in ForgeLogic.visible_upgrades() (see
## forge_logic.gd's UPGRADES table) — the recipe gate the toast announces.

const DATA := {
	"id": "sten_fang_steel",
	"preconditions": {
		"flag_set": "sten_l7_choice_a",
		"flag_absent": "sten_masterwork_done",
		"next_day_after_flag": "sten_l7_choice_a",
		"has_item": "steel_sword",
		"block/hours": ["6-9", "9-12"],
		"map": "town",
	},
	"script": [
		"camera sten",
		"speak sten \"You came. Good. Bench.\"",
		"speak sten \"Twenty years I let judges tell me what finished looks like.\"",
		"wait 1.0",
		"speak sten \"Watch. This part I only do once.\"",
		"face sten left",
		"wait 1.5",
		"speak sten \"Folded steel remembers every hand that failed it. Today it gets one that didn't.\"",
		"speak sten \"Base is done. The edge is yours to earn — fang, glass, coin. Forge is open when you are.\"",
		"toast \"Forging unlocked: Fangsteel Blade\"",
		"bond sten 50",
		"flag sten_masterwork_done",
		"end",
	],
}
