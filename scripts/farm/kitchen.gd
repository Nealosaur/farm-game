extends Area2D
## Interactable: opens the Cooking UI (Craft Stride 1). Placed on the farm
## beside the house (see farm.gd's KITCHEN_CELL / _add_props()).


func interact(_player) -> void:
	var screen := get_tree().get_first_node_in_group("cooking_screen") as CookingScreen
	if screen == null or screen.is_open():
		return
	screen.open()
