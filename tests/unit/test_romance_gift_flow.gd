extends GutTest
## Marriage M1: bouquet/pendant gift-flow wiring in npc.gd — bouquet starts
## dating at L8+ (romanceable only), refuses gently otherwise (item NOT
## consumed on refusal — see npc.gd's _resolve_bouquet_gift doc), and a
## pendant given while dating at L10 triggers the proposal DSL scene instead
## of an ordinary gift. Uses a standalone NPC + DialogBox (same shape as
## test_npc.gd's own gift-flow tests) since these are single-interact
## resolutions, not the multi-scene DSL chain (see test_romance_chain.gd for
## the full pendant->propose->wedding->married E2E through a real town.tscn).

var npc: NPC
var dialog: DialogBox


func before_each() -> void:
	Clock.day = 1
	Clock.minutes = 10 * 60
	Relationships._state = {}
	SaveManager.world.erase("relationships")
	Romance._state = {}
	Romance._spouse = ""
	SaveManager.world.erase("romance")
	GameState.reset_new_game()
	Inventory.reset()

	npc = NPCFactory.make_npc("rosa")
	add_child_autofree(npc)
	dialog = (load("res://scripts/ui/dialog_box.gd") as GDScript).new() as DialogBox
	add_child_autofree(dialog)


func after_each() -> void:
	Clock.day = 1
	Clock.minutes = Clock.DAY_START_MINUTES
	Relationships._state = {}
	SaveManager.world.erase("relationships")
	Romance._state = {}
	Romance._spouse = ""
	SaveManager.world.erase("romance")
	GameState.flags = {}


func _give_selected_item(target: NPC) -> void:
	target.interact(null)
	# Advance through every queued line (a pending level-perk line can
	# prepend the ordinary resolved line — see npc.gd's
	# _grant_pending_perk_if_any()) until the choice buttons appear.
	for i in 10:
		if dialog._showing_choices or not dialog.is_open():
			break
		dialog._advance()
	var labels: Array[String] = []
	for child in dialog.choice_box.get_children():
		labels.append((child as Button).text)
	var idx := -1
	for i in labels.size():
		if labels[i].begins_with("Give "):
			idx = i
			break
	assert_true(idx >= 0, "precondition: a Give choice must be offered")
	(dialog.choice_box.get_child(idx) as Button).pressed.emit()


## ---- bouquet: starts dating at L8+ ----

func test_bouquet_at_l8_starts_dating_and_consumes_item() -> void:
	Relationships._get_or_create("rosa")["points"] = 800  # L8
	Relationships.mark_event_seen("rosa", "l3")
	Relationships.mark_event_seen("rosa", "l7")
	Relationships.mark_event_seen("rosa", "l8")  # clear Rosa's own L8 heart-event gate so talk resolves normally
	Inventory.add_item("bouquet")
	Inventory.select_hotbar(0)
	watch_signals(EventBus)

	_give_selected_item(npc)
	await wait_process_frames(2)

	assert_true(Romance.is_dating("rosa"))
	assert_eq(Inventory.count_of("bouquet"), 0, "bouquet is consumed when dating starts")
	assert_signal_emitted(EventBus, "toast_requested")


func test_bouquet_below_l8_refuses_and_does_not_consume() -> void:
	Relationships._get_or_create("rosa")["points"] = 750  # L7, one level short
	Relationships.mark_event_seen("rosa", "l3")
	Relationships.mark_event_seen("rosa", "l7")  # clear the L7 heart-event gate so talk resolves normally
	Inventory.add_item("bouquet")
	Inventory.select_hotbar(0)

	_give_selected_item(npc)
	await wait_process_frames(2)

	assert_false(Romance.is_dating("rosa"))
	assert_eq(Inventory.count_of("bouquet"), 1, "a refused bouquet must NOT be consumed")


func test_bouquet_to_non_romanceable_npc_refuses_and_does_not_consume() -> void:
	var marta := NPCFactory.make_npc("marta")
	add_child_autofree(marta)
	Relationships._get_or_create("marta")["points"] = 1000  # even at max level
	Relationships.mark_event_seen("marta", "l3")
	Relationships.mark_event_seen("marta", "l7")  # clear Marta's own L7 heart-event gate
	Inventory.add_item("bouquet")
	Inventory.select_hotbar(0)

	_give_selected_item(marta)
	await wait_process_frames(2)

	assert_false(Romance.is_dating("marta"))
	assert_eq(Inventory.count_of("bouquet"), 1, "a refused bouquet must NOT be consumed")


func test_bouquet_gift_does_not_apply_ordinary_bond_math() -> void:
	## A bouquet isn't in anyone's loved/liked/disliked lists — this asserts
	## the special-case branch is taken INSTEAD of Relationships.gift()'s
	## ordinary reaction lookup (which would otherwise just silently apply a
	## "neutral" +20 and mark the gift used for today).
	Relationships._get_or_create("rosa")["points"] = 750
	Relationships.mark_event_seen("rosa", "l3")
	Relationships.mark_event_seen("rosa", "l7")
	Inventory.add_item("bouquet")
	Inventory.select_hotbar(0)

	_give_selected_item(npc)
	await wait_process_frames(2)

	assert_false(Relationships.has_gifted_today("rosa"), "a refused bouquet must not burn today's ordinary gift slot")


## ---- pendant: triggers proposal only when dating at L10 ----

