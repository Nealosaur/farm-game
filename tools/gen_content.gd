extends SceneTree
## Writes all slice content as .tres files under res://data/.
## Rerun to regenerate (overwrites). Values come from the design spec.
## Run AFTER an --import pass (needs placeholder icons + class names).

func _init() -> void:
	for d in ["res://data/items", "res://data/crops", "res://data/enemies", "res://data/recipes"]:
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

	# Craft Stride 2 (Forging) — Sten's smithy upgrades. All forge-only
	# (buy_price 0 = "not sold", per the bible: granted by ForgeLogic.upgrade(),
	# never Marta's shop) and max_stack 1 (swords/cans/hoes are equipment,
	# never stack — matches every existing ToolData). water_width/till_width
	# default to 1 for every tool except the wide-area tiers below.
	_tool("steel_sword", "Steel Sword", ToolData.ToolType.SWORD, 3, 16, 0)
	_tool("fangsteel_blade", "Fangsteel Blade", ToolData.ToolType.SWORD, 3, 22, 0)
	_tool_watering_can("copper_can", "Copper Watering Can", 3, 3)

	# DEPTH stride: the tool-tier ladder extends to a "gold" capstone on every
	# tool (bible: "copper -> steel -> gold style tiers") — a gold-equivalent
	# sword (iridium_blade, past the masterwork-gated fangsteel), a wider
	# golden watering can (width 5, past copper's width 3), and a brand-new
	# hoe ladder (copper_hoe width 3, golden_hoe width 5) mirroring the can's
	# shape exactly. rp_cost holds steady per tool family (upgrades trade
	# materials/gold for AREA, not cheaper RP, per the bible's "area/
	# efficiency gains" framing landing on area here).
	_tool("iridium_blade", "Iridium Blade", ToolData.ToolType.SWORD, 3, 30, 0)
	_tool_watering_can("golden_can", "Golden Watering Can", 3, 5)
	_tool_hoe("copper_hoe", "Copper Hoe", 4, 3)
	_tool_hoe("golden_hoe", "Golden Hoe", 4, 5)

	# DEPTH stride: Fishing Rod — sold at Marta's (buy_price > 0, unlike the
	# forge-only tiers above), rp_cost 0 (bible: "fail loses nothing but the
	# cast" — the RP cost model is for farm-tool/combat actions, casting a
	# line isn't one).
	_tool("fishing_rod", "Fishing Rod", ToolData.ToolType.FISHING_ROD, 0, 0, 300)

	_material("slime_gel", "Slime Gel", 15)
	_material("wisp_dust", "Wisp Dust", 25)
	_material("goblin_fang", "Goblin Fang", 40)

	# DEPTH stride: fish species (FoodData — sellable, most edible). River
	# (Riverwoods) vs sea (Beach) pools, rarity-weighted in FishingLogic's
	# RIVER_POOL/SEA_POOL (common -> uncommon -> rare, matching the sell-price
	# ladder below). Pufferfish is sell-only (hp_restore/rp_restore 0 — a fugu
	# joke fish, matches the "some edible" bible wording implying not all are).
	_food("rivertrout", "Rivertrout", 70, 35, 0)
	_food("bluegill", "Bluegill", 90, 40, 0)
	_food("eel", "Eel", 180, 60, 10)
	_food("sardine", "Sardine", 60, 30, 0)
	_food("bass", "Bass", 100, 45, 0)
	_food("pufferfish", "Pufferfish", 220, 0, 0)

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

	# Craft Stride 3 (Taming): slime is tameable, favorite food turnip (bible:
	# "EnemyData: slime gets tameable=true, favorite_food='turnip'"). Wisp,
	# goblin, and the boss stay untameable this phase (defaults apply).
	_enemy("slime", "Slime", 20, 4, 40.0, 8, 2, 5, "slime_gel", 0.5, true, "turnip")
	_enemy("wisp", "Wisp", 14, 6, 60.0, 12, 4, 8, "wisp_dust", 0.5)
	_enemy("goblin", "Goblin", 35, 10, 45.0, 20, 8, 15, "goblin_fang", 0.4)
	_enemy("slime_king", "Slime King", 300, 14, 30.0, 150, 200, 300, "slime_gel", 1.0)

	# Craft Stride 1 — Cooking. Dishes (FoodData, is_dish=true) + recipes
	# (RecipeData). Sell price = round(sum of ingredient sell_price * 1.25)
	# per the bible's "sell ≈ sum of ingredients +25%, rounded" rule.
	_dish("roast_turnip", "Roast Turnip", 113, 70, 0, 0)
	_dish("carrot_soup", "Carrot Soup", 263, 90, 10, 0)
	_dish("berry_jam", "Berry Jam", 488, 80, 0, 0)
	_dish("corn_chowder", "Corn Chowder", 381, 120, 20, 0)
	_dish("melon_sorbet", "Melon Sorbet", 400, 140, 0, 0)
	_dish("pumpkin_pie", "Pumpkin Pie", 438, 160, 40, 0)
	_dish("forest_stew", "Forest Stew", 163, 110, 25, 0)
	_dish("miners_meal", "Miner's Meal", 213, 100, 0, 2)

	_recipe("roast_turnip", {"turnip": 2}, "roast_turnip")
	_recipe("carrot_soup", {"carrot": 2}, "carrot_soup")
	_recipe("berry_jam", {"strawberry": 3}, "berry_jam")
	_recipe("corn_chowder", {"corn": 2, "carrot": 1}, "corn_chowder")
	_recipe("melon_sorbet", {"melon": 1}, "melon_sorbet")
	_recipe("pumpkin_pie", {"pumpkin": 1, "corn": 1}, "pumpkin_pie")
	_recipe("forest_stew", {"wildroot": 2, "emberberry": 1}, "forest_stew")
	_recipe("miners_meal", {"frostcap": 1, "eggplant": 1}, "miners_meal")

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


