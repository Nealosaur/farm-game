class_name ParticleFX
extends RefCounted
## FEEL Stride 3: thin one-shot particle spawner built on CPUParticles2D.
## Every spawn_* helper here builds a small, self-freeing burst from a
## pre-generated texture in res://assets/particles/ (see tools/gen_particles.gd)
## and adds it under `parent` at `world_pos` (GLOBAL position — callers pass
## global_position, not a local offset, so the particle survives its emitter
## being freed/reparented without moving).
##
## Self-freeing: `one_shot = true` + `emitting = true` fires exactly `amount`
## particles once; a SceneTreeTimer slightly longer than lifetime+duration
## queue_frees the node so nothing is left orphaned in the tree. Guards
## `is_instance_valid` in the timer callback in case `parent` itself was
## already freed by the time the timer fires (e.g. a scene swap mid-burst).

const TEX_DIR := "res://assets/particles/"

## Small cache so repeated spawns (e.g. every footstep) don't re-load the same
## PNG from disk each time.
static var _tex_cache: Dictionary = {}


static func _tex(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var tex := load(TEX_DIR + name + ".png") as Texture2D
	_tex_cache[name] = tex
	return tex


## Generic one-shot burst builder shared by every spawn_* below.
static func _burst(parent: Node, world_pos: Vector2, texture_name: String,
		amount: int, lifetime: float, spread_deg: float, velocity_min: float, velocity_max: float,
		scale_min: float, scale_max: float, gravity: Vector2 = Vector2.ZERO) -> CPUParticles2D:
	if parent == null or not is_instance_valid(parent):
		return null
	var p := CPUParticles2D.new()
	p.texture = _tex(texture_name)
	p.global_position = world_pos
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = spread_deg
	p.initial_velocity_min = velocity_min
	p.initial_velocity_max = velocity_max
	p.scale_amount_min = scale_min
	p.scale_amount_max = scale_max
	p.gravity = gravity
	p.emitting = true
	parent.add_child(p)
	var timer := p.get_tree().create_timer(lifetime + 0.2)
	# Close over the INSTANCE ID (an int), not the Node itself: capturing the
	# Node directly makes Godot null the lambda's own capture slot the moment
	# the node is freed (e.g. a scene swap mid-burst) and print an "Unexpected
	# Errors"-level warning even though the null-check below handles it fine
	# — capturing a plain int sidesteps that entirely, and
	# instance_from_id/is_instance_id_valid is the standard "might already be
	# gone" lookup pattern.
	var id := p.get_instance_id()
	timer.timeout.connect(func() -> void:
		if is_instance_id_valid(id):
			(instance_from_id(id) as Node).queue_free()
	)
	return p


## ---- footstep dust (walk cadence) ----
static func spawn_dust(parent: Node, world_pos: Vector2) -> CPUParticles2D:
	return _burst(parent, world_pos, "dust", 3, 0.35, 40.0, 4.0, 10.0, 0.6, 1.1)


## ---- till (dirt clods flung up) ----
static func spawn_till(parent: Node, world_pos: Vector2) -> CPUParticles2D:
	return _burst(parent, world_pos, "dirt_clod", 6, 0.4, 60.0, 16.0, 32.0, 0.8, 1.3, Vector2(0, 140))


## ---- watering (droplets) ----
static func spawn_water(parent: Node, world_pos: Vector2) -> CPUParticles2D:
	return _burst(parent, world_pos, "water_droplet", 5, 0.45, 50.0, 12.0, 26.0, 0.8, 1.2, Vector2(0, 160))


## ---- harvest (leaf/crop burst) ----
static func spawn_harvest(parent: Node, world_pos: Vector2) -> CPUParticles2D:
	return _burst(parent, world_pos, "leaf", 7, 0.5, 360.0, 14.0, 30.0, 0.8, 1.3, Vector2(0, 60))


## ---- landed hit (impact spark/pop) ----
static func spawn_hit(parent: Node, world_pos: Vector2) -> CPUParticles2D:
	return _burst(parent, world_pos, "impact_spark", 5, 0.25, 360.0, 20.0, 44.0, 0.9, 1.4)


## ---- enemy death (slime splat) ----
static func spawn_death_splat(parent: Node, world_pos: Vector2) -> CPUParticles2D:
	return _burst(parent, world_pos, "slime_splat", 4, 0.5, 360.0, 8.0, 22.0, 0.9, 1.5, Vector2(0, 100))


## ---- pickup collect (sparkle) ----
static func spawn_sparkle(parent: Node, world_pos: Vector2) -> CPUParticles2D:
	return _burst(parent, world_pos, "sparkle", 6, 0.4, 360.0, 10.0, 24.0, 0.8, 1.2)


## ---- sword-swing arc ----
## Unlike the bursts above, the swing arc is a single short-lived SPRITE (not
## a particle scatter) rotated to face the swing direction, since it's meant
## to read as one coherent steel-catching-light shape, not scattered dots.
## `facing` is a unit-ish Vector2 (Player.facing cast to float, e.g.
## Vector2(1,0)) — the source texture's arc sweeps from +x (right) counter-
## clockwise, so rotation = facing.angle() aims it at the swing direction.
const SWING_ARC_DURATION := 0.12


static func spawn_swing_arc(parent: Node, world_pos: Vector2, facing: Vector2) -> Sprite2D:
	if parent == null or not is_instance_valid(parent):
		return null
	var s := Sprite2D.new()
	s.texture = _tex("swing_arc")
	s.global_position = world_pos
	s.rotation = facing.angle()
	s.modulate.a = 0.9
	parent.add_child(s)
	var tween := s.create_tween()
	tween.tween_property(s, "modulate:a", 0.0, SWING_ARC_DURATION)
	# See spawn_dust's _burst helper above for why this closes over an
	# instance ID rather than `s` directly.
	var id := s.get_instance_id()
	tween.tween_callback(func() -> void:
		if is_instance_id_valid(id):
			(instance_from_id(id) as Node).queue_free()
	)
	return s
