class_name RosaDialog
extends RefCounted
## Rosa — Saloon keeper, festival organizer. All strings VERBATIM from
## docs/design/characters.md (typos and all — they're voice). Do not
## paraphrase; if a line needs to change, change characters.md first.
##
## Shape consumed by DialogResolver.pick() — see data/dialog/marta.gd's
## header comment for the full documented shape.
##
## Marriage M2: heart_events.l8/l10, dating_lines, and fourteen_heart below
## are the AUTHORED VERBATIM romance content from docs/design/romance-dialog.md
## (M1 shipped placeholder-but-real text for Rosa as the pilot; this replaces
## it character-for-character). "fourteen_heart" is data-only in M2 — the
## capstone scene text lives here so M3 (spouse-on-farm) can wire the actual
## L14/spouse trigger; see romance_events.gd's fourteen_heart_line() and
## data/events/spouse_capstone.gd for the generic parametric scene M2 built
## as the ready-to-trigger consumer of this data.

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
		"l8": {
			"id": "the_extra_chair",
			"lines": [
				"Rosa's closing up, one chair still out.",
				"\"Mother's rule was 'no one leaves sad.' I kept it for everyone but the one pouring. Then you started staying past last call. ...I stopped counting the chairs, love. I only count one now.\"",
			],
			"choice_a": "\"Then I'll be the one who stays.\"",
			"choice_b": "\"You're just tired, Rosa.\"",
			"response_a": "\"...Say it again slower so I can keep it. You'll be the one who stays. Yeah. Yeah, you will.\"",
			"response_b": "\"Tired. Sure. That's the word we're using.\" (she sets the chair back, quieter)",
		},
		"l10": {
			"id": "pouring_for_two",
			"lines": [
				"The Ember's dark, two glasses, both full.",
				"\"I've filled this room for two hundred and gone home to none, and I told myself that was the trade. It isn't. I don't want the whole room anymore. I want the one who does the dishes he keeps promising to do.\"",
			],
			"choice_a": "\"Marry me into the dish rotation, then.\"",
			"choice_b": "\"The room needs you more than I do.\"",
			"response_a": "\"Is that— ROSA don't cry, you run this place— ...ask me properly with something shiny and I'll pour us the good bottle. The one I've been saving for no reason. THIS reason.\"",
			"response_b": "\"...Course it does. Course. Good night, love. Lock the latch on your way.\"",
		},
	},
	"fourteen_heart": {
		"id": "the_quiet_ember",
		"lines": [
			"Farm porch, dawn, Rosa with two mugs.",
			"\"First morning in my life I woke up and didn't have to open a room for anyone. Just this one. Just us. Turns out I do know how to leave a room happy, love. I just had to build it out here with you.\"",
		],
	},
	## Marriage M2 (bible §6): dating-flavored lines, checked when
	## Romance.is_dating("rosa") is true, above the ordinary tier pool but
	## below any special-occasion line (birthday/festival/rain/seasonal) —
	## see dialog_resolver.gd's precedence doc. Verbatim from
	## docs/design/romance-dialog.md's DATING pool.
	"dating_lines": [
		"You walked in and the room did that thing again. The better thing. That's you, love, that's just what you do.",
		"I set your chair by the window. Don't argue. It's yours now.",
		"Forty-one chairs, and I finally know whose the extra one is.",
	],
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
