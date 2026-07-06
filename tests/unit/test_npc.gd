extends GutTest
## Marta-as-NPC interact() flow: heart-event gate, ordinary talk + choices
## (gift / browse-store / leave), Relationships wiring, and the L4/L7 shop
## discount. Uses MartaData/MartaDialog (real data) since the resolver's own
## precedence logic is already covered against a fixture in
## test_dialog_resolver.gd — this file is about the NPC wiring, not the data.

var npc: NPC
var dialog: DialogBox
var shop: ShopScreen
var _clock_minutes_before: int


func before_each() -> void:
	_clock_minutes_before = Clock.minutes
	Clock.day = 1
	Relationships._state = {}
	SaveManager.world.erase("relationships")
	GameState.reset_new_game()
	Inventory.reset()

	npc = NPC.new()
	npc.npc_data = MartaData.build()
	npc.dialog_data = MartaDialog.DATA
	npc.has_shop = true
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	npc.add_child(sprite)
	add_child_autofree(npc)

	dialog = (load("res://scripts/ui/dialog_box.gd") as GDScript).new() as DialogBox
	add_child_autofree(dialog)

	shop = (load("res://scripts/ui/shop_screen.gd") as GDScript).new() as ShopScreen
	add_child_autofree(shop)


func after_each() -> void:
	Clock.minutes = _clock_minutes_before
	Clock.day = 1
	Relationships._state = {}
	SaveManager.world.erase("relationships")
	get_tree().paused = false


func _set_hour(h: int) -> void:
	Clock.minutes = h * 60


# ---- ordinary talk ----

func test_interact_opens_dialog_and_grants_talk_points() -> void:
	_set_hour(10)
	npc.interact(null)
	assert_true(dialog.is_open())
	assert_eq(Relationships.points("marta"), 15)


func test_second_interact_same_day_does_not_regrant_points() -> void:
	_set_hour(20)  # outside shop hours so no "Browse the store" choice complicates advancing
	npc.interact(null)
	# Advance through to Leave and close.
	while dialog.is_open():
		dialog._advance()
		if not dialog.is_open():
			break
		if dialog.choice_box.get_child_count() > 0:
			(dialog.choice_box.get_child(dialog.choice_box.get_child_count() - 1) as Button).pressed.emit()
	npc.interact(null)
	assert_eq(Relationships.points("marta"), 15, "second talk same day must not add points again")


func test_interact_offers_leave_choice_always() -> void:
	_set_hour(20)  # closed hours, no giftable item selected -> only "Leave"
	npc.interact(null)
	dialog._advance()  # past the single resolved line -> reveals choice buttons
	assert_eq(dialog.choice_box.get_child_count(), 1)
	assert_eq((dialog.choice_box.get_child(0) as Button).text, "Leave")


func test_interact_offers_browse_store_during_shop_hours_only() -> void:
	_set_hour(10)
	npc.interact(null)
	dialog._advance()
	var labels: Array[String] = []
	for child in dialog.choice_box.get_children():
		labels.append((child as Button).text)
	assert_true("Browse the store" in labels)

	# Close and try again outside hours.
	(dialog.choice_box.get_child(labels.find("Browse the store")) as Button).pressed.emit()
	Clock.day += 1  # fresh talk allowance for a clean second interact
	_set_hour(20)
	npc.interact(null)
	dialog._advance()
	labels = []
	for child in dialog.choice_box.get_children():
		labels.append((child as Button).text)
	assert_false("Browse the store" in labels)


func test_picking_browse_store_opens_shop_with_discount() -> void:
	_set_hour(10)
	Relationships._get_or_create("marta")["points"] = 500  # level 5 (FRIEND) -> 0.95 discount (L4+)
	Relationships.mark_event_seen("marta", "l3")  # clear the L3 heart-event gate so talk proceeds normally
	Relationships.mark_perk_given("marta", "l5")  # clear the L5 perk-handout gate (World Stride C) too
	npc.interact(null)
	dialog._advance()
	var labels: Array[String] = []
	for child in dialog.choice_box.get_children():
		labels.append((child as Button).text)
	var idx := labels.find("Browse the store")
	(dialog.choice_box.get_child(idx) as Button).pressed.emit()
	await wait_process_frames(2)
	assert_true(shop.is_open())
	assert_almost_eq(shop.discount, 0.95, 0.001)


func test_shop_discount_ninety_percent_at_level_seven() -> void:
	Relationships._get_or_create("marta")["points"] = 700
	assert_almost_eq(npc.shop_discount(), 0.90, 0.001)


