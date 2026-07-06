extends GutTest
## Craft Stride 1: CookingLogic — recipe crafting math (consume/produce,
## full-inventory refusal) + a meta-test that every recipe in ItemDB resolves
## against real ingredient/result ids.


func before_each() -> void:
	Inventory.reset()


# ---- meta-test: every recipe resolves against ItemDB ----

func test_all_recipes_resolve_against_item_db() -> void:
	assert_eq(ItemDB.recipes.size(), 8, "bible table lists 8 dishes")
	for id: String in ItemDB.recipes:
		var recipe: RecipeData = ItemDB.recipes[id]
		assert_not_null(ItemDB.get_item(recipe.result_id),
			"recipe %s -> unknown result %s" % [id, recipe.result_id])
		var result := ItemDB.get_item(recipe.result_id)
		assert_true(result is FoodData, "recipe %s result must be FoodData" % id)
		assert_true((result as FoodData).is_dish, "recipe %s result must be a dish" % id)
		assert_false(recipe.ingredients.is_empty(), "recipe %s has no ingredients" % id)
		for item_id: String in recipe.ingredients:
			assert_not_null(ItemDB.get_item(item_id),
				"recipe %s -> unknown ingredient %s" % [id, item_id])
			assert_gt(int(recipe.ingredients[item_id]), 0,
				"recipe %s ingredient %s must need a positive count" % [id, item_id])


func test_all_recipes_have_positive_sell_price_dishes() -> void:
	for id: String in ItemDB.recipes:
		var recipe: RecipeData = ItemDB.recipes[id]
		var result := ItemDB.get_item(recipe.result_id)
		assert_gt(result.sell_price, 0, "%s should be sellable" % recipe.result_id)


# ---- can_cook ----

func test_can_cook_false_when_missing_ingredients() -> void:
	var recipe := ItemDB.get_recipe("roast_turnip")
	assert_false(CookingLogic.can_cook(recipe))


func test_can_cook_true_when_ingredients_present() -> void:
	Inventory.add_item("turnip", 2)
	var recipe := ItemDB.get_recipe("roast_turnip")
	assert_true(CookingLogic.can_cook(recipe))


func test_can_cook_false_when_partial_ingredients() -> void:
	Inventory.add_item("corn", 2)  # missing the carrot corn_chowder also needs
	var recipe := ItemDB.get_recipe("corn_chowder")
	assert_false(CookingLogic.can_cook(recipe))


# ---- cook: consume + produce ----

func test_cook_consumes_ingredients_and_produces_dish() -> void:
	Inventory.add_item("turnip", 2)
	var recipe := ItemDB.get_recipe("roast_turnip")
	var result := CookingLogic.cook(recipe)
	assert_eq(result, CookingLogic.Result.OK)
	assert_eq(Inventory.count_of("turnip"), 0)
	assert_eq(Inventory.count_of("roast_turnip"), 1)


func test_cook_multi_ingredient_recipe_consumes_each() -> void:
	Inventory.add_item("corn", 2)
	Inventory.add_item("carrot", 1)
	var recipe := ItemDB.get_recipe("corn_chowder")
	var result := CookingLogic.cook(recipe)
	assert_eq(result, CookingLogic.Result.OK)
	assert_eq(Inventory.count_of("corn"), 0)
	assert_eq(Inventory.count_of("carrot"), 0)
	assert_eq(Inventory.count_of("corn_chowder"), 1)


func test_cook_leaves_surplus_ingredients_untouched() -> void:
	Inventory.add_item("turnip", 5)
	var recipe := ItemDB.get_recipe("roast_turnip")
	CookingLogic.cook(recipe)
	assert_eq(Inventory.count_of("turnip"), 3, "only the needed 2 are consumed")


func test_cook_fails_with_missing_ingredients_and_consumes_nothing() -> void:
	Inventory.add_item("turnip", 1)  # roast_turnip needs 2
	var recipe := ItemDB.get_recipe("roast_turnip")
	var result := CookingLogic.cook(recipe)
	assert_eq(result, CookingLogic.Result.MISSING_INGREDIENTS)
	assert_eq(Inventory.count_of("turnip"), 1, "nothing consumed on refusal")
	assert_eq(Inventory.count_of("roast_turnip"), 0)


func test_cook_refuses_when_inventory_full_and_keeps_ingredients() -> void:
	Inventory.add_item("turnip", 2)
	# Fill every remaining slot with a different-id, non-stacking token so
	# the roast_turnip result truly has nowhere to land.
	for i in Inventory.SIZE:
		if Inventory.slots[i] == null:
			Inventory.slots[i] = {"id": "iron_sword", "count": 1}
	var recipe := ItemDB.get_recipe("roast_turnip")
	var result := CookingLogic.cook(recipe)
	assert_eq(result, CookingLogic.Result.INVENTORY_FULL)
	assert_eq(Inventory.count_of("turnip"), 2, "ingredients must survive a full-inventory refusal")
	assert_eq(Inventory.count_of("roast_turnip"), 0)


func test_cook_succeeds_when_result_can_stack_onto_existing_slot() -> void:
	Inventory.add_item("turnip", 2)
	Inventory.add_item("roast_turnip", 1)  # existing stack with room (max_stack 99)
	for i in Inventory.SIZE:
		if Inventory.slots[i] == null:
			Inventory.slots[i] = {"id": "iron_sword", "count": 1}
	var recipe := ItemDB.get_recipe("roast_turnip")
	var result := CookingLogic.cook(recipe)
	assert_eq(result, CookingLogic.Result.OK, "should stack onto the existing roast_turnip slot")
	assert_eq(Inventory.count_of("roast_turnip"), 2)


# ---- all_recipes ----

func test_all_recipes_sorted_by_id() -> void:
	var recipes := CookingLogic.all_recipes()
	var ids: Array = []
	for r: RecipeData in recipes:
		ids.append(r.id)
	var sorted_ids := ids.duplicate()
	sorted_ids.sort()
	assert_eq(ids, sorted_ids)
	assert_eq(recipes.size(), 8)
