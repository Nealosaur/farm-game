class_name FinnData
extends RefCounted
## Finn's NPCData factory. Follows MartaData's shape (see data/npcs/marta.gd
## for the full convention note), but Finn is the first NPC whose schedule
## SPANS two maps: beach by day, town in the evening/night. Per-block entries
## that live off his home_map use the {"map": String, "cell": Vector2i}
## override shape documented in NPCRegistry.cell_for()/map_for().
##
## Cell layout references:
##   Beach (scripts/maps/beach.gd, World Stride C): PIER area + general beach
##   floor — see beach.gd's own constants for the exact rects.
##   Town (scripts/maps/town.gd): PLAZA Rect2i(16,10,12,8); SALOON_FLOOR
##   Rect2i(17,21,8,5) for his rain shelter.

const ID := "finn"

const CELL_BEACH_PIER := Vector2i(6, 9)         # beach pier, morning
const CELL_BEACH_DAY := Vector2i(10, 11)        # beach general area, midday
const CELL_SALOON_CORNER := Vector2i(22, 24)    # rain shelter: "saloon corner"
const CELL_PLAZA_FOUNTAIN := Vector2i(25, 13)   # plaza, "fountain edge"
const CELL_HOME := Vector2i(10, 3)              # town home row
const CELL_FESTIVAL := Vector2i(19, 15)         # "wherever the food is" — beside Bram's festival spot


static func build() -> NPCData:
	var d := NPCData.new()
	d.id = ID
	d.display_name = "Finn"
	d.birthday_season = 1  # Summer
	d.birthday_day = 17
	d.home_map = "town"  # evening/night blocks live in town; see per-block overrides below

	var loved: Array[String] = ["slime_gel"]
	d.loved_items = loved
	var liked: Array[String] = ["wisp_dust", "tideshell"]
	d.liked_items = liked
	var disliked: Array[String] = ["turnip"]
	d.disliked_items = disliked

	# Schedule (bible): 6-9 beach pier; 9-12 beach; 12-17 beach (rain: saloon
	# corner); 17-20 plaza fountain edge; 20-2 home (town).
	d.schedule = {
		NPCRegistry.BLOCK_6_9: {"map": "beach", "cell": CELL_BEACH_PIER},
		NPCRegistry.BLOCK_9_12: {"map": "beach", "cell": CELL_BEACH_DAY},
		NPCRegistry.BLOCK_12_17: {"map": "beach", "cell": CELL_BEACH_DAY},
		NPCRegistry.BLOCK_17_20: CELL_PLAZA_FOUNTAIN,
		NPCRegistry.BLOCK_20_2: CELL_HOME,
	}
	# Rain (bible): only the 12-17 block changes ("rain: saloon corner") —
	# morning pier/beach and evening/night are unaffected, so only that one
	# block needs an entry (NPCRegistry falls back to `schedule` for blocks
	# missing from rain_schedule).
	d.rain_schedule = {
		NPCRegistry.BLOCK_12_17: CELL_SALOON_CORNER,
	}
	# Festival (bible): "wherever the food is".
	d.festival_cell = CELL_FESTIVAL

	return d
