class_name FinnDialog
extends RefCounted
## Finn — Beach kid (teen), dreamer. All strings VERBATIM from
## docs/design/characters.md (typos and all — they're voice). Do not
## paraphrase; if a line needs to change, change characters.md first.
##
## Shape consumed by DialogResolver.pick() — see data/dialog/marta.gd's
## header comment for the full documented shape.

const DATA := {
	"tier_pools": {
		"STRANGER": [
			"You're the farmer who FIGHTS?! Okay okay okay act normal.",
			"I've seen the whole Delve. From outside. The door part.",
			"Shells for sale! Not really. But LOOK at this one.",
			"Bet you can't hit that post from here. Bet you CAN though, actually.",
		],
		"ACQUAINT": [
			"Garrick says the Delve's floor two has wisps. Describe them. Slowly.",
			"I'm not scared of the water, the water's scared of— okay a wave got me earlier, don't tell Rosa.",
			"When I'm your age I'm gonna have a sword AND a boat.",
			"Doc says I have 'energy.' He says it like a diagnosis.",
		],
		"FRIEND": [
			"You're basically my hero, but don't let it change how you act around me. Be exactly this cool.",
			"I mapped the beach. All of it. Took an hour. The SEA though — the sea's gonna take WEEKS.",
			"Tell me the slime king part again. The SLAM part.",
			"I put a shell on your fence post. It's a signal. It means 'hi.'",
		],
		"CLOSE": [
			"Dad's boat is still in the shed. Nobody says that out loud around here, so, now you know why the pier and me.",
			"If you ever go down past floor three — take me. Not INTO it. Just... to the door. Deal?",
			"You're the only one who answers my questions like they're real questions.",
		],
		"KINDRED": [
			"Okay so long-term plan: you farm, I sail, Emberhollow gets famous. I've told no one else the plan. Guard it.",
			"Best friend. That's just — that's just what the role's called. Deal with it.",
		],
	},
	"seasonal": [
		{"season": 1, "min_level": 0, "line": "Sunfire festival! Bonfire! Rosa lets me stack the wood if I stop 'improving' the stack!"},
	],
	"rain": [
		"Pier's slippery. Which makes it BETTER, but Doc made me promise.",
	],
	"festival": [],
	"birthday_reaction": "You KNOW my birthday? This is the best day of my ENTIRE— okay top five. TOP FIVE.",
	"gift_reactions": {
		"loved": "SLIME! You get me. You completely get me.",
		"liked": "Ooh, for the collection. The collection is a bucket.",
		"disliked": "...I'll trade it to Marta for something with bounce.",
	},
	"heart_events": {
		"l3": {
			"id": "the_map_of_everything",
			"lines": [
				"Finn unrolls a hand-drawn map: the beach in obsessive detail, the sea a huge blank with 'EVERYTHING ELSE' written across it. \"Everyone laughs at the blank part. The blank part's the POINT.\"",
			],
			"choice_a": "\"Blank means yours.\"",
			"choice_b": "\"You should fill in what's real first.\"",
			"response_a": "\"...yeah. YEAH. 'Blank means yours.' I'm writing that ON it.\"",
			"response_b": "\"That's what EVERYONE— whatever. Tide's changing.\"",
		},
		"l7": {
			"id": "the_shed",
			"lines": [
				"Finn, quiet for once, outside a locked boat shed. \"Dad's boat. Three years. Mom won't sell it, won't open it. I tell everyone I fish so I have a reason to be near it. That's the whole secret. That's all of it.\"",
			],
			"choice_a": "\"When you're ready, I'll help you open it.\"",
			"choice_b": "\"It's just a boat, Finn.\"",
			"response_a": "\"...not today. But that's the first plan for it I've ever liked.\"",
			"response_b": "\"Right. Just a boat. Tide's going out, you should too.\"",
		},
	},
	## Level perks (bible/characters.md): L5 gift: 3 tideshell; L8 gift:
	## "lucky lure" trinket dialog + 150g. See marta.gd's "perks" doc for the
	## shape npc.gd consumes.
	"perks": {
		"l5": {
			"line": "Three tideshells! The good ones. I've been SAVING these.",
			"items": {"tideshell": 3},
			"gold": 0,
		},
		"l8": {
			"line": "My lucky lure. Don't lose it. Actually — you won't. That's why it's yours now.",
			"items": {},
			"gold": 150,
		},
	},
}
