extends GutTest
## ShopScreen: open/close pause behavior, buy/sell rows dynamically reflect
## ItemDB/Inventory via ShopLogic (thin-UI contract), and Esc/Tab closes.

var shop: ShopScreen


func before_each() -> void:
	GameState.reset_new_game()
	Inventory.reset()
	shop = (load("res://scripts/ui/shop_screen.gd") as GDScript).new() as ShopScreen
	add_child_autofree(shop)


func after_each() -> void:
	get_tree().paused = false


func test_open_pauses_tree_and_shows_buy_tab_first() -> void:
	shop.open()
	assert_true(shop.is_open())
	assert_true(get_tree().paused)
	assert_eq(shop._tab, ShopScreen.Tab.BUY)


func test_close_unpauses_tree() -> void:
	shop.open()
	shop.close()
	assert_false(shop.is_open())
	assert_false(get_tree().paused)


func test_buy_rows_match_shop_logic_buyable_items() -> void:
	shop.open()
	assert_eq(shop.buy_list.get_child_count(), ShopLogic.buyable_items().size())


func test_sell_rows_match_shop_logic_sellable_stacks() -> void:
	Inventory.add_item("turnip", 3)
	shop.open()
	shop._on_sell_tab_pressed()
	assert_eq(shop.sell_list.get_child_count(), ShopLogic.sellable_stacks().size())
	assert_eq(shop.sell_list.get_child_count(), 1)


func test_buy_button_click_spends_gold_and_adds_item() -> void:
	shop.open()
	var gold_before := GameState.gold
	shop._on_buy_pressed("turnip_seeds")
	assert_eq(GameState.gold, gold_before - 20)
	assert_eq(Inventory.count_of("turnip_seeds"), 1)


func test_sell_button_click_sells_one_by_default() -> void:
	Inventory.add_item("turnip", 5)
	shop.open()
	shop._on_sell_pressed("turnip")
	assert_eq(Inventory.count_of("turnip"), 4)


func test_pause_action_closes_shop() -> void:
	shop.open()
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	shop._unhandled_input(ev)
	assert_false(shop.is_open())
