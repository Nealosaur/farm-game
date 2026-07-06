class_name AldenData
extends RefCounted
## Mayor Alden's NPCData factory. Follows MartaData's shape (see
## data/npcs/marta.gd for the full convention note).
##
## Town cell layout reference (scripts/maps/town.gd, World Stride C):
## MAYOR_FLOOR Rect2i(18,3,6,5) north of the plaza; PLAZA Rect2i(16,10,12,8);
## SALOON_FLOOR Rect2i(17,21,8,5).
##
## Day-1 intro (farm, one-time, quest grant) is World Stride C SCOPE per the
## contract's inclusion list, but the INTRO block itself is explicitly
## EXCLUDED this stride ("Alden's day-1 INTRO block... stride D scope") — so
## this factory only carries his ordinary town schedule/dialog-gating data.
## The quest-grant flow and its dedicated dialog will read docs/design/
## world-bible.md's "Opening" section when Stride D wires quests.

const ID := "alden"

const CELL_PORCH := Vector2i(20, 5)       # mayor's house porch (also his home cell)
const CELL_NOTICE_BOARD := Vector2i(20, 11)  # plaza notice board, adjacent to town.gd's own board cell
const CELL_PLAZA_WALK := Vector2i(23, 13)  # plaza/town walk
const CELL_SALOON_CIDER := Vector2i(18, 22)  # "one cider" at the saloon
const CELL_FESTIVAL := Vector2i(21, 13)   # plaza podium


static func build() -> NPCData:
	var d := NPCData.new()
	d.id = ID
	d.display_name = "Mayor Alden"
	d.birthday_season = 0  # Spring
	d.birthday_day = 6
	d.home_map = "town"

	var loved: Array[String] = ["turnip"]
	d.loved_items = loved
	var disliked: Array[String] = ["wisp_dust"]
	d.disliked_items = disliked
	var liked_categories: Array[String] = [NPCData.ANY_CROP_CATEGORY]
	d.liked_categories = liked_categories

	# Schedule (bible): 6-9 mayor's house porch; 9-12 plaza notice board;
	# 12-17 plaza/town walk; 17-20 saloon (one cider); 20-2 home.
	d.schedule = {
		NPCRegistry.BLOCK_6_9: CELL_PORCH,
		NPCRegistry.BLOCK_9_12: CELL_NOTICE_BOARD,
		NPCRegistry.BLOCK_12_17: CELL_PLAZA_WALK,
		NPCRegistry.BLOCK_17_20: CELL_SALOON_CIDER,
		NPCRegistry.BLOCK_20_2: CELL_PORCH,
	}
	# No rain override documented for Alden — his seasonal/rain LINE changes
	# ("Rain on the ledger...") but his schedule doesn't; leave rain_schedule
	# empty so NPCRegistry falls back to the normal schedule every block.
	d.rain_schedule = {}
	# Festival (bible): "plaza podium".
	d.festival_cell = CELL_FESTIVAL

	return d
