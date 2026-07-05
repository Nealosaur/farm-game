class_name ArenaSeal
extends RefCounted
## Pure state machine for the boss arena gate: sealed/unsealed given events.
## Extracted from dungeon_3's scene-local wiring so the decision logic is
## unit-testable without a live scene tree (per spec). Scene-local because
## seal state must NOT survive into a fresh floor load — a respawned visit
## (post-collapse) always starts unsealed with a fresh ArenaSeal instance,
## even if the boss is still alive from before.
##
## Events: player_entered_arena() seals the gate (guarded so it only seals
## once); boss_defeated() and player_collapsed() both unseal (the fight is
## over, one way or another).

var sealed := false


func player_entered_arena() -> bool:
	## Returns true the moment the seal actually engages (false if already
	## sealed) — callers use this to know whether to place the wall blocker
	## and fire the toast, rather than re-doing it every physics frame the
	## player stands in the trigger area.
	if sealed:
		return false
	sealed = true
	return true


func boss_defeated() -> void:
	sealed = false


func player_collapsed() -> void:
	sealed = false
