class_name NightVignette
extends CanvasLayer
## V3 (docs/design/visual-overhaul.md "day/night + season retune"): a subtle
## radial darkening at the screen edges that lifts during the day and
## thickens toward night, layered ON TOP of DayTint's CanvasModulate tint
## (which recolors/darkens the whole scene uniformly) to give night a bit of
## "the world falls away past the lamplight" depth without crushing the
## center of the screen unreadable — the actual tint math (readability) is
## still DayTint's job; this is a purely additive atmosphere layer.
##
## Same lifecycle contract as DayTint: instanced fresh per map (see
## MapSceneHelper.AUTO_INSTANCE_SCRIPTS), tracks Clock via named-method
## EventBus connections (auto-disconnect with the node), follows the SAME
## curve breakpoints as DayTint (dusk starts fading in, night is fully in) so
## the two effects move in lockstep instead of drifting apart.
##
## Full-rect coverage (not camera-relative): the TextureRect is anchored to
## the viewport, not the world, so the vignette always frames the SCREEN
## regardless of camera position — matches how a lens vignette actually
## behaves, not a world-space decal.

const MAX_ALPHA := 0.38  # night-time peak darkening at the far screen edges

var _rect: TextureRect


func _ready() -> void:
	layer = 12  # above DayTint's CanvasModulate (which isn't layer-ordered the
	# same way — CanvasModulate affects the whole canvas regardless of
	# CanvasLayer — but above the world layer (0) and below the HUD (10)/
	# dialog (15)/menus (20) so it never washes out UI text.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_rect = TextureRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.texture = _build_gradient_texture()
	add_child(_rect)

	EventBus.time_ticked.connect(_on_time_ticked)
	EventBus.day_passed.connect(_on_day_passed)
	_refresh()


func _on_time_ticked(_hour, _minute) -> void:
	_refresh()


func _on_day_passed(_day) -> void:
	_refresh()


func _refresh() -> void:
	_rect.modulate.a = night_factor(Clock.minutes)


## Pure curve: 0.0 in full daylight, ramps up across DayTint's own dusk/night
## breakpoints, 1.0 once fully night (holds to curfew) — same shape as
## DayTint.tint_for_minutes so the vignette and the color tint always finish
## fading together instead of one lagging the other.
static func night_factor(m: int) -> float:
	if m <= DayTint.DUSK_START:
		return 0.0
	if m < DayTint.DUSK_END:
		return float(m - DayTint.DUSK_START) / float(DayTint.DUSK_END - DayTint.DUSK_START) * 0.5
	if m < DayTint.NIGHT_START:
		var t: float = float(m - DayTint.DUSK_END) / float(DayTint.NIGHT_START - DayTint.DUSK_END)
		return lerp(0.5, 1.0, t)
	return 1.0


## Builds a radial GradientTexture2D once per instance: transparent center,
## MAX_ALPHA black at the edges. Code-built (no PNG asset) so it needs no
## generator step and is trivially reproducible.
static func _build_gradient_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0, 0, 0, 0.0),
		Color(0, 0, 0, 0.0),
		Color(0, 0, 0, MAX_ALPHA),
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex
