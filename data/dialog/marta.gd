class_name MartaDialog
extends RefCounted
## Marta — General Store keeper. All strings VERBATIM from
## docs/design/characters.md (typos and all — they're voice). Do not
## paraphrase; if a line needs to change, change characters.md first.
##
## Shape consumed by DialogResolver.pick() (scripts/npcs/dialog_resolver.gd):
##   {
##     "tier_pools": { tier_name: [String, ...] },
##     "seasonal": [ {"season": int, "min_level": int, "line": String}, ... ],
##     "rain": [String, ...],
##     "festival": [String, ...],           # optional; falls back to tier pool if empty
##     "birthday_reaction": String,
##     "gift_reactions": {"loved": String, "liked": String, "disliked": String},
##     "heart_events": {
##       "l3": {"id": String, "lines": [String], "choice_a": String, "choice_b": String,
##              "response_a": String, "response_b": String},
##       "l7": { ... same shape ... },
##     },
##   }
## `season` in `seasonal` entries is a Clock.season() index (0 Spring..3
## Winter) or -1 for "any season". `min_level` gates the line to a tier (per
## characters.md's "(Spring/FRIEND+)" / "(Winter/any)" annotations) — the
## resolver only offers a seasonal line when the NPC's current level meets it.

const DATA := {
	"tier_pools": {
		"STRANGER": [
			"Welcome to the store. Prices are on the shelf, dear.",
			"You're the Hearthstead one? Hm. Your grandmother kept better hours.",
			"Coin first, questions after. Store policy.",
			"Mind the floor, I just swept.",
		],
		"ACQUAINT": [
			"Back again! I'll start a tab. I won't honor it, but I'll start one.",
			"Turnips are moving well. Folk are hungrier lately.",
			"The Delve's got the whole town spooked, you know.",
			"You look like you slept in a field. ...You did, didn't you.",
		],
		"FRIEND": [
			"I saved the good seed packets back for you. Don't tell Alden.",
			"Tomas used to say a store's just a pantry with manners.",
			"You're half the gossip in this town now. The good half, mostly.",
			"Eat something before you go back down that hole. Promise me.",
		],
		"CLOSE": [
			"I reopened Tomas's price book last night. First time in years. Your fault, somehow.",
			"This counter's seen three mayors and one of you. You're the interesting one.",
			"If you ever don't come back from that Delve, I'm raising your prices posthumously.",
		],
		"KINDRED": [
			"Family discount. Don't argue, it's already rung up.",
			"Hearthstead and this store — town runs on the pair of us, dear.",
		],
	},
	"seasonal": [
		{"season": 0, "min_level": 4, "line": "Planting weather. Tomas proposed to me in planting weather."},
		{"season": 3, "min_level": 0, "line": "Cold keeps the shelves full and the door shut. Sit a minute."},
	],
	"rain": [
		"Rain's good for exactly two things: crops and my ledger.",
	],
	"festival": [],
	"birthday_reaction": "You remembered?! Even Tomas forgot twice.",
	"gift_reactions": {
		"loved": "Oh, my favorite! You clever thing.",
		"liked": "That'll do nicely, thank you.",
		"disliked": "I... will find a use. Outdoors.",
	},
	"heart_events": {
		"l3": {
			"id": "the_price_book",
			"lines": [
				"Marta is wiping the counter, an old ledger open. \"Tomas priced everything in this town by hand. Even the things nobody bought. 'Someone might need it someday,' he'd say.\" She closes it. \"Silly to keep it. Prices change.\"",
			],
			"choice_a": "\"Read me one page?\"",
			"choice_b": "\"Yeah, old prices are useless.\"",
			"response_a": "she laughs, reads an entry for 'moonlight, per jar — free'. \"...He was ridiculous. Thank you.\"",
			"response_b": "\"...Right. Business as usual, then.\"",
		},
		"l7": {
			"id": "restock",
			"lines": [
				"She's up a ladder, restocking the top shelf. \"Tomas's shelf. I've left it empty for six years. Time it earned its keep.\" She hands you the first item down: a seed packet marked in faded ink.",
			],
			"choice_a": "\"He'd like what you've done with the place.\"",
			"choice_b": "\"Finally, more inventory.\"",
			"response_a": "\"He'd like YOU, which is worse. Take the packet. Grow something loud.\"",
			"response_b": "\"...Yes. Inventory. That's all it was.\"",
		},
	},
}
