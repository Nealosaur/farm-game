extends GutTest
## Craft Stride 3 (Taming): pure unit coverage for Taming's world["taming"]
## blob logic — no scene tree needed (mirrors DungeonState/Forage's own
## pure-utility test style).

func test_default_blob_shape() -> void:
	var blob := Taming.default_blob()
	assert_eq(int(blob["slime_feeds"]), 0)
	assert_eq((blob["barn"] as Array).size(), 0)


func test_read_coerces_missing_keys_to_defaults() -> void:
	var blob := Taming.read({})
	assert_eq(int(blob["slime_feeds"]), 0)
	assert_eq((blob["barn"] as Array).size(), 0)


func test_read_coerces_json_float_feeds_to_int() -> void:
	## JSON round-trips numbers as floats — established gotcha every other
	## world blob coerces on read; Taming must too.
	var world := {"taming": {"slime_feeds": 2.0, "barn": []}}
	var blob := Taming.read(world)
	assert_eq(blob["slime_feeds"], 2)
	assert_true(blob["slime_feeds"] is int)


func test_read_coerces_barn_entries_to_string() -> void:
	var world := {"taming": {"slime_feeds": 0, "barn": ["slime"]}}
	var blob := Taming.read(world)
	assert_eq(blob["barn"][0], "slime")
	assert_true(blob["barn"][0] is String)


func test_barn_count_and_has_room() -> void:
	var world := {"taming": {"slime_feeds": 0, "barn": ["slime"]}}
	assert_eq(Taming.barn_count(world), 1)
	assert_true(Taming.has_room(world))
	world["taming"]["barn"] = ["slime", "slime"]
	assert_eq(Taming.barn_count(world), Taming.MAX_BARN)
	assert_false(Taming.has_room(world))


func test_record_feed_below_threshold_just_feeds() -> void:
	var world := {}
	var outcome := Taming.record_feed(world, "slime")
	assert_eq(outcome["result"], Taming.RESULT_FED)
	assert_eq(int(outcome["blob"]["slime_feeds"]), 1)
	assert_eq((outcome["blob"]["barn"] as Array).size(), 0)


func test_record_feed_reaching_threshold_tames_with_room() -> void:
	var world := {"taming": {"slime_feeds": Taming.THRESHOLD, "barn": []}}
	var outcome := Taming.record_feed(world, "slime")
	assert_eq(outcome["result"], Taming.RESULT_TAMED)
	assert_eq(outcome["blob"]["barn"], ["slime"])
	assert_eq(int(outcome["blob"]["slime_feeds"]), 0, "threshold feed spends down the tally")


func test_record_feed_at_threshold_with_full_barn_reports_barn_full() -> void:
	var world := {"taming": {"slime_feeds": Taming.THRESHOLD, "barn": ["slime", "slime"]}}
	var outcome := Taming.record_feed(world, "slime")
	assert_eq(outcome["result"], Taming.RESULT_BARN_FULL)
	assert_eq((outcome["blob"]["barn"] as Array).size(), Taming.MAX_BARN,
		"barn roster must not grow past the cap")
	assert_eq(int(outcome["blob"]["slime_feeds"]), Taming.THRESHOLD + 1,
		"a barn-full feed still consumes the item — tally keeps counting, not reset")


func test_feeds_below_threshold_never_tame_across_repeated_feeds() -> void:
	var world := {}
	for i in Taming.THRESHOLD:
		var outcome := Taming.record_feed(world, "slime")
		assert_eq(outcome["result"], Taming.RESULT_FED, "feed #%d must not tame yet" % (i + 1))
		world["taming"] = outcome["blob"]
	# The feed AT the threshold count is the one that tames.
	var final_outcome := Taming.record_feed(world, "slime")
	assert_eq(final_outcome["result"], Taming.RESULT_TAMED)
