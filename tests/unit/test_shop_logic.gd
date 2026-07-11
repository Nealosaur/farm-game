extends GutTest
## Covers ShopLogic's buy/sell rules and the store-hours gate. UI (ShopScreen)
## stays a thin shell over this, mirroring Shipping/test_shipping.gd.


func before_each() -> void:
	GameState.reset_new_game()
	Inventory.reset()


func after_each() -> void:
	# Two tests below force Clock.day for season-filter coverage — restore
	# the default so later test files see day 1 as they always have.
	Clock.day = 1


# ---- is_open (store-hours gate) ----

func test_is_open_true_within_9_to_5() -> void:
	assert_true(ShopLogic.is_open(9))
	assert_true(ShopLogic.is_open(12))
	assert_true(ShopLogic.is_open(16))


func test_is_open_false_outside_9_to_5() -> void:
	assert_false(ShopLogic.is_open(8))
	assert_false(ShopLogic.is_open(17))
	assert_false(ShopLogic.is_open(0))
	assert_false(ShopLogic.is_open(23))


# ---- buy() ----

func test_buy_success_decrements_gold_and_adds_item() -> void:
	var gold_before := GameState.gold
	var result := ShopLogic.buy("turnip_seeds")
	assert_eq(result, ShopLogic.Result.OK)
	assert_eq(GameState.gold, gold_before - 20)
	assert_eq(Inventory.count_of("turnip_seeds"), 1)


func test_buy_multiple_count() -> void:
	var gold_before := GameState.gold
	var result := ShopLogic.buy("turnip_seeds", 3)
	assert_eq(result, ShopLogic.Result.OK)
	assert_eq(GameState.gold, gold_before - 60)
	assert_eq(Inventory.count_of("turnip_seeds"), 3)


func test_buy_insufficient_gold_is_noop() -> void:
	GameState.gold = 10
	var result := ShopLogic.buy("iron_sword")
	assert_eq(result, ShopLogic.Result.INSUFFICIENT_GOLD)
	assert_eq(GameState.gold, 10)
	assert_eq(Inventory.count_of("iron_sword"), 0)


func test_buy_not_for_sale_item_rejected() -> void:
	var gold_before := GameState.gold
	var result := ShopLogic.buy("turnip")  # sell_price only, no buy_price
	assert_eq(result, ShopLogic.Result.NOT_FOR_SALE)
	assert_eq(GameState.gold, gold_before)


func test_buy_unknown_item_rejected() -> void:
	var result := ShopLogic.buy("nonsense")
	assert_eq(result, ShopLogic.Result.NOT_FOR_SALE)


func test_buy_inventory_full_refunds_gold() -> void:
	# Fill every slot with a full stack of turnip (max_stack 99) so there is
	# no room left for the purchased seed stack.
	for i in Inventory.SIZE:
		Inventory.slots[i] = {"id": "turnip", "count": 99}
	var gold_before := GameState.gold
	var result := ShopLogic.buy("turnip_seeds")
	assert_eq(result, ShopLogic.Result.INVENTORY_FULL)
	assert_eq(GameState.gold, gold_before, "gold must be refunded in full")
	assert_eq(Inventory.count_of("turnip_seeds"), 0)


func test_buy_applies_discount_multiplier() -> void:
	# World Stride B: Marta's L4 discount is 0.95, L7 is 0.90.
	var gold_before := GameState.gold
	var result := ShopLogic.buy("turnip_seeds", 1, 0.95)
	assert_eq(result, ShopLogic.Result.OK)
	assert_eq(GameState.gold, gold_before - 19, "20g * 0.95 = 19g (floored)")


func test_unit_price_floors_the_discount() -> void:
	assert_eq(ShopLogic.unit_price(20, 0.95), 19)
	assert_eq(ShopLogic.unit_price(20, 0.90), 18)
	assert_eq(ShopLogic.unit_price(20, 1.0), 20)


func test_buy_iron_sword_is_purchasable_and_equippable_data() -> void:
	GameState.gold = 5000
	var result := ShopLogic.buy("iron_sword")
	assert_eq(result, ShopLogic.Result.OK)
	assert_eq(Inventory.count_of("iron_sword"), 1)
	var data := Inventory.get_selected_item_data()
	# iron_sword occupies slot 0 in a freshly reset inventory (hotbar slot),
	# so it's immediately selectable/equippable like any tool.
	var found := false
	for s in Inventory.slots:
		if s != null and s.id == "iron_sword":
			found = true
	assert_true(found)
	assert_true(ItemDB.get_item("iron_sword") is ToolData)
	assert_eq((ItemDB.get_item("iron_sword") as ToolData).tool_type, ToolData.ToolType.SWORD)


# ---- sell() ----

func test_sell_removes_item_and_pays_gold() -> void:
	Inventory.add_item("turnip", 5)
	var gold_before := GameState.gold
	var result := ShopLogic.sell("turnip", 5)
	assert_eq(result, ShopLogic.Result.OK)
	assert_eq(Inventory.count_of("turnip"), 0)
	assert_eq(GameState.gold, gold_before + 5 * 45)


func test_sell_default_count_is_one() -> void:
	Inventory.add_item("turnip", 5)
	var gold_before := GameState.gold
	ShopLogic.sell("turnip")
	assert_eq(Inventory.count_of("turnip"), 4)
	assert_eq(GameState.gold, gold_before + 45)


