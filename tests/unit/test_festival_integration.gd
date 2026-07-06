extends GutTest
## World Stride D: festival machinery through the REAL town scene — schedule
## override placement (all 8 present, Willow's early leave), plaza decor
## applied/cleared, the Harvest Fair contest via the real Alden node, the
## Sowing stall via the real Marta node, and Winter Star via real NPC nodes.
## Mirrors test_town_npc_integration.gd's shape/cleanup discipline.
##
## NOT covered headless (same documented tradeoff as test_town_npc_integration):
## actual portal travel between scenes.

const TOWN_SCENE := "res://scenes/maps/town.tscn"
const FALL_16 := (2 * 28) + 16  # Fall 16 — Harvest Fair (Clock.DAYS_PER_SEASON == 28)
const SPRING_14 := 14           # Spring 14 — Sowing Festival
const SUMMER_21 := 28 + 21      # Summer 21 — Sunfire Festival


func before_each() -> void:
	Clock.paused = true
	SaveManager.world.erase("relationships")
	SaveManager.world.erase("quests")
	SaveManager.world.erase("festival")
	SaveManager.save_path = "user://test_festival_integration.json"
	SaveManager.new_game()
	Clock.weather = "clear"
	Relationships._state = {}
	Quests._quests = {}
	GameState.flags = {}
	SceneChanger.spawn_name = "default"


func after_each() -> void:
	Clock.paused = false
	Clock.minutes = Clock.DAY_START_MINUTES
	Clock.day = 1
	Clock.weather = "clear"
	Relationships._state = {}
	Quests._quests = {}
	GameState.flags = {}
	SaveManager.world.erase("relationships")
	SaveManager.world.erase("quests")
	SaveManager.world.erase("festival")
	SceneChanger.spawn_name = "default"
	SaveManager.save_path = "user://save1.json"
	if FileAccess.file_exists("user://test_festival_integration.json"):
		DirAccess.remove_absolute("user://test_festival_integration.json")


func _make_town() -> Node2D:
	return (load(TOWN_SCENE) as PackedScene).instantiate()


func _force_close_if_open(dialog: DialogBox) -> void:
	if dialog.is_open():
		dialog._advance()
		if dialog.is_open() and dialog.choice_box.get_child_count() > 0:
			(dialog.choice_box.get_child(dialog.choice_box.get_child_count() - 1) as Button).pressed.emit()


# ---- schedule override ----

func test_all_eight_npcs_present_at_noon_on_harvest_fair() -> void:
	Clock.day = FALL_16
	Clock.minutes = 12 * 60
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	for npc_id: String in NPCFactory.ALL_IDS:
		var npc: NPC = town.npcs[npc_id]
		assert_true(npc.visible, "%s must be visible at the festival at noon" % npc_id)


func test_willow_gone_from_town_at_fifteen_thirty_on_harvest_fair() -> void:
	Clock.day = FALL_16
	Clock.minutes = 12 * 60
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	assert_true(town.npcs["willow"].visible)
	Clock.minutes = int(15.5 * 60)  # 15:30 — mid-block (12-17), tests the festival-phase (not just block) refresh
	EventBus.time_ticked.emit(Clock.hour(), Clock.minute())
	assert_false(town.npcs["willow"].visible, "Willow must be gone from the plaza by 15:30")


func test_sunfire_evening_window_places_npcs_at_twenty_hundred() -> void:
	Clock.day = SUMMER_21
	Clock.minutes = 20 * 60
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	assert_true(town.npcs["rosa"].visible)
	assert_eq(town.npcs["rosa"].position, MapBuilder.cell_center(RosaData.CELL_FESTIVAL))


func test_no_festival_npcs_at_ordinary_positions() -> void:
	Clock.day = FALL_16 + 1  # the day after — no festival
	Clock.minutes = 12 * 60
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	assert_eq(town.npcs["alden"].position, MapBuilder.cell_center(AldenData.CELL_PLAZA_WALK))


# ---- plaza decor ----

