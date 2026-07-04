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
## Areas:  player_hitbox monitors enemy_hurtbox only (mask 7).
##         enemy_hitbox monitors player_hurtbox only (mask 5).
##         hurtboxes are monitorABLE (detected) but do not themselves monitor
##         anything besides catching the opposing hitbox's area_entered signal.

const WORLD := 1
const PLAYER_BODY := 2
const ENEMY_BODY := 3
const PLAYER_HITBOX := 4
const PLAYER_HURTBOX := 5
const ENEMY_HITBOX := 6
const ENEMY_HURTBOX := 7


static func bit(layer_number: int) -> int:
	return 1 << (layer_number - 1)
