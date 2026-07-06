class_name NPCData
extends Resource
## Data-driven NPC registry entry (World Stride B). One resource per NPC:
## identity, birthday, gift preferences, and the schedule block table.
##
## Gift resolution precedence (Relationships._reaction_for): concrete
## loved_items > disliked_items > liked_items > liked_categories. Category
## fallback strings are matched against ItemDB item "kind" via
## matches_any_category() — for this stride only "any_crop" is implemented
## (bible: Marta/Bram/Alden "likes any crop"), matching any item whose id
## resolves to a CropData product (i.e. any harvestable produce id).
##
## Schedule blocks (bible): "6-9", "9-12", "12-17", "17-20", "20-2" — 5 blocks
## covering the full 6:00-26:00 day. schedule is a Dictionary block_key ->
## Vector2i cell on `home_map` (this stride: all of Marta's blocks are on the
## town map, so a single map id suffices; a per-block map override can be
## added later without changing this shape — just make the value a
## {"map": String, "cell": Vector2i} dict if a future NPC needs it).
## rain_schedule / festival_cell override the normal block lookup; see
## NPCRegistry.cell_for() for precedence (festival > rain > block).

const ANY_CROP_CATEGORY := "any_crop"

@export var id: String = ""
@export var display_name: String = ""

## Clock.season() index (0 Spring..3 Winter) and day_of_season (1-based).
@export var birthday_season: int = 0
@export var birthday_day: int = 1

@export var loved_items: Array[String] = []
@export var liked_items: Array[String] = []
@export var disliked_items: Array[String] = []
## Category fallback strings, checked after concrete liked/disliked ids.
## Currently supported: "any_crop".
@export var liked_categories: Array[String] = []

## home map scene id (NPCRegistry keys maps by this), e.g. "town".
@export var home_map: String = ""

## block_key ("6-9" etc.) -> Vector2i cell. See NPCRegistry.
@export var schedule: Dictionary = {}
## Optional: block_key -> Vector2i cell override when Clock.is_raining().
## A block missing here falls back to `schedule`.
@export var rain_schedule: Dictionary = {}
## Optional: single cell used for every block on a festival day.
@export var festival_cell := Vector2i(-1, -1)

## Alive Stride 1: optional priority-key schedule tables, keyed by table name
## ("spring"/"summer"/"fall"/"winter", "weekend", "<season>_weekend"), each a
## block_key -> Vector2i (or {"map","cell"}) Dictionary with the same shape
## as `schedule`. Checked by NPCRegistry._raw_entry in priority order between
## rain_schedule and schedule — see NPCRegistry's class doc for the full
## precedence chain and the weekend rule. Entirely optional: an empty (the
## default) or partial table for any key is fine — a missing block falls
## back further down the chain, never straight to `schedule`.
@export var extra_schedules: Dictionary = {}


static func is_birthday_today(npc: NPCData) -> bool:
	return Clock.season() == npc.birthday_season and Clock.day_of_season() == npc.birthday_day


static func matches_any_category(item_id: String, categories: Array) -> bool:
	if categories.is_empty():
		return false
	for cat: String in categories:
		if cat == ANY_CROP_CATEGORY and _is_crop_product(item_id):
			return true
	return false


static func _is_crop_product(item_id: String) -> bool:
	for crop_id: String in ItemDB.crops:
		var crop: CropData = ItemDB.crops[crop_id]
		if crop.product_id == item_id:
			return true
	return false