func test_decor_applied_on_festival_day() -> void:
	Clock.day = FALL_16
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	var cell: Vector2i = Festival.decor_cells_for(Festival.ID_HARVEST_FAIR)[0]
	assert_ne(town.festival_decor.get_cell_source_id(cell), -1, "decor must be painted on a festival day")


func test_no_decor_on_non_festival_day() -> void:
	Clock.day = FALL_16 + 1
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	for cell: Vector2i in Festival.decor_cells_for(Festival.ID_HARVEST_FAIR):
		assert_eq(town.festival_decor.get_cell_source_id(cell), -1)


func test_decor_cleared_the_day_after_a_festival() -> void:
	Clock.day = FALL_16
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	var cell: Vector2i = Festival.decor_cells_for(Festival.ID_HARVEST_FAIR)[0]
	assert_ne(town.festival_decor.get_cell_source_id(cell), -1)
	Clock.day = FALL_16 + 1
	EventBus.day_passed.emit(Clock.day)
	assert_eq(town.festival_decor.get_cell_source_id(cell), -1, "decor must clear the day after the festival")


# ---- notice board ----

func test_notice_board_interact_shows_next_festival_text() -> void:
	Clock.day = 1
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	watch_signals(EventBus)
	town.notice_board.interact(town.player)
	assert_signal_emitted_with_parameters(EventBus, "toast_requested", [Festival.notice_board_text(1)])


# ---- Harvest Fair contest via real Alden ----

func test_entering_contest_with_alden_first_place() -> void:
	Clock.day = FALL_16
	Clock.minutes = 12 * 60
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	Inventory.reset()
	Inventory.add_item("melon")  # sell_price 320 -> 1st place tier
	Inventory.select_hotbar(0)
	GameState.gold = 0

	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	town.npcs["alden"].interact(town.player)
	assert_true(dialog.is_open())
	dialog._advance()  # reveal choices
	assert_true(dialog.choice_box.get_child_count() > 0)
	var contest_btn: Button = null
	for child in dialog.choice_box.get_children():
		if (child as Button).text.begins_with("Enter the contest with"):
			contest_btn = child
			break
	assert_not_null(contest_btn, "the contest choice must be offered with a crop item selected")
	contest_btn.pressed.emit()
	await wait_process_frames(2)
	_force_close_if_open(dialog)

	assert_eq(GameState.gold, 500)
	assert_eq(Inventory.count_of("melon"), 0, "the entered item must be consumed")
	assert_eq(Relationships.points("sten"), Festival.CONTEST_FIRST_BOND_BONUS,
		"1st place must bump EVERY NPC's bond, not just Alden's")


func test_contest_only_once_per_year() -> void:
	Clock.day = FALL_16
	Clock.minutes = 12 * 60
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	Inventory.reset()
	Inventory.add_item("melon", 2)
	Inventory.select_hotbar(0)

	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	town.npcs["alden"].interact(town.player)
	dialog._advance()
	for child in dialog.choice_box.get_children():
		if (child as Button).text.begins_with("Enter the contest with"):
			child.pressed.emit()
			break
	await wait_process_frames(2)
	_force_close_if_open(dialog)

	# Second interact, same year: no contest choice should be offered again.
	town.npcs["alden"].interact(town.player)
	var offered_again := false
	if dialog.is_open() and dialog._choices.is_empty():
		dialog._advance()
	for child in dialog.choice_box.get_children():
		if (child as Button).text.begins_with("Enter the contest with"):
			offered_again = true
	_force_close_if_open(dialog)
	assert_false(offered_again, "the contest must not be offered twice in the same year")


# ---- Sowing Festival stall via real Marta ----