func test_shop_discount_ninety_five_percent_at_level_four() -> void:
	Relationships._get_or_create("marta")["points"] = 400
	assert_almost_eq(npc.shop_discount(), 0.95, 0.001)


func test_shop_discount_full_price_below_level_four() -> void:
	Relationships._get_or_create("marta")["points"] = 300
	assert_almost_eq(npc.shop_discount(), 1.0, 0.001)


# ---- gift ----

func test_interact_offers_give_choice_for_giftable_held_item() -> void:
	Inventory.add_item("pumpkin")
	Inventory.select_hotbar(0)
	_set_hour(20)
	npc.interact(null)
	dialog._advance()
	var labels: Array[String] = []
	for child in dialog.choice_box.get_children():
		labels.append((child as Button).text)
	assert_true("Give Pumpkin" in labels)


func test_interact_does_not_offer_give_for_tool() -> void:
	Inventory.add_item("hoe")
	Inventory.select_hotbar(0)
	_set_hour(20)
	npc.interact(null)
	dialog._advance()
	var labels: Array[String] = []
	for child in dialog.choice_box.get_children():
		labels.append((child as Button).text)
	for l in labels:
		assert_false(l.begins_with("Give "), "tools must never be offered as gifts")


func test_picking_give_applies_gift_and_removes_item() -> void:
	Inventory.add_item("pumpkin")
	Inventory.select_hotbar(0)
	_set_hour(20)
	npc.interact(null)
	dialog._advance()
	var labels: Array[String] = []
	for child in dialog.choice_box.get_children():
		labels.append((child as Button).text)
	var idx := labels.find("Give Pumpkin")
	(dialog.choice_box.get_child(idx) as Button).pressed.emit()
	await wait_process_frames(2)
	assert_eq(Inventory.count_of("pumpkin"), 0)
	assert_eq(Relationships.points("marta"), 15 + 80, "talk +15 then loved gift +80")
	assert_true(Relationships.has_gifted_today("marta"))


func test_gift_not_offered_twice_same_day() -> void:
	Inventory.add_item("pumpkin", 2)
	Inventory.select_hotbar(0)
	_set_hour(20)
	npc.interact(null)
	dialog._advance()
	var labels: Array[String] = []
	for child in dialog.choice_box.get_children():
		labels.append((child as Button).text)
	(dialog.choice_box.get_child(labels.find("Give Pumpkin")) as Button).pressed.emit()
	await wait_process_frames(2)
	assert_true(dialog.is_open(), "the gift reaction line should be showing")
	dialog._advance()  # close the reaction line dialog before interacting again
	assert_false(dialog.is_open())

	npc.interact(null)
	dialog._advance()
	labels = []
	for child in dialog.choice_box.get_children():
		labels.append((child as Button).text)
	for l in labels:
		assert_false(l.begins_with("Give "), "gift already used today must not be offered again")


# ---- heart events ----

func test_heart_event_l3_triggers_at_level_three_and_gates_the_normal_talk() -> void:
	Relationships._get_or_create("marta")["points"] = 300
	npc.interact(null)
	assert_true(dialog.is_open())
	assert_eq(dialog.label.text, MartaDialog.DATA["heart_events"]["l3"]["lines"][0])


func test_heart_event_choice_a_applies_plus_thirty_and_marks_seen() -> void:
	Relationships._get_or_create("marta")["points"] = 300
	npc.interact(null)
	dialog._advance()  # reveal choice buttons
	(dialog.choice_box.get_child(0) as Button).pressed.emit()  # [A] empathetic
	assert_eq(Relationships.points("marta"), 330)
	assert_eq(Relationships.pending_event("marta"), "", "l3 must be marked seen")


func test_heart_event_choice_b_applies_minus_thirty() -> void:
	Relationships._get_or_create("marta")["points"] = 300
	npc.interact(null)
	dialog._advance()
	(dialog.choice_box.get_child(1) as Button).pressed.emit()  # [B] dismissive
	assert_eq(Relationships.points("marta"), 270)


func test_heart_event_does_not_regrant_talk_points() -> void:
	Relationships._get_or_create("marta")["points"] = 300
	npc.interact(null)
	dialog._advance()
	(dialog.choice_box.get_child(0) as Button).pressed.emit()
	assert_eq(Relationships.points("marta"), 330, "heart event choice must be the ONLY delta — no +15 talk stacked on top")


func test_l7_heart_event_after_l3_seen() -> void:
	Relationships._get_or_create("marta")["points"] = 700
	Relationships.mark_event_seen("marta", "l3")
	npc.interact(null)
	assert_eq(dialog.label.text, MartaDialog.DATA["heart_events"]["l7"]["lines"][0])
