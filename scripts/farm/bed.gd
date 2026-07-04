extends Area2D
## Interactable: sleeping ends the day (DayFlow arrives in Task 11).


func interact(_player) -> void:
	var flow := get_tree().get_first_node_in_group("day_flow")
	if flow != null:
		flow.sleep()
	else:
		EventBus.toast_requested.emit("(sleep flow arrives in Task 11)")
