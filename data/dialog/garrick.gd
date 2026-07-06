class_name GarrickDialog
extends RefCounted
## Garrick — Retired adventurer, quest-giver. All strings VERBATIM from
## docs/design/characters.md (typos and all — they're voice). Do not
## paraphrase; if a line needs to change, change characters.md first.
##
## EXCLUDED by contract: characters.md's "QUESTS" block (Q2 "Prove It", Q3
## "The King Below") — that's World Stride D scope (quests aren't
## implemented yet). Only the ordinary tier-pool/seasonal/rain/birthday/gift/
## heart-event data below ships this stride.
##
## Shape consumed by DialogResolver.pick() — see data/dialog/marta.gd's
## header comment for the full documented shape.

const DATA := {
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
}
