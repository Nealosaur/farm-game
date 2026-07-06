class_name RosaData
extends RefCounted
## Rosa's NPCData factory. Follows MartaData's shape (see data/npcs/marta.gd
## for the full convention note).
##
## Town cell layout reference (scripts/maps/town.gd, World Stride C):
## SALOON_FLOOR Rect2i(17,21,8,5) south of the plaza; PLAZA Rect2i(16,10,12,8).

const ID := "rosa"

const CELL_PLAZA_CHAIRS := Vector2i(19, 12)  # plaza, "setting chairs" for the morning block
const CELL_SALOON := Vector2i(20, 23)        # saloon bar spot
const CELL_FESTIVAL := Vector2i(21, 14)      # plaza center — "she runs them"


static func build() -> NPCData:
	var d := NPCData.new()
	d.id = ID
	d.display_name = "Rosa"
	d.birthday_season = 2  # Fall
	d.birthday_day = 2
	d.home_map = "town"

	var loved: Array[String] = ["strawberry", "melon"]
	d.loved_items = loved
	var liked: Array[String] = ["corn", "tomato", "emberberry"]
	d.liked_items = liked
	var disliked: Array[String] = ["driftglass"]
	d.disliked_items = disliked

	# Schedule (bible): 6-9 plaza (setting chairs); 9-12 saloon; 12-17 saloon;
	# 17-20 saloon; 20-2 saloon.
	d.schedule = {
		NPCRegistry.BLOCK_6_9: CELL_PLAZA_CHAIRS,
		NPCRegistry.BLOCK_9_12: CELL_SALOON,
		NPCRegistry.BLOCK_12_17: CELL_SALOON,
		NPCRegistry.BLOCK_17_20: CELL_SALOON,
		NPCRegistry.BLOCK_20_2: CELL_SALOON,
	}
	# Rain (bible): "saloon all day".
	d.rain_schedule = {
		NPCRegistry.BLOCK_6_9: CELL_SALOON,
		NPCRegistry.BLOCK_9_12: CELL_SALOON,
		NPCRegistry.BLOCK_12_17: CELL_SALOON,
		NPCRegistry.BLOCK_17_20: CELL_SALOON,
		NPCRegistry.BLOCK_20_2: CELL_SALOON,
	}
	# Festival (bible): "plaza center (she runs them)".
	d.festival_cell = CELL_FESTIVAL

	return d
