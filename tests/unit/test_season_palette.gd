extends GutTest
## World Stride A visuals: seasonal ground palette (SeasonPalette) and the
## rain factor DayTint multiplies into its day/night curve — plus the
## dungeon exemption for both.


func before_each() -> void:
	Clock.paused = true
	Clock.day = 1
	Clock.weather = "clear"
	Clock.minutes = Clock.DAY_START_MINUTES


func after_each() -> void:
	Clock.day = 1
	Clock.weather = "clear"
	Clock.minutes = Clock.DAY_START_MINUTES


# ---- SeasonPalette ----

func test_palette_colors_per_season() -> void:
	assert_eq(SeasonPalette.color_for_season(0), Color(1.0, 1.0, 1.0))
	assert_eq(SeasonPalette.color_for_season(1), Color(1.02, 1.0, 0.9))
	assert_eq(SeasonPalette.color_for_season(2), Color(1.1, 0.85, 0.6))
	assert_eq(SeasonPalette.color_for_season(3), Color(0.8, 0.85, 1.0))


func test_palette_applies_to_layer_and_tracks_day_passed() -> void:
	var layer := TileMapLayer.new()
	add_child_autofree(layer)
	var pal := SeasonPalette.new()
	add_child_autofree(pal)
	Clock.day = 57  # Fall
	pal.setup(layer)
	assert_eq(layer.modulate, SeasonPalette.color_for_season(2), "fall amber on setup")
	Clock.day = 85  # Winter — overnight season flip
	EventBus.day_passed.emit(85)
	assert_eq(layer.modulate, SeasonPalette.color_for_season(3), "winter pale after day_passed")


# ---- DayTint rain factor ----

func test_rain_tinted_multiplies_componentwise() -> void:
	var rained := DayTint.rain_tinted(DayTint.WHITE)
	assert_eq(rained, Color(0.75, 0.8, 0.95))
	var night := DayTint.rain_tinted(DayTint.NIGHT)
	assert_almost_eq(night.r, DayTint.NIGHT.r * 0.75, 0.0001)
	assert_almost_eq(night.g, DayTint.NIGHT.g * 0.8, 0.0001)
	assert_almost_eq(night.b, DayTint.NIGHT.b * 0.95, 0.0001)
	assert_eq(night.a, DayTint.NIGHT.a, "alpha untouched")


func test_day_tint_applies_rain_on_outdoor_maps() -> void:
	var host := Node2D.new()
	add_child_autofree(host)
	Clock.weather = "rain"
	Clock.minutes = 12 * 60  # noon: base curve is WHITE
	var tint := DayTint.new()
	host.add_child(tint)
	assert_eq(tint.color, Color(0.75, 0.8, 0.95), "noon rain = pure rain factor")


func test_day_tint_skips_rain_in_dungeons() -> void:
	var host := Node2D.new()
	host.add_to_group("dungeon_map")  # what DungeonFloor._ready() does
	add_child_autofree(host)
	Clock.weather = "rain"
	Clock.minutes = 12 * 60
	var tint := DayTint.new()
	host.add_child(tint)
	assert_eq(tint.color, DayTint.WHITE, "underground ignores the weather")


func test_day_tint_reacts_to_weather_changed() -> void:
	var host := Node2D.new()
	add_child_autofree(host)
	Clock.weather = "clear"
	Clock.minutes = 12 * 60
	var tint := DayTint.new()
	host.add_child(tint)
	assert_eq(tint.color, DayTint.WHITE)
	Clock.weather = "rain"
	EventBus.weather_changed.emit("rain")
	assert_eq(tint.color, Color(0.75, 0.8, 0.95), "tint recomputes when the weather turns")
