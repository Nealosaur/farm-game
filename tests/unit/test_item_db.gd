extends GutTest


func test_content_loaded() -> void:
	# World Stride A: 6 new crops (strawberry/tomato/corn/melon/eggplant/
	# amberleaf -> 6 produce + 6 seeds = 12 items) + 5 forage items (wildroot,
	# emberberry, frostcap, tideshell, driftglass) = 13 + 17 = 30 items;
	# 3 + 6 = 9 crops. Enemies untouched.
	# Craft Stride 1: + 8 cooked dishes = 38 items; + 8 recipes.
	# Craft Stride 2: + 3 forge tools (steel_sword, fangsteel_blade,
	# copper_can) = 41 items.
	# DEPTH stride: + 4 tool-tier capstones (iridium_blade, golden_can,
	# copper_hoe, golden_hoe) = 45 items; + fishing rod + 6 fish species
	# (rivertrout/bluegill/eel/sardine/bass/pufferfish) = 52 items.
	assert_eq(ItemDB.items.size(), 52)
	assert_eq(ItemDB.crops.size(), 9)
	assert_eq(ItemDB.enemies.size(), 4)
	assert_eq(ItemDB.recipes.size(), 8)


func test_typed_lookups() -> void:
	assert_true(ItemDB.get_item("turnip_seeds") is SeedData)
	assert_true(ItemDB.get_item("turnip") is FoodData)
	assert_true(ItemDB.get_item("hoe") is ToolData)
	assert_true(ItemDB.get_crop("pumpkin") is CropData)
	assert_true(ItemDB.get_enemy("slime_king") is EnemyData)
	assert_null(ItemDB.get_item("nonsense"))


func test_forge_tools_resolve_with_contract_stats() -> void:
	## Craft Stride 2 content meta-test: the three forge-only tools exist with
	## the bible's exact stats, are ToolData of the right type, never stack,
	## and are NOT sold at Marta's (buy_price 0 = forge-only).
	var steel := ItemDB.get_item("steel_sword") as ToolData
	assert_not_null(steel)
	assert_eq(steel.tool_type, ToolData.ToolType.SWORD)
	assert_eq(steel.damage, 16)
	assert_eq(steel.max_stack, 1)
	assert_eq(steel.buy_price, 0, "steel_sword must not be sold in the store")

	var fangsteel := ItemDB.get_item("fangsteel_blade") as ToolData
	assert_not_null(fangsteel)
	assert_eq(fangsteel.tool_type, ToolData.ToolType.SWORD)
	assert_eq(fangsteel.damage, 22)
	assert_eq(fangsteel.max_stack, 1)
	assert_eq(fangsteel.buy_price, 0, "fangsteel_blade must not be sold in the store")

	var copper := ItemDB.get_item("copper_can") as ToolData
	assert_not_null(copper)
	assert_eq(copper.tool_type, ToolData.ToolType.WATERING_CAN)
	assert_eq(copper.rp_cost, 3)
	assert_eq(copper.water_width, 3)
	assert_eq(copper.max_stack, 1)
	assert_eq(copper.buy_price, 0, "copper_can must not be sold in the store")


func test_depth_stride_tool_tiers_resolve_with_contract_stats() -> void:
	## DEPTH stride content meta-test: the four new tool-tier capstones exist
	## with the expected stats/types, never stack, and are forge-only.
	var iridium := ItemDB.get_item("iridium_blade") as ToolData
	assert_not_null(iridium)
	assert_eq(iridium.tool_type, ToolData.ToolType.SWORD)
	assert_eq(iridium.damage, 30)
	assert_eq(iridium.max_stack, 1)
	assert_eq(iridium.buy_price, 0)

	var golden_can := ItemDB.get_item("golden_can") as ToolData
	assert_not_null(golden_can)
	assert_eq(golden_can.tool_type, ToolData.ToolType.WATERING_CAN)
	assert_eq(golden_can.water_width, 5)
	assert_eq(golden_can.max_stack, 1)
	assert_eq(golden_can.buy_price, 0)

	var copper_hoe := ItemDB.get_item("copper_hoe") as ToolData
	assert_not_null(copper_hoe)
	assert_eq(copper_hoe.tool_type, ToolData.ToolType.HOE)
	assert_eq(copper_hoe.till_width, 3)
	assert_eq(copper_hoe.max_stack, 1)
	assert_eq(copper_hoe.buy_price, 0)

	var golden_hoe := ItemDB.get_item("golden_hoe") as ToolData
	assert_not_null(golden_hoe)
	assert_eq(golden_hoe.tool_type, ToolData.ToolType.HOE)
	assert_eq(golden_hoe.till_width, 5)
	assert_eq(golden_hoe.max_stack, 1)
	assert_eq(golden_hoe.buy_price, 0)


