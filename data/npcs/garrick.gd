class_name GarrickData
extends RefCounted
## Garrick's NPCData factory. Follows MartaData's shape (see
## data/npcs/marta.gd for the full convention note). Like Finn, his schedule
## spans two maps: the farm-side Delve entrance in the morning, town's saloon
## in the afternoon/evening, town home at night — per-block {"map", "cell"}
## overrides for the farm blocks (see NPCRegistry.cell_for()/map_for()).
##
## QUESTS (Q2 "Prove It", Q3 "The King Below") are explicitly OUT of this
## stride's scope per the contract ("EXCLUDE... Garrick's QUEST lines —
## stride D scope") — this factory only carries schedule/gift/dialog-gating
## data; his dialog file omits the "QUESTS" block from characters.md
## entirely (ordinary tier-pool/heart-event lines only).
##
## Cell layout references: farm.gd's DUNGEON_PORTAL_CELL area (farm-side
## Delve entrance) for the morning blocks; town.gd's SALOON_FLOOR
## Rect2i(17,21,8,5) for afternoon/evening.

const ID := "garrick"

const CELL_FARM_DELVE_ENTRANCE := Vector2i(38, 12)  # a few cells short of the dungeon portal (41,12)
const CELL_SALOON := Vector2i(23, 22)                # saloon, near Rosa's cider
const CELL_HOME := Vector2i(12, 3)                   # town home row
const CELL_FESTIVAL := Vector2i(22, 14)              # plaza, "near Rosa's cider"


static func build() -> NPCData:
	var d := NPCData.new()
	d.id = ID
	d.display_name = "Garrick"
	d.birthday_season = 3  # Winter
	d.birthday_day = 15
	d.home_map = "town"  # afternoon/evening/night blocks are town; see farm overrides below

	var loved: Array[String] = ["goblin_fang", "emberberry"]
	d.loved_items = loved
	var liked: Array[String] = ["slime_gel", "wisp_dust"]
	d.liked_items = liked
	var disliked: Array[String] = ["strawberry"]
	d.disliked_items = disliked

	# Schedule (bible): 6-9 farm-side Delve entrance; 9-12 Delve entrance;
	# 12-17 saloon; 17-20 saloon; 20-2 home (town).
	d.schedule = {
		NPCRegistry.BLOCK_6_9: {"map": "farm", "cell": CELL_FARM_DELVE_ENTRANCE},
		NPCRegistry.BLOCK_9_12: {"map": "farm", "cell": CELL_FARM_DELVE_ENTRANCE},
		NPCRegistry.BLOCK_12_17: CELL_SALOON,
		NPCRegistry.BLOCK_17_20: CELL_SALOON,
		NPCRegistry.BLOCK_20_2: CELL_HOME,
	}
	# Rain (bible): "saloon all day" — every block, including what would
	# otherwise be his farm-side morning blocks.
	d.rain_schedule = {
		NPCRegistry.BLOCK_6_9: CELL_SALOON,
		NPCRegistry.BLOCK_9_12: CELL_SALOON,
		NPCRegistry.BLOCK_12_17: CELL_SALOON,
		NPCRegistry.BLOCK_17_20: CELL_SALOON,
		NPCRegistry.BLOCK_20_2: CELL_HOME,
	}
	# Festival (bible): "plaza, near Rosa's cider".
	d.festival_cell = CELL_FESTIVAL

	return d
