class_name NoticeBoard
extends Area2D
## Plaza notice board (World Stride C). Bible's eventual contract is "shows
## next festival + any active quest hints" — that's World Stride D content
## (festivals/quests aren't implemented yet). This stride ships the
## flavor-toast stub the contract explicitly calls for: interacting always
## shows "Nothing posted yet." via the toast queue, same as any other
## no-op-flavor interactable (see farm/bed.gd's placeholder toast).

func interact(_player: Node) -> void:
	EventBus.toast_requested.emit("Nothing posted yet.")
