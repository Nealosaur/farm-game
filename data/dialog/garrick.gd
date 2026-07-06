class_name GarrickDialog
extends RefCounted
## Garrick — Retired adventurer, quest-giver. All strings VERBATIM from
## docs/design/characters.md (typos and all — they're voice). Do not
## paraphrase; if a line needs to change, change characters.md first.
##
## World Stride D adds the "quests" block below: Garrick's hand-in lines for
## Q2 "Prove It" and Q3 "The King Below" (verbatim, characters.md's QUESTS
## block), consumed by npc.gd's quest-hook methods, NOT DialogResolver.pick()
## (pick() only resolves the ordinary ambient-talk line; quest grant/hand-in
## are their own dedicated flow).
##
## Alive Stride 2: the KINDRED pool's "I told Sten his steel saved my
## life..." line only actually surfaces once flag "garrick_sten_reconciled"
## is true (set by "The Bench" scene, data/events/garrick_sten_bench.gd) —
## npc.gd's _gated_dialog_data() filters it OUT of the pool dynamically until
## then. Lives here in the ordinary pool (not a separate list) so this file
## stays pure data.
##
## Shape consumed by DialogResolver.pick() — see data/dialog/marta.gd's
## header comment for the full documented shape.

const DATA := {
	"quests": {
		"prove_it_hand_in": "Delve salvage, and a hint worth more: iron holds where steel folds. Floor two taught you that, didn't it.",
		"king_below_hand_in": "The King's down. Knew you had it in you, farmer.",
		"king_below_hand_in_already_defeated": "Heard the King's already met you. Ha! Money's still money.",
	},
	"tier_pools": {
		"STRANGER": [
			"Farmer with a blade. The Delve's eaten better. ...Prove me wrong, actually. Please.",
			"Floor one's slimes. Floor two's worse. Floor three sings. You'll see.",
			"I'd go myself but my knee retired before I did.",
			"Watch the goblin wind-up. The tell's in the shoulders.",
		],
		"ACQUAINT": [
			"Still standing. Good. The Delve notices persistence.",
			"Dodge THROUGH the slam, not away. Rings are thinner than they look.",
			"I cleared floor two the year of the long winter. Alone. Stupid. Glorious.",
			"Don't ask about Sten. ...You were about to.",
		],
		"FRIEND": [
			"You fight smarter than I did. Less shoulder, more feet. Good.",
			"The King wasn't always down there. Something soured that place around when my sword broke. I don't say that in the saloon.",
			"First rule of deep floors: eat BEFORE you're hungry. RP's just courage with a number on it.",
			"That shield trick of mine — remind me. When you're ready. Not yet.",
		],
		"CLOSE": [
			"My last sword was Sten's finest. It broke mid-swing, floor three. I said things. He said things. Twenty years of things, now.",
			"You went further down than I ever did, you know that? Don't grin. Fine. Grin.",
			"The knee's fake, mostly. What retired was my nerve. Delve gives it back to me, watching you.",
		],
		"KINDRED": [
			"I told Sten his steel saved my life for ten years before the day it didn't. Took me twenty years and one farmer to say it. He heard me out. So. That happened.",
			"Adventurer's toast: to floors below and friends above. You're the second one.",
		],
	},
	"seasonal": [
		{"season": 3, "min_level": 0, "line": "Delve's warmer than the street in winter. That's not a recommendation. It's just true."},
	],
	"rain": [
		"Rain never reaches floor two. Weather for going down, if you ask me.",
	],
	"festival": [],
	"birthday_reaction": "You track birthdays AND slime patterns. Terrifying person. Thank you.",
	"gift_reactions": {
		"loved": "Ha! Now THAT'S useful. Old habits are pleased.",
		"liked": "Delve salvage. Takes me back. Mostly to bad places, but fondly.",
		"disliked": "I have EXACTLY one sweet tooth and it's retired too.",
	},
	"heart_events": {
		"l3": {
			"id": "the_tell",
			"lines": [
				"Garrick, at the Delve door, watching you check your gear. \"You checked your food before your blade. That's the tell of someone who plans to come BACK. I never had it. Checked the blade first, every time.\"",
			],
			"choice_a": "\"You came back anyway.\"",
			"choice_b": "\"Blade first sounds cooler.\"",
			"response_a": "\"Limped back. Semantics. ...Keep checking food first, farmer.\"",
			"response_b": "\"'Cooler.' Aye. Cool as a condolence letter. Alden signs those, ask him.\"",
		},
		"l7": {
			"id": "the_broken_sword",
			"lines": [
				"Saloon, late. He sets a wrapped bundle on the table: two halves of a beautiful blade. \"Sten's masterwork, before the one he never finished. I told the whole town it failed ME. Truth is I blocked a slam I was told never to block. Steel did everything right. I didn't.\"",
			],
			"choice_a": "\"Twenty years is long enough. Tell HIM that.\"",
			"choice_b": "\"Why keep a broken sword?\"",
			"response_a": "\"...Pour me one first, then. Tomorrow. Early. Before my nerve retires again.\" (unlocks CLOSE line about the reconciliation)",
			"response_b": "\"Same reason the town keeps a broken adventurer. Somebody might need the reminder. Night, farmer.\"",
		},
	},
	## Level perks (bible/characters.md): L5 gift: 2 goblin fang; L8 gift:
	## "old shield technique" dialog → one-time +10 max HP flag. See
	## marta.gd's "perks" doc for the shape npc.gd consumes.
	"perks": {
		"l5": {
			"line": "Two goblin fangs. Delve salvage. Don't ask how old.",
			"items": {"goblin_fang": 2},
			"gold": 0,
		},
		"l8": {
			"line": "The old shield technique. Watch the shoulders, brace like this — there. You'll carry it now.",
			"items": {},
			"gold": 0,
			"max_hp": 10,
		},
	},
}
