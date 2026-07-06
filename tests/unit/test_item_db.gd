extends GutTest


func test_content_loaded() -> void:
	# World Stride A: 6 new crops (strawberry/tomato/corn/melon/eggplant/
	# amberleaf -> 6 produce + 6 seeds = 12 items) + 5 forage items (wildroot,
	# emberberry, frostcap, tideshell, driftglass) = 13 + 17 = 30 items;
	# 3 + 6 = 9 crops. Enemies untouched.
	# Craft Stride 1: + 8 cooked dishes = 38 items; + 8 recipes.
	assert_eq(ItemDB.items.size(), 38)
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


func test_seed_links_to_crop_and_product() -> void:
	var seed_item: SeedData = ItemDB.get_item("carrot_seeds")
	var crop: CropData = ItemDB.get_crop(seed_item.crop_id)
	assert_not_null(crop)
	assert_not_null(ItemDB.get_item(crop.product_id))


func test_tools_do_not_stack() -> void:
	assert_eq((ItemDB.get_item("hoe") as ItemData).max_stack, 1)


func test_validate_passes() -> void:
	assert_true(ItemDB.validate())
