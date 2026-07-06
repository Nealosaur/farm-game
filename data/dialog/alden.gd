class_name AldenDialog
extends RefCounted
## Mayor Alden — Mayor, opens the game. All strings VERBATIM from
## docs/design/characters.md (typos and all — they're voice). Do not
## paraphrase; if a line needs to change, change characters.md first.
##
## World Stride D adds the "intro" block below: Alden's Day-1 farm-intro
## lines (verbatim, characters.md's INTRO block) plus his New Roots hand-in
## line, both consumed by npc.gd's day-1/quest-hook methods, NOT by
## DialogResolver.pick() (pick() only ever resolves the ordinary ambient-
## talk line; intro/hand-in are their own dedicated flows).
##
## Shape consumed by DialogResolver.pick() — see data/dialog/marta.gd's
## header comment for the full documented shape.

const DATA := {
	"intro": {
		"lines": [
			"Ah — you made it. Welcome to Hearthstead. Your grandmother worked this soil forty years; the town ate from it for most of them.",
			"I'll be plain: Emberhollow is fading. Shops quiet, plaza empty, and something old has soured in the Delve east of here.",
			"But a lit window on this farm is the best news we've had in years. Meet the town — all eight of us worth meeting, I'm afraid I'm counted. Come find me after. There's a fund.",
		],
	},
	"new_roots_hand_in": "The town fund thanks you. Marta insisted on the seeds.",
	"tier_pools": {
		"STRANGER": [
			"Good day. The notice board is current — I see to it personally.",
			"Eight residents, four festivals, one mayor. Modest, but accounted for.",
			"Your grandmother once out-argued me at a Harvest Fair. Twice.",
			"Mind the Delve, please. I sign the condolence letters.",
		],
		"ACQUAINT": [
			"The plaza had markets every week, once. I remember the noise. Good noise.",
			"Rosa calls my budgeting 'a war on joy.' I fund her festivals anyway. Don't tell her.",
			"Crops from Hearthstead in Marta's window again. People notice, you know.",
			"Paperwork, dear neighbor, is how a small town says 'we intend to still exist.'",
		],
		"FRIEND": [
			"I walk the plaza each noon so it's never truly empty. Between us, it's the best part of my day.",
			"You've met everyone now. You know what I know: this town is eight good reasons.",
			"Garrick and Sten — that feud predates my office. Even mayors don't touch it.",
			"The condolence drawer has been shut all season. I credit you.",
		],
		"CLOSE": [
			"Thirty years in office. My great act may be having handed you a quest list.",
			"I drafted my resignation the winter before you came. It's still in the drawer. It can stay there.",
			"When the Fair judging comes, I am RUTHLESSLY impartial. ...Grow something orange anyway.",
		],
		"KINDRED": [
			"I've started calling it 'the year things turned' in the town ledger. You know which year.",
			"If Emberhollow has a future worth the name, it walked in off that farm.",
		],
	},
	"seasonal": [
		{"season": 0, "min_level": 0, "line": "Sowing Festival on the 14th. Attendance is not mandatory. Attendance is deeply hoped for."},
	],
	"rain": [
		"Rain on the ledger means rain in the fields means a good column of numbers. Lovely.",
	],
	"festival": [],
	"birthday_reaction": "Well. The office rarely receives, only disburses. Thank you, truly.",
	"gift_reactions": {
		"loved": "A turnip. You absolute historian. Thank you.",
		"liked": "For the town table. Which is my table, but the sentiment scales.",
		"disliked": "I'll log this as... miscellaneous.",
	},
	"heart_events": {
		"l3": {
			"id": "the_ledger",
			"lines": [
				"Alden at the notice board with the town ledger. \"Population column. Forty-one, then thirty, then twelve, then eight. I keep neat books of a quiet decline. That is most of mayoring, it turns out.\"",
			],
			"choice_a": "\"Add a line: fields at Hearthstead, replanted.\"",
			"choice_b": "\"Numbers are numbers.\"",
			"response_a": "he actually writes it. \"...Unorthodox bookkeeping. I'll allow it.\"",
			"response_b": "\"Quite. Neatness endures. Good day.\"",
		},
		"l7": {
			"id": "the_drawer",
			"lines": [
				"His porch, evening. He shows you a yellowed envelope. \"My resignation. Drafted the winter the clinic nearly closed. I keep it to remember I chose to stay. Everyone here chose to stay, you know. Even you.\"",
			],
			"choice_a": "\"Especially me.\"",
			"choice_b": "\"Maybe it's time to retire anyway.\"",
			"response_a": "\"Then the drawer keeps its letter, and I keep my town. A fine trade.\"",
			"response_b": "\"...Perhaps. The drawer will outlast the dream, at this rate. Good evening.\"",
		},
	},
	## Level perks (bible/characters.md): L5 gift: 100g "town gratitude
	## fund"; L8 gift: deed dialog + plaza key line (flavor only — no
	## concrete item/gold named beyond the L5 fund). See marta.gd's "perks"
	## doc for the shape npc.gd consumes.
	"perks": {
		"l5": {
			"line": "A disbursement from the town gratitude fund. Long overdue.",
			"items": {},
			"gold": 100,
		},
		"l8": {
			"line": "A key to the plaza gates, and the deed's footnote with your name added. Small formalities. They matter anyway.",
			"items": {},
			"gold": 0,
		},
	},
}
