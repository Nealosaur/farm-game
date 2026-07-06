extends GutTest
## World Stride C: level-perk handout integration — once-only gating (via
## Relationships.pending_perk/mark_perk_given) and the two documented
## permanent max_hp flags (Bram L8, Garrick L8). Uses real NPC nodes (like
## test_npc.gd) rather than calling Relationships directly, so the actual
## npc.gd._grant_pending_perk_if_any() wiring is under test, not just the
## autoload it calls into.

var npc: NPC
var dialog: DialogBox


func before_each() -> void:
	Clock.day = 1
	Clock.minutes = 10 * 60
	Relationships._state = {}
	SaveManager.world.erase("relationships")
	GameState.reset_new_game()
	Inventory.reset()

	dialog = DialogBox.new()
	add_child_autofree(dialog)


func _make_npc(npc_id: String) -> NPC:
	var n := NPCFactory.make_npc(npc_id)
	add_child_autofree(n)
	return n


func _talk_through(target: NPC) -> void:
	## Drives interact() -> resolves whatever lines/choices appear -> closes,
	## so a single call leaves the dialog box ready for the NEXT interact().
	target.interact(null)
	while dialog.is_open():
		if dialog._showing_choices:
			var last := dialog.choice_box.get_child(dialog.choice_box.get_child_count() - 1) as Button
			last.pressed.emit()
		else:
			dialog._advance()
		await wait_process_frames(1)


func test_l5_perk_grants_items_once_and_marks_given() -> void:
	npc = _make_npc("marta")
	Relationships._get_or_create("marta")["points"] = 500  # level 5
	Relationships.mark_event_seen("marta", "l3")  # clear heart-event gate

	assert_eq(Relationships.pending_perk("marta"), "l5")
	await _talk_through(npc)
	assert_eq(Relationships.pending_perk("marta"), "", "l5 perk must be marked given after one talk")

	var found_seeds := false
	for slot in Inventory.slots:
		if slot != null and slot.id == "strawberry_seeds":
			found_seeds = true
	assert_true(found_seeds, "Marta's L5 perk grants 3 strawberry_seeds")


func test_perk_does_not_regrant_on_second_talk_same_day() -> void:
	npc = _make_npc("sten")
	Relationships._get_or_create("sten")["points"] = 500  # level 5
	Relationships.mark_event_seen("sten", "l3")

	var gold_before := GameState.gold
	await _talk_through(npc)
	assert_eq(GameState.gold, gold_before + 150, "Sten's L5 perk grants 150g once")

	# Force a second talk today (talk() itself is once/day, but the perk gate
	# is independent — mark_perk_given must be what prevents a re-grant).
	Relationships._get_or_create("sten")["talked_day"] = -1  # allow talk() to fire again for this check
	await _talk_through(npc)
	assert_eq(GameState.gold, gold_before + 150, "a second talk must not re-grant the same perk")


func test_l8_perk_grants_gold_once_l5_and_l8_are_independent_gates() -> void:
	npc = _make_npc("rosa")
	Relationships._get_or_create("rosa")["points"] = 800  # level 8: both l5 and l8 gates are met
	Relationships.mark_event_seen("rosa", "l3")
	Relationships.mark_event_seen("rosa", "l7")

	# pending_perk() returns "l8" first when both qualify (mirrors pending_event's documented precedence).
	assert_eq(Relationships.pending_perk("rosa"), "l8")
	var gold_before := GameState.gold
	await _talk_through(npc)
	assert_eq(GameState.gold, gold_before + 250, "Rosa's L8 perk grants 250g")
	# l8 is marked given and won't be re-offered, but l5 is a SEPARATE
	# one-time reward that was never granted (the player jumped straight to
	# L8) — pending_perk correctly still reports it pending, same as
	# pending_event's documented "l7 takes precedence... shouldn't happen
	# since l3 is marked seen long before l7" note acknowledges l3 can still
	# be outstanding independently.
	assert_eq(Relationships.pending_perk("rosa"), "l5")


func test_bram_l8_perk_grants_permanent_plus_20_max_hp() -> void:
	npc = _make_npc("bram")
	Relationships._get_or_create("bram")["points"] = 800  # level 8
	Relationships.mark_event_seen("bram", "l3")
	Relationships.mark_event_seen("bram", "l7")

	var max_hp_before := GameState.max_hp
	await _talk_through(npc)
	assert_eq(GameState.max_hp, max_hp_before + 20, "Bram's L8 perk grants +20 max HP")
	# l5 is a separate, still-outstanding reward (see the Rosa test's note above).
	assert_eq(Relationships.pending_perk("bram"), "l5")


func test_garrick_l8_perk_grants_permanent_plus_10_max_hp() -> void:
	npc = _make_npc("garrick")
	Relationships._get_or_create("garrick")["points"] = 800  # level 8
	Relationships.mark_event_seen("garrick", "l3")
	Relationships.mark_event_seen("garrick", "l7")

	var max_hp_before := GameState.max_hp
	await _talk_through(npc)
	assert_eq(GameState.max_hp, max_hp_before + 10, "Garrick's L8 perk grants +10 max HP")


func test_no_perk_pending_below_level_5_does_not_grant_anything() -> void:
	npc = _make_npc("marta")
	Relationships._get_or_create("marta")["points"] = 200  # level 2, below both gates
	assert_eq(Relationships.pending_perk("marta"), "")
	var gold_before := GameState.gold
	await _talk_through(npc)
	assert_eq(GameState.gold, gold_before, "no perk should fire below level 5")
