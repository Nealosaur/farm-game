extends SceneTree
## FEEL Stride 3: small particle textures for the one-shot juice emitters
## (ParticleFX.spawn_* — see scripts/components/particle_fx.gd). Follows the
## same conventions as tools/gen_placeholders.gd: PixelArt primitives only,
## fully deterministic (no Date/random — any variation seeded via
## PixelArt.hash_seed), rerun -> git status clean.
##
## Every texture here is a TINY (4-8px) single-frame sprite meant to be
## scaled/rotated/tinted by the CPUParticles2D or AnimatedSprite2D that uses
## it, not a multi-frame sheet — juice particles are simple dots/blobs/arcs,
## not characters.
##
## Run: "$GODOT" --headless --path . -s res://tools/gen_particles.gd
## Emits the mandatory review contact sheet to tools/_proto/particles_6x.png.

const OUT := "res://assets/particles/"
const PROTO_OUT := "res://tools/_proto/"


func _init() -> void:
	var dir_err := DirAccess.make_dir_recursive_absolute(OUT)
	assert(dir_err == OK, "Cannot create " + OUT)
	DirAccess.make_dir_recursive_absolute(PROTO_OUT)

	var entries: Array = []

	entries.append(_entry("dust", _dust()))
	entries.append(_entry("dirt_clod", _dirt_clod()))
	entries.append(_entry("water_droplet", _water_droplet()))
	entries.append(_entry("leaf", _leaf()))
	entries.append(_entry("impact_spark", _impact_spark()))
	entries.append(_entry("slime_splat", _slime_splat()))
	entries.append(_entry("sparkle", _sparkle()))
	entries.append(_entry("swing_arc", _swing_arc()))

	for e: Dictionary in entries:
		_save(OUT + String(e["name"]) + ".png", e["image"])

	_write_contact_sheet(entries)
	print("particles written: ", entries.size())
	quit(0)


func _entry(name: String, img: Image) -> Dictionary:
	return {"name": name, "image": img, "tick_color": PixelArt.average_color(img)}


## ---- individual particle textures ----

## Small pale puff — a soft off-white/tan blob, no outline (outlines read as
## hard edges; a puff should read soft). Used for the walk-cadence dust.
func _dust() -> Image:
	var img := PixelArt.blank(6, 6)
	var c := Color(0.82, 0.76, 0.62, 0.55)
	PixelArt.fill_circle(img, 3, 3, 2.4, c)
	PixelArt.fill_circle(img, 3, 3, 1.3, Color(0.88, 0.83, 0.7, 0.7))
	return img


## Small dark-brown irregular clod (a few offset squares, not a perfect
## circle) for the till puff — reads as flung dirt rather than smoke.
func _dirt_clod() -> Image:
	var img := PixelArt.blank(5, 5)
	var soil := Color("5a3f28")
	var soil_dark := Color("402c1c")
	PixelArt.rect(img, 1, 1, 3, 3, soil)
	PixelArt.px(img, 0, 2, soil)
	PixelArt.px(img, 3, 0, soil)
	PixelArt.px(img, 2, 3, soil_dark)
	PixelArt.px(img, 1, 3, soil_dark)
	return img


## A single teardrop-ish water droplet: pale blue circle + a brighter
## highlight pixel, translucent so several overlapping droplets don't look
## like a solid blob.
func _water_droplet() -> Image:
	var img := PixelArt.blank(4, 4)
	var body := Color(0.45, 0.65, 0.95, 0.8)
	var hi := Color(0.75, 0.88, 1.0, 0.9)
	PixelArt.fill_circle(img, 2, 2, 1.6, body)
	PixelArt.px(img, 1, 1, hi)
	return img


## A tiny green leaf fleck (asymmetric so it reads as organic, not a dot) for
## the harvest burst.
func _leaf() -> Image:
	var img := PixelArt.blank(5, 5)
	var leaf_c := Color("5a8a3a")
	var leaf_shade := Color("3f6a28")
	PixelArt.px(img, 2, 0, leaf_c)
	PixelArt.px(img, 1, 1, leaf_c)
	PixelArt.px(img, 2, 1, leaf_c)
	PixelArt.px(img, 3, 1, leaf_c)
	PixelArt.px(img, 1, 2, leaf_shade)
	PixelArt.px(img, 2, 2, leaf_c)
	PixelArt.px(img, 3, 2, leaf_shade)
	PixelArt.px(img, 2, 3, leaf_shade)
	return img


