class_name HealthComponent
extends Node
## Generic HP pool for anything that isn't the player (player HP lives in
## GameState). Edge-detects the alive->dead transition like GameState.take_damage.

signal damaged(amount: int)
signal died

@export var max_hp: int = 10

var hp: int


func _ready() -> void:
	hp = max_hp


func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	var was_alive := hp > 0
	hp = maxi(0, hp - amount)
	damaged.emit(amount)
	if was_alive and hp == 0:
		died.emit()


func heal(amount: int) -> void:
	if amount <= 0:
		return
	hp = mini(max_hp, hp + amount)


func is_alive() -> bool:
	return hp > 0
