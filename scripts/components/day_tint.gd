class_name DayTint
extends CanvasModulate
## Day/night visual: whole-scene tint driven by Clock. Full white 6:00-16:00,
## lerps to warm dusk by 19:00, to dark blue night by 21:00, holds to curfew
## (2 AM). Indoor-less game (spec) — this applies to every map, so it lives in
## AUTO_INSTANCE_SCRIPTS (and farm.gd's inline copy) alongside HUD/DayFlow.
## Pure curve logic is a static func so it's unit-testable without a live tree.

const WHITE := Color(1.0, 1.0, 1.0)
const DUSK := Color(1.0, 0.75, 0.55)
const NIGHT := Color(0.35, 0.4, 0.6)

const DUSK_START := 16 * 60   # 16:00
const DUSK_END := 19 * 60     # 19:00 — fully dusk
const NIGHT_START := 21 * 60  # 21:00 — fully night, holds until curfew (2 AM/26:00)


func _ready() -> void:
	# Named methods only — this node can outlive individual scenes only in the
	# sense that it's re-instanced per map (see AUTO_INSTANCE_SCRIPTS), so a
	# fresh connection each _ready() is correct and never double-connects.
	EventBus.time_ticked.connect(_on_time_ticked)
	EventBus.day_passed.connect(_on_day_passed)
	color = tint_for_minutes(Clock.minutes)  # instant set: mid-day loads shouldn't fade in


func _on_time_ticked(_hour, _minute) -> void:
	color = tint_for_minutes(Clock.minutes)


func _on_day_passed(_day) -> void:
	color = tint_for_minutes(Clock.minutes)


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
