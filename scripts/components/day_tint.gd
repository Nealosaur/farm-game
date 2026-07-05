class_name DayTint
extends CanvasModulate
## Day/night visual: whole-scene tint driven by Clock. Full white 6:00-16:00,
## lerps to warm dusk by 19:00, to dark blue night by 21:00, holds to curfew
## (2 AM). This applies to every map, so it lives in AUTO_INSTANCE_SCRIPTS
## (and farm.gd's inline copy) alongside HUD/DayFlow.
## Pure curve logic is a static func so it's unit-testable without a live tree.
##
## Weather (World Stride A): while it rains, RAIN_TINT is multiplied into the
## computed day/night tint — OUTDOOR maps only. Dungeon floors are exempt:
## DungeonFloor._ready() puts the map root in the "dungeon_map" group before
## this node is instanced, and we check our parent for it (dungeons also skip
## the seasonal ground palette — see season_palette.gd / dungeon_floor.gd).

const WHITE := Color(1.0, 1.0, 1.0)
const DUSK := Color(1.0, 0.75, 0.55)
const NIGHT := Color(0.35, 0.4, 0.6)

const DUSK_START := 16 * 60   # 16:00
const DUSK_END := 19 * 60     # 19:00 — fully dusk
const NIGHT_START := 21 * 60  # 21:00 — fully night, holds until curfew (2 AM/26:00)

## Gray-blue rain factor, multiplied component-wise into the day/night tint.
const RAIN_TINT := Color(0.75, 0.8, 0.95)

var _weather_exempt := false  # true on dungeon floors — no rain tint below ground


func _ready() -> void:
	# Named methods only — this node can outlive individual scenes only in the
	# sense that it's re-instanced per map (see AUTO_INSTANCE_SCRIPTS), so a
	# fresh connection each _ready() is correct and never double-connects.
	EventBus.time_ticked.connect(_on_time_ticked)
	EventBus.day_passed.connect(_on_day_passed)
	EventBus.weather_changed.connect(_on_weather_changed)
	_weather_exempt = get_parent() != null and get_parent().is_in_group("dungeon_map")
	color = _current_tint()  # instant set: mid-day loads shouldn't fade in


func _on_time_ticked(_hour, _minute) -> void:
	color = _current_tint()


func _on_day_passed(_day) -> void:
	color = _current_tint()


func _on_weather_changed(_weather) -> void:
	color = _current_tint()


func _current_tint() -> Color:
	var c := tint_for_minutes(Clock.minutes)
	if Clock.is_raining() and not _weather_exempt:
		c = rain_tinted(c)
	return c


static func tint_for_minutes(m: int) -> Color:
	if m <= DUSK_START:
		return WHITE
	if m < DUSK_END:
		var t: float = float(m - DUSK_START) / float(DUSK_END - DUSK_START)
		return WHITE.lerp(DUSK, t)
	if m < NIGHT_START:
		var t2: float = float(m - DUSK_END) / float(NIGHT_START - DUSK_END)
		return DUSK.lerp(NIGHT, t2)
	return NIGHT


static func rain_tinted(c: Color) -> Color:
	## Component-wise multiply of the rain factor into a computed tint.
	return Color(c.r * RAIN_TINT.r, c.g * RAIN_TINT.g, c.b * RAIN_TINT.b, c.a)
