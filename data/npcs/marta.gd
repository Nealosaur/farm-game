class_name MartaData
extends RefCounted
## Marta's NPCData factory. A plain GDScript factory (not a .tres resource)
## by choice — her schedule Dictionary keys time-blocks to Vector2i cells,
## and keeping it in code next to the cell-placement comments is easier to
## review/adjust than a nested Dictionary literal inside a .tres text
## resource. Every other NPC added later should follow the same shape
## (data/npcs/<id>.gd exporting a static build() -> NPCData).
##
## Town cell layout reference (scripts/maps/town.gd, World Stride C
## rebuild): STORE_FLOOR Rect2i(4,11,6,6) west side, PLAZA
## Rect2i(16,10,12,8) center. Marta's cells below match that layout:
##   - counter/store block -> town.gd's SHOPKEEPER_CELL (8,13): she replaces
##     the old generic shopkeeper there.
##   - plaza bench (17-20) -> (17,13): inside the plaza rect, off the
##     CROSS_ROAD_X=21 and MAIN_ROAD_Y=14 spines, on stone floor.
##   - home (20-2) -> (4,3): near the town's home row (matches the other
##     NPCs' CELL_HOME cells in that same row, e.g. Sten (6,3), Bram (8,3)).
##   - festival stall -> (18,11): plaza, near the notice board.

const ID := "marta"

const CELL_COUNTER := Vector2i(8, 13)    # store counter (matches town.gd's SHOPKEEPER_CELL)
const CELL_PLAZA_BENCH := Vector2i(17, 13)
const CELL_HOME := Vector2i(4, 3)        # town home row
const CELL_FESTIVAL_STALL := Vector2i(18, 11)  # plaza stall, near the notice board


static func build() -> NPCData:
	var d := NPCData.new()
	d.id = ID
	d.display_name = "Marta"
	d.birthday_season = 0  # Spring
	d.birthday_day = 19
	d.home_map = "town"

	var loved: Array[String] = ["pumpkin", "strawberry"]
	d.loved_items = loved
	var disliked: Array[String] = ["slime_gel"]
	d.disliked_items = disliked
	var liked_categories: Array[String] = [NPCData.ANY_CROP_CATEGORY]
	d.liked_categories = liked_categories

	# Schedule (bible): 6-9 store counter; 9-12 store; 12-17 store; 17-20
	# plaza bench; 20-2 home.
	d.schedule = {
		NPCRegistry.BLOCK_6_9: CELL_COUNTER,
		NPCRegistry.BLOCK_9_12: CELL_COUNTER,
		NPCRegistry.BLOCK_12_17: CELL_COUNTER,
		NPCRegistry.BLOCK_17_20: CELL_PLAZA_BENCH,
		NPCRegistry.BLOCK_20_2: CELL_HOME,
	}
	# Rain (bible): "all blocks store" — she stays at the counter all day.
	d.rain_schedule = {
		NPCRegistry.BLOCK_6_9: CELL_COUNTER,
		NPCRegistry.BLOCK_9_12: CELL_COUNTER,
		NPCRegistry.BLOCK_12_17: CELL_COUNTER,
		NPCRegistry.BLOCK_17_20: CELL_COUNTER,
		NPCRegistry.BLOCK_20_2: CELL_HOME,  # still goes home for the night even in rain
	}
	# Festival (bible): "plaza stall".
	d.festival_cell = CELL_FESTIVAL_STALL

	return d
