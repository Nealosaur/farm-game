class_name Layers
extends RefCounted
## Collision layer/mask scheme for the combat foundation. Bit numbers below are
## 1-indexed to match the Godot editor's Layer/Mask UI.
##
##   1  world        — solid tiles (walls/water), see MapBuilder.SOLID
##   2  player_body   — the player's CharacterBody2D
##   3  enemy_body    — enemy CharacterBody2D (enemies do NOT collide with each other)
##   4  player_hitbox — player's active weapon hitboxes (SwordHitbox)
##   5  player_hurtbox — the player's HurtboxComponent (receives enemy hits)
##   6  enemy_hitbox  — enemy contact/attack hitboxes
##   7  enemy_hurtbox — enemy HurtboxComponent (receives player sword hits)
##
## Bodies: player_body collides with world + enemy_body (mask 1|3).
##         enemy_body collides with world + player_body, NOT other enemies (mask 1|2).
## Areas:  Godot fires area_entered independently per side — each area's own
##         collision_mask decides what IT detects, regardless of the other
##         area's mask. So both sides of each pair need layer+mask set:
##           player_hitbox: layer=player_hitbox, mask=enemy_hurtbox
##           enemy_hurtbox: layer=enemy_hurtbox,  mask=player_hitbox
##           enemy_hitbox:  layer=enemy_hitbox,   mask=player_hurtbox
##           player_hurtbox: layer=player_hurtbox, mask=enemy_hitbox
##         HurtboxComponent connects its own area_entered AND polls
##         get_overlapping_areas() once per physics frame (Godot does not
##         retroactively fire area_entered for an Area2D whose
##         monitoring/monitorable flips on while already spatially
##         overlapping — the common case for a melee swing that activates
##         directly on top of a stationary target).

const WORLD := 1
const PLAYER_BODY := 2
const ENEMY_BODY := 3
const PLAYER_HITBOX := 4
const PLAYER_HURTBOX := 5
const ENEMY_HITBOX := 6
const ENEMY_HURTBOX := 7


static func bit(layer_number: int) -> int:
	return 1 << (layer_number - 1)
