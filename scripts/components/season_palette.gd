class_name SeasonPalette
extends Node
## Seasonal ground recolor (World Stride A): modulates one TileMapLayer (the
## map's Ground) with the current season's palette color. Attach via
## MapSceneHelper.attach_season_palette() on OUTDOOR maps only — dungeon
## floors are exempt simply by never attaching one (see dungeon_floor.gd).
## Reapplies on day_passed because sleeping can cross a season boundary.
## Stacks with DayTint (CanvasModulate multiplies over layer modulate).

const SEASON_GROUND := [
	Color(1.0, 1.0, 1.0),    # Spring — neutral
	Color(1.02, 1.0, 0.9),   # Summer — sun-baked
	Color(1.1, 0.85, 0.6),   # Fall — amber
	Color(0.8, 0.85, 1.0),   # Winter — pale
]

var _layer: TileMapLayer


static func color_for_season(s: int) -> Color:
	return SEASON_GROUND[s]


func _ready() -> void:
	# Named method, NOT a lambda — method connections auto-disconnect when
	# this node is freed with its map scene (project convention).
	EventBus.day_passed.connect(_on_day_passed)
	_apply()


func setup(layer: TileMapLayer) -> void:
	_layer = layer
	_apply()


func _on_day_passed(_day) -> void:
	_apply()


func _apply() -> void:
	if _layer != null:
		_layer.modulate = SEASON_GROUND[Clock.season()]