func test_marta_offers_festival_stall_choice_during_sowing() -> void:
	Clock.day = SPRING_14
	Clock.minutes = 12 * 60
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)

	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	town.npcs["marta"].interact(town.player)
	dialog._advance()
	var stall_offered := false
	var browse_offered := false
	for child in dialog.choice_box.get_children():
		var text: String = (child as Button).text
		if text == "Festival stall":
			stall_offered = true
		if text == "Browse the store":
			browse_offered = true
	assert_true(stall_offered, "Marta must offer the Festival stall choice during Sowing")
	assert_false(browse_offered, "Marta's ordinary store choice must be omitted during festival hours")
	_force_close_if_open(dialog)


func test_festival_stall_opens_shop_with_extra_discount() -> void:
	Clock.day = SPRING_14
	Clock.minutes = 12 * 60
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)

	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	var shop := get_tree().get_first_node_in_group("shop_screen") as ShopScreen
	town.npcs["marta"].interact(town.player)
	dialog._advance()
	for child in dialog.choice_box.get_children():
		if (child as Button).text == "Festival stall":
			child.pressed.emit()
			break
	await wait_process_frames(2)
	assert_true(shop.is_open())
	assert_almost_eq(shop.discount, 0.8, 0.001, "no friendship discount yet at L0, so just the 20% stall discount")
	assert_true(shop.festival_seeds_only)
	shop.close()


# ---- festival +30 bond on talk ----

func test_talking_at_the_festival_grants_festival_bonus() -> void:
	Clock.day = FALL_16
	Clock.minutes = 12 * 60
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	town.npcs["sten"].interact(town.player)
	assert_eq(Relationships.points("sten"), 15 + 30)
	_force_close_if_open(dialog)


# ---- Winter Star via real NPC nodes ----

func test_gifting_winter_star_target_forces_loved_reaction_and_x5() -> void:
	var winter_star_day := (3 * 28) + 24  # Winter 24
	Clock.day = winter_star_day
	Clock.minutes = 12 * 60
	var target_id := WinterStar.target_npc_id()
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	assert_true(town.npcs.has(target_id), "the Winter Star target must be one of the 8 registered NPCs")

	Inventory.reset()
	Inventory.add_item("wisp_dust")  # an item that is NOT loved by most NPCs — forced "loved" should override
	Inventory.select_hotbar(0)

	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	var target_npc: NPC = town.npcs[target_id]
	target_npc.interact(town.player)
	dialog._advance()  # reveal choices
	var gift_btn: Button = null
	for child in dialog.choice_box.get_children():
		if (child as Button).text.begins_with("Give "):
			gift_btn = child
			break
	assert_not_null(gift_btn, "a giftable item must offer the Give choice")
	gift_btn.pressed.emit()
	await wait_process_frames(2)
	_force_close_if_open(dialog)

	# Winter Star uses the normal 10:00-18:00 festival window like Sowing/
	# Harvest Fair, so talk() ALSO gets the +30 festival-attendance bonus on
	# top of the gift's own x5 multiplier: 15 + 30 (talk+festival) + 80*5
	# (loved forced, x5 Winter Star multiplier) = 445.
	assert_eq(Relationships.points(target_id), 15 + 30 + (80 * 5))
	_force_close_if_open(dialog)


func test_receiving_plaza_gift_on_winter_star() -> void:
	var winter_star_day := (3 * 28) + 24
	Clock.day = winter_star_day
	Clock.minutes = 12 * 60
	var gifter_id := WinterStar.plaza_gifter_npc_id()
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)

	Inventory.reset()
	var before_count := Inventory.count_of(NPCFactory.build_data(gifter_id).loved_items[0]) \
		if not NPCFactory.build_data(gifter_id).loved_items.is_empty() else 0
	var before_gold := GameState.gold

	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	var gifter_npc: NPC = town.npcs[gifter_id]
	gifter_npc.interact(town.player)
	_force_close_if_open(dialog)

	var data := NPCFactory.build_data(gifter_id)
	if not data.loved_items.is_empty():
		assert_eq(Inventory.count_of(String(data.loved_items[0])), before_count + 1)
	else:
		assert_eq(GameState.gold, before_gold + 100)
	assert_true(WinterStar.has_received_plaza_gift_today())
