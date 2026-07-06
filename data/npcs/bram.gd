class_name BramData
extends RefCounted
## Doc Bram's NPCData factory. Follows MartaData's shape (see
## data/npcs/marta.gd for the full convention note).
##
## Town cell layout reference (scripts/maps/town.gd, World Stride C):
## CLINIC_FLOOR Rect2i(31,8,6,5) east side, north of the smithy; PLAZA
## Rect2i(16,10,12,8).

const ID := "bram"

const CELL_CLINIC := Vector2i(33, 10)    # clinic counter
const CELL_PLAZA_WALK := Vector2i(22, 12)  # plaza, per "plaza walk" schedule note
const CELL_HOME := Vector2i(8, 3)        # town home row
const CELL_FESTIVAL := Vector2i(20, 15)  # plaza, "hovering near the food" (saloon-plaza border)


static func build() -> NPCData:
	var d := NPCData.new()
	d.id = ID
	d.display_name = "Doc Bram"
	d.birthday_season = 1  # Summer
	d.birthday_day = 4
	d.home_map = "town"

	var loved: Array[String] = ["carrot", "frostcap"]
	d.loved_items = loved
	var liked: Array[String] = ["wildroot"]
	d.liked_items = liked
	var disliked: Array[String] = ["goblin_fang"]
	d.disliked_items = disliked
	var liked_categories: Array[String] = [NPCData.ANY_CROP_CATEGORY]
	d.liked_categories = liked_categories

	# Schedule (bible): 6-9 clinic; 9-12 clinic; 12-17 clinic; 17-20 plaza
	# walk; 20-2 home.
	d.schedule = {
		NPCRegistry.BLOCK_6_9: CELL_CLINIC,
		NPCRegistry.BLOCK_9_12: CELL_CLINIC,
		NPCRegistry.BLOCK_12_17: CELL_CLINIC,
		NPCRegistry.BLOCK_17_20: CELL_PLAZA_WALK,
		NPCRegistry.BLOCK_20_2: CELL_HOME,
	}
	# Rain (bible): "clinic all day".
	d.rain_schedule = {
		NPCRegistry.BLOCK_6_9: CELL_CLINIC,
		NPCRegistry.BLOCK_9_12: CELL_CLINIC,
		NPCRegistry.BLOCK_12_17: CELL_CLINIC,
		NPCRegistry.BLOCK_17_20: CELL_CLINIC,
		NPCRegistry.BLOCK_20_2: CELL_HOME,
	}
	# Festival (bible): "plaza, hovering near the food".
	d.festival_cell = CELL_FESTIVAL

	return d
