class_name WillowDialog
extends RefCounted
## Willow — Riverwoods herbalist. All strings VERBATIM from
## docs/design/characters.md (typos and all — they're voice). Do not
## paraphrase; if a line needs to change, change characters.md first.
##
## Craft Stride 3 (Taming): the CLOSE pool's "You kept one..." line only
## actually surfaces once world["taming"].barn is non-empty (a tamed slime
## living in the farm's pen) — npc.gd's _gated_dialog_data() filters it OUT
## of the pool dynamically until then (see its _BARN_GATED_LINES table).
## Lives here in the ordinary pool (not a separate list) so this file stays
## pure data, same convention as Garrick/Sten's "The Bench" gated lines.
##
## Shape consumed by DialogResolver.pick() — see data/dialog/marta.gd's
## header comment for the full documented shape.

const DATA := {
	"tier_pools": {
		"STRANGER": [
			"...Oh. A person. Hello, person.",
			"The river's high today. It's showing off.",
			"You may pick the berries. Ask the bush first. It can't answer. Ask anyway.",
			"The farm woke up. The woods mentioned it.",
		],
		"ACQUAINT": [
			"You walk quieter than you used to. The forest appreciates it.",
			"Wisps aren't angry, you know. They're LOST. There's a difference.",
			"I trade Doc herbs for silence. Both of us overpay happily.",
			"Rain is the forest drinking. It's rude to interrupt. We can talk after.",
		],
		"FRIEND": [
			"I saved the sunny clearing for you. I mean — it was already there. But I THOUGHT of you.",
			"The Delve wasn't always sour. The roots remember a door that sang. Roots exaggerate. ...Some.",
			"You fight the forest's lost things gently. I checked. That's why we're friends.",
			"Emberberries. Second-best thing in the woods. I won't say the first, it gets vain.",
		],
		"CLOSE": [
			"I came here after the city, like Doc. His wound has a name. Mine is just... crowds. The trees never ask me to be loud.",
			"I marked your fence line in forest-sign. It means 'kin of this ground.' The deer will still eat your lettuce. It's not magic. It's manners.",
			"Take frostcap into the Delve in winter. The dark respects what grows in cold.",
			"You kept one. The woods sorted you into \"safe\" years ago. Now the slimes have too.",
		],
		"KINDRED": [
			"The woods count you as weather now. Reliable. Returning. That's their highest rank. Mine too.",
			"When the wisps calm someday — and they will, near you — come find me first.",
		],
	},
	"seasonal": [
		{"season": 3, "min_level": 0, "line": "Frostcap under the snow line. The forest keeps a pantry. It shares with the polite."},
	],
	"rain": [
		"Shhh. ...Sorry. It's drinking. Isn't it lovely.",
	],
	"festival": [],
	"birthday_reaction": "The forest didn't tell you. So a PERSON remembered. ...I'm keeping this feeling.",
	"gift_reactions": {
		"loved": "From the ground, given with hands. That's the whole ceremony. Thank you.",
		"liked": "Mm. The woods approve. I concur.",
		"disliked": "I'll bury it respectfully.",
	},
	"heart_events": {
		"l3": {
			"id": "the_listening",
			"lines": [
				"Willow presses your hand flat to a mossy trunk. \"Wait. ...There. Sap-rise. Most people can't wait long enough to feel it. Most people are a bit broken that way.\"",
			],
			"choice_a": "Wait, and say nothing.",
			"choice_b": "\"I don't feel anything.\"",
			"response_a": "she smiles fully for the first time. \"You heard it. Now you can't unhear it. Congratulations. Condolences.\"",
			"response_b": "\"You didn't WAIT. ...It's fine. Not everyone waits.\"",
		},
		"l7": {
			"id": "why_the_woods",
			"lines": [
				"Her hut, tea, rain outside. \"The city had a market street. Ten thousand voices. I stood in it one morning and couldn't find mine anywhere in the noise. So I moved somewhere quiet enough to hear it again. It took two years. It sounds like this. This exact volume.\"",
			],
			"choice_a": "(match her volume) \"It's a good voice.\"",
			"choice_b": "\"You'd get used to the noise again.\"",
			"response_a": "\"...The forest said you'd say that. The forest is very smug about you.\"",
			"response_b": "\"That's what losing your voice FEELS like, at first. More tea?\"",
		},
	},
	## Level perks (bible/characters.md): L5 gift: 2 wildroot + 1 emberberry;
	## L8 gift: "forest-mark" dialog + 200g worth of forage bundle (shipped
	## as flat gold — no itemized "bundle" contents are specified). See
	## marta.gd's "perks" doc for the shape npc.gd consumes.
	"perks": {
		"l5": {
			"line": "The forest sent these along. Well — I picked them. The forest just approved.",
			"items": {"wildroot": 2, "emberberry": 1},
			"gold": 0,
		},
		"l8": {
			"line": "A forest-mark, just for you. And a bundle from the good clearings. The forest agrees, for once loudly.",
			"items": {},
			"gold": 200,
		},
	},
}