func test_fishing_rod_resolves_and_is_shop_stock() -> void:
	## DEPTH stride content meta-test: the fishing rod exists, is a
	## FISHING_ROD ToolData, never stacks, and (unlike the forge-only tiers)
	## IS sold at Marta's — see ShopLogic.buyable_items()'s new expected count.
	var rod := ItemDB.get_item("fishing_rod") as ToolData
	assert_not_null(rod)
	assert_eq(rod.tool_type, ToolData.ToolType.FISHING_ROD)
	assert_eq(rod.max_stack, 1)
	assert_gt(rod.buy_price, 0, "fishing rod must be purchasable, unlike forge-only tiers")


func test_all_fish_species_resolve_as_food_and_are_sellable() -> void:
	## DEPTH stride content meta-test: every id FishingLogic's pools can roll
	## must exist in ItemDB as FoodData and be sellable — a fish that resolves
	## to null or can't be sold would silently break the catch-delivery path.
	var all_ids: Array = []
	all_ids.append_array(FishingLogic.RIVER_POOL.keys())
	all_ids.append_array(FishingLogic.SEA_POOL.keys())
	for id: String in all_ids:
		var fish := ItemDB.get_item(id) as FoodData
		assert_not_null(fish, "fish id '%s' must resolve in ItemDB" % id)
		assert_gt(fish.sell_price, 0, "fish id '%s' must be sellable" % id)


func test_existing_watering_can_keeps_width_one() -> void:
	## water_width is a NEW ToolData field defaulting to 1 — the pre-Forge can
	## (and every other regenerated tool) must be unaffected by the copper
	## can's wide-watering behavior.
	assert_eq((ItemDB.get_item("watering_can") as ToolData).water_width, 1)
	assert_eq((ItemDB.get_item("hoe") as ToolData).water_width, 1)


func test_forge_upgrade_table_ids_all_resolve() -> void:
	## Every id ForgeLogic.UPGRADES references (old tool, materials, result)
	## must exist in ItemDB — the forge equivalent of ItemDB.validate()'s
	## recipe check (ForgeLogic upgrades are code data, not .tres, so
	## validate() never sees them).
	for upgrade: Dictionary in ForgeLogic.UPGRADES:
		var old_tool := String(upgrade.get("old_tool", ""))
		if old_tool != "":
			assert_not_null(ItemDB.get_item(old_tool), "unknown old_tool " + old_tool)
		for item_id: String in upgrade.get("materials", {}):
			assert_not_null(ItemDB.get_item(item_id), "unknown material " + item_id)
		assert_not_null(ItemDB.get_item(String(upgrade.get("result_id", ""))),
			"unknown result " + String(upgrade.get("result_id", "")))


func test_seed_links_to_crop_and_product() -> void:
	var seed_item: SeedData = ItemDB.get_item("carrot_seeds")
	var crop: CropData = ItemDB.get_crop(seed_item.crop_id)
	assert_not_null(crop)
	assert_not_null(ItemDB.get_item(crop.product_id))


func test_tools_do_not_stack() -> void:
	assert_eq((ItemDB.get_item("hoe") as ItemData).max_stack, 1)


func test_validate_passes() -> void:
	assert_true(ItemDB.validate())
