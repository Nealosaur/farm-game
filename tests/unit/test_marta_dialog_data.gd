extends GutTest
## Sanity-checks MartaDialog.DATA's shape and a few verbatim strings against
## docs/design/characters.md (full-file diffing isn't practical in GUT, so
## this spot-checks the structurally important/easy-to-typo lines).


func test_tier_pools_present_and_non_empty() -> void:
	for tier in ["STRANGER", "ACQUAINT", "FRIEND", "CLOSE", "KINDRED"]:
		var pool: Array = MartaDialog.DATA["tier_pools"].get(tier, [])
		assert_gt(pool.size(), 0, tier + " pool must not be empty")


func test_stranger_pool_verbatim() -> void:
	var pool: Array = MartaDialog.DATA["tier_pools"]["STRANGER"]
	assert_true("Welcome to the store. Prices are on the shelf, dear." in pool)
	assert_true("Mind the floor, I just swept." in pool)


func test_birthday_reaction_verbatim() -> void:
	assert_eq(MartaDialog.DATA["birthday_reaction"], "You remembered?! Even Tomas forgot twice.")


func test_gift_reactions_verbatim() -> void:
	var g: Dictionary = MartaDialog.DATA["gift_reactions"]
	assert_eq(g["loved"], "Oh, my favorite! You clever thing.")
	assert_eq(g["liked"], "That'll do nicely, thank you.")
	assert_eq(g["disliked"], "I... will find a use. Outdoors.")


func test_rain_line_verbatim() -> void:
	assert_true("Rain's good for exactly two things: crops and my ledger." in MartaDialog.DATA["rain"])


func test_heart_event_l3_shape() -> void:
	var l3: Dictionary = MartaDialog.DATA["heart_events"]["l3"]
	assert_eq(l3["id"], "the_price_book")
	assert_gt((l3["lines"] as Array).size(), 0)
	assert_true(l3.has("choice_a"))
	assert_true(l3.has("choice_b"))
	assert_true(l3.has("response_a"))
	assert_true(l3.has("response_b"))


func test_heart_event_l7_shape() -> void:
	var l7: Dictionary = MartaDialog.DATA["heart_events"]["l7"]
	assert_eq(l7["id"], "restock")
	assert_gt((l7["lines"] as Array).size(), 0)


func test_seasonal_spring_friend_plus_gated() -> void:
	var entries: Array = MartaDialog.DATA["seasonal"]
	var found := false
	for e: Dictionary in entries:
		if e["season"] == 0:
			assert_eq(e["min_level"], 4, "Spring seasonal line is FRIEND+ (level 4)")
			found = true
	assert_true(found, "Marta must have a Spring seasonal entry")


func test_seasonal_winter_any_level() -> void:
	var entries: Array = MartaDialog.DATA["seasonal"]
	var found := false
	for e: Dictionary in entries:
		if e["season"] == 3:
			assert_eq(e["min_level"], 0, "Winter seasonal line is 'any' level")
			found = true
	assert_true(found, "Marta must have a Winter seasonal entry")
