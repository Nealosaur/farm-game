extends GutTest
## Craft Stride 2: ForgeLogic upgrade matrix — visibility gating (fangsteel
## hidden until sten_masterwork_done), affordability across old-tool/
## materials/gold, and consume+grant semantics including "no state change at
## all on refusal" and "old tool consumed on success". Touches the real
## GameState/Inventory autoloads directly, same convention as
## test_shop_logic.gd/test_cooking.gd.


func before_each() -> void:
	GameState.reset_new_game()
	Inventory.reset()
	GameState.flags = {}


func after_each() -> void:
	GameState.flags = {}


func _stock_steel_upgrade() -> void:
	Inventory.add_item("iron_sword", 1)
	Inventory.add_item("goblin_fang", 3)
	GameState.gold = 800


func _stock_fangsteel_upgrade() -> void:
	Inventory.add_item("steel_sword", 1)
	Inventory.add_item("goblin_fang", 5)
	Inventory.add_item("driftglass", 2)
	GameState.gold = 2000


## ---- visibility (hidden-until-flag gating) ----

func test_visible_upgrades_hides_fangsteel_until_masterwork_flag() -> void:
	var ids: Array[String] = []
	for upgrade: Dictionary in ForgeLogic.visible_upgrades():
		ids.append(String(upgrade["id"]))
	assert_true("steel_sword" in ids)
	assert_true("copper_can" in ids)
	assert_false("fangsteel_blade" in ids, "fangsteel must be hidden until sten_masterwork_done")


func test_visible_upgrades_shows_fangsteel_once_flag_set() -> void:
	GameState.flags["sten_masterwork_done"] = true
	var ids: Array[String] = []
	for upgrade: Dictionary in ForgeLogic.visible_upgrades():
		ids.append(String(upgrade["id"]))
	assert_true("fangsteel_blade" in ids)
	assert_eq(ids.size(), ForgeLogic.UPGRADES.size(),
		"every upgrade is visible once the only gated one (fangsteel) unlocks")


## ---- affordability matrix ----

func test_can_afford_true_when_everything_present() -> void:
	_stock_steel_upgrade()
	assert_true(ForgeLogic.can_afford(ForgeLogic.get_upgrade("steel_sword")))


func test_can_afford_false_when_old_tool_missing() -> void:
	Inventory.add_item("goblin_fang", 3)
	GameState.gold = 800
	assert_false(ForgeLogic.can_afford(ForgeLogic.get_upgrade("steel_sword")))


func test_can_afford_false_when_materials_short() -> void:
	Inventory.add_item("iron_sword", 1)
	Inventory.add_item("goblin_fang", 2)  # needs 3
	GameState.gold = 800
	assert_false(ForgeLogic.can_afford(ForgeLogic.get_upgrade("steel_sword")))


func test_can_afford_false_when_gold_short() -> void:
	Inventory.add_item("iron_sword", 1)
	Inventory.add_item("goblin_fang", 3)
	GameState.gold = 799
	assert_false(ForgeLogic.can_afford(ForgeLogic.get_upgrade("steel_sword")))


## ---- upgrade: consume + grant ----

func test_steel_upgrade_consumes_old_tool_materials_and_gold_and_grants() -> void:
	_stock_steel_upgrade()
	var result := ForgeLogic.upgrade("steel_sword")
	assert_eq(result, ForgeLogic.Result.OK)
	assert_eq(Inventory.count_of("iron_sword"), 0, "old tool must be consumed")
	assert_eq(Inventory.count_of("goblin_fang"), 0, "materials must be consumed")
	assert_eq(GameState.gold, 0, "gold must be spent")
	assert_eq(Inventory.count_of("steel_sword"), 1, "new tool must be granted")


func test_copper_can_upgrade_consumes_watering_can_and_grants_copper() -> void:
	Inventory.add_item("watering_can", 1)
	Inventory.add_item("slime_gel", 3)
	GameState.gold = 500
	var result := ForgeLogic.upgrade("copper_can")
	assert_eq(result, ForgeLogic.Result.OK)
	assert_eq(Inventory.count_of("watering_can"), 0)
	assert_eq(Inventory.count_of("slime_gel"), 0)
	assert_eq(GameState.gold, 0)
	assert_eq(Inventory.count_of("copper_can"), 1)


## ---- DEPTH stride: tool-tier ladder (hoe/can capstones + iridium sword) ----

