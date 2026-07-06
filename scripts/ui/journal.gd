class_name Journal
extends CanvasLayer
## Player's journal. Two tabs:
##   SOCIAL — every registered NPC: name, level bar (points/1000), tier
##            name, birthday, talked-today/gifted-today checkmarks.
##   QUESTS — (World Stride D) real quest list: active quests with a
##            progress string (Quests.progress_text), then a completed
##            section for quests that finished but haven't been handed in
##            yet (state == "done" but still present — see quests.gd's
##            "retire on hand-in" contract, meaning anything still in
##            Quests' tracking dict IS either active or awaiting hand-in;
##            nothing shows here once fully handed in).
##
## Key binding: "journal" input action = physical_keycode 75 (K). NOT J (74) —
## J is already bound to use_item (see project.godot). Documented here and in
## the commit message per the stride's own ambiguity note.
##
## Pause convention (matches InventoryScreen/ShopScreen/PauseMenu): tree
## pauses while open, this node keeps processing via PROCESS_MODE_ALWAYS.
## Esc ("pause") or "journal" (K) closes it — same dual-close pattern
## ShopScreen uses for "pause"/"inventory".
##
## Registered-NPC list: NPCS constant below is the "who exists" registry for
## the SOCIAL tab. World Stride C appends all 7 remaining NPCs alongside
## Marta (npc_data.id -> factory.build()); NPCFactory.ALL_IDS/REGISTRY is the
## single source of truth for id -> data-script path everywhere else, but
## this stays a plain path list (matching World Stride B's shape) since the
## SOCIAL tab only ever needs the data half, never the dialog/sprite/has_shop
## bits NPCFactory also carries.

const NPCS := [
	"res://data/npcs/marta.gd",
	"res://data/npcs/sten.gd",
	"res://data/npcs/bram.gd",
	"res://data/npcs/rosa.gd",
	"res://data/npcs/alden.gd",
	"res://data/npcs/finn.gd",
	"res://data/npcs/willow.gd",
	"res://data/npcs/garrick.gd",
]

var tab_container: TabContainer
var social_list: VBoxContainer
var quests_label: Label  # kept for the "no active quests" empty-state text
var quests_list: VBoxContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("journal")
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-140, -110)
	panel.size = Vector2(280, 220)
	add_child(panel)

	tab_container = TabContainer.new()
	tab_container.position = Vector2(8, 8)
	tab_container.size = Vector2(264, 204)
	panel.add_child(tab_container)

	var social_scroll := ScrollContainer.new()
	social_scroll.name = "Social"
	tab_container.add_child(social_scroll)
	social_list = VBoxContainer.new()
	social_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	social_scroll.add_child(social_list)

	var quests_scroll := ScrollContainer.new()
	quests_scroll.name = "Quests"
	tab_container.add_child(quests_scroll)
	quests_list = VBoxContainer.new()
	quests_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quests_scroll.add_child(quests_list)
	quests_label = Label.new()
	quests_label.text = "No active quests"
	quests_list.add_child(quests_label)

	EventBus.relationship_changed.connect(_on_relationship_changed)
	EventBus.quest_updated.connect(_on_quest_updated)


func is_open() -> bool:
	return visible


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func open() -> void:
	if is_open():
		return
	visible = true
	get_tree().paused = true
	_refresh_social()
	_refresh_quests()


func close() -> void:
	if not is_open():
		return
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not is_open():
		return
	if event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func _on_relationship_changed(_npc_id) -> void:
	if is_open():
		_refresh_social()


func _on_quest_updated(_quest_id) -> void:
	if is_open():
		_refresh_quests()


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.free()


func _refresh_social() -> void:
	_clear(social_list)
	for path: String in NPCS:
		var factory: GDScript = load(path)
		var npc: NPCData = factory.build()
		social_list.add_child(_make_npc_row(npc))


func _make_npc_row(npc: NPCData) -> Control:
	var row := VBoxContainer.new()

	var header := Label.new()
	var tier := Relationships.tier_name(npc.id)
	header.text = "%s — %s (Lv %d)" % [npc.display_name, tier, Relationships.level(npc.id)]
	row.add_child(header)

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = Relationships.MAX_POINTS
	bar.value = clampi(Relationships.points(npc.id), 0, Relationships.MAX_POINTS)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(220, 12)
	row.add_child(bar)

	var detail := Label.new()
	var season_name: String = Clock.SEASON_NAMES[npc.birthday_season]
	var talked := "yes" if Relationships.has_talked_today(npc.id) else "no"
	var gifted := "yes" if Relationships.has_gifted_today(npc.id) else "no"
	detail.text = "Birthday: %s %d   Talked today: %s   Gifted today: %s" % [
		season_name, npc.birthday_day, talked, gifted,
	]
	detail.add_theme_font_size_override("font_size", 10)
	row.add_child(detail)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	row.add_child(spacer)

	return row


## ---- QUESTS tab (World Stride D) ----

func _refresh_quests() -> void:
	_clear(quests_list)
	if Clock.is_festival_today() == Festival.ID_WINTER_STAR:
		var winter_star_label := Label.new()
		winter_star_label.text = WinterStar.journal_text()
		winter_star_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		quests_list.add_child(winter_star_label)
		var winter_star_spacer := Control.new()
		winter_star_spacer.custom_minimum_size = Vector2(0, 6)
		quests_list.add_child(winter_star_spacer)

	var active := Quests.active_quest_ids()
	var done := Quests.done_quest_ids()
	if active.is_empty() and done.is_empty():
		quests_label = Label.new()
		quests_label.text = "No active quests"
		quests_list.add_child(quests_label)
		return

	if not active.is_empty():
		var active_header := Label.new()
		active_header.text = "Active"
		quests_list.add_child(active_header)
		for quest_id: String in active:
			quests_list.add_child(_make_quest_row(quest_id, false))

	if not done.is_empty():
		var done_header := Label.new()
		done_header.text = "Completed"
		quests_list.add_child(done_header)
		for quest_id: String in done:
			quests_list.add_child(_make_quest_row(quest_id, true))


func _make_quest_row(quest_id: String, done: bool) -> Control:
	var row := VBoxContainer.new()

	var name_label := Label.new()
	name_label.text = Quests.display_name(quest_id)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(name_label)

	var detail := Label.new()
	var progress := Quests.progress_text(quest_id)
	detail.text = ("Complete — " + progress) if done else progress
	detail.add_theme_font_size_override("font_size", 10)
	row.add_child(detail)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	row.add_child(spacer)

	return row
