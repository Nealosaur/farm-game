class_name GroundShadow
extends RefCounted
## LOOK V2: a small flat dark ellipse shadow, built as its OWN node (a
## Polygon2D) rather than baked into the animated sheet, so it stays put at
## the character's feet and doesn't get swapped/hidden/flipped along with the
## AnimatedSprite2D's frame — and doesn't participate in the sprite's Y-sort
## the way a shadow drawn INTO a frame would if this project ever turns on
## per-node Y-sorting above the character.
##
## Usage: GroundShadow.attach(self, Vector2(0, 4), Vector2(14, 6)) in a
## character's _ready() — adds a low-opacity ellipse Polygon2D named
## "GroundShadow" as a child, positioned at `offset` (character-local space,
## typically a few px below the sprite's feet) sized `size` (width, height).

const SEGMENTS := 12
const ALPHA := 0.4


static func attach(parent: Node2D, offset: Vector2, size: Vector2) -> Polygon2D:
	var shadow := Polygon2D.new()
	shadow.name = "GroundShadow"
	shadow.color = Color(0.0, 0.0, 0.0, ALPHA)
	shadow.polygon = _ellipse_points(size.x * 0.5, size.y * 0.5)
	shadow.position = offset
	shadow.z_as_relative = false
	shadow.z_index = -1  # stays visually under the character's own sprite
	parent.add_child(shadow)
	parent.move_child(shadow, 0)  # first child: draws under any sprite added after it
	return shadow


static func _ellipse_points(rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in SEGMENTS:
		var t := TAU * float(i) / float(SEGMENTS)
		pts.append(Vector2(cos(t) * rx, sin(t) * ry))
	return pts
