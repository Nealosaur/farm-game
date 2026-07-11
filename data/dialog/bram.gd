class_name BramDialog
extends RefCounted
## Doc Bram — Clinic doctor. All strings VERBATIM from
## docs/design/characters.md (typos and all — they're voice). Do not
## paraphrase; if a line needs to change, change characters.md first.
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
		"l8": {
			"id": "the_chart",
			"lines": [
				"Empty clinic, Bram holding your file.",
				"\"I keep a chart on everyone. Symptoms, follow-ups, the professional distance. Yours has gotten... unprofessional. There's worry in the margins that isn't clinical. I've been calling it diligence. That was a lie a doctor tells himself.\"",
			],
			"choice_a": "\"Call it what it is.\"",
			"choice_b": "\"Diligence is fine, Doc.\"",
			"response_a": "\"...Affection. There. Said aloud in a room where I usually only deliver bad news. This one's not bad. I'm as surprised as you.\"",
			"response_b": "\"Yes. Diligence. Safer word. ...Appointment's over. Eat a vegetable.\"",
		},
		"l10": {
			"id": "the_reason_part_two",
			"lines": [
				"Dusk, Bram unprompted.",
				"\"I told you once why I left the city — the one I lost, the error the numbers forgave and I didn't. I came here to feel small. To matter to no one so I could never fail anyone that size again. And then you walked in needing bandages and I have never in my life been so afraid of how much someone could matter.\"",
			],
			"choice_a": "\"Let me matter that much anyway.\"",
			"choice_b": "\"You don't have to risk it.\"",
			"response_a": "\"...God help my nerve. Bring me something that means forever and I'll risk it. I'll risk YOU. First brave thing I've done since the table.\"",
			"response_b": "\"No. I don't. That's the tragedy of being careful. Good evening. Mind the wet step.\"",
		},
	},
	"fourteen_heart": {
		"id": "morning_rounds",
		"lines": [
			"Farm kitchen, Bram with coffee and your chart, now framed as a joke.",
			"\"Healthiest patient in Emberhollow. Official. I retired the worry from your margins — turns out you can't chart a thing you get to check on every morning. I stopped feeling small. I started feeling like a man who got a second table and didn't lose anyone on it.\"",
		],
	},
	## Marriage M2 (bible §6): dating-flavored lines, checked when
	## Romance.is_dating("bram") is true — see rosa.gd's identical doc for the
	## resolver precedence. Verbatim from docs/design/romance-dialog.md's
	## DATING pool.
	"dating_lines": [
		"I updated your chart. Under 'prognosis' I wrote a word I haven't used professionally in six years. I'm not telling you which.",
		"Rosa asked why I'm eating better. I said 'reasons.' Singular reason. You.",
		"I left the city so the stakes would be small. Then the stakes became you. That was not the plan and I do not object.",
	],
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
