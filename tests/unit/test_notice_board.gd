extends GutTest
## World Stride D: NoticeBoard.interact() — festival text always shown,
## quest-hint line appended only when a quest is active.

var board: NoticeBoard


func before_each() -> void:
	Clock.day = 1
	Quests._quests = {}
	SaveManager.world.erase("quests")
	board = (load("res://scripts/components/notice_board.gd") as GDScript).new() as NoticeBoard
	add_child_autofree(board)


func after_each() -> void:
	Clock.day = 1
	Quests._quests = {}
	SaveManager.world.erase("quests")


func test_interact_shows_only_festival_text_when_no_quest_active() -> void:
	watch_signals(EventBus)
	board.interact(null)
	assert_signal_emitted_with_parameters(EventBus, "toast_requested", [Festival.notice_board_text(1)])


func test_interact_appends_quest_hint_when_a_quest_is_active() -> void:
	Quests.grant_new_roots()
	watch_signals(EventBus)
	board.interact(null)
	var expected := Festival.notice_board_text(1) + "\n" + Quests.notice_board_hint(Clock.season())
	assert_signal_emitted_with_parameters(EventBus, "toast_requested", [expected])


func test_quests_notice_board_hint_empty_with_no_active_quest() -> void:
	assert_eq(Quests.notice_board_hint(0), "")


func test_quests_notice_board_hint_mentions_progress() -> void:
	Quests.grant_new_roots()
	Quests.record_talk("marta")
	var hint := Quests.notice_board_hint(0)
	assert_true(hint.contains("Met 1/8"))
