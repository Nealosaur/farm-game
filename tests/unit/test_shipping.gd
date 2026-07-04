extends GutTest


func test_payout_sums_sell_prices() -> void:
	var bin := {"turnip": 3, "carrot": 2}          # 3*45 + 2*105 = 345
	assert_eq(Shipping.payout(bin), 345)


func test_payout_ignores_unknown_and_unsellable() -> void:
	assert_eq(Shipping.payout({"nonsense": 5}), 0)
	assert_eq(Shipping.payout({}), 0)


func test_bin_interact_ships_selected_stack() -> void:
	SaveManager.world.erase("shipping_bin")
	Inventory.reset()
	Inventory.add_item("turnip", 7)
	Inventory.select_hotbar(0)
	var bin_area = (load("res://scripts/farm/shipping_bin.gd") as GDScript).new()
	add_child_autofree(bin_area)
	bin_area.interact(null)
	assert_eq(Inventory.count_of("turnip"), 0)
	assert_eq(SaveManager.world["shipping_bin"]["turnip"], 7)
	assert_eq(Shipping.payout(SaveManager.world["shipping_bin"]), 7 * 45)
