class_name BoatShed
extends Area2D
## Finn's father's boat shed on the beach (World Stride C) — referenced in
## his CLOSE/L7 heart-event dialog ("Dad's boat is still in the shed"). This
## stride ships it as a flavor-only interactable (no shop/inventory effect),
## matching farm/bed.gd's placeholder-toast convention: it's locked, and
## saying so IS the content this phase.

func interact(_player: Node) -> void:
	EventBus.toast_requested.emit("The shed door's locked tight. Someone doesn't want it opened.")
