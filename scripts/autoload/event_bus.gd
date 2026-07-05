extends Node
## Global signal hub. Signals only — no logic, no state.
## Params are untyped on purpose: EventBus loads before resource classes.

signal time_ticked(hour, minute)
signal day_passed(day)
signal weather_changed(weather)
signal curfew_reached
signal money_changed(gold)
signal stats_changed
signal player_leveled(level)
signal player_died
signal enemy_died(data, position)
signal item_shipped(item_id, count)
signal inventory_changed
signal hotbar_selection_changed(index)
signal boss_defeated
signal toast_requested(message)
signal camera_shake(strength)
