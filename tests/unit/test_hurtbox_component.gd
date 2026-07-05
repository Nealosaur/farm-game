extends GutTest
## Drives HurtboxComponent's own _on_area_entered directly rather than
## relying on physics overlap detection — faster and deterministic, per the
## combat-foundation test guidance ("drive timers manually").

var hurtbox: HurtboxComponent
var hitbox: HitboxComponent
var owner_node: Node2D


func before_each() -> void:
	owner_node = Node2D.new()
	add_child_autofree(owner_node)

	hurtbox = HurtboxComponent.new()
	hurtbox.iframe_duration = 0.4
	owner_node.add_child(hurtbox)
	hurtbox.owner = owner_node

	hitbox = HitboxComponent.new()
	hitbox.damage = 7
	hitbox.knockback_force = 100.0
	add_child_autofree(hitbox)
	hitbox.global_position = owner_node.global_position + Vector2(10, 0)


func test_hit_emits_hit_taken_with_damage_and_knockback_away_from_hitbox() -> void:
	watch_signals(hurtbox)
	hurtbox._on_area_entered(hitbox)
	assert_signal_emitted(hurtbox, "hit_taken")
	var params = get_signal_parameters(hurtbox, "hit_taken")
	assert_eq(params[0], 7)
	assert_almost_eq(params[1].x, -100.0, 0.01)  # owner is left of hitbox -> knocked further left


func test_hit_starts_iframes() -> void:
	hurtbox._on_area_entered(hitbox)
	assert_true(hurtbox.is_invincible())


func test_second_hit_during_iframes_is_ignored() -> void:
	watch_signals(hurtbox)
	hurtbox._on_area_entered(hitbox)
	hurtbox._on_area_entered(hitbox)
	assert_signal_emit_count(hurtbox, "hit_taken", 1)


func test_iframes_expire_after_duration() -> void:
	hurtbox._on_area_entered(hitbox)
	assert_true(hurtbox.is_invincible())
	await wait_seconds(0.45)
	assert_false(hurtbox.is_invincible())


func test_hit_after_iframes_expire_is_registered() -> void:
	watch_signals(hurtbox)
	hurtbox._on_area_entered(hitbox)
	await wait_seconds(0.45)
	hurtbox._on_area_entered(hitbox)
	assert_signal_emit_count(hurtbox, "hit_taken", 2)


func test_trigger_iframes_directly_for_dodge_use() -> void:
	hurtbox.trigger_iframes(0.2)
	assert_true(hurtbox.is_invincible())
	await wait_seconds(0.25)
	assert_false(hurtbox.is_invincible())


func test_non_hitbox_area_is_ignored() -> void:
	watch_signals(hurtbox)
	var plain_area := Area2D.new()
	add_child_autofree(plain_area)
	hurtbox._on_area_entered(plain_area)
	assert_signal_not_emitted(hurtbox, "hit_taken")


func test_hit_flashes_owner_modulate_white_on_impact() -> void:
	owner_node.modulate = Color.WHITE
	hurtbox._on_area_entered(hitbox)
	# Impact frame: modulate spiked above 1.0 (blown-out white), not the resting color.
	assert_true(owner_node.modulate.r > 1.0, "modulate should spike above 1.0 on the impact frame")


func test_flash_settles_back_to_opaque_white() -> void:
	owner_node.modulate = Color.WHITE
	hurtbox._on_area_entered(hitbox)
	await wait_seconds(HurtboxComponent.FLASH_DURATION + 0.05)
	assert_almost_eq(owner_node.modulate.r, 1.0, 0.01)
