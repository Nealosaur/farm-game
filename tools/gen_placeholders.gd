extends SceneTree
## Generates flat-color placeholder PNGs at final art dimensions.
## Rerun any time (it overwrites). Real art later replaces files, same names.
## Run: "$GODOT" --headless --path . -s res://tools/gen_placeholders.gd

const OUT := "res://assets/placeholder/"

const TILES := {
	"tile_grass": "4a7a3a",
	"tile_grass_dark": "3f6a31",
	"tile_soil_tilled": "6b4a2f",
	"tile_soil_watered": "4a3320",
	"tile_stone_floor": "6e6e78",
	"tile_wall": "3a3a44",
	"tile_water": "2f5f8f",
	"tile_path": "9a8a6a",
}

const SPRITES := {
	"char_player": [16, 32, "e0b070"],
	"char_shopkeeper": [16, 32, "c070c0"],
	"char_slime": [16, 16, "50c050"],
	"char_wisp": [16, 16, "70c0e0"],
	"char_goblin": [16, 24, "a05030"],
	"char_slime_king": [48, 48, "208020"],
	"prop_bed": [16, 24, "b03030"],
	"prop_shipping_bin": [16, 16, "8a5a2a"],
	"prop_stairs_down": [16, 16, "222230"],
	"prop_stairs_up": [16, 16, "d0d0e0"],
	"prop_house": [48, 48, "7a4a3a"],
	"prop_counter": [32, 16, "5a3a2a"],
	"item_turnip": [16, 16, "e8e0d0"],
	"item_carrot": [16, 16, "e07820"],
	"item_pumpkin": [16, 16, "d06010"],
	"item_turnip_seeds": [16, 16, "c8c0a0"],
	"item_carrot_seeds": [16, 16, "c09060"],
	"item_pumpkin_seeds": [16, 16, "b08040"],
	"item_hoe": [16, 16, "808890"],
	"item_watering_can": [16, 16, "4080b0"],
	"item_wooden_sword": [16, 16, "9a6a3a"],
	"item_iron_sword": [16, 16, "c0c8d0"],
	"item_slime_gel": [16, 16, "60d060"],
	"item_wisp_dust": [16, 16, "90d0f0"],
	"item_goblin_fang": [16, 16, "e0d0b0"],
}

# 4 growth-stage sprites per crop: stage 0 (seeded, soil brown) -> 3 (ripe, final color).
const CROPS := {
	"turnip": "e8e0d0",
	"carrot": "e07820",
	"pumpkin": "d06010",
}


func _init() -> void:
	var dir_err := DirAccess.make_dir_recursive_absolute(OUT)
	assert(dir_err == OK, "Cannot create " + OUT)
	var count := 0
	for n: String in TILES:
		_write(n, 16, 16, Color(TILES[n]))
		count += 1
	for n: String in SPRITES:
		var s: Array = SPRITES[n]
		_write(n, s[0], s[1], Color(s[2]))
		count += 1
	for c: String in CROPS:
		for stage in 4:
			var col := Color("6b4a2f").lerp(Color(CROPS[c]), stage / 3.0)
			_write("crop_%s_%d" % [c, stage], 16, 16, col)
			count += 1
	print("placeholders written: ", count)
	quit(0)


func _write(name: String, w: int, h: int, c: Color) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(c)
	var dark := c.darkened(0.4)
	for x in w:
		img.set_pixel(x, 0, dark)
		img.set_pixel(x, h - 1, dark)
	for y in h:
		img.set_pixel(0, y, dark)
		img.set_pixel(w - 1, y, dark)
	var err := img.save_png(OUT + name + ".png")
	assert(err == OK, "Failed to write " + name)
