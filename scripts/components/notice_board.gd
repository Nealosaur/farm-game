class_name NoticeBoard
extends Area2D
## Plaza notice board. Bible: "shows next festival + any active quest hints
## (flavor text, one-liner per season)". The festival half
## (Festival.notice_board_text()) always has content (there are always 4
## festivals/year); the quest-hint half (Quests.notice_board_hint()) is
## appended as a second toast line only when a quest is actually active, so
## a fresh Day 1 (nothing granted yet) still just shows the festival line —
## the old "Nothing posted yet." stub never shows once this is live.

func interact(_player: Node) -> void:
	var lines := PackedStringArray([Festival.notice_board_text(Clock.day)])
	var hint := Quests.notice_board_hint(Clock.season())
	if hint != "":
		lines.append(hint)
	EventBus.toast_requested.emit("\n".join(lines))
