class_name AldenDialog
extends RefCounted
## Mayor Alden — Mayor, opens the game. All strings VERBATIM from
## docs/design/characters.md (typos and all — they're voice). Do not
## paraphrase; if a line needs to change, change characters.md first.
##
## EXCLUDED by contract: characters.md's "INTRO (Day 1, on the farm,
## one-time — quest grant 'New Roots')" block — that's World Stride D scope
## (quests aren't implemented yet). Only the ordinary tier-pool/seasonal/
## rain/birthday/gift/heart-event data below ships this stride.
##
## Shape consumed by DialogResolver.pick() — see data/dialog/marta.gd's
## header comment for the full documented shape.

const DATA := {
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
}
