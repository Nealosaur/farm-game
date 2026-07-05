extends GutTest
## Pure block/cell resolution for NPCRegistry — no scene tree.


func _npc(schedule: Dictionary, rain_schedule: Dictionary = {}, festival_cell := Vector2i(-1, -1)) -> NPCData:
	var d := NPCData.new()
	d.id = "test_npc"
	d.schedule = schedule
	d.rain_schedule = rain_schedule
	d.festival_cell = festival_cell
	return d


func test_block_for_covers_all_five_blocks() -> void:
	assert_eq(NPCRegistry.block_for(6), NPCRegistry.BLOCK_6_9)
	assert_eq(NPCRegistry.block_for(8), NPCRegistry.BLOCK_6_9)
	assert_eq(NPCRegistry.block_for(9), NPCRegistry.BLOCK_9_12)
	assert_eq(NPCRegistry.block_for(11), NPCRegistry.BLOCK_9_12)
	assert_eq(NPCRegistry.block_for(12), NPCRegistry.BLOCK_12_17)
	assert_eq(NPCRegistry.block_for(16), NPCRegistry.BLOCK_12_17)
	assert_eq(NPCRegistry.block_for(17), NPCRegistry.BLOCK_17_20)
	assert_eq(NPCRegistry.block_for(19), NPCRegistry.BLOCK_17_20)
	assert_eq(NPCRegistry.block_for(20), NPCRegistry.BLOCK_20_2)
	assert_eq(NPCRegistry.block_for(23), NPCRegistry.BLOCK_20_2)
	assert_eq(NPCRegistry.block_for(1), NPCRegistry.BLOCK_20_2)


func test_cell_for_normal_block() -> void:
	var npc := _npc({NPCRegistry.BLOCK_9_12: Vector2i(5, 5)})
	assert_eq(NPCRegistry.cell_for(npc, 10, false, false), Vector2i(5, 5))


func test_cell_for_missing_block_returns_sentinel() -> void:
	var npc := _npc({NPCRegistry.BLOCK_9_12: Vector2i(5, 5)})
	assert_eq(NPCRegistry.cell_for(npc, 22, false, false), Vector2i(-1, -1))
	assert_false(NPCRegistry.is_present(npc, 22, false, false))


func test_rain_override_takes_precedence_over_normal_schedule() -> void:
	var npc := _npc(
		{NPCRegistry.BLOCK_9_12: Vector2i(5, 5)},
		{NPCRegistry.BLOCK_9_12: Vector2i(1, 1)})
	assert_eq(NPCRegistry.cell_for(npc, 10, true, false), Vector2i(1, 1))
	assert_eq(NPCRegistry.cell_for(npc, 10, false, false), Vector2i(5, 5))


func test_rain_override_falls_back_when_block_not_overridden() -> void:
	var npc := _npc(
		{NPCRegistry.BLOCK_9_12: Vector2i(5, 5)},
		{NPCRegistry.BLOCK_17_20: Vector2i(9, 9)})
	assert_eq(NPCRegistry.cell_for(npc, 10, true, false), Vector2i(5, 5))


func test_festival_cell_beats_everything() -> void:
	var npc := _npc(
		{NPCRegistry.BLOCK_9_12: Vector2i(5, 5)},
		{NPCRegistry.BLOCK_9_12: Vector2i(1, 1)},
		Vector2i(20, 20))
	assert_eq(NPCRegistry.cell_for(npc, 10, true, true), Vector2i(20, 20))


func test_festival_without_festival_cell_falls_back() -> void:
	var npc := _npc({NPCRegistry.BLOCK_9_12: Vector2i(5, 5)})
	assert_eq(NPCRegistry.cell_for(npc, 10, false, true), Vector2i(5, 5))
