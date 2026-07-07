extends GutTest
## DEPTH stride: FishingLogic — pure dict/geometry logic for the fishing
## minigame. No scene tree — mirrors MineState/DungeonState's "pure helper,
## no autoload state" test shape.


## ---- can_fish_at gate ----

func test_can_fish_requires_both_rod_and_water() -> void:
	assert_true(FishingLogic.can_fish_at(true, true))
	assert_false(FishingLogic.can_fish_at(false, true), "no rod -> refused even facing water")
	assert_false(FishingLogic.can_fish_at(true, false), "not facing water -> refused even with a rod")
	assert_false(FishingLogic.can_fish_at(false, false))


## ---- bite delay ----

func test_bite_delay_within_configured_bounds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 50:
		var delay := FishingLogic.roll_bite_delay(rng)
		assert_gte(delay, FishingLogic.MIN_BITE_DELAY)
		assert_lte(delay, FishingLogic.MAX_BITE_DELAY)


## ---- marker sweep (pure function of elapsed time) ----

func test_marker_position_starts_at_zero() -> void:
	assert_almost_eq(FishingLogic.marker_position(0.0), 0.0, 0.001)


func test_marker_position_deterministic_for_same_elapsed() -> void:
	assert_eq(FishingLogic.marker_position(0.37), FishingLogic.marker_position(0.37))


func test_marker_position_stays_within_zero_one() -> void:
	for i in 100:
		var t := i * 0.05
		var pos := FishingLogic.marker_position(t)
		assert_gte(pos, 0.0, "t=%f" % t)
		assert_lte(pos, 1.0, "t=%f" % t)


func test_marker_position_bounces_back_down_after_reaching_one() -> void:
	# At speed 1.0, t = fmod(elapsed, 2.0): the wave rises 0->1 over elapsed
	# 0..1 (peaking at elapsed=1.0), then falls 1->0 over elapsed 1..2
	# (back to 0 at elapsed=2.0, i.e. a fresh cycle) — a true triangle wave.
	var peak := FishingLogic.marker_position(1.0, 1.0)
	var mid_of_fall := FishingLogic.marker_position(1.5, 1.0)
	var full_cycle := FishingLogic.marker_position(2.0, 1.0)
	assert_almost_eq(peak, 1.0, 0.01, "elapsed=speed's period/2 is the peak")
	assert_almost_eq(mid_of_fall, 0.5, 0.01, "falling leg is symmetric to the rising leg")
	assert_almost_eq(full_cycle, 0.0, 0.01, "a full 0->1->0 cycle returns to the start")


## ---- target zone roll ----

func test_target_zone_deterministic_for_same_seed() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 42
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 42
	assert_eq(FishingLogic.roll_target_zone(rng_a), FishingLogic.roll_target_zone(rng_b))


func test_target_zone_stays_within_zero_one_and_has_configured_width() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 50:
		var zone := FishingLogic.roll_target_zone(rng)
		assert_gte(zone.x, 0.0)
		assert_lte(zone.y, 1.0)
		assert_almost_eq(zone.y - zone.x, FishingLogic.TARGET_ZONE_WIDTH, 0.001)


func test_is_within_zone_boundaries_inclusive() -> void:
	var zone := Vector2(0.4, 0.6)
	assert_true(FishingLogic.is_within_zone(0.4, zone))
	assert_true(FishingLogic.is_within_zone(0.5, zone))
	assert_true(FishingLogic.is_within_zone(0.6, zone))
	assert_false(FishingLogic.is_within_zone(0.39, zone))
	assert_false(FishingLogic.is_within_zone(0.61, zone))


## ---- species weighting ----

func test_roll_species_deterministic_for_same_seed() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 99
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 99
	assert_eq(FishingLogic.roll_species(FishingLogic.WATER_RIVER, rng_a),
		FishingLogic.roll_species(FishingLogic.WATER_RIVER, rng_b))


func test_roll_species_only_returns_ids_from_the_correct_pool() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 100:
		var species := FishingLogic.roll_species(FishingLogic.WATER_RIVER, rng)
		assert_true(FishingLogic.RIVER_POOL.has(species), "got '%s'" % species)
	for i in 100:
		var species := FishingLogic.roll_species(FishingLogic.WATER_SEA, rng)
		assert_true(FishingLogic.SEA_POOL.has(species), "got '%s'" % species)


func test_roll_species_distribution_covers_every_species_and_weights_rarity() -> void:
	## Over many rolls, every species in the pool must appear at least once,
	## and the rarest (lowest weight) must appear less often than the most
	## common — a crude but effective check that the weighted table isn't
	## secretly uniform or missing a branch (same spirit as MineState's
	## floor-type distribution test).
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var counts := {"rivertrout": 0, "bluegill": 0, "eel": 0}
	for i in 2000:
		var species := FishingLogic.roll_species(FishingLogic.WATER_RIVER, rng)
		counts[species] = int(counts[species]) + 1
	assert_gt(counts["rivertrout"], 0)
	assert_gt(counts["bluegill"], 0)
	assert_gt(counts["eel"], 0)
	assert_gt(counts["rivertrout"], counts["eel"],
		"rivertrout (weight 50) must be rolled more often than eel (weight 15)")


func test_pool_for_water_selects_river_or_sea() -> void:
	assert_eq(FishingLogic.pool_for_water(FishingLogic.WATER_RIVER), FishingLogic.RIVER_POOL)
	assert_eq(FishingLogic.pool_for_water(FishingLogic.WATER_SEA), FishingLogic.SEA_POOL)
	assert_eq(FishingLogic.pool_for_water("nonsense"), FishingLogic.RIVER_POOL,
		"unknown water body defaults to river, not a crash")
