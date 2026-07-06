class_name NoticeBoard
extends Area2D
## Plaza notice board. Bible: "shows next festival + any active quest
## hints" — World Stride D wires the "next festival" half via
## Festival.notice_board_text(), which always has content (there are always
## 4 festivals/year), so the old "Nothing posted yet." stub never shows once
## this is live.

func interact(_player: Node) -> void:
	EventBus.toast_requested.emit(Festival.notice_board_text(Clock.day))
