class_name StenData
extends RefCounted
## Sten's NPCData factory. Follows MartaData's shape (see data/npcs/marta.gd
## for the full convention note) — a plain GDScript factory, not a .tres.
##
## Town cell layout reference (scripts/maps/town.gd, World Stride C):
## SMITHY_FLOOR Rect2i(31,16,6,5) east side south; SALOON_FLOOR
## Rect2i(17,21,8,5) south of plaza.
##
## Alive Stride 1 proof-of-concept: a "winter" extra_schedules entry
## (characters.md seasonal line: "Forge season. Whole town finally
## understands my job.") — in winter he stays at the smithy through the
## evening block instead of heading to the saloon, only letting up for the
## night block same as always. Only the 17-20 block differs from `schedule`;
## every other block is left unset so NPCRegistry falls back to the normal
## schedule for them (see NPCRegistry._raw_entry's per-block fallback).

const ID := "sten"

const CELL_SMITHY := Vector2i(33, 18)    # smithy counter/anvil spot
const CELL_SALOON := Vector2i(19, 23)    # saloon interior, east corner (near Rosa's bar)
const CELL_HOME := Vector2i(6, 3)        # town home row, near mayor-house grounds
const CELL_FESTIVAL := Vector2i(17, 11)  # plaza edge, per characters.md "standing at the edge"


static func build() -> NPCData:
	var d := NPCData.new()
	d.id = ID
	d.display_name = "Sten"
	d.birthday_season = 3  # Winter
	d.birthday_day = 8
	d.home_map = "town"

	var loved: Array[String] = ["goblin_fang", "driftglass"]
	d.loved_items = loved
	var liked: Array[String] = ["slime_gel", "wisp_dust", "tideshell"]
	d.liked_items = liked
	var disliked: Array[String] = ["strawberry"]
	d.disliked_items = disliked

	# Schedule (bible): 6-9 smithy; 9-12 smithy; 12-17 smithy; 17-20 saloon;
	# 20-2 home.
	d.schedule = {
		NPCRegistry.BLOCK_6_9: CELL_SMITHY,
		NPCRegistry.BLOCK_9_12: CELL_SMITHY,
		NPCRegistry.BLOCK_12_17: CELL_SMITHY,
		NPCRegistry.BLOCK_17_20: CELL_SALOON,
		NPCRegistry.BLOCK_20_2: CELL_HOME,
	}
	# Rain (bible): "no change (forge doesn't care)" — identical to normal schedule.
	d.rain_schedule = {
		NPCRegistry.BLOCK_6_9: CELL_SMITHY,
		NPCRegistry.BLOCK_9_12: CELL_SMITHY,
		NPCRegistry.BLOCK_12_17: CELL_SMITHY,
		NPCRegistry.BLOCK_17_20: CELL_SALOON,
		NPCRegistry.BLOCK_20_2: CELL_HOME,
	}
	# Festival (bible): "plaza, standing at the edge".
	d.festival_cell = CELL_FESTIVAL

	# Winter (Alive Stride 1 proof, characters.md: "Forge season. Whole town
	# finally understands my job.") — stays at the smithy through 17-20
	# instead of the saloon; 20-2 home is untouched (falls back to `schedule`).
	d.extra_schedules = {
		"winter": {
			NPCRegistry.BLOCK_17_20: CELL_SMITHY,
		},
	}

	return d