func test_visible_upgrades_includes_every_new_tier_and_none_are_hidden() -> void:
	var ids: Array[String] = []
	for upgrade: Dictionary in ForgeLogic.visible_upgrades():
		ids.append(String(upgrade["id"]))
	for expected in ["iridium_blade", "golden_can", "copper_hoe", "golden_hoe"]:
		assert_true(expected in ids, "%s must be visible (no hidden_until_flag)" % expected)


func test_iridium_blade_requires_fangsteel_and_grants_iridium() -> void:
	Inventory.add_item("fangsteel_blade", 1)
	Inventory.add_item("wisp_dust", 6)
	Inventory.add_item("driftglass", 4)
	GameState.gold = 3500
	var result := ForgeLogic.upgrade("iridium_blade")
	assert_eq(result, ForgeLogic.Result.OK)
	assert_eq(Inventory.count_of("fangsteel_blade"), 0, "old tool must be consumed")
	assert_eq(Inventory.count_of("wisp_dust"), 0)
	assert_eq(Inventory.count_of("driftglass"), 0)
	assert_eq(GameState.gold, 0)
	assert_eq(Inventory.count_of("iridium_blade"), 1)


func test_iridium_blade_refuses_without_fangsteel() -> void:
	Inventory.add_item("wisp_dust", 6)
	Inventory.add_item("driftglass", 4)
	GameState.gold = 3500
	var result := ForgeLogic.upgrade("iridium_blade")
	assert_eq(result, ForgeLogic.Result.MISSING_OLD_TOOL)
	assert_eq(Inventory.count_of("iridium_blade"), 0)


func test_golden_can_requires_copper_can_and_grants_golden() -> void:
	Inventory.add_item("copper_can", 1)
	Inventory.add_item("slime_gel", 5)
	Inventory.add_item("wisp_dust", 3)
	GameState.gold = 1400
	var result := ForgeLogic.upgrade("golden_can")
	assert_eq(result, ForgeLogic.Result.OK)
	assert_eq(Inventory.count_of("copper_can"), 0)
	assert_eq(Inventory.count_of("golden_can"), 1)
	var golden := ItemDB.get_item("golden_can") as ToolData
	assert_eq(golden.water_width, 5, "golden can must be a wider tier than copper (3)")


func test_golden_can_refuses_without_copper_can() -> void:
	Inventory.add_item("slime_gel", 5)
	Inventory.add_item("wisp_dust", 3)
	GameState.gold = 1400
	var result := ForgeLogic.upgrade("golden_can")
	assert_eq(result, ForgeLogic.Result.MISSING_OLD_TOOL)


func test_copper_hoe_requires_base_hoe_and_grants_copper() -> void:
	Inventory.add_item("hoe", 1)
	Inventory.add_item("slime_gel", 3)
	GameState.gold = 500
	var result := ForgeLogic.upgrade("copper_hoe")
	assert_eq(result, ForgeLogic.Result.OK)
	assert_eq(Inventory.count_of("hoe"), 0)
	assert_eq(Inventory.count_of("copper_hoe"), 1)
	var copper := ItemDB.get_item("copper_hoe") as ToolData
	assert_eq(copper.till_width, 3)


func test_golden_hoe_requires_copper_hoe_and_grants_golden() -> void:
	Inventory.add_item("copper_hoe", 1)
	Inventory.add_item("goblin_fang", 3)
	Inventory.add_item("wisp_dust", 3)
	GameState.gold = 1400
	var result := ForgeLogic.upgrade("golden_hoe")
	assert_eq(result, ForgeLogic.Result.OK)
	assert_eq(Inventory.count_of("copper_hoe"), 0)
	assert_eq(Inventory.count_of("golden_hoe"), 1)
	var golden := ItemDB.get_item("golden_hoe") as ToolData
	assert_eq(golden.till_width, 5, "golden hoe must be a wider tier than copper (3)")


func test_golden_hoe_refuses_without_copper_hoe() -> void:
	Inventory.add_item("goblin_fang", 3)
	Inventory.add_item("wisp_dust", 3)
	GameState.gold = 1400
	var result := ForgeLogic.upgrade("golden_hoe")
	assert_eq(result, ForgeLogic.Result.MISSING_OLD_TOOL)


