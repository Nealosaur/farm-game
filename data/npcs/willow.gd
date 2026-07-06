class_name WillowData
extends RefCounted
## Willow's NPCData factory. Follows MartaData's shape (see data/npcs/marta.gd
## for the full convention note). home_map is "riverwoods" — every ordinary
## schedule block lives there; only her festival appearance crosses onto the
## town plaza (bible: "present 10:00-15:00 only").
##
## Cell layout reference: scripts/maps/riverwoods.gd's own constants for the
## hut/riverbank/forest-path cells (World Stride C, new map).
##
## The "present only 10:00-15:00" festival window isn't representable by the
## plain festival_cell sentinel (which NPCRegistry treats as "present all
## day once set") — npc.gd/town.gd query is_present_on_map for placement, so
## this is documented here and enforced by whichever caller checks festival
## hours; see riverwoods.gd/town.gd for the actual gating note. For THIS
## stride's contract (schedules + placement, not full festival implementation
## — festivals are content for World Stride D), festival_cell is set as
## normal and the hour-window nuance is left as a documented gap (world-bible
## festivals aren't wired yet at all, so nothing currently queries this
## outside the four-festival system that doesn't exist yet).

const ID := "willow"

const CELL_HUT := Vector2i(6, 5)          # Riverwoods hut (morning/evening/night)
const CELL_RIVERBANK := Vector2i(14, 10)  # riverbank, mid-morning
const CELL_FOREST_PATH := Vector2i(20, 14)  # forest paths, afternoon
const CELL_FESTIVAL := Vector2i(26, 12)   # town plaza, "at the very edge"


static func build() -> NPCData:
	var d := NPCData.new()
	d.id = ID
	d.display_name = "Willow"
	d.birthday_season = 2  # Fall
	d.birthday_day = 21
	d.home_map = "riverwoods"

	var loved: Array[String] = ["wildroot", "frostcap"]
	d.loved_items = loved
	var liked: Array[String] = ["emberberry", "wisp_dust"]
	d.liked_items = liked
	var disliked: Array[String] = ["goblin_fang"]
	d.disliked_items = disliked

	# Schedule (bible): 6-9 Riverwoods hut; 9-12 riverbank; 12-17 forest
	# paths; 17-20 hut; 20-2 hut.
	d.schedule = {
		NPCRegistry.BLOCK_6_9: CELL_HUT,
		NPCRegistry.BLOCK_9_12: CELL_RIVERBANK,
		NPCRegistry.BLOCK_12_17: CELL_FOREST_PATH,
		NPCRegistry.BLOCK_17_20: CELL_HUT,
		NPCRegistry.BLOCK_20_2: CELL_HUT,
	}
	# Rain (bible): "under the hut awning, delighted" — all blocks at the hut.
	d.rain_schedule = {
		NPCRegistry.BLOCK_6_9: CELL_HUT,
		NPCRegistry.BLOCK_9_12: CELL_HUT,
		NPCRegistry.BLOCK_12_17: CELL_HUT,
		NPCRegistry.BLOCK_17_20: CELL_HUT,
		NPCRegistry.BLOCK_20_2: CELL_HUT,
	}
	# Festival (bible): "plaza, at the very edge, leaves early... (present
	# 10:00-15:00 only)" — see class doc note on the hour-window nuance.
	d.festival_cell = CELL_FESTIVAL

	return d
