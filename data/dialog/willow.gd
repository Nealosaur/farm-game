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
##
## Marriage M2: heart_events.l8/l10, dating_lines, and fourteen_heart below
## are AUTHORED VERBATIM romance content from docs/design/romance-dialog.md —
## see rosa.gd's identical class-doc note for the full convention (data-only
## fourteen_heart; M3 wires the trigger).

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
		"l8": {
			"id": "kin_of_this_ground",
			"lines": [
				"Willow presses your hand to the old trunk, then keeps her hand over yours.",
				"\"I sorted you 'safe' a long time ago. That's the forest's highest rank. But there's a rank above it the trees don't have a word for, because trees don't get lonely. I do. I did. ...Less, lately. Because of a person. A specific one.\"",
			],
			"choice_a": "\"Say the specific one's name.\"",
			"choice_b": "\"The forest is enough company.\"",
			"response_a": "\"...You. The forest is unbearably smug. So am I, quietly. That's the loudest I get.\"",
			"response_b": "\"It was. It's rude to say 'was' out loud. ...The sap's still rising. We can talk after.\"",
		},
		"l10": {
			"id": "the_volume_of_a_voice",
			"lines": [
				"Her hut, rain, one cup between you.",
				"\"I moved somewhere quiet enough to hear my own voice again. It took two years. And now there's a second voice I'd move a whole forest to keep in earshot. I didn't plan for that. The woods don't plan. They just grow toward the light and call it choice.\"",
			],
			"choice_a": "\"Then grow toward me.\"",
			"choice_b": "\"You'd tire of the noise of me.\"",
			"response_a": "\"...I have been. For a season. Bring me something bright and permanent and I'll stop pretending it's the trees leaning, not me.\"",
			"response_b": "\"You're not noise. That's the whole point I just— ...more tea. We'll let the rain finish its sentence.\"",
		},
	},
	"fourteen_heart": {
		"id": "two_quiet_things",
		"lines": [
			"Riverwoods clearing, late light.",
			"\"The wisps stayed calm the whole way here. They do that near you now. I said someday you'd come find me first when they did. You did. So here's the first thing I never told anyone: I'm happy. In this exact volume. Don't repeat it — the trees will never let me hear the end of it.\"",
		],
	},
	## Marriage M2 (bible §6): dating-flavored lines, checked when
	## Romance.is_dating("willow") is true — see rosa.gd's identical doc for
	## the resolver precedence. Verbatim from docs/design/romance-dialog.md's
	## DATING pool.
	"dating_lines": [
		"The woods asked what changed in you. I told them your name. They already knew.",
		"I marked a second path to the sunny clearing. Wide enough for two, if one of them walks quiet.",
		"You wait long enough to hear the sap rise now. You learned that from me. I'm keeping it.",
	],
	## Marriage M3 (bible §3): spouse-tier lines, checked when
	## Romance.is_married_to("willow") is true — the TOP dialog tier, above
	## KINDRED and dating (see dialog_resolver.gd's precedence doc). Verbatim
	## from docs/design/romance-dialog.md's SPOUSE pool.
	"spouse_lines": [
		"Morning. The kitchen already smells like you were in it. I like that better than the woods, some days. Don't tell the trees.",
		"Left something on the counter. From the good clearing. It's not medicine. It's just — for you.",
		"You go quiet in that Delve too long and even the wisps get restless topside. So do I. Come back before the sap finishes rising.",
		"The forest asks about you less now. It knows where you are. So do I. That's the whole trick to being married, I think — always knowing the one root.",
	],
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
