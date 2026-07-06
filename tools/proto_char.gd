extends SceneTree
## Spike: prove we can generate REAL pixel-art characters parametrically
## (not flat rectangles). Draws a down-facing farmer + an 8x preview to eyeball.
## Run: godot --headless --path . -s res://tools/proto_char.gd

const OUT := "res://tools/_proto/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var img := _farmer_down()
	img.save_png(OUT + "farmer_down.png")
	_save_preview(img, "farmer_down_8x.png", 8)
	# a slime too, to test enemy style
	var slime := _slime()
	slime.save_png(OUT + "slime.png")
	_save_preview(slime, "slime_8x.png", 8)
	print("proto written")
	quit(0)


func _blank(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < img.get_width() and yy < img.get_height():
				img.set_pixel(xx, yy, c)


func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


## Adds a 1px dark outline around the silhouette + a soft ground shadow.
func _finish(img: Image, outline: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var edges: Array = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a < 0.5:
				# transparent pixel touching an opaque one -> outline
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx >= 0 and ny >= 0 and nx < w and ny < h and img.get_pixel(nx, ny).a >= 0.5:
						edges.append(Vector2i(x, y))
						break
	for e: Vector2i in edges:
		img.set_pixel(e.x, e.y, outline)


func _farmer_down() -> Image:
	var img := _blank(16, 32)
	var skin := Color("e8b88a")
	var skin_shade := Color("c99268")
	var hair := Color("6b4423")
	var shirt := Color("4a7ac0")
	var shirt_shade := Color("35609a")
	var pants := Color("33405a")
	var boots := Color("6b4a2f")
	var eyes := Color("2a2030")

	# ground shadow (drawn first, semi-transparent, NOT outlined)
	var shadow := Color(0, 0, 0, 0.28)
	for x in range(4, 12):
		_px(img, x, 30, shadow)
	for x in range(5, 11):
		_px(img, x, 31, shadow)

	# legs + boots
	_rect(img, 5, 22, 2, 6, pants)
	_rect(img, 9, 22, 2, 6, pants)
	_rect(img, 5, 28, 2, 2, boots)
	_rect(img, 9, 28, 2, 2, boots)
	# torso (shirt) with a shaded right side for volume
	_rect(img, 5, 15, 6, 7, shirt)
	_rect(img, 9, 15, 2, 7, shirt_shade)
	# arms
	_rect(img, 4, 15, 1, 5, skin)
	_rect(img, 11, 15, 1, 5, skin_shade)
	# head
	_rect(img, 5, 8, 6, 7, skin)
	_rect(img, 9, 8, 2, 7, skin_shade)
	# hair (cap + bangs)
	_rect(img, 5, 7, 6, 3, hair)
	_px(img, 4, 8, hair)
	_px(img, 11, 8, hair)
	_px(img, 4, 9, hair)
	_px(img, 11, 9, hair)
	# eyes
	_px(img, 6, 11, eyes)
	_px(img, 9, 11, eyes)

	_finish(img, Color("2b2233"))
	return img


func _slime() -> Image:
	var img := _blank(16, 16)
	var body := Color("5fcf5f")
	var body_shade := Color("3fa83f")
	var hi := Color("aef0ae")
	var eyes := Color("203020")
	var shadow := Color(0, 0, 0, 0.28)
	for x in range(3, 13):
		_px(img, x, 15, shadow)
	# dome body
	for y in range(6, 15):
		var half := int(3 + (y - 6) * 0.7)
		for x in range(8 - half, 9 + half):
			_px(img, x, y, body)
	# shaded lower-right
	for y in range(11, 15):
		var half2 := int(3 + (y - 6) * 0.7)
		for x in range(8, 9 + half2):
			_px(img, x, y, body_shade)
	# highlight + eyes
	_px(img, 6, 8, hi)
	_px(img, 7, 8, hi)
	_px(img, 6, 11, eyes)
	_px(img, 10, 11, eyes)
	_finish(img, Color("205020"))
	return img


func _save_preview(img: Image, name: String, scale: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var big := _blank(w * scale, h * scale)
	# checker background so transparency + shape are both visible
	var a := Color("3a3a46")
	var b := Color("2e2e38")
	for y in big.get_height():
		for x in big.get_width():
			big.set_pixel(x, y, a if ((x / 8 + y / 8) % 2 == 0) else b)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a >= 0.5:
				for sy in scale:
					for sx in scale:
						big.set_pixel(x * scale + sx, y * scale + sy, c)
	big.save_png(OUT + name)
