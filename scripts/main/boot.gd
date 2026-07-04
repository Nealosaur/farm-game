extends Node
## Boot: continue if a save exists, else new game, then go to the farm.
## Owns the load-failure fallback per the SaveManager contract.


func _ready() -> void:
	if not SaveManager.load_game():
		SaveManager.new_game()
	SceneChanger.travel.call_deferred("res://scenes/maps/farm.tscn", "default")