func _dish(id: String, name: String, sell: int, rp: int, hp: int, attack_bonus: int) -> void:
	## Cooked dish (Craft Stride 1): uses the "dish_<id>" placeholder icon
	## (circle-with-dot, distinct from raw produce's plain circle — see
	## gen_placeholders.gd's KIND_CIRCLE_DOT).
	var r := FoodData.new()
	r.id = id
	r.display_name = name
	r.icon = load("res://assets/placeholder/dish_%s.png" % id)
	r.sell_price = sell
	r.rp_restore = rp
	r.hp_restore = hp
	r.attack_bonus = attack_bonus
	r.is_dish = true
	_save(r, "items/%s.tres" % id)


func _recipe(id: String, ingredients: Dictionary, result_id: String) -> void:
	var r := RecipeData.new()
	r.id = id
	r.ingredients = ingredients
	r.result_id = result_id
	_save(r, "recipes/%s.tres" % id)


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


func _tool_watering_can(id: String, name: String, rp_cost: int, water_width: int) -> void:
	## Craft Stride 2: Copper Watering Can — same shape as _tool() but also
	## sets water_width (see tool_data.gd's field doc). Kept as its own small
	## helper rather than adding a rarely-used parameter to every _tool() call
	## site (every OTHER tool, present and future non-can, is water_width 1
	## by the field's own default).
	var r := ToolData.new()
	r.id = id
	r.display_name = name
	r.icon = _icon(id)
	r.max_stack = 1
	r.buy_price = 0
	r.tool_type = ToolData.ToolType.WATERING_CAN
	r.rp_cost = rp_cost
	r.water_width = water_width
	_save(r, "items/%s.tres" % id)


func _tool_hoe(id: String, name: String, rp_cost: int, till_width: int) -> void:
	## DEPTH stride: Copper/Golden Hoe — same shape as _tool_watering_can()
	## but sets till_width instead of water_width (see tool_data.gd's field
	## doc). Kept as its own small helper for the same reason as
	## _tool_watering_can(): every OTHER tool stays till_width 1 by the
	## field's own default.
	var r := ToolData.new()
	r.id = id
	r.display_name = name
	r.icon = _icon(id)
	r.max_stack = 1
	r.buy_price = 0
	r.tool_type = ToolData.ToolType.HOE
	r.rp_cost = rp_cost
	r.till_width = till_width
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
		gmin: int, gmax: int, drop: String, chance: float,
		tameable: bool = false, favorite_food: String = "") -> void:
	## Craft Stride 3 (Taming): tameable/favorite_food default false/"" so the
	## three existing untameable calls (wisp/goblin/slime_king) don't need
	## edits — only slime's call site below passes the taming pair.
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
	r.tameable = tameable
	r.favorite_food = favorite_food
	_save(r, "enemies/%s.tres" % id)
