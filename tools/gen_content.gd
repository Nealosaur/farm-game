extends SceneTree
## Writes all slice content as .tres files under res://data/.
## Rerun to regenerate (overwrites). Values come from the design spec.
## Run AFTER an --import pass (needs placeholder icons + class names).

func _init() -> void:
	for d in ["res://data/items", "res://data/crops", "res://data/enemies"]:
		DirAccess.make_dir_recursive_absolute(d)

	# Seeds — sell = half of buy, rounded down (eggplant 45 -> 22).
	_seed("turnip_seeds", "Turnip Seeds", 20, 10, "turnip")
	_seed("carrot_seeds", "Carrot Seeds", 40, 20, "carrot")
	_seed("strawberry_seeds", "Strawberry Seeds", 90, 45, "strawberry")
	_seed("tomato_seeds", "Tomato Seeds", 60, 30, "tomato")
	_seed("corn_seeds", "Corn Seeds", 80, 40, "corn")
	_seed("melon_seeds", "Melon Seeds", 120, 60, "melon")
	_seed("pumpkin_seeds", "Pumpkin Seeds", 80, 40, "pumpkin")
	_seed("eggplant_seeds", "Eggplant Seeds", 45, 22, "eggplant")
	_seed("amberleaf_seeds", "Amberleaf Seeds", 100, 50, "amberleaf")

	_food("turnip", "Turnip", 45, 30, 0)
	_food("carrot", "Carrot", 105, 50, 0)
	_food("strawberry", "Strawberry", 130, 45, 0)
	_food("tomato", "Tomato", 90, 40, 0)
	_food("corn", "Corn", 100, 55, 0)
	_food("melon", "Melon", 320, 90, 15)
	_food("pumpkin", "Pumpkin", 250, 80, 20)
	_food("eggplant", "Eggplant", 95, 45, 0)
	_food("amberleaf", "Amberleaf", 260, 70, 0)

	# Forage (World Stride A: data + placeholders only — map spawn points
	# arrive in a later stride). Edibles are FoodData; shore finds sell-only.
	_food("wildroot", "Wildroot", 35, 25, 0)
	_food("emberberry", "Emberberry", 60, 40, 0)
	_food("frostcap", "Frostcap", 75, 50, 0)
	_material("tideshell", "Tideshell", 45)
	_material("driftglass", "Driftglass", 80)

	_tool("hoe", "Hoe", ToolData.ToolType.HOE, 4, 0, 0)
	_tool("watering_can", "Watering Can", ToolData.ToolType.WATERING_CAN, 2, 0, 0)
	_tool("wooden_sword", "Wooden Sword", ToolData.ToolType.SWORD, 3, 5, 0)
	_tool("iron_sword", "Iron Sword", ToolData.ToolType.SWORD, 3, 11, 2500)

	_material("slime_gel", "Slime Gel", 15)
	_material("wisp_dust", "Wisp Dust", 25)
	_material("goblin_fang", "Goblin Fang", 40)

	# Crops: stage_days sums to the bible's grow time (3-stage convention,
	# split roughly even with the remainder on later stages, matching the
	# existing turnip/carrot/pumpkin shapes). seasons: 0 Spring, 1 Summer,
	# 2 Fall, 3 Winter. regrow 0 = single harvest.
	_crop("turnip", [1, 1, 1], "turnip", [0], 0)
	_crop("carrot", [1, 2, 2], "carrot", [0], 0)
	_crop("strawberry", [2, 2, 3], "strawberry", [0], 3)
	_crop("tomato", [2, 2, 2], "tomato", [1], 4)
	_crop("corn", [2, 3, 3], "corn", [1], 4)
	_crop("melon", [3, 3, 4], "melon", [1], 0)
	_crop("pumpkin", [2, 3, 3], "pumpkin", [2], 0)  # MOVED to fall (World Stride A)
	_crop("eggplant", [2, 2, 2], "eggplant", [2], 0)
	_crop("amberleaf", [3, 3, 3], "amberleaf", [2], 0)

	_enemy("slime", "Slime", 20, 4, 40.0, 8, 2, 5, "slime_gel", 0.5)
	_enemy("wisp", "Wisp", 14, 6, 60.0, 12, 4, 8, "wisp_dust", 0.5)
	_enemy("goblin", "Goblin", 35, 10, 45.0, 20, 8, 15, "goblin_fang", 0.4)
	_enemy("slime_king", "Slime King", 300, 14, 30.0, 150, 200, 300, "slime_gel", 1.0)

	print("content written")
	quit(0)


func _icon(id: String) -> Texture2D:
	return load("res://assets/placeholder/item_%s.png" % id)


func _save(r: Resource, rel: String) -> void:
	var err := ResourceSaver.save(r, "res://data/" + rel)
	assert(err == OK, "Failed to save " + rel)


func _seed(id: String, name: String, buy: int, sell: int, crop: String) -> void:
	var r := SeedData.new()
	r.id = id
	r.display_name = name
	r.icon = _icon(id)
	r.buy_price = buy
	r.sell_price = sell
	r.crop_id = crop
	_save(r, "items/%s.tres" % id)


func _food(id: String, name: String, sell: int, rp: int, hp: int) -> void:
	var r := FoodData.new()
	r.id = id
	r.display_name = name
	r.icon = _icon(id)
	r.sell_price = sell
	r.rp_restore = rp
	r.hp_restore = hp
	_save(r, "items/%s.tres" % id)


func _tool(id: String, name: String, type: ToolData.ToolType, rp_cost: int, damage: int, buy: int) -> void:
	var r := ToolData.new()
	r.id = id
	r.display_name = name
	r.icon = _icon(id)
	r.max_stack = 1
	r.buy_price = buy
	r.tool_type = type
	r.rp_cost = rp_cost
	r.damage = damage
	_save(r, "items/%s.tres" % id)


func _material(id: String, name: String, sell: int) -> void:
	var r := ItemData.new()
	r.id = id
	r.display_name = name
	r.icon = _icon(id)
	r.sell_price = sell
	_save(r, "items/%s.tres" % id)


func _crop(id: String, stages: Array[int], product: String,
		seasons: Array[int], regrow: int) -> void:
	var r := CropData.new()
	r.id = id
	r.stage_days = stages
	r.product_id = product
	r.seasons = seasons
	r.regrow_days = regrow
	_save(r, "crops/%s.tres" % id)


func _enemy(id: String, name: String, hp: int, dmg: int, speed: float, xp: int,
		gmin: int, gmax: int, drop: String, chance: float) -> void:
	var r := EnemyData.new()
	r.id = id
	r.display_name = name
	r.max_hp = hp
	r.damage = dmg
	r.speed = speed
	r.xp = xp
	r.gold_min = gmin
	r.gold_max = gmax
	r.drop_item_id = drop
	r.drop_chance = chance
	_save(r, "enemies/%s.tres" % id)
