class_name BramDialog
extends RefCounted
## Doc Bram — Clinic doctor. All strings VERBATIM from
## docs/design/characters.md (typos and all — they're voice). Do not
## paraphrase; if a line needs to change, change characters.md first.
##
## Shape consumed by DialogResolver.pick() — see data/dialog/marta.gd's
## header comment for the full documented shape.

const DATA := {
	"tier_pools": {
		"STRANGER": [
			"Clinic's open. Try not to need it.",
			"You're the one going into the Delve? I'll prep a bed.",
			"Sleep. Water. Vegetables. That's the whole lecture.",
			"Hm, farmer's hands already. Blisters heal, keep working.",
		],
		"ACQUAINT": [
			"Your color's better than last month. Marginally.",
			"I've stitched three goblin bites this season. Bring me a boring week.",
			"The city had better equipment. Worse patients. Don't quote me.",
			"Eat the carrots you grow. Doctor's orders, literally.",
		],
		"FRIEND": [
			"You're my healthiest patient. That's a low bar. Still.",
			"Rosa keeps sending soup for 'my patients.' I AM eating it myself, yes.",
			"I don't miss the city. I miss thinking I was important. Different things.",
			"Show me the arm. ...The OTHER arm. You didn't even notice this one?",
		],
		"CLOSE": [
			"I keep a chart on you. Professional habit. It's mostly worry now.",
			"You know why I left the city? Someday I'll tell you. Not today. The light's wrong.",
			"If the Delve takes you, I want it noted I objected.",
		],
		"KINDRED": [
			"I told you why I left, once. You're the only one here who knows. Keep being careful with it.",
			"Healthiest person in Emberhollow. Official chart. Don't let it go to your head.",
		],
	},
	"seasonal": [
		{"season": 3, "min_level": 4, "line": "Frostcap season. Nature's apology for winter."},
	],
	"rain": [
		"Rain means slip injuries. Walk like you have a spare ankle. You don't.",
	],
	"festival": [],
	"birthday_reaction": "A birthday acknowledged. How clinical of you. ...Thank you.",
	"gift_reactions": {
		"loved": "Ah — actual nutrition. You listen.",
		"liked": "This will do you more good than me. Take half back. ...No? Fine.",
		"disliked": "Why.",
	},
	"heart_events": {
		"l3": {
			"id": "quiet_hours",
			"lines": [
				"The clinic is empty. Bram is staring at a framed city medical license. \"Busiest surgeon on my floor, once. Now I lance boils and lecture about vegetables. Some days that feels like falling.\"",
			],
			"choice_a": "\"Feels like landing, to me.\"",
			"choice_b": "\"So go back.\"",
			"response_a": "\"...Huh. Landing. I'll try that word for a while.\"",
			"response_b": "\"Yes. Well. Appointment's over.\"",
		},
		"l7": {
			"id": "the_reason",
			"lines": [
				"Dusk. Bram, unprompted: \"I lost one on the table. My error. Everyone said the numbers forgave me. Numbers do that. I didn't. So I came here, where the stakes are boils and birthdays.\"",
			],
			"choice_a": "\"The stakes here are people. Same as there.\"",
			"choice_b": "\"Everyone makes mistakes, forget it.\"",
			"response_a": "quiet. \"...That is the first true thing anyone's said to me in six years.\"",
			"response_b": "\"'Forget it.' The city said that too. Good evening.\"",
		},
	},
	## Level perks (bible/characters.md): L5 gift: 2 frostcap; L8 gift:
	## "house call" +20 max HP permanent (one-time, GameState.max_hp += 20
	## with the perks_given flag as the "one-time" guard — see marta.gd's
	## "perks" doc for the shape npc.gd consumes).
	"perks": {
		"l5": {
			"line": "Two frostcap. Eat them before the Delve, not after.",
			"items": {"frostcap": 2},
			"gold": 0,
		},
		"l8": {
			"line": "A house call, on me. You'll feel it — I've adjusted your chart permanently.",
			"items": {},
			"gold": 0,
			"max_hp": 20,
		},
	},
}
