class_name StenDialog
extends RefCounted
## Sten — Blacksmith. All strings VERBATIM from docs/design/characters.md
## (typos and all — they're voice). Do not paraphrase; if a line needs to
## change, change characters.md first.
##
## Shape consumed by DialogResolver.pick() — see data/dialog/marta.gd's
## header comment for the full documented shape.

const DATA := {
	"tier_pools": {
		"STRANGER": [
			"Forge is hot. Stand back.",
			"Need something hammered, or just standing there?",
			"Hm.",
			"The Delve chews up cheap steel. Remember that.",
		],
		"ACQUAINT": [
			"Your sword's holding an edge. Barely.",
			"Iron sword at Marta's. My work. Overpriced. Worth it.",
			"Goblin fang. Good carbon in it. Odd, that.",
			"You swing like a farmer. ...That's not an insult. Farmers work.",
		],
		"FRIEND": [
			"Brought the forge up early. Had a feeling you'd come by.",
			"Anyone can make sharp. Making TOUGH, that's the trade.",
			"The old adventurer, Garrick — we don't talk. Ask him why.",
			"Show me your blade. ...Fine. FINE work is different from fine.",
		],
		"CLOSE": [
			"Started something on the back bench. Not for sale. Maybe for you, someday, if you stop dying.",
			"My father shod horses here. His father too. I make swords for a farmer. World's strange.",
			"You're the only one who doesn't flinch at the forge. Noticed that.",
		],
		"KINDRED": [
			"Bench is yours whenever. Just put the hammer back straight.",
			"Blades I've made that I trust: three. You carry one.",
		],
	},
	"seasonal": [
		{"season": 3, "min_level": 0, "line": "Forge season. Whole town finally understands my job."},
	],
	"rain": [
		"Rain rusts. Come in or go home.",
	],
	"festival": [],
	"birthday_reaction": "...How did you know that. WHO told you that.",
	"gift_reactions": {
		"loved": "Hm. Good material. Good eye.",
		"liked": "Usable.",
		"disliked": "No.",
	},
	"heart_events": {
		"l3": {
			"id": "the_rejected_blade",
			"lines": [
				"Sten pulls a sword from the scrap barrel — beautiful, but with a hairline crack. \"Made this at your age. Judges at the capital called it 'promising.' Promising means no.\"",
			],
			"choice_a": "\"The crack's only in the steel.\"",
			"choice_b": "\"So sell it cheap.\"",
			"response_a": "long pause. \"...Hm. That's either wise or stupid. I'll take it.\"",
			"response_b": "\"It's SCRAP.\" (he doesn't speak again today)",
		},
		"l7": {
			"id": "masterwork",
			"lines": [
				"The back bench is uncovered: an unfinished blade, folded steel, years of dust. \"Stopped the day the judges wrote back. Question is whether a thing half-made is a failure or just patient.\"",
			],
			"choice_a": "\"Patient. Like its maker.\"",
			"choice_b": "\"It's been dust for years. Let it go.\"",
			"response_a": "\"...Get out before I say something soft. Come back tomorrow. Bring fang steel.\"",
			"response_b": "\"Maybe. Forge's cold today.\"",
		},
	},
	## Level perks (bible/characters.md): L5 gift: 150g "scrap credit"; L8
	## gift: whetstone dialog + 300g. See marta.gd's "perks" doc for the
	## shape npc.gd consumes.
	"perks": {
		"l5": {
			"line": "Scrap credit. Don't spend it on anything soft.",
			"items": {},
			"gold": 150,
		},
		"l8": {
			"line": "A whetstone. Keep that edge yourself for once.",
			"items": {},
			"gold": 300,
		},
	},
}
