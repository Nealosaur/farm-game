class_name MartaData
extends RefCounted
## Marta's NPCData factory. A plain GDScript factory (not a .tres resource)
## by choice — her schedule Dictionary keys time-blocks to Vector2i cells,
## and keeping it in code next to the cell-placement comments is easier to
## review/adjust than a nested Dictionary literal inside a .tres text
## resource. Every other NPC added later should follow the same shape
## (data/npcs/<id>.gd exporting a static build() -> NPCData).
##
## Town cell layout reference (scripts/maps/town.gd): plaza Rect2i(10,8,10,6),
## shop floor Rect2i(20,6,6,5), counter (22,8), existing shopkeeper cell
## (23,8). Marta's cells below reuse/extend that layout:
##   - counter/store block -> the existing SHOPKEEPER_CELL (23,8): she
##     replaces the old generic shopkeeper there.
##   - plaza bench (17-20) -> (12,10): inside the plaza rect, south side,
##     away from the through-road at y=10... NOTE the plaza road runs at
##     y=10 (main east-west street) so the "bench" cell is placed at (12,9),
##     just off the road on stone floor.
##   - home (20-2) -> (4,3): "near mayor-house row" per her schedule note;
##     town.gd's HOUSE_A_CELL is (3,3) (top-left of a 3x3 footprint), so
##     (4,3) sits just beside House A on its stone/grass border, standing in
##     for "mayor-house row" until a dedicated house exists for her.

const ID := "marta"

const CELL_COUNTER := Vector2i(23, 8)   # store counter (matches town.gd's SHOPKEEPER_CELL)
const CELL_PLAZA_BENCH := Vector2i(12, 9)
const CELL_HOME := Vector2i(4, 3)       # beside HOUSE_A_CELL, standing in for "mayor-house row"
const CELL_FESTIVAL_STALL := Vector2i(14, 9)  # plaza stall, near the bench spot


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
