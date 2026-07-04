class_name PlaceholderFrames
extends RefCounted
## Builds a SpriteFrames where every named animation is the same single
## placeholder frame. Real art later replaces this with authored SpriteFrames;
## animation NAMES are the stable contract (spec §12).


static func build(tex: Texture2D, names: PackedStringArray) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for n in names:
		sf.add_animation(n)
		sf.add_frame(n, tex)
		sf.set_animation_speed(n, 5.0)
	return sf
