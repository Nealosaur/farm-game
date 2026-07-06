extends GutTest
## World Stride C: dialog-data completeness meta-test across all 8 NPCs —
## generalizes test_marta_dialog_data.gd's spot-checks into a shape/
## non-emptiness sweep every NPC's DATA dict must satisfy, per the
## DialogResolver-consumed shape documented in data/dialog/marta.gd.
## Per-NPC VERBATIM-text spot-checks stay in each NPC's own file below
## (one function per NPC) rather than trying to diff the whole
## characters.md file here.

const DIALOG_SCRIPTS := {
	"marta": "res://data/dialog/marta.gd",
	"sten": "res://data/dialog/sten.gd",
	"bram": "res://data/dialog/bram.gd",
	"rosa": "res://data/dialog/rosa.gd",
	"alden": "res://data/dialog/alden.gd",
	"finn": "res://data/dialog/finn.gd",
	"willow": "res://data/dialog/willow.gd",
	"garrick": "res://data/dialog/garrick.gd",
}

const TIERS := ["STRANGER", "ACQUAINT", "FRIEND", "CLOSE", "KINDRED"]


func _data(npc_id: String) -> Dictionary:
	var script: GDScript = load(DIALOG_SCRIPTS[npc_id])
	return script.DATA


func test_every_npc_has_all_five_tier_pools_non_empty() -> void:
	for npc_id: String in DIALOG_SCRIPTS:
		var data := _data(npc_id)
		var pools: Dictionary = data.get("tier_pools", {})
		for tier in TIERS:
			var pool: Array = pools.get(tier, [])
			assert_gt(pool.size(), 0, "%s: %s pool must not be empty" % [npc_id, tier])


func test_every_npc_has_rain_line() -> void:
	for npc_id: String in DIALOG_SCRIPTS:
		var data := _data(npc_id)
		var rain: Array = data.get("rain", [])
		assert_gt(rain.size(), 0, "%s: must have at least one rain line" % npc_id)


func test_every_npc_has_at_least_one_seasonal_line() -> void:
	for npc_id: String in DIALOG_SCRIPTS:
		var data := _data(npc_id)
		var seasonal: Array = data.get("seasonal", [])
		assert_gt(seasonal.size(), 0, "%s: must have at least one seasonal line" % npc_id)


func test_every_npc_has_birthday_reaction() -> void:
	for npc_id: String in DIALOG_SCRIPTS:
		var data := _data(npc_id)
		assert_ne(String(data.get("birthday_reaction", "")), "", "%s: birthday_reaction must be set" % npc_id)


func test_every_npc_has_all_three_gift_reactions() -> void:
	for npc_id: String in DIALOG_SCRIPTS:
		var data := _data(npc_id)
		var g: Dictionary = data.get("gift_reactions", {})
		for key in ["loved", "liked", "disliked"]:
			assert_ne(String(g.get(key, "")), "", "%s: gift_reactions.%s must be set" % [npc_id, key])


func test_every_npc_has_l3_and_l7_heart_events_with_full_shape() -> void:
	for npc_id: String in DIALOG_SCRIPTS:
		var data := _data(npc_id)
		var events: Dictionary = data.get("heart_events", {})
		for level_key in ["l3", "l7"]:
			var event: Dictionary = events.get(level_key, {})
			assert_true(event.has("id"), "%s: heart_events.%s must have an id" % [npc_id, level_key])
			assert_gt((event.get("lines", []) as Array).size(), 0,
				"%s: heart_events.%s must have at least one line" % [npc_id, level_key])
			for key in ["choice_a", "choice_b", "response_a", "response_b"]:
				assert_ne(String(event.get(key, "")), "",
					"%s: heart_events.%s.%s must be set" % [npc_id, level_key, key])


func test_every_npc_has_l5_and_l8_perks_with_line() -> void:
	for npc_id: String in DIALOG_SCRIPTS:
		var data := _data(npc_id)
		var perks: Dictionary = data.get("perks", {})
		for level_key in ["l5", "l8"]:
			var perk: Dictionary = perks.get(level_key, {})
			assert_ne(String(perk.get("line", "")), "",
				"%s: perks.%s must have a non-empty flavor line" % [npc_id, level_key])


func test_bram_and_garrick_l8_perks_carry_the_documented_max_hp_flag() -> void:
	var bram_l8: Dictionary = _data("bram")["perks"]["l8"]
	assert_eq(int(bram_l8.get("max_hp", 0)), 20, "Bram's L8 perk must grant +20 max HP")
	var garrick_l8: Dictionary = _data("garrick")["perks"]["l8"]
	assert_eq(int(garrick_l8.get("max_hp", 0)), 10, "Garrick's L8 perk must grant +10 max HP")


func test_alden_intro_and_garrick_quests_are_excluded_this_stride() -> void:
	## Explicit scope guard: Alden's day-1 INTRO block and Garrick's QUESTS
	## block are stride D content and must NOT appear in the shipped data.
	var alden := _data("alden")
	assert_false(alden.has("intro"), "Alden's INTRO block is stride D scope, not this stride")
	var garrick := _data("garrick")
	assert_false(garrick.has("quests"), "Garrick's QUESTS block is stride D scope, not this stride")


## ---- per-NPC verbatim spot-checks (one representative string each) ----

func test_sten_verbatim_spot_check() -> void:
	var data := _data("sten")
	assert_true("Forge is hot. Stand back." in data["tier_pools"]["STRANGER"])
	assert_eq(data["birthday_reaction"], "...How did you know that. WHO told you that.")


func test_bram_verbatim_spot_check() -> void:
	var data := _data("bram")
	assert_true("Clinic's open. Try not to need it." in data["tier_pools"]["STRANGER"])
	assert_eq(data["gift_reactions"]["disliked"], "Why.")


func test_rosa_verbatim_spot_check() -> void:
	var data := _data("rosa")
	assert_true("Welcome to The Ember! First smile's free." in data["tier_pools"]["STRANGER"])
	assert_eq(data["heart_events"]["l3"]["id"], "empty_chairs")


func test_alden_verbatim_spot_check() -> void:
	var data := _data("alden")
	assert_true("Good day. The notice board is current — I see to it personally." in data["tier_pools"]["STRANGER"])
	assert_eq(data["heart_events"]["l7"]["id"], "the_drawer")


func test_finn_verbatim_spot_check() -> void:
	var data := _data("finn")
	assert_true("You're the farmer who FIGHTS?! Okay okay okay act normal." in data["tier_pools"]["STRANGER"])
	assert_eq(data["gift_reactions"]["loved"], "SLIME! You get me. You completely get me.")


func test_willow_verbatim_spot_check() -> void:
	var data := _data("willow")
	assert_true("...Oh. A person. Hello, person." in data["tier_pools"]["STRANGER"])
	assert_eq(data["heart_events"]["l3"]["id"], "the_listening")


func test_garrick_verbatim_spot_check() -> void:
	var data := _data("garrick")
	assert_true("Farmer with a blade. The Delve's eaten better. ...Prove me wrong, actually. Please." in data["tier_pools"]["STRANGER"])
	assert_eq(data["heart_events"]["l7"]["id"], "the_broken_sword")
