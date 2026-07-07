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
## FEEL Stride 6: `delta` (the signed points change, e.g. +15/+80/-20) added
## so the floating bond-number feedback (BondNumber/wherever it listens) can
## show the right amount — see Relationships._add_points, the single funnel
## every talk/gift/heart-event/flat-bond call routes through.
signal relationship_changed(npc_id, delta)
signal quest_updated(quest_id)
