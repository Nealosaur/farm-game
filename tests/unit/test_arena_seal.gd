extends GutTest
## Pure state machine for the boss arena gate (sealed/unsealed). No scene
## tree needed — same style as test_dungeon_state.gd.


func test_starts_unsealed() -> void:
	var seal := ArenaSeal.new()
	assert_false(seal.sealed)


func test_player_entered_arena_seals_and_returns_true_first_time() -> void:
	var seal := ArenaSeal.new()
	var sealed_now := seal.player_entered_arena()
	assert_true(sealed_now)
	assert_true(seal.sealed)


func test_player_entered_arena_is_idempotent() -> void:
	var seal := ArenaSeal.new()
	seal.player_entered_arena()
	var sealed_again := seal.player_entered_arena()
	assert_false(sealed_again, "re-triggering while already sealed must not re-fire the wall/toast")
	assert_true(seal.sealed)


func test_boss_defeated_unseals() -> void:
	var seal := ArenaSeal.new()
	seal.player_entered_arena()
	seal.boss_defeated()
	assert_false(seal.sealed)


func test_player_collapsed_unseals() -> void:
	var seal := ArenaSeal.new()
	seal.player_entered_arena()
	seal.player_collapsed()
	assert_false(seal.sealed)


func test_can_reseal_after_unsealing() -> void:
	var seal := ArenaSeal.new()
	seal.player_entered_arena()
	seal.player_collapsed()
	var sealed_again := seal.player_entered_arena()
	assert_true(sealed_again)
	assert_true(seal.sealed)
