class_name IntroAldenEvent
extends RefCounted
## Alive Stride 2: Day-1 opening, migrated from the dedicated
## scripts/components/alden_intro.gd Area2D one-shot into an authored
## EventScript scene. VERBATIM lines are unchanged from AldenDialog.DATA["intro"]
## (see data/dialog/alden.gd) — this file's `script` array is the ONLY place
## those lines are spoken now; the old hardcoded alden_intro.gd interactable
## is removed (see farm.gd's updated wiring).
##
## Improvement over the old version (contract): Alden now WALKS in from the
## farm's west edge to the player's position, speaks, then walks off toward
## the east/town side and despawns (a temp-spawned actor — see EventRunner's
## actor-resolution doc — since Alden has no ordinary farm schedule slot;
## his real NPC instance lives on the town map).
##
## Trigger: TriggerService gates this the same way the old Area2D did — only
## on day 1, only once (the "intro_done" flag IS this scene's own
## once-per-forever marker; see farm.gd's call site, which checks
## GameState.flags["intro_done"] directly rather than routing through
## world["events_seen"] since intro_done already existed pre-stride and
## SaveManager's migration logic already targets that exact key — see
## SaveManager._migrate_intro_flag()). "id" below is still declared for
## API consistency with every other event file, but this one's gate lives on
## GameState.flags, not TriggerService.seen_forever().
##
## Quest hook: `flag intro_done` marks the flag; the New Roots grant itself
## is NOT expressible as a plain EventScript command (it needs Quests.grant_new_roots(),
## not just a bool flag) — EventRunner has no `quest` command in this
## contract, so the calling site (farm.gd's intro trigger, mirroring the old
## alden_intro.gd's _on_intro_finished()) grants the quest itself right after
## play() finishes. This keeps EventRunner's command set exactly the 15
## verbs the contract specifies, with quest-granting staying a thin, testable
## one-line call at the trigger site rather than a bespoke 16th command for
## a single scene.

const PLAYER_SPAWN_CELL := Vector2i(9, 9)  # matches farm.gd's SPAWNS["default"] — where Alden meets the player
const ALDEN_ENTER_CELL := Vector2i(2, 7)   # west edge, on the walkable path row (y=7)
const ALDEN_MEET_CELL := Vector2i(10, 7)   # a few cells from the player, path row — matches the old ALDEN_INTRO_CELL
const ALDEN_EXIT_CELL := Vector2i(20, 7)   # east, toward town — off camera, on the same path row

const DATA := {
	"id": "intro_alden",
	"preconditions": {},  # gated by GameState.flags["intro_done"] at the call site — see class doc
	"script": [
		"move alden 2 7 teleport",
		"move alden 10 7 walk",
		"face alden player",
		"speak alden \"Ah — you made it. Welcome to Hearthstead. Your grandmother worked this soil forty years; the town ate from it for most of them.\"",
		"speak alden \"I'll be plain: Emberhollow is fading. Shops quiet, plaza empty, and something old has soured in the Delve east of here.\"",
		"speak alden \"But a lit window on this farm is the best news we've had in years. Meet the town — all eight of us worth meeting, I'm afraid I'm counted. Come find me after. There's a fund.\"",
		"flag intro_done",
		"move alden 20 7 walk",
		"end",
	],
}