func test_upgrade_leaves_surplus_materials_untouched() -> void:
	Inventory.add_item("iron_sword", 1)
	Inventory.add_item("goblin_fang", 5)  # 2 surplus
	GameState.gold = 1000                 # 200 surplus
	ForgeLogic.upgrade("steel_sword")
	assert_eq(Inventory.count_of("goblin_fang"), 2)
	assert_eq(GameState.gold, 200)


## ---- refusals: no state change at all ----

func test_upgrade_refuses_when_old_tool_missing_and_consumes_nothing() -> void:
	Inventory.add_item("goblin_fang", 3)
	GameState.gold = 800
	var result := ForgeLogic.upgrade("steel_sword")
	assert_eq(result, ForgeLogic.Result.MISSING_OLD_TOOL)
	assert_eq(Inventory.count_of("goblin_fang"), 3)
	assert_eq(GameState.gold, 800)
	assert_eq(Inventory.count_of("steel_sword"), 0)


func test_upgrade_refuses_when_materials_short_and_consumes_nothing() -> void:
	Inventory.add_item("iron_sword", 1)
	Inventory.add_item("goblin_fang", 2)
	GameState.gold = 800
	var result := ForgeLogic.upgrade("steel_sword")
	assert_eq(result, ForgeLogic.Result.MISSING_MATERIALS)
	assert_eq(Inventory.count_of("iron_sword"), 1)
	assert_eq(Inventory.count_of("goblin_fang"), 2)
	assert_eq(GameState.gold, 800)


func test_upgrade_refuses_when_gold_short_and_consumes_nothing() -> void:
	Inventory.add_item("iron_sword", 1)
	Inventory.add_item("goblin_fang", 3)
	GameState.gold = 799
	var result := ForgeLogic.upgrade("steel_sword")
	assert_eq(result, ForgeLogic.Result.INSUFFICIENT_GOLD)
	assert_eq(Inventory.count_of("iron_sword"), 1)
	assert_eq(Inventory.count_of("goblin_fang"), 3)
	assert_eq(GameState.gold, 799)


func test_unknown_upgrade_id_refuses_without_crashing() -> void:
	assert_eq(ForgeLogic.upgrade("nonsense"), ForgeLogic.Result.MISSING_OLD_TOOL)


## ---- hidden-fangsteel gating on upgrade() itself ----

func test_fangsteel_upgrade_refuses_while_hidden_even_when_affordable() -> void:
	_stock_fangsteel_upgrade()
	var result := ForgeLogic.upgrade("fangsteel_blade")
	assert_eq(result, ForgeLogic.Result.HIDDEN)
	assert_eq(Inventory.count_of("steel_sword"), 1, "hidden refusal must consume nothing")
	assert_eq(Inventory.count_of("goblin_fang"), 5)
	assert_eq(Inventory.count_of("driftglass"), 2)
	assert_eq(GameState.gold, 2000)


func test_fangsteel_upgrade_works_once_masterwork_flag_set() -> void:
	GameState.flags["sten_masterwork_done"] = true
	_stock_fangsteel_upgrade()
	var result := ForgeLogic.upgrade("fangsteel_blade")
	assert_eq(result, ForgeLogic.Result.OK)
	assert_eq(Inventory.count_of("steel_sword"), 0, "steel sword must be consumed")
	assert_eq(Inventory.count_of("goblin_fang"), 0)
	assert_eq(Inventory.count_of("driftglass"), 0)
	assert_eq(GameState.gold, 0)
	assert_eq(Inventory.count_of("fangsteel_blade"), 1)


## ---- inventory-full edge (old tool's slot frees up room) ----

func test_upgrade_succeeds_when_inventory_otherwise_full() -> void:
	## The old tool's own slot frees mid-upgrade, so a completely full
	## inventory still has room for the result — the contract's "guaranteed
	## non-full" case, exercised end-to-end.
	_stock_steel_upgrade()
	# Fill every remaining slot to the brim (iron_sword + goblin_fang already
	# occupy two; 28 slots * 99 turnips fills the rest exactly).
	var leftover := Inventory.add_item("turnip", 28 * 99)
	assert_eq(leftover, 0, "precondition: inventory now completely full")
	var result := ForgeLogic.upgrade("steel_sword")
	assert_eq(result, ForgeLogic.Result.OK)
	assert_eq(Inventory.count_of("steel_sword"), 1)
	assert_eq(Inventory.count_of("iron_sword"), 0)