## Bright 4-point star/spark for a landed hit — white-hot core, warm-yellow
## points, no outline (outlines would deaden the "flash" read).
func _impact_spark() -> Image:
	var img := PixelArt.blank(7, 7)
	var core := Color(1.0, 0.98, 0.85, 1.0)
	var point_c := Color(1.0, 0.85, 0.35, 0.95)
	PixelArt.px(img, 3, 3, core)
	PixelArt.px(img, 3, 1, point_c)
	PixelArt.px(img, 3, 2, point_c)
	PixelArt.px(img, 3, 4, point_c)
	PixelArt.px(img, 3, 5, point_c)
	PixelArt.px(img, 1, 3, point_c)
	PixelArt.px(img, 2, 3, point_c)
	PixelArt.px(img, 4, 3, point_c)
	PixelArt.px(img, 5, 3, point_c)
	return img


## Small translucent green-blue blob-with-drip for the slime death splat —
## flatter/wider than the dust puff so it reads as "splashed on the ground"
## rather than airborne.
func _slime_splat() -> Image:
	var img := PixelArt.blank(8, 6)
	var body := Color("6ec87a")
	body.a = 0.75
	var shade := Color("4a9a58")
	shade.a = 0.75
	PixelArt.fill_ellipse(img, 4, 3, 3.5, 2.2, body)
	PixelArt.fill_ellipse(img, 4, 3.6, 3.5, 1.4, shade)
	PixelArt.px(img, 1, 1, body)
	PixelArt.px(img, 6, 1, body)
	return img


## A tiny 4-point sparkle (bright white/gold cross) for pickup collection —
## distinct from the impact spark by being purely warm/gold, softer edges,
## meant to read as "reward", not "damage".
func _sparkle() -> Image:
	var img := PixelArt.blank(5, 5)
	var c := Color(1.0, 0.95, 0.6, 1.0)
	var dim := Color(1.0, 0.9, 0.5, 0.55)
	PixelArt.px(img, 2, 2, c)
	PixelArt.px(img, 2, 0, dim)
	PixelArt.px(img, 2, 4, dim)
	PixelArt.px(img, 0, 2, dim)
	PixelArt.px(img, 4, 2, dim)
	PixelArt.px(img, 2, 1, c)
	PixelArt.px(img, 2, 3, c)
	PixelArt.px(img, 1, 2, c)
	PixelArt.px(img, 3, 2, c)
	return img


## A short curved arc (crescent-ish sliver) for the sword-swing trail — a
## bright edge on one side fading to transparent, so SwingArc can rotate it
## to face the swing direction and it reads as "steel catching light" for a
## couple frames.
func _swing_arc() -> Image:
	var img := PixelArt.blank(16, 16)
	var c := Color(0.92, 0.96, 1.0, 0.85)
	var dim := Color(0.85, 0.9, 1.0, 0.35)
	var cx := 8.0
	var cy := 8.0
	var r_outer := 7.2
	var r_inner := 4.8
	for y in 16:
		for x in 16:
			var dx := x + 0.5 - cx
			var dy := y + 0.5 - cy
			var dist := sqrt(dx * dx + dy * dy)
			if dist > r_inner and dist <= r_outer:
				# Only the upper-right quarter-arc (an ~90 degree swipe) —
				# angle measured from +x axis, negative-y is "up" in image space.
				var ang := atan2(-dy, dx)
				if ang >= 0.0 and ang <= PI * 0.5:
					var edge_t: float = (dist - r_inner) / (r_outer - r_inner)
					img.set_pixel(x, y, c if edge_t > 0.5 else dim)
	return img


## ---- save + review ----

func _save(path: String, img: Image) -> void:
	var err := img.save_png(path)
	assert(err == OK, "Failed to write " + path)


func _write_contact_sheet(entries: Array) -> void:
	var sheet := PixelArt.compose_contact_sheet(entries, 4, 6)
	sheet.save_png(PROTO_OUT + "particles_6x.png")