func test_pendant_while_dating_at_l10_triggers_proposal_and_consumes_item() -> void:
	Relationships._get_or_create("rosa")["points"] = 1000  # L10
	Relationships.mark_event_seen("rosa", "l3")
	Relationships.mark_event_seen("rosa", "l7")
	Relationships.mark_event_seen("rosa", "l8")
	Relationships.mark_event_seen("rosa", "l10")
	Romance.start_dating("rosa")
	Inventory.add_item("pendant")
	Inventory.select_hotbar(0)

	_give_selected_item(npc)
	await wait_process_frames(2)

	assert_eq(Inventory.count_of("pendant"), 0, "the pendant is spent the instant the proposal is presented")
	assert_true(GameFlow.cutscene_active, "the proposal DSL scene must be playing")
	# Clean up the still-running scene so it doesn't leak cutscene_active/
	# Clock.paused into a later test (no town map root here to drive it to
	# completion the way test_romance_chain.gd does — this test only asserts
	# that the trigger fires). RomanceEvents.play_proposal() falls back to
	# parenting the EventRunner under `npc` itself when no map_root/current_scene
	# is present (see romance_events.gd's _scene_parent_for doc) — exactly
	# this test's situation (a standalone NPC, no map).
	for child in npc.get_children():
		if child is EventRunner:
			child.free()
	GameFlow.cutscene_active = false
	Clock.paused = false


func test_pendant_while_dating_below_l10_is_an_ordinary_gift() -> void:
	Relationships._get_or_create("rosa")["points"] = 900  # dating-eligible level but not L10
	Relationships.mark_event_seen("rosa", "l3")
	Relationships.mark_event_seen("rosa", "l7")
	Relationships.mark_event_seen("rosa", "l8")
	Romance.start_dating("rosa")
	# start_dating requires L8+; drop back under L10 to isolate the L10 gate.
	Inventory.add_item("pendant")
	Inventory.select_hotbar(0)

	_give_selected_item(npc)
	await wait_process_frames(2)

	assert_false(GameFlow.cutscene_active, "no proposal below L10")
	assert_eq(Inventory.count_of("pendant"), 0, "an ordinary gift still consumes the item")
	assert_true(Relationships.has_gifted_today("rosa"))


func test_pendant_while_not_dating_is_an_ordinary_gift() -> void:
	Relationships._get_or_create("rosa")["points"] = 1000  # L10 but never started dating
	Relationships.mark_event_seen("rosa", "l3")
	Relationships.mark_event_seen("rosa", "l7")
	Relationships.mark_event_seen("rosa", "l8")
	Relationships.mark_event_seen("rosa", "l10")
	Inventory.add_item("pendant")
	Inventory.select_hotbar(0)

	_give_selected_item(npc)
	await wait_process_frames(2)

	assert_false(GameFlow.cutscene_active, "no proposal without dating first")
	assert_true(Relationships.has_gifted_today("rosa"))


## ---- Marriage M1: Rosa's L8/L10 heart events (pilot) ----

func test_rosa_l8_heart_event_triggers_and_gates_normal_talk() -> void:
	Relationships._get_or_create("rosa")["points"] = 800  # L8
	Relationships.mark_event_seen("rosa", "l3")
	Relationships.mark_event_seen("rosa", "l7")
	npc.interact(null)
	assert_true(dialog.is_open())
	assert_eq(dialog.label.text, RosaDialog.DATA["heart_events"]["l8"]["lines"][0])


func test_rosa_l8_heart_event_choice_a_applies_plus_thirty_and_marks_seen() -> void:
	Relationships._get_or_create("rosa")["points"] = 800
	Relationships.mark_event_seen("rosa", "l3")
	Relationships.mark_event_seen("rosa", "l7")
	npc.interact(null)
	dialog._advance()  # reveal the second line
	dialog._advance()  # reveal choice buttons
	(dialog.choice_box.get_child(0) as Button).pressed.emit()
	assert_eq(Relationships.points("rosa"), 830)
	assert_eq(Relationships.pending_event("rosa"), "", "l8 must be marked seen (l10 not yet reachable at L8 points)")


func test_rosa_l10_heart_event_after_l8_seen() -> void:
	Relationships._get_or_create("rosa")["points"] = 1000  # L10
	Relationships.mark_event_seen("rosa", "l3")
	Relationships.mark_event_seen("rosa", "l7")
	Relationships.mark_event_seen("rosa", "l8")
	npc.interact(null)
	assert_eq(dialog.label.text, RosaDialog.DATA["heart_events"]["l10"]["lines"][0])


## ---- Marriage M1: dating dialog resolver hook (Rosa pilot) ----

func test_dating_line_appears_on_ordinary_talk_once_dating() -> void:
	Relationships._get_or_create("rosa")["points"] = 850  # past L8, below L10 — ordinary talk territory
	Relationships.mark_event_seen("rosa", "l3")
	Relationships.mark_event_seen("rosa", "l7")
	Relationships.mark_event_seen("rosa", "l8")
	Relationships.mark_perk_given("rosa", "l5")  # clear both perk lines so they don't prepend
	Relationships.mark_perk_given("rosa", "l8")
	Romance.start_dating("rosa")
	npc.interact(null)
	assert_true(dialog.label.text in RosaDialog.DATA["dating_lines"],
		"once dating, an ordinary talk must surface a dating-flavored line")


func test_dating_line_does_not_appear_before_dating_starts() -> void:
	Relationships._get_or_create("rosa")["points"] = 850
	Relationships.mark_event_seen("rosa", "l3")
	Relationships.mark_event_seen("rosa", "l7")
	Relationships.mark_event_seen("rosa", "l8")
	Relationships.mark_perk_given("rosa", "l5")
	Relationships.mark_perk_given("rosa", "l8")
	npc.interact(null)
	assert_false(dialog.label.text in RosaDialog.DATA["dating_lines"])
