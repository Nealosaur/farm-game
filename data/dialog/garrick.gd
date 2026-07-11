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
##
## Marriage M2: heart_events.l8/l10, dating_lines, and fourteen_heart below
## are AUTHORED VERBATIM romance content from docs/design/romance-dialog.md —
## see rosa.gd's identical class-doc note for the full convention (data-only
## fourteen_heart; M3 wires the trigger).

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
		"l8": {
			"id": "the_tell_again",
			"lines": [
				"Garrick at the Delve door, watching you gear up.",
				"\"You check your food before your blade now. I taught you that — 'the tell of someone who plans to come back.' What I didn't say: somewhere along the way, the thing I started planning to come back TO stopped being the surface. Started being a person standing on it. This person. Now.\"",
			],
			"choice_a": "\"Then come back to me. Every time.\"",
			"choice_b": "\"You come back for the town, Garrick.\"",
			"response_a": "\"...Twenty years I came back to an empty room and called it freedom. Freedom's overrated next to a lit window. I'll come back to you, farmer. That's a vow from a man who doesn't make them.\"",
			"response_b": "\"Aye. The town. Sure. ...Mind the goblin wind-up down there. Tell's in the shoulders.\"",
		},
		"l10": {
			"id": "a_friend_above_the_floors",
			"lines": [
				"Saloon, late, Garrick sets down the two halves of his old broken sword — mended now, welded whole.",
				"\"Sten fixed it. Said a thing kept for the reminder can also be kept for the mending. Twenty years I carried a broken blade to remember what I lost. I'd rather carry something that means what I found. That's you. I'm too old and too scarred to say it prettier: I love you, and I'd like to stop adventuring toward anything but here.\"",
			],
			"choice_a": "\"Then stop here. With me.\"",
			"choice_b": "\"You'd get restless, old man.\"",
			"response_a": "\"...Bring me something that means it and I'll hang up the wandering for good. Never wanted a floor deeper than the one you're standing on.\"",
			"response_b": "\"Maybe. Maybe the knee finally wins. ...Night, farmer. Eat before you're hungry.\"",
		},
	},
	"fourteen_heart": {
		"id": "the_lit_window",
		"lines": [
			"Farm, night, Garrick on the porch looking back at the house.",
			"\"Used to navigate by the Delve entrance. Now I navigate by that window being lit. Simpler map. Better one. Sten and I are talking again, the King's dead, and I married a farmer who checks her food before her blade. Old adventurer's supposed to die with his boots on. I'd rather wear out slow, right here, boots off, with you. That's the best ending I never went looking for.\"",
		],
	},
	## Marriage M2 (bible §6): dating-flavored lines, checked when
	## Romance.is_dating("garrick") is true — see rosa.gd's identical doc for
	## the resolver precedence. Verbatim from docs/design/romance-dialog.md's
	## DATING pool.
	"dating_lines": [
		"First rule of deep floors: come back to something. Never had a something. ...Have one now. Ruins the whole grim-adventurer bit. Worth it.",
		"Checked my food before my blade this morning. You did that to me. Man who plans to come back. To you.",
		"Adventurer's toast: to floors below and a friend above. You're the friend. Also the above. Also, apparently, the toast.",
	],
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
