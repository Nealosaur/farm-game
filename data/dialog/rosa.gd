class_name RosaDialog
extends RefCounted
## Rosa — Saloon keeper, festival organizer. All strings VERBATIM from
## docs/design/characters.md (typos and all — they're voice). Do not
## paraphrase; if a line needs to change, change characters.md first.
##
## Shape consumed by DialogResolver.pick() — see data/dialog/marta.gd's
## header comment for the full documented shape.

const DATA := {
	"tier_pools": {
		"STRANGER": [
			"Welcome to The Ember! First smile's free.",
			"New face! Sit, sit. Standing people make the room nervous.",
			"We pour cider and opinions. Both strong.",
			"Hearthstead's heir! The plaza's been WAITING for you.",
		],
		"ACQUAINT": [
			"The usual? You don't have a usual yet. Let's fix that.",
			"Alden says festivals are 'expenditures.' I say they're the point.",
			"I've seen you hauling turnips. Farmers who wave get discounts. Wave more.",
			"Finn was in here doing impressions of you fighting slimes. It was AFFECTIONATE.",
		],
		"FRIEND": [
			"There you are! The room's better with you in it.",
			"When the plaza's full, this town remembers itself. That's my whole religion.",
			"Sten smiled in here Tuesday. Wrote the date down.",
			"You fight, you farm, you still come by. You're my favorite kind of tired.",
		],
		"CLOSE": [
			"I planned four festivals the year everyone said this town was done. Spite is a renewable resource, love.",
			"My mother ran The Ember. Her rule: no one drinks alone, no one leaves sad. I've only ever broken it for myself.",
			"You're on festival crew for life now. No, you can't resign.",
		],
		"KINDRED": [
			"The Ember's yours as much as mine. You just don't do dishes.",
			"Town's alive again. Everyone says it's the festivals. It's not, love. It's that people watched YOU try.",
		],
	},
	"seasonal": [
		{"season": 1, "min_level": 0, "line": "Sunfire's coming! I can smell the bonfire already. That might be the kitchen."},
	],
	"rain": [
		"Rain! Saloon weather. The till loves a good storm.",
	],
	"festival": [],
	"birthday_reaction": "For ME? The organizer never gets organized FOR. You've broken something in me, love. Happily.",
	"gift_reactions": {
		"loved": "LOVE. LOVE! Kitchen, now, we're celebrating.",
		"liked": "Into the pot it goes. You'll taste it Friday.",
		"disliked": "...I'm going to smile through this one, love.",
	},
	"heart_events": {
		"l3": {
			"id": "empty_chairs",
			"lines": [
				"Before opening, Rosa is arranging plaza chairs for a festival, half of them empty last year. \"Some years I set forty and fill twelve. Alden thinks I don't count. I count every chair, love.\"",
			],
			"choice_a": "\"Set forty-one. I'm coming.\"",
			"choice_b": "\"Maybe set twelve then.\"",
			"response_a": "\"One yes at a time. That's how mother filled rooms. FORTY-ONE it is.\"",
			"response_b": "\"...Twelve. Sure. Efficient.\" (she sets forty anyway, quieter)",
		},
		"l7": {
			"id": "mothers_rule",
			"lines": [
				"Late. Rosa alone, one glass, lights low. \"'No one leaves sad.' Mother's rule. She died in the spring, the plaza was full for her, and I poured for two hundred people and went home to none.\"",
			],
			"choice_a": "Sit down and stay a while.",
			"choice_b": "\"You're the happiest person I know.\"",
			"response_a": "(no dialog choice text; the scene simply holds a beat) \"...Thanks, love. Rule holds. Even for me, turns out.\"",
			"response_b": "\"That's the till talking, love. Good night.\"",
		},
	},
	## Level perks (bible/characters.md): L5 gift: 2 melon seeds; L8 gift:
	## "The Ember's own" recipe dialog + 250g. See marta.gd's "perks" doc for
	## the shape npc.gd consumes.
	"perks": {
		"l5": {
			"line": "Two melon seeds. Grow something worth celebrating, love.",
			"items": {"melon_seeds": 2},
			"gold": 0,
		},
		"l8": {
			"line": "The Ember's own recipe. Mother's, really. Don't tell the whole town.",
			"items": {},
			"gold": 250,
		},
	},
}