func test_sell_unsellable_item_rejected() -> void:
	Inventory.add_item("hoe")
	var gold_before := GameState.gold
	var result := ShopLogic.sell("hoe")
	assert_eq(result, ShopLogic.Result.UNSELLABLE)
	assert_eq(GameState.gold, gold_before)
	assert_eq(Inventory.count_of("hoe"), 1)


func test_sell_more_than_owned_rejected() -> void:
	Inventory.add_item("turnip", 2)
	var gold_before := GameState.gold
	var result := ShopLogic.sell("turnip", 5)
	assert_eq(result, ShopLogic.Result.NOTHING_TO_SELL)
	assert_eq(GameState.gold, gold_before)
	assert_eq(Inventory.count_of("turnip"), 2)


func test_sell_unknown_item_rejected() -> void:
	var result := ShopLogic.sell("nonsense")
	assert_eq(result, ShopLogic.Result.UNSELLABLE)


# ---- listing helpers ----

func test_buyable_items_includes_seeds_and_iron_sword_only() -> void:
	# World Stride A: buyable_items() now also filters seeds by season (Marta
	# only stocks in-season seeds) — force Spring (day 1) so this test's
	# expectations are stable regardless of which day the suite runs on.
	# Marriage M1: bouquet + pendant are also season-blind Marta stock now
	# (buy_price > 0, like the tools) — +2 to every seasonal count below.
	Clock.day = 1  # Spring, day_of_season 1
	var ids: Array[String] = []
	for item: ItemData in ShopLogic.buyable_items():
		ids.append(item.id)
	assert_true(ids.has("turnip_seeds"))
	assert_true(ids.has("carrot_seeds"))
	assert_true(ids.has("strawberry_seeds"), "strawberry is a spring crop")
	assert_true(ids.has("iron_sword"))
	assert_true(ids.has("fishing_rod"), "DEPTH stride: fishing rod is Marta stock, season-blind")
	assert_true(ids.has("bouquet"), "Marriage M1: bouquet is Marta stock, season-blind")
	assert_true(ids.has("pendant"), "Marriage M1: pendant is Marta stock, season-blind")
	assert_eq(ids.size(), 7, "3 spring seeds + iron sword + fishing rod + bouquet + pendant are buyable in Spring")
	assert_false(ids.has("pumpkin_seeds"), "pumpkin is fall-only, excluded in spring")
	assert_false(ids.has("tomato_seeds"), "tomato is summer-only, excluded in spring")
	assert_false(ids.has("wooden_sword"), "wooden_sword has no buy_price")
	assert_false(ids.has("hoe"), "hoe has no buy_price")


func test_buyable_items_stocks_pumpkin_again_in_fall() -> void:
	# Pumpkin MOVED to fall (World Stride A) — it must leave the spring shelf
	# (asserted above) and come back when its season arrives, with the other
	# fall seeds, while spring/summer seeds rotate out.
	Clock.day = 57  # Fall 1
	var ids: Array[String] = []
	for item: ItemData in ShopLogic.buyable_items():
		ids.append(item.id)
	assert_true(ids.has("pumpkin_seeds"))
	assert_true(ids.has("eggplant_seeds"))
	assert_true(ids.has("amberleaf_seeds"))
	assert_false(ids.has("turnip_seeds"))
	assert_false(ids.has("melon_seeds"))
	assert_true(ids.has("iron_sword"), "non-seed stock is season-blind")


func test_buyable_items_excludes_all_seeds_in_winter() -> void:
	# Winter day: e.g. day 85 = Winter day_of_season 1 (season index 3).
	Clock.day = 85
	assert_eq(Clock.season(), 3, "sanity: day 85 is Winter")
	var ids: Array[String] = []
	for item: ItemData in ShopLogic.buyable_items():
		ids.append(item.id)
	assert_true(ids.has("iron_sword"), "tools are season-blind")
	assert_true(ids.has("fishing_rod"), "tools are season-blind")
	assert_true(ids.has("bouquet"), "Marriage M1: bouquet is season-blind")
	assert_true(ids.has("pendant"), "Marriage M1: pendant is season-blind")
	assert_eq(ids.size(), 4, "no seeds are plantable in winter — only iron sword + fishing rod + bouquet + pendant")


func test_sellable_stacks_merges_across_slots_and_sorts() -> void:
	Inventory.add_item("turnip", 50)
	Inventory.add_item("turnip", 50)   # spills to a 2nd slot; must merge in the total
	Inventory.add_item("carrot", 1)
	var stacks := ShopLogic.sellable_stacks()
	var by_id := {}
	for s: Dictionary in stacks:
		by_id[s["id"]] = s["count"]
	assert_eq(by_id["turnip"], 100)
	assert_eq(by_id["carrot"], 1)


func test_sellable_stacks_excludes_unsellable_items() -> void:
	Inventory.add_item("hoe")
	Inventory.add_item("turnip", 2)
	var stacks := ShopLogic.sellable_stacks()
	var ids: Array[String] = []
	for s: Dictionary in stacks:
		ids.append(s["id"])
	assert_false(ids.has("hoe"), "hoe has no sell_price and must be excluded")
	assert_true(ids.has("turnip"))
