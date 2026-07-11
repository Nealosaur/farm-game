class_name StenDialog
extends RefCounted
## Sten — Blacksmith. All strings VERBATIM from docs/design/characters.md
## (typos and all — they're voice). Do not paraphrase; if a line needs to
## change, change characters.md first.
##
## Shape consumed by DialogResolver.pick() — see data/dialog/marta.gd's
## header comment for the full documented shape.
##
## Alive Stride 2: the CLOSE pool below carries ONE line ("Garrick's back at
## the bench...") that only actually surfaces once flag
## "garrick_sten_reconciled" is true — npc.gd's _gated_dialog_data() filters
## it OUT of the pool dynamically until then (see its class doc). It lives
## here, in the ordinary pool, rather than a separate gated-only list, so
## this file stays pure data and the completeness meta-test's "every NPC has
## 3+ lines per tier" style checks see it like any other line.
##
## Marriage M2: heart_events.l8/l10, dating_lines, and fourteen_heart below
## are AUTHORED VERBATIM romance content from docs/design/romance-dialog.md —
## see rosa.gd's identical class-doc note for the full convention (data-only
## fourteen_heart; M3 wires the trigger).

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
			"Garrick's back at the bench. Hands me things wrong. It's good.",
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
		"l8": {
			"id": "the_back_bench",
			"lines": [
				"Sten uncovers the back bench — not the masterwork, something small, half-made.",
				"\"Been shaping this between jobs. Not a blade. A ring band, if you must know. No stone yet. Told myself it was practice. Man doesn't practice a thing three hundred times unless he's hoping.\"",
			],
			"choice_a": "\"Hoping for what, Sten?\"",
			"choice_b": "\"It's just practice, then.\"",
			"response_a": "\"...Hm. For a hand it fits. Been avoiding saying whose. It's yours. There. Forge is hot, I said something soft, those two facts are related.\"",
			"response_b": "\"Aye. Practice. ...Cover it back up. Forge's cold today, turns out.\"",
		},
		"l10": {
			"id": "folded_steel",
			"lines": [
				"The band's finished, a small bright stone set in it.",
				"\"My father made swords for a town. His father, horses. I made blades for a farmer and thought that was the strange part. Wrong. The strange part is I fold steel for a living and the toughest thing I ever made is whatever's holding my chest together when you walk in. Take the band. It's not a gift. It's a question I'm too gruff to say straight.\"",
			],
			"choice_a": "\"Then I'll answer it — bring me something to say yes to.\"",
			"choice_b": "\"Keep it — it's your best work.\"",
			"response_a": "\"...Get out before I make more noise like a man with feelings. Bring the pendant. I'll be here. I'm always here. For you, that's the point, not the complaint.\"",
			"response_b": "\"My best work's meant to be carried. If you won't carry it... fine. Fine. Put the hammer back straight on your way.\"",
		},
	},
	"fourteen_heart": {
		"id": "the_warm_forge",
		"lines": [
			"Farm, evening, Sten with the coat-hook he made hung by your door.",
			"\"Whole life the forge was the warmest thing I owned. Isn't anymore. Don't repeat that in the saloon. Garrick already knows — hands me things wrong on purpose just to see me not mind. I don't mind anything, lately. Turns out tough was never the hard part. This is. Glad I made it.\"",
		],
	},
	## Marriage M2 (bible §6): dating-flavored lines, checked when
	## Romance.is_dating("sten") is true — see rosa.gd's identical doc for the
	## resolver precedence. Verbatim from docs/design/romance-dialog.md's
	## DATING pool.
	"dating_lines": [
		"Made you something. Don't look at it like that. It's just a hook by the door. For your coat. Which is here now. Often.",
		"Forge ran warm all day. Wasn't the coal.",
		"Hammer goes back straight. Coat goes there. You go... wherever you like. Preferably here.",
	],
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
